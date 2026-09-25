# Eigener Systemaccount fuer den OpenClaw-Agent (Skitarii, laeuft als `claw` auf primus).
# Shared: gilt fuer jeden Host, der diesen Modul-Stack bekommt -- also auch fuer
# fabricus-itinerans, sobald cachus-rex gebaut wird.
#
# LEITIDEE: Auf persoenlichen Maschinen darf der Agent LESEN, nicht MUTIEREN.
#   - kein `wheel`  -> kein sudo, kein Paket/Service/Config-Zugriff
#   - kein `docker` -> die docker-Gruppe ist root-aequivalent (Container mit
#                      `-v /:/host` mounten das ganze Dateisystem), sie waere
#                      ein stiller Bypass um jede sudo-Regel herum
#   - `systemd-journal` -> volle Log-Diagnose, aber rein lesend
#
# ZUGANGSWEG seit 19.09.2026: ausschliesslich Tailscale SSH. Es gibt keinen
# sshd-Key mehr (siehe authorizedKeys.keys unten); wer hereindarf, entscheidet
# die SSH-Policy der Tailnet-ACL, nicht eine Datei auf dieser Maschine.
#
# Config-Aenderungen laufen deshalb NICHT ueber diesen Account, sondern als
# Commits im Flake-Repo (github.com/HelplessSneeker/nixos-setup). Der Agent
# liefert Diffs, `nixos-rebuild switch` macht bfn. Damit ist der Audit-Trail
# die git-History: off-host, nachvollziehbar, vom Agenten nicht umschreibbar --
# was ein lokales Log auf einer Maschine mit root-Zugriff nie sein kann.
{ pkgs, ... }:
{
  users.users.skitarii = {
    isNormalUser = true;
    description = "OpenClaw Agent (Skitarii) -- read-only";
    extraGroups = [ "systemd-journal" ];
    shell = pkgs.bashInteractive;

    # Kein Passwort gesetzt -> kein lokaler Login, kein `su`.
    # Ohne Passwort ist auch `su skitarii` -> `sudo` sinnlos, selbst wenn der
    # Account je versehentlich in wheel landet.
    hashedPassword = null;

    # BEWUSST LEER (19.09.2026). Der Zugang laeuft ausschliesslich ueber
    # Tailscale SSH -- dieselbe Bauart wie auf cogitator-prime (seit 16.09.)
    # und personal-server.
    #
    # Warum der Key weg muss, obwohl er seit `--ssh` ohnehin tot ist:
    # tailscaled faengt Port 22 im Tailnet ab, sshd sieht die Verbindung gar
    # nicht mehr. Der Eintrag waere also kein zweiter Weg, sondern ein
    # SCHLAFENDER -- er wuerde in genau dem Moment wieder scharf, in dem
    # Tailscale SSH ausfaellt oder abgeschaltet wird, und zwar lautlos und
    # ohne die ACL-Bestaetigung, die der ganze Umbau bezwecken soll.
    #
    # PREIS, bewusst akzeptiert: damit gibt es fuer den Agenten keinen
    # Rueckweg auf diese Maschine. Kein LAN-Notzugang wie `cogitator-lan` --
    # `services.openssh.openFirewall = false` (modules/ssh-hardening.nix)
    # laesst Port 22 nur ueber tailscale0 zu, und dort sitzt tailscaled davor.
    # Auf einem Desktop, vor dem bfn sitzt, ist das der richtige Tausch:
    # der Notzugang ist die Tastatur.
    #
    # Wer den Zugang wiederherstellen will, aktiviert Tailscale SSH
    # (services.tailscale.extraSetFlags in modules/tailscale.nix) -- nicht
    # diesen Key.
    openssh.authorizedKeys.keys = [ ];
  };

  # NOTFALL-SPERRE (kompromittierter primus) -- korrigiert 21.09.2026.
  #
  # RICHTIG, wirkt in Sekunden und beendet laut Tailscale-Referenz auch
  # laufende Sessions:
  #   1. die `skitarii`-Regel aus dem `ssh`-Block der Tailnet-Policy nehmen
  #      (Vorlage: nix/fabricus/acl-ssh-block-vorschlag.hujson im
  #      Agent-Workspace -- `sshTests` in derselben Speicherung auf `deny`,
  #      sonst lehnt Tailscale die Policy ab)
  #   2. global ueber alle Hosts: primus im Tailscale-Admin disablen
  #
  # `usermod --expire` stand hier frueher und ist entfernt (bfn 25.09.2026):
  # Tailscale SSH umgeht PAM, die Zeile hat nie gesperrt. Zugang hat Skitarii
  # ohnehin nur, wenn bfn ihn ueber die Tailnet-Policy freischaltet.
}
