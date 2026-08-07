# Remote-Zugang fuer den OpenClaw-Agent (Skitarii) auf primus.
# Shared: gilt fuer jeden Host, der dieses Modul importiert.
#
# Der Agent hat seit 07.08.2026 einen EIGENEN Account: siehe modules/agent-user.nix.
# Der `bfn`-Zugang unten ist nur noch Rueckfallebene waehrend der Umstellung.
{ ... }:
{
  # +-----------------------------------------------------------------------+
  # | PHASE 2 -- nach verifiziertem `ssh skitarii@fabricus` diese Liste leeren |
  # +-----------------------------------------------------------------------+
  # Solange dieser Key hier steht, ist die ganze Beschraenkung wirkungslos:
  # der Agent koennte sich per `ssh bfn@<host>` jederzeit die vollen Rechte
  # holen (wheel + docker). Erst das Entfernen macht die Trennung echt.
  #
  # Reihenfolge NICHT umdrehen -- wer diesen Key entfernt, bevor der
  # skitarii-Account nachweislich funktioniert, sperrt den Agenten aus.
  users.users.bfn.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwaPB8AWgkY5ie4daz89VIE9rvQ78xju4NXbmXxkM4V claw@primus"
  ];
  # +--------------------------- Ende Phase-2-Block -------------------------+
}
