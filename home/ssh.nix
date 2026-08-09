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
  # Ab home-manager 26.05: `settings` statt `matchBlocks`, und die Schluessel
  # sind die ECHTEN OpenSSH-Direktivnamen (HostName, User, IdentityFile ...)
  # statt der camelCase-Varianten. matchBlocks funktioniert noch, warnt aber.
  programs.ssh = {
    enable = true;

    # Die eingebauten Defaults sind ausgeschaltet und stehen stattdessen
    # unten in settings."*". Grund: home-manager warnt, dass es sie kuenftig
    # ersatzlos entfernt -- dann waeren sie stillschweigend weg. Explizit
    # gesetzt aendert sich nichts am Verhalten, aber es bleibt sichtbar, was
    # gilt. Die Werte sind 1:1 die bisherigen home-manager-Defaults.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        # --- bisherige home-manager-Defaults, jetzt explizit ---
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";

        # --- eigene Einstellungen ---
        # Vorab-verifizierte Host-Keys (known_hosts_nix unten) zusaetzlich zur
        # normalen, schreibbaren known_hosts. Verhindert den TOFU-Prompt beim
        # ersten Connect, ohne die schreibbare Datei durch einen Store-Symlink
        # zu ersetzen. Ueberschreibt den Default "~/.ssh/known_hosts".
        UserKnownHostsFile = "~/.ssh/known_hosts ~/.ssh/known_hosts_nix";

        # SSH nutzt den 1Password-Agent statt eines Keys auf der Platte.
        # Der Socket kommt vom System-Modul (modules/gui-apps.nix,
        # programs._1password-gui); hier zeigt nur ~/.ssh/config drauf.
        # WICHTIG: in der 1Password-GUI einmalig Settings -> Developer ->
        # "Use the SSH agent" aktivieren, sonst existiert der Socket nicht.
        IdentityAgent = "~/.1password/agent.sock";
      };

      # OpenClaw-Host (Hetzner-VPS). User ist `claw`, nicht `bfn` --
      # auf primus existiert kein bfn-Account.
      primus = {
        HostName = "primus.${tailnet}";
        User = "claw";
        IdentityFile = "~/.ssh/primus-vps.pub";   # 1Password-Eintrag "Primus VPS SSH"
        IdentitiesOnly = true;
      };

      # Heim-Server (Media-/Torrent-Stack). Nutzt den lokalen fabricus-Key,
      # nicht 1Password -- dort liegt kein passender Eintrag.
      cogitator-prime = {
        HostName = "cogitator-prime.${tailnet}";
        User = "bfn";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
      };

      # Coolify-Host. Laeuft Tailscale SSH (Auth ueber Tailnet-Identity),
      # daher bewusst KEIN Key/IdentitiesOnly -- nur der User zaehlt.
      personal-server = {
        HostName = "personal-server.${tailnet}";
        User = "bfn";
      };

      # Die beiden eigenen Maschinen untereinander. Beide autorisieren denselben
      # Key `openclaw-lab` (steht deklarativ in beiden hosts/*/configuration.nix),
      # dessen privater Teil in 1Password liegt -- deshalb dieselbe Mechanik wie
      # bei primus: IdentityFile zeigt auf den *public* Key, IdentitiesOnly
      # schraenkt die Agent-Auswahl darauf ein.
      #
      # Ohne diese beiden Bloecke laeuft der Agent alle Keys durch und sshd
      # bricht mit "Too many authentication failures" ab, bevor der richtige
      # dran ist -- am 09.08.2026 genau so passiert.
      #
      # Der Eintrag fuer die eigene Maschine ist jeweils inert, aber das Modul
      # ist shared: so gilt auf beiden Hosts dieselbe Datei.
      fabricus = {
        HostName = "fabricus.${tailnet}";
        User = "bfn";
        IdentityFile = "~/.ssh/openclaw-lab.pub";
        IdentitiesOnly = true;
      };

      fabricus-itinerans = {
        HostName = "fabricus-itinerans.${tailnet}";
        User = "bfn";
        IdentityFile = "~/.ssh/openclaw-lab.pub";
        IdentitiesOnly = true;
      };
    };
  };

  # Public Key des 1Password-Eintrags "Primus VPS SSH". Nur oeffentlich, gehoert
  # nicht zu den Secrets -- darf im (public) GitHub-Repo stehen.
  home.file.".ssh/primus-vps.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBMd+ZsTr68NdZlioXii1MZFbtZx3v5TmqyG53+M0ub primus-vps\n";

  # Public Key des 1Password-Eintrags "openclaw-lab" -- derselbe Key steht als
  # authorizedKey in beiden hosts/*/configuration.nix. Nur oeffentlich.
  home.file.".ssh/openclaw-lab.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdHqQP/7i5iIK4hBcLnjzvvQKFiD7xHH9+o7x95i58a openclaw-lab\n";

  # Host-Keys, verifiziert am 06.08.2026 per ssh-keyscan aus dem Tailnet heraus.
  # Bei Neuinstallation eines Hosts hier den Eintrag aktualisieren, sonst
  # meldet ssh "REMOTE HOST IDENTIFICATION HAS CHANGED".
  #
  # fabricus + fabricus-itinerans ergaenzt am 09.08.2026. Der Laptop-Key wurde
  # doppelt bestaetigt: ssh-keyscan von primus und der TOFU-Prompt auf fabricus
  # zeigen denselben Fingerprint
  # (SHA256:BjloS3/zAZKfflsTmmmDTZ+TJr90V2cAz0zchRW6Xx8).
  home.file.".ssh/known_hosts_nix".text = ''
    primus,primus.${tailnet},100.73.119.56 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9nn1+O1p2FLVtEN3PINm948NQu2hVpGxXWPbopTSCH
    cogitator-prime,cogitator-prime.${tailnet},100.123.62.126 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhGLbay2eMoV9Ls4G1I2X6YdKmdigXHFkXdXdqqkYyO
    personal-server,personal-server.${tailnet},100.116.251.104 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjiKE7VILsFyUI3FL7wsM4ztlGlN7SRjWBAjhbhyWzp
    fabricus,fabricus.${tailnet},100.105.13.78 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTh8W7s/z53sSUJoRjZUlNuiAkB5RaZYTtac2WpMj+w
    fabricus-itinerans,fabricus-itinerans.${tailnet},100.99.116.48 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID4IcFf4c71HIIIDSEuPBdgyqZ6Jz5I78p05dNL2dqvY
  '';
}
