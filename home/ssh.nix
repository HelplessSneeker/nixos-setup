# SSH-Client-Konfiguration (home-manager). Shared home-Modul.
#
# Zwei Dinge passieren hier:
#  1. Host-Aliase fuer das Tailnet -> `ssh primus` statt `ssh claw@primus.tail...`
#  2. Key-Pinning pro Host. Ohne das bietet ssh alle 8 Keys aus dem
#     1Password-Agent der Reihe nach an; der primus-Key ist der letzte
#     -> Server bricht vorher mit "Too many authentication failures" ab.
#     Trick: IdentityFile zeigt auf den *public* Key, IdentitiesOnly=yes
#     schraenkt damit die Agent-Auswahl auf genau diesen einen Key ein.
{ config, pkgs, lib, ... }:
let
  tailnet = "tail872491.ts.net";
in
{
  programs.ssh = {
    enable = true;

    # Vorab-verifizierte Host-Keys (siehe known_hosts_nix unten) zusaetzlich zur
    # normalen, schreibbaren known_hosts. Verhindert den TOFU-Prompt beim ersten
    # Connect, ohne die schreibbare Datei durch einen Store-Symlink zu ersetzen.
    userKnownHostsFile = "~/.ssh/known_hosts ~/.ssh/known_hosts_nix";

    matchBlocks = {
      # SSH nutzt den 1Password-Agent statt eines Keys auf der Platte.
      # Der Socket kommt vom System-Modul (modules/desktop-apps.nix,
      # programs._1password-gui); hier zeigt nur ~/.ssh/config drauf. WICHTIG:
      # in der 1Password-GUI einmalig Settings -> Developer -> "Use the SSH
      # agent" aktivieren, sonst existiert der Socket nicht.
      "*".extraOptions.IdentityAgent = "~/.1password/agent.sock";

      # OpenClaw-Host (Hetzner-VPS). User ist `claw`, nicht `bfn` --
      # auf primus existiert kein bfn-Account.
      primus = {
        hostname = "primus.${tailnet}";
        user = "claw";
        identityFile = "~/.ssh/primus-vps.pub";   # 1Password-Eintrag "Primus VPS SSH"
        identitiesOnly = true;
      };

      # Heim-Server (Media-/Torrent-Stack). Nutzt den lokalen fabricus-Key,
      # nicht 1Password -- dort liegt kein passender Eintrag.
      cogitator-prime = {
        hostname = "cogitator-prime.${tailnet}";
        user = "bfn";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      # Coolify-Host. Laeuft Tailscale SSH (Auth ueber Tailnet-Identity),
      # daher bewusst KEIN Key/IdentitiesOnly -- nur der User zaehlt.
      personal-server = {
        hostname = "personal-server.${tailnet}";
        user = "bfn";
      };
    };
  };

  # Public Key des 1Password-Eintrags "Primus VPS SSH". Nur oeffentlich, gehoert
  # nicht zu den Secrets -- darf im (public) GitHub-Repo stehen.
  home.file.".ssh/primus-vps.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBMd+ZsTr68NdZlioXii1MZFbtZx3v5TmqyG53+M0ub primus-vps\n";

  # Host-Keys, verifiziert am 06.08.2026 per ssh-keyscan aus dem Tailnet heraus.
  # Bei Neuinstallation eines Hosts hier den Eintrag aktualisieren, sonst
  # meldet ssh "REMOTE HOST IDENTIFICATION HAS CHANGED".
  home.file.".ssh/known_hosts_nix".text = ''
    primus,primus.${tailnet},100.73.119.56 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9nn1+O1p2FLVtEN3PINm948NQu2hVpGxXWPbopTSCH
    cogitator-prime,cogitator-prime.${tailnet},100.123.62.126 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhGLbay2eMoV9Ls4G1I2X6YdKmdigXHFkXdXdqqkYyO
    personal-server,personal-server.${tailnet},100.116.251.104 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjiKE7VILsFyUI3FL7wsM4ztlGlN7SRjWBAjhbhyWzp
  '';
}
