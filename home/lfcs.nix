# `lfcs` -- Bedienung der LFCS-Lab-VM (modules/lfcs-lab.nix) mit einem Befehl.
#
#   lfcs            ssh in die VM (startet sie bei Bedarf, ~10 s)
#   lfcs up         VM starten und warten, bis ssh bereit ist
#   lfcs reset      zurueck auf das Golden-Image (fragt nach)
#   lfcs down       VM aus, Aenderungen weg (fragt nach)
#   lfcs status     laeuft sie?
#   lfcs build      Golden-Image neu bauen (~2 min)
#
# Die VM laeuft auf dem Laptop. Dort ruft der Befehl systemctl direkt auf --
# die Polkit-Regel im Modul erlaubt bfn das ohne sudo. Auf fabricus reicht er
# alles ausser dem ssh selbst per ssh an den Laptop weiter.
{ pkgs, lib, osConfig, ... }:
let
  host = osConfig.networking.hostName;
  isLaptop = host == "fabricus-itinerans";

  remote = ''
    # fabricus: die VM lebt auf dem Laptop.
    case "''${1:-}" in
      ""|ssh) [ $# -gt 0 ] && shift; exec ssh lfcs "$@" ;;
      *) exec ssh -t fabricus-itinerans lfcs "$@" ;;
    esac
  '';

  local = ''
    confirm() {
      [ "''${2:-}" = "-y" ] && return 0
      [ -t 0 ] || { echo "$1: ohne Terminal nur mit -y" >&2; exit 2; }
      read -r -p "$1 verwirft alles, was in der VM geaendert wurde. Weiter? [j/N] " a
      [ "$a" = j ] || [ "$a" = J ] || exit 1
    }
    case "''${1:-}" in
      ""|ssh) [ $# -gt 0 ] && shift; exec ssh lfcs "$@" ;;
      up)
        systemctl start lfcs-lab-ssh.service && echo "VM laeuft, ssh lfcs ist bereit." ;;
      reset)
        confirm reset "''${2:-}"
        systemctl restart lfcs-lab.service && systemctl start lfcs-lab-ssh.service \
          && echo "Zurueckgesetzt, ssh lfcs ist bereit." ;;
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
        echo "lfcs [ssh|up|reset|down|status|build]  -- reset/down fragen nach, -y ueberspringt" >&2
        exit 2 ;;
    esac
  '';

  lfcs = pkgs.writeShellScriptBin "lfcs" (if isLaptop then local else remote);
in
lib.mkIf (isLaptop || host == "fabricus") {
  home.packages = [ lfcs ];
}
