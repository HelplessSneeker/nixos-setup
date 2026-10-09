# LFCS-Lab-VM -- Uebungsflaeche fuer den LFCS-Stoff (Runbook im bfn-wiki:
# runbooks/2026-10-06 - LFCS-Lab-VM auf fabricus-itinerans.md).
# Importiert NUR von hosts/fabricus-itinerans/configuration.nix.
#
# BAUART, kurz (die Begruendung steht im Runbook):
#   - kein libvirt: die Gruppe libvirtd ist root-gleich, aus demselben Grund
#     wie docker (siehe modules/agent-user.nix). QEMU laeuft direkt als
#     unprivilegierter System-User `lfcs-lab`.
#   - Arbeitsstand bleibt, bis jemand zuruecksetzt (seit 09.10.2026, davor
#     `-snapshot`). Jede Platte bekommt ein eigenes qcow2-Overlay
#     work-<platte>.qcow2 mit dem Golden-Image als Backing-File; QEMU schreibt
#     nur dorthin. Stop, Neustart des Laptops, `poweroff` im Gast: alles
#     bleibt. Stoppen faehrt den Gast per ACPI sauber herunter (QMP
#     system_powerdown), erst nach 60 s hart.
#     Reset = lfcs-lab-reset.service: stoppt die VM, loescht die Overlays,
#     der naechste Start legt sie leer neu an.
#   - Das Golden-Image baut lfcs-lab-build.service aus einem per Hash
#     gepinnten Ubuntu-Cloud-Image und cloud-init. Nie von Hand aendern --
#     Aenderungen laufen ueber userData unten und einen neuen Build.
#   - User-Netz statt Bridge: kein NetworkManager, keine Firewall-Ports.
#     primus kommt per `ssh -J fabricus-itinerans` hin -- Tailscale SSH
#     erlaubt das Port-Forwarding, am 09.10.2026 vor dem Bau gemessen.
#   - Start bei Bedarf (seit 09.10.2026): systemd lauscht selbst auf
#     127.0.0.1:2222. Die erste Verbindung startet die VM, wartet auf den
#     Gast-sshd und reicht dann an QEMUs internen Port 2322 weiter
#     (systemd-socket-proxyd). Gestoppt wird NIE automatisch -- ein
#     Leerlauf-Stopp wuerde nach einer Pause die Arbeit im Gast verwerfen.
#   - skitarii und bfn duerfen die drei Dienste starten/stoppen (Polkit
#     unten), sonst nichts -- skitarii ohne sudo, ohne wheel.
#
# Bedienung: Befehl `vm` aus home/lfcs.nix (`vm help`),
# oder direkt:
#   ssh lfcs                         # startet die VM bei Bedarf, ~10 s
#   systemctl stop lfcs-lab          # VM sauber aus, Arbeitsstand bleibt
#   systemctl start lfcs-lab-reset   # zurueck auf das Golden-Image
#   systemctl start lfcs-lab-build   # Golden-Image (neu) bauen, ~2 min (gemessen 76 s)
#   (`systemctl restart lfcs-lab` ist nur noch ein Neustart, KEIN Reset)
{ config, pkgs, lib, ... }:
let
  stateDir = "/var/lib/lfcs-lab";
  runDir = "/run/lfcs-lab";
  # Aussen lauscht systemd (Socket unten), innen QEMUs hostfwd.
  sshPort = 2222;
  innerPort = 2322;
  qemu = pkgs.qemu_kvm;

  # Fester Release-Pfad, NICHT current/ -- sonst bricht der Hash beim naechsten
  # Image. Ubuntu raeumt alte Serials nach einigen Monaten weg: faellt der
  # Download irgendwann mit 404 aus, Serial + Hash aus
  # https://cloud-images.ubuntu.com/releases/noble/ anheben (SHA256SUMS).
  # Solange die Datei im Store liegt, betrifft das nur einen frischen Rebuild.
  # 24.04, weil die Linux Foundation keine Pruefungsversion nennt (06.10.2026).
  image = pkgs.fetchurl {
    url = "https://cloud-images.ubuntu.com/releases/noble/release-20260926/ubuntu-24.04-server-cloudimg-amd64.img";
    sha256 = "6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2";
  };

  # Feste MACs, im Build und im Betrieb identisch. cloud-init schreibt beim
  # Build eine netplan-Datei, die auf die MAC der ersten Karte matcht -- mit
  # anderer MAC im Betrieb haette der Gast kein Netz. Die beiden anderen Karten
  # bleiben unkonfiguriert, die sind Uebungsmaterial (Bond/Bridge/statisch).
  macs = [ "52:54:00:4c:46:01" "52:54:00:4c:46:02" "52:54:00:4c:46:03" ];

  # Public Keys, duerfen ins oeffentliche Repo.
  #   - bfn: 1Password-Eintrag "cogitator-prime", derselbe Key wie in
  #     home/ssh.nix. Auf dem Laptop und auf fabricus im Agent.
  #   - skitarii@primus: damit Primus die Aufgaben per ssh pruefen kann.
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESznCeiuvFIcwB58RTCMe3ALD6kn95vn0KKDhk5pNVV cogitator-prime"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgwlg6AR8S63vxQnvfkQZ+kpm7LhqhIQig49+dXJNSJ skitarii@primus"
  ];

  # Laeuft genau einmal, beim Build. Am Ende schaltet sich cloud-init selbst
  # ab und faehrt den Gast herunter -- QEMU beendet sich, der Build ist fertig.
  #
  # apt-daily/-upgrade werden zusaetzlich zu unattended-upgrades maskiert:
  # apt-daily.service zieht kurz nach dem Boot die Paketlisten und haelt dabei
  # den apt-Lock. Nach jedem Reset wuerde das die ersten Minuten eines Slots
  # blockieren (`apt install nginx` -> "Could not get lock").
  #
  # Die Markerzeile auf ttyS0 ist die Erfolgsmeldung an das Build-Skript:
  # cloud-init faehrt auch bei Fehlern herunter, ohne Marker gilt der Build
  # als gescheitert und das alte Golden-Image bleibt stehen.
  # Als JSON geschrieben -- JSON ist gueltiges YAML, und so kann keine
  # Einrueckung im Nix-String die Struktur verbiegen.
  userData = pkgs.writeText "user-data" ("#cloud-config\n" + builtins.toJSON {
    hostname = "lfcs-lab";
    preserve_hostname = false;
    # Sonst UTC -- Cron-Aufgaben (O4) und Log-Zeitstempel liefen dann zwei
    # Stunden neben der Uhr an der Wand.
    timezone = "Europe/Vienna";
    ssh_pwauth = false;
    users = [{
      name = "bfn";
      shell = "/bin/bash";
      lock_passwd = true;
      sudo = "ALL=(ALL) NOPASSWD:ALL";
      ssh_authorized_keys = sshKeys;
    }];
    package_update = true;
    package_upgrade = true;
    packages = [ "qemu-guest-agent" ];
    runcmd = [
      [ "apt-get" "purge" "-y" "unattended-upgrades" ]
      [ "systemctl" "mask" "apt-daily.timer" "apt-daily-upgrade.timer" "apt-daily.service" "apt-daily-upgrade.service" ]
      [ "apt-get" "clean" ]
      [ "touch" "/etc/cloud/cloud-init.disabled" ]
      [ "sh" "-c" "dpkg -s qemu-guest-agent >/dev/null && ! dpkg -s unattended-upgrades >/dev/null 2>&1 && echo LFCS-BUILD-OK > /dev/ttyS0" ]
    ];
    power_state = { mode = "poweroff"; condition = true; timeout = 120; };
  });

  metaData = pkgs.writeText "meta-data" ''
    instance-id: lfcs-lab
    local-hostname: lfcs-lab
  '';

  disks = [ "root" "vdb" "vdc" ];

  # Gemeinsame QEMU-Argumente fuer Build und Betrieb. vda/vdb/vdc folgen der
  # Reihenfolge auf der Kommandozeile -- nicht umsortieren.
  # `file` bildet den Plattennamen auf die Datei ab: der Build schreibt in
  # <platte>.qcow2.new, der Betrieb in die Overlays work-<platte>.qcow2.
  # -nodefaults: ohne ihn haengt QEMU Diskette (fd0) und CD-Laufwerk (sr0) an,
  # die dann in jedem `lsblk` der Storage-Aufgaben herumstehen.
  baseArgs = file: [
    "-nodefaults"
    "-enable-kvm" "-cpu" "host" "-smp" "2" "-m" "2048"
    "-display" "none" "-monitor" "none" "-serial" "stdio"
  ] ++ lib.concatMap (d: [ "-drive" "file=${stateDir}/${file d},if=virtio,format=qcow2" ]) disks;
  nicArgs = [
    "-nic" "user,model=virtio-net-pci,mac=${builtins.elemAt macs 0},hostfwd=tcp:127.0.0.1:${toString innerPort}-:22"
    "-nic" "user,model=virtio-net-pci,mac=${builtins.elemAt macs 1},restrict=on"
    "-nic" "user,model=virtio-net-pci,mac=${builtins.elemAt macs 2},restrict=on"
  ];
  # QMP nur fuer das saubere Herunterfahren beim Stop (stopScript unten).
  qmpArgs = [ "-qmp" "unix:${runDir}/qmp.sock,server=on,wait=off" ];
  qgaArgs = [
    "-chardev" "socket,path=${runDir}/qga.sock,server=on,wait=off,id=qga0"
    "-device" "virtio-serial"
    "-device" "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
  ];

  # Baut in *.new-Dateien und tauscht erst nach erfolgreichem Build -- ein
  # abgebrochener Build laesst das bestehende Golden-Image stehen.
  buildScript = pkgs.writeShellScript "lfcs-lab-build" ''
    set -euo pipefail
    cd ${stateDir}
    rm -f -- *.new seed.iso build-serial.log

    qemu-img convert -O qcow2 ${image} root.qcow2.new
    qemu-img resize -q root.qcow2.new 20G
    qemu-img create -q -f qcow2 vdb.qcow2.new 5G
    qemu-img create -q -f qcow2 vdc.qcow2.new 5G

    install -m 0644 ${userData} user-data
    install -m 0644 ${metaData} meta-data
    genisoimage -quiet -output seed.iso -volid cidata -joliet -rock user-data meta-data
    rm -f user-data meta-data

    # Ohne -snapshot: cloud-init schreibt ins Golden-Image. Seed als vierte
    # Platte (vdd), damit vda-vdc dieselben bleiben wie im Betrieb.
    timeout 45m qemu-system-x86_64 \
      ${lib.escapeShellArgs (baseArgs (d: "${d}.qcow2.new"))} \
      -drive file=seed.iso,if=virtio,format=raw,readonly=on \
      ${lib.escapeShellArgs nicArgs} \
      | tee build-serial.log

    rm -f seed.iso
    if ! grep -q LFCS-BUILD-OK build-serial.log; then
      echo "cloud-init hat den Erfolgsmarker nicht geschrieben -- Build verworfen, siehe ${stateDir}/build-serial.log" >&2
      rm -f -- *.new
      exit 1
    fi
    for f in root vdb vdc; do mv -f "$f.qcow2.new" "$f.qcow2"; done
    chmod 0640 root.qcow2 vdb.qcow2 vdc.qcow2
    # Die Overlays haengen am alten Golden-Image und waeren jetzt Muell.
    rm -f work-root.qcow2 work-vdb.qcow2 work-vdc.qcow2
    echo "Golden-Image fertig: $(stat -c '%y' root.qcow2)"
  '';

  # Build und Betrieb schliessen sich aus: der Build ueberschreibt die Images,
  # auf denen die VM sitzt. Frueher per `conflicts` -- das hat aber die
  # falsche Richtung: eine ssh-Verbindung waehrend eines Builds haette ueber
  # den Socket die VM gestartet und damit den Build abgeschossen.
  guard = other: pkgs.writeShellScript "lfcs-lab-guard-${other}" ''
    state=$(systemctl show -p ActiveState --value ${other}.service)
    case "$state" in inactive|failed) exit 0 ;; esac
    echo "${other}.service ist $state -- erst abwarten oder stoppen" >&2
    exit 1
  '';

  # Legt fehlende Overlays an -- nach einem Reset oder dem ersten Build.
  # Backing-Pfad absolut, damit qemu-img/QEMU ihn unabhaengig vom cwd finden.
  overlayScript = pkgs.writeShellScript "lfcs-lab-overlays" ''
    set -eu
    cd ${stateDir}
    for d in ${toString disks}; do
      [ -e "work-$d.qcow2" ] && continue
      qemu-img create -q -f qcow2 -b "${stateDir}/$d.qcow2" -F qcow2 "work-$d.qcow2"
      echo "Overlay work-$d.qcow2 neu angelegt"
    done
  '';

  # ACPI-Power-Knopf statt SIGTERM: der Gast faehrt sauber herunter, QEMU
  # beendet sich dann selbst. Haengt der Gast, kommt nach 60 s systemds
  # SIGTERM -- das Overlay bleibt dabei lesbar, der Gast sieht einen Stromausfall.
  # stdin bleibt eine Sekunde offen, sonst schliesst socat vor der Antwort
  # (dieselbe Falle wie beim Guest-Agent).
  stopScript = pkgs.writeShellScript "lfcs-lab-stop" ''
    (printf '{"execute":"qmp_capabilities"}\n{"execute":"system_powerdown"}\n'; sleep 1) \
      | socat - UNIX-CONNECT:${runDir}/qmp.sock >/dev/null 2>&1 || true
    pid=''${MAINPID:-}
    [ -n "$pid" ] || exit 0
    for _ in $(seq 1 60); do
      kill -0 "$pid" 2>/dev/null || exit 0
      sleep 1
    done
    echo "Gast nach 60 s nicht heruntergefahren -- harter Stopp" >&2
  '';

  resetScript = pkgs.writeShellScript "lfcs-lab-reset" ''
    set -eu
    cd ${stateDir}
    rm -f work-root.qcow2 work-vdb.qcow2 work-vdc.qcow2
    echo "Arbeitsstand verworfen, naechster Start beginnt beim Golden-Image"
  '';

  # Haelt die erste Verbindung im Socket fest, bis der Gast-sshd sein Banner
  # schickt. Ohne das nimmt slirp die Verbindung waehrend des Boots an und
  # schliesst sie sofort wieder -- ssh meldet dann "Connection closed".
  waitSsh = pkgs.writeShellScript "lfcs-lab-wait-ssh" ''
    for _ in $(seq 1 120); do
      if timeout 2 ${pkgs.bash}/bin/bash -c 'exec 3<>/dev/tcp/127.0.0.1/${toString innerPort} && head -c 4 <&3' 2>/dev/null \
          | grep -q '^SSH-'; then
        exit 0
      fi
      sleep 1
    done
    echo "Gast-sshd nach 120 s nicht erreichbar" >&2
    exit 1
  '';
in
{
  users.groups.lfcs-lab = { };
  users.users.lfcs-lab = {
    isSystemUser = true;
    group = "lfcs-lab";
    home = stateDir;
    # /dev/kvm ist auf diesem Host 0666, die Gruppe kvm ist trotzdem der
    # saubere Weg, falls sich die udev-Regel je aendert.
    extraGroups = [ "kvm" ];
  };

  # Gruppe lfcs-lab gibt skitarii Zugriff auf den Guest-Agent-Socket -- sonst
  # auf nichts (stateDir ist 0750, die Images 0640, lesend reicht).
  users.users.skitarii.extraGroups = [ "lfcs-lab" ];
  # bfn: damit `vm status` Golden-Image und Arbeitsstand sehen kann.
  users.users.bfn.extraGroups = [ "lfcs-lab" ];

  systemd.tmpfiles.rules = [ "d ${stateDir} 0750 lfcs-lab lfcs-lab -" ];

  systemd.services.lfcs-lab-build = {
    description = "LFCS-Lab: Golden-Image aus Ubuntu-Cloud-Image bauen";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ qemu pkgs.cdrkit pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "oneshot";
      User = "lfcs-lab";
      Group = "lfcs-lab";
      WorkingDirectory = stateDir;
      ExecStartPre = guard "lfcs-lab";
      ExecStart = buildScript;
      TimeoutStartSec = "50min";
      PrivateTmp = true;
    };
    # Kein wantedBy -- laeuft nur auf Anforderung.
  };

  systemd.services.lfcs-lab = {
    description = "LFCS-Lab-VM (QEMU, Arbeitsstand in Overlays, Gast-ssh intern auf 127.0.0.1:${toString innerPort})";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "${stateDir}/root.qcow2";
    path = [ qemu pkgs.coreutils pkgs.socat ];
    serviceConfig = {
      User = "lfcs-lab";
      Group = "lfcs-lab";
      WorkingDirectory = stateDir;
      RuntimeDirectory = "lfcs-lab";
      RuntimeDirectoryMode = "0750";
      # Socket gruppenschreibbar, sonst kann skitarii den Guest-Agent nicht
      # ansprechen.
      UMask = "0007";
      PrivateTmp = true;
      ExecStartPre = [ (guard "lfcs-lab-build") overlayScript ];
      ExecStart = "${qemu}/bin/qemu-system-x86_64 ${lib.escapeShellArgs (baseArgs (d: "work-${d}.qcow2") ++ nicArgs ++ qmpArgs ++ qgaArgs)}";
      ExecStop = stopScript;
      TimeoutStopSec = "90s";
      Restart = "no";
    };
    # Kein wantedBy -- die VM laeuft nur, wenn jemand sie startet, direkt
    # oder ueber den Socket unten.
  };

  # Reset: Conflicts stoppt die VM (sauber, ueber ExecStop), After sorgt
  # dafuer, dass das Loeschen erst danach laeuft.
  systemd.services.lfcs-lab-reset = {
    description = "LFCS-Lab: Arbeitsstand verwerfen, zurueck auf das Golden-Image";
    conflicts = [ "lfcs-lab.service" ];
    after = [ "lfcs-lab.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "lfcs-lab";
      Group = "lfcs-lab";
      ExecStart = resetScript;
    };
  };

  # Eingang fuer `ssh lfcs`. Der Socket laeuft immer (nur Loopback), die VM
  # erst bei der ersten Verbindung.
  systemd.sockets.lfcs-lab-ssh = {
    description = "LFCS-Lab: ssh-Eingang 127.0.0.1:${toString sshPort}, startet die VM bei Bedarf";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString sshPort}" ];
  };

  # bindsTo: geht die VM aus (stop/restart), geht der Proxy mit. Die naechste
  # Verbindung startet ihn ueber den Socket neu.
  systemd.services.lfcs-lab-ssh = {
    description = "LFCS-Lab: ssh-Weiterleitung in den Gast";
    bindsTo = [ "lfcs-lab.service" ];
    after = [ "lfcs-lab.service" ];
    path = [ pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      DynamicUser = true;
      ExecStartPre = waitSsh;
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString innerPort}";
      TimeoutStartSec = "150s";
    };
  };

  # skitarii und bfn duerfen genau diese vier Units starten, stoppen, neu
  # starten. bfn hat zwar wheel, braeuchte dafuer aber sudo bzw. einen
  # Polkit-Dialog -- ueber ssh von fabricus aus gibt es keinen.
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          (subject.user == "skitarii" || subject.user == "bfn")) {
        var unit = action.lookup("unit");
        var verb = action.lookup("verb");
        if ((unit == "lfcs-lab.service" || unit == "lfcs-lab-build.service" ||
             unit == "lfcs-lab-ssh.service" || unit == "lfcs-lab-reset.service") &&
            (verb == "start" || verb == "stop" || verb == "restart")) {
          return polkit.Result.YES;
        }
      }
    });
  '';

  # Fuer den Guest-Agent-Weg, wenn bfn im Gast ssh abgeschossen hat:
  #   echo '{"execute":"guest-ping"}' | socat - UNIX-CONNECT:/run/lfcs-lab/qga.sock
  environment.systemPackages = [ pkgs.socat ];
}
