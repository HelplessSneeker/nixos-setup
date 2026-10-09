# `vm` -- Bedienung der LFCS-Lab-VM (modules/lfcs-lab.nix) mit einem Befehl.
# Die Datei heisst nach dem Lab, der Befehl kurz `vm` (bfn, 09.10.2026).
# Ausfuehrliche Hilfe: `vm help`. Runbook im bfn-wiki:
#   runbooks/2026-10-06 - LFCS-Lab-VM auf fabricus-itinerans.md
#
# Die VM laeuft auf dem Laptop. Dort ruft der Befehl systemctl direkt auf --
# die Polkit-Regel im Modul erlaubt bfn das ohne sudo. Auf fabricus reicht er
# alles ausser ssh und help per ssh an den Laptop weiter.
{ pkgs, lib, osConfig, ... }:
let
  host = osConfig.networking.hostName;
  isLaptop = host == "fabricus-itinerans";

  # Steht auf beiden Maschinen identisch im Skript -- `vm help` braucht also
  # auch auf fabricus keine Verbindung zum Laptop.
  helpText = ''
    vm -- LFCS-Lab-VM (Ubuntu 24.04 auf fabricus-itinerans)

    BEFEHLE
      vm               ssh in die VM. Ist sie aus, startet sie von selbst
                       (~10 s), danach geht es direkt weiter.
      vm up            VM starten und warten, bis ssh bereit ist.
      vm reset [-y]    Zurueck auf das Golden-Image. Alles, was im Gast
                       geaendert wurde, ist weg. Fragt nach, -y nicht.
      vm down  [-y]    VM aus. Aenderungen sind ebenfalls weg.
      vm status        Laeuft die VM, laeuft der Build, wie alt ist das Image.
      vm build         Golden-Image neu bauen (~2 min, VM muss aus sein).
      vm help          Diese Hilfe.

    WAS MAN WISSEN MUSS
      - Jeder Start beginnt beim Golden-Image. Reboots IM Gast ueberleben
        die Aenderungen, erst vm reset/down oder ein Neustart des Laptops
        verwirft sie.
      - Die VM stoppt nie von selbst. Nach dem Slot: vm down.
      - Im Gast: User bfn, sudo ohne Passwort (sudo -i wie in der Pruefung).
        Leere Platten vdb und vdc (je 5G), Netzwerkkarten ens2 (Internet),
        ens3 und ens4 (Uebungsmaterial, ohne Konfiguration).
      - Nach vm build hat der Gast einen neuen Host-Key. Dann einmal
        ssh-keygen -R lfcs-lab, auf dem Laptop, auf fabricus und auf primus.
      - Ausgesperrt (ufw, sshd kaputt)? vm reset. Primus kommt notfalls ueber
        den Guest-Agent noch hinein.

    Doku: bfn-wiki, runbooks/2026-10-06 - LFCS-Lab-VM auf fabricus-itinerans.md
  '';

  common = ''
    help() { cat <<'EOF'
    ${helpText}EOF
    }
    case "''${1:-}" in
      help|-h|--help) help; exit 0 ;;
      ""|ssh) [ $# -gt 0 ] && shift; exec ssh lfcs "$@" ;;
    esac
  '';

  remote = ''
    # fabricus: die VM lebt auf dem Laptop.
    exec ssh -t fabricus-itinerans vm "$@"
  '';

  local = ''
    confirm() {
      [ "''${2:-}" = "-y" ] && return 0
      [ -t 0 ] || { echo "vm $1: ohne Terminal nur mit -y" >&2; exit 2; }
      read -r -p "vm $1 verwirft alles, was in der VM geaendert wurde. Weiter? [j/N] " a
      [ "$a" = j ] || [ "$a" = J ] || exit 1
    }
    case "$1" in
      up)
        systemctl start lfcs-lab-ssh.service && echo "VM laeuft, vm bzw. ssh lfcs ist bereit." ;;
      reset)
        confirm reset "''${2:-}"
        systemctl restart lfcs-lab.service && systemctl start lfcs-lab-ssh.service \
          && echo "Zurueckgesetzt, vm bzw. ssh lfcs ist bereit." ;;
      down)
        confirm down "''${2:-}"
        systemctl stop lfcs-lab.service && echo "VM aus." ;;
      status)
        echo "VM:    $(systemctl is-active lfcs-lab.service)"
        echo "ssh:   $(systemctl is-active lfcs-lab-ssh.service) (Socket: $(systemctl is-active lfcs-lab-ssh.socket))"
        echo "Build: $(systemctl is-active lfcs-lab-build.service), Golden-Image vom $(date -r /var/lib/lfcs-lab/root.qcow2 '+%d.%m.%Y %H:%M' 2>/dev/null || echo '?')" ;;
      build)
        systemctl start lfcs-lab-build.service \
          && echo "Golden-Image neu. Der Gast hat einen neuen Host-Key: ssh-keygen -R lfcs-lab (auch auf fabricus und primus)." ;;
      *)
        echo "vm: unbekannter Befehl '$1'" >&2
        help >&2
        exit 2 ;;
    esac
  '';

  vm = pkgs.writeShellScriptBin "vm" (common + (if isLaptop then local else remote));
in
lib.mkIf (isLaptop || host == "fabricus") {
  home.packages = [ vm ];
}
