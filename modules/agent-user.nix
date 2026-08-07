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

    # Kein Passwort gesetzt -> Login ausschliesslich per SSH-Key.
    # Ohne Passwort ist auch `su skitarii` -> `sudo` sinnlos, selbst wenn der
    # Account je versehentlich in wheel landet.
    hashedPassword = null;

    openssh.authorizedKeys.keys = [
      # from=  : nur von primus' Tailnet-IP; der Key allein reicht nicht.
      # no-*-forwarding: verhindert, dass die Agent-Session als Sprungbrett
      #                  oder Port-Tunnel ins LAN missbraucht wird.
      ''from="100.73.119.56",no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgwlg6AR8S63vxQnvfkQZ+kpm7LhqhIQig49+dXJNSJ skitarii@primus''
    ];
  };

  # NOTFALL-SPERRE (kompromittierter primus), wirkt sofort ohne Rebuild:
  #   sudo usermod --expire 1 skitarii      # sperrt den Account
  #   sudo usermod --expire "" skitarii     # hebt die Sperre wieder auf
  # Global ueber alle Hosts gleichzeitig: primus im Tailscale-Admin disablen.
}
