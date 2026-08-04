# Remote-Zugang fuer den OpenClaw-Agent (Skitarii) auf primus.
# Shared: gilt fuer jeden Host, der dieses Modul importiert.
# Gibt dem primus-Agent SSH als bfn@<host> ueber das Tailnet.
{ ... }:
{
  users.users.bfn.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwaPB8AWgkY5ie4daz89VIE9rvQ78xju4NXbmXxkM4V claw@primus"
  ];
}
