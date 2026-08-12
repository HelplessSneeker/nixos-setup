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

      # Heim-Server (Media-/Torrent-Stack). Klassisches sshd mit
      # ~/.ssh/authorized_keys -- anders als personal-server, das Tailscale SSH
      # nutzt und deshalb ganz ohne Key auskommt.
      #
      # Bis 11.08.2026 stand hier ~/.ssh/id_ed25519. Diese Datei liegt aber nur
      # auf fabricus (Desktop) auf der Platte -- vom Laptop aus gab es damit
      # keinen anbietbaren Key ("no such identity"), und IdentitiesOnly sperrte
      # den 1Password-Agent zusaetzlich aus. Genau das war der Grund, warum
      # cogitator vom Laptop nie erreichbar war.
      #
      # Jetzt der 1Password-Eintrag "cogitator-prime", am 11.08.2026 angelegt
      # und auf dem Server an /home/bfn/.ssh/authorized_keys *angehaengt*;
      # `media-server` und `fabricus` stehen weiterhin daneben.
      # Fingerprint: SHA256:s535wIXb/AylSt0zsKIu+JIcUG0SXLVTV7STvmjBdTA
      cogitator-prime = {
        HostName = "cogitator-prime.${tailnet}";
        User = "bfn";
        IdentityFile = "~/.ssh/cogitator-prime.pub";
        IdentitiesOnly = true;
      };

      # Coolify-Host. Laeuft Tailscale SSH (Auth ueber Tailnet-Identity),
      # daher bewusst KEIN Key/IdentitiesOnly -- nur der User zaehlt.
      personal-server = {
        HostName = "personal-server.${tailnet}";
        User = "bfn";
      };

      # Die beiden eigenen Maschinen untereinander.
      #
      # ACHTUNG, STAND 11.08.2026: diese beiden Bloecke funktionieren NICHT.
      # Sie zeigen auf `openclaw-lab`, und von diesem Key existiert kein
      # privater Teil -- der 1Password-Agent listet ihn nicht (`ssh-add -l`),
      # und in den sshd-Journalen beider Hosts steht seit dem 09.08.2026 kein
      # einziger `bfn`-Login damit. Der Pubkey wurde am 08.08.2026 deklariert,
      # ohne dass je ein Gegenstueck angelegt wurde. Karteileiche.
      #
      # Absicht der Mechanik (die stimmt): IdentityFile zeigt auf den *public*
      # Key, IdentitiesOnly schraenkt die Agent-Auswahl darauf ein. Ohne das
      # laeuft der Agent alle Keys durch und sshd bricht mit "Too many
      # authentication failures" ab -- am 09.08.2026 genau so passiert.
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

  # Public Key des 1Password-Eintrags "cogitator-prime" (angelegt 11.08.2026).
  # Gegenstueck steht auf dem Server in /home/bfn/.ssh/authorized_keys --
  # cogitator ist Debian, nicht NixOS, also nicht deklarativ von hier aus.
  # Nur oeffentlich, gehoert nicht zu den Secrets.
  home.file.".ssh/cogitator-prime.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESznCeiuvFIcwB58RTCMe3ALD6kn95vn0KKDhk5pNVV cogitator-prime\n";

  # Pubkey `openclaw-lab`, steht als authorizedKey in beiden
  # hosts/*/configuration.nix. TOTER KEY -- kein privater Teil existiert
  # (siehe Kommentar bei den fabricus-Bloecken oben). Bleibt vorerst stehen,
  # damit die Bloecke evaluieren; ersatzlos raus oder durch einen echten Key
  # ersetzen, sobald entschieden ist, ob die Maschinen sich gegenseitig
  # ueberhaupt per SSH erreichen sollen.
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
