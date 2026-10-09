# LFCS-Lab-VM -- Uebungsflaeche fuer den LFCS-Stoff (Runbook im bfn-wiki:
# runbooks/2026-10-06 - LFCS-Lab-VM auf fabricus-itinerans.md).
# Importiert NUR von hosts/fabricus-itinerans/configuration.nix.
#
# BAUART, kurz (die Begruendung steht im Runbook):
#   - kein libvirt: die Gruppe libvirtd ist root-gleich, aus demselben Grund
#     wie docker (siehe modules/agent-user.nix). QEMU laeuft direkt als
#     unprivilegierter System-User `lfcs-lab`.
#   - Reset = Neustart. lfcs-lab.service startet QEMU mit `-snapshot`, alle
#     Schreibzugriffe landen in Overlays unter dem privaten /var/tmp des
#     Dienstes. Reboots IM Gast ueberleben sie (der QEMU-Prozess laeuft
#     weiter), erst `systemctl restart lfcs-lab` verwirft alles.
#   - Das Golden-Image baut lfcs-lab-build.service aus einem per Hash
#     gepinnten Ubuntu-Cloud-Image und cloud-init. Nie von Hand aendern --
#     Aenderungen laufen ueber userData unten und einen neuen Build.
#   - User-Netz statt Bridge: kein NetworkManager, keine Firewall-Ports.
#     Gast-sshd am Host nur auf 127.0.0.1:2222. primus kommt per
#     `ssh -J fabricus-itinerans` hin -- Tailscale SSH erlaubt das
#     Port-Forwarding, am 09.10.2026 vor dem Bau gemessen.
#   - skitarii darf genau die zwei Units starten/stoppen (Polkit unten),
#     sonst nichts -- kein sudo, kein wheel.
#
# Bedienung:
#   systemctl start lfcs-lab-build   # Golden-Image (neu) bauen, ~2 min (gemessen 76 s)
#   systemctl start lfcs-lab         # VM an,  danach `ssh lfcs`
#   systemctl restart lfcs-lab       # Reset auf das Golden-Image
#   systemctl stop lfcs-lab          # VM aus, Overlays weg
{ config, pkgs, lib, ... }:
let
  stateDir = "/var/lib/lfcs-lab";
  runDir = "/run/lfcs-lab";
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

  # Gemeinsame QEMU-Argumente fuer Build und Betrieb. vda/vdb/vdc folgen der
  # Reihenfolge auf der Kommandozeile -- nicht umsortieren.
  # `sfx` haengt der Build an (".new"), der Betrieb nicht.
  # -nodefaults: ohne ihn haengt QEMU Diskette (fd0) und CD-Laufwerk (sr0) an,
  # die dann in jedem `lsblk` der Storage-Aufgaben herumstehen.
  baseArgs = sfx: [
    "-nodefaults"
    "-enable-kvm" "-cpu" "host" "-smp" "2" "-m" "2048"
    "-display" "none" "-monitor" "none" "-serial" "stdio"
  ] ++ lib.concatMap (d: [ "-drive" "file=${stateDir}/${d}.qcow2${sfx},if=virtio,format=qcow2" ])
    [ "root" "vdb" "vdc" ];
  nicArgs = [
    "-nic" "user,model=virtio-net-pci,mac=${builtins.elemAt macs 0},hostfwd=tcp:127.0.0.1:2222-:22"
    "-nic" "user,model=virtio-net-pci,mac=${builtins.elemAt macs 1},restrict=on"
    "-nic" "user,model=virtio-net-pci,mac=${builtins.elemAt macs 2},restrict=on"
  ];
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
      ${lib.escapeShellArgs (baseArgs ".new")} \
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
    echo "Golden-Image fertig: $(stat -c '%y' root.qcow2)"
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

  systemd.tmpfiles.rules = [ "d ${stateDir} 0750 lfcs-lab lfcs-lab -" ];

  systemd.services.lfcs-lab-build = {
    description = "LFCS-Lab: Golden-Image aus Ubuntu-Cloud-Image bauen";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Ein Build ueberschreibt die Images, auf denen eine laufende VM sitzt.
    conflicts = [ "lfcs-lab.service" ];
    path = [ qemu pkgs.cdrkit pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "oneshot";
      User = "lfcs-lab";
      Group = "lfcs-lab";
      WorkingDirectory = stateDir;
      ExecStart = buildScript;
      TimeoutStartSec = "50min";
      PrivateTmp = true;
    };
    # Kein wantedBy -- laeuft nur auf Anforderung.
  };

  systemd.services.lfcs-lab = {
    description = "LFCS-Lab-VM (QEMU, -snapshot, ssh auf 127.0.0.1:2222)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "${stateDir}/root.qcow2";
    serviceConfig = {
      User = "lfcs-lab";
      Group = "lfcs-lab";
      WorkingDirectory = stateDir;
      RuntimeDirectory = "lfcs-lab";
      RuntimeDirectoryMode = "0750";
      # Socket gruppenschreibbar, sonst kann skitarii den Guest-Agent nicht
      # ansprechen.
      UMask = "0007";
      # Die -snapshot-Overlays landen in $TMPDIR bzw. /var/tmp -- privat fuer
      # den Dienst und mit ihm weg.
      PrivateTmp = true;
      ExecStart = "${qemu}/bin/qemu-system-x86_64 ${lib.escapeShellArgs (baseArgs "" ++ [ "-snapshot" ] ++ nicArgs ++ qgaArgs)}";
      Restart = "no";
    };
    # Kein wantedBy -- die VM laeuft nur, wenn jemand sie startet.
  };

  # skitarii darf genau diese zwei Units starten, stoppen, neu starten.
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "skitarii") {
        var unit = action.lookup("unit");
        var verb = action.lookup("verb");
        if ((unit == "lfcs-lab.service" || unit == "lfcs-lab-build.service") &&
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
