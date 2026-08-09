{ config, pkgs, pkgsUnstable, lib, inputs, ... }:
{

  imports = [
    ./apps.nix
    ./ssh.nix
    ./hyprland.nix
    ./theme.nix
    ./fish.nix
    ./noctalia.nix
    inputs.noctalia.homeModules.default
  ];

  home.username = "bfn";
  home.homeDirectory = "/home/bfn";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    # settings.user.* statt userName/userEmail -- in home-manager 26.05
    # umbenannt. Die alten Namen funktionieren noch, warnen aber bei jedem
    # Rebuild. settings bildet die git-Config direkt ab (Sektion.Schluessel).
    settings.user = {
      name = "Benjamin Nößler";
      email = "benjamin@noessler.at";
    };
  };

  # programs.noctalia (Theming, Wallpaper, Bar-Layout) lebt jetzt in ./noctalia.nix

  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.kitty.enable = true;

  # tldr-Client: tealdeer (Rust). Von den drei Kandidaten -- tldr (C), tlrc
  # (offizieller Rust-Client), tealdeer -- der einzige mit home-manager-Modul;
  # Binary heisst bei allen `tldr`. Passt ausserdem zum Rest des CLI-Stacks
  # (ripgrep/fd/bat/eza).
  #
  # PAKET AUS UNSTABLE (1.8.1) -- nicht kosmetisch, 25.05 ist hier KAPUTT:
  # tealdeer 1.7.2 hat die Archiv-URL fest einkompiliert
  # (src/main.rs: ARCHIVE_URL = "https://tldr.sh/assets/tldr.zip").
  # Die liefert seit einem Umbau auf tldr.sh keinen ZIP mehr, sondern
  # 301 -> HTML-Seite. tealdeer laedt also HTML und stirbt beim Entpacken:
  #   "Could not decompress downloaded ZIP archive
  #    Caused by: invalid Zip archive: Could not find EOCD"
  # (EOCD = End Of Central Directory, der ZIP-Endmarker -- in HTML nie da.)
  # Geprueft am 07.08.2026: die URL antwortet mit content-type text/html.
  # `updates.auto_update` haette daran nichts geaendert -- gleiche URL,
  # gleicher Fehler, nur oefter.
  #
  # Ab 1.8.0 ist der Default https://github.com/tldr-pages/tldr/releases/latest/download/
  # und zusaetzlich ueber settings.updates.archive_source konfigurierbar.
  # Verifiziert: liefert echten ZIP (Magic PK\x03\x04).
  # Der bereits gepinnte nixpkgs-unstable-Input hat 1.8.1 -- kein Lock-Bump
  # noetig. Sobald 26.05 tealdeer >=1.8 mitbringt, kann das hier wieder auf
  # `pkgs` zurueck.
  #
  # `enableAutoUpdates` steht per Default auf true und legt einen systemd-
  # user-Timer `tldr-update` an (weekly, Persistent=true -> holt einen
  # verpassten Lauf nach dem Boot nach); der Timer erbt package von hier,
  # zieht also ebenfalls 1.8.1. Deshalb bewusst KEIN
  # settings.updates.auto_update: das waere ein zweiter, konkurrierender
  # Update-Pfad, der die Cache-Aktualisierung in einen beliebigen
  # `tldr`-Aufruf haengt statt in den Timer.
  #
  # settings bleibt ungesetzt -> home-manager schreibt gar keine config.toml,
  # der Cache unter ~/.cache/tealdeer bleibt normal beschreibbar.
  programs.tealdeer = {
    enable = true;
    package = pkgsUnstable.tealdeer;
  };

  # pnpm legt global installierte Pakete unter $PNPM_HOME ab. Ohne die Variable
  # verweigert `pnpm add -g` den Dienst ("Unable to find the global bin
  # directory") und will stattdessen `pnpm setup` laufen lassen -- das schreibt
  # in ~/.config/fish/config.fish, die home-manager als Store-Symlink verwaltet
  # (read-only). Also deklarativ setzen statt pnpm dran zu lassen.
  home.sessionVariables.PNPM_HOME = "${config.home.homeDirectory}/.local/share/pnpm";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/share/pnpm" ];

  home.packages = with pkgs; [
    gh nodejs_22
    # pnpm 10.15.1 aus 25.05 (geprueft am 07.08.2026 gegen den gepinnten
    # nixpkgs) -- kein unstable noetig. Bewusst NICHT ueber corepack: das
    # laedt die Manager zur Laufzeit nach und wird ab Node 25 nicht mehr
    # mitgeliefert; das Nix-Paket ist reproduzierbar und rollback-faehig.
    pnpm
    ripgrep fd fzf bat eza jq btop tmux unzip wget
    waybar hyprpaper hyprlock hypridle   # mako raus: noctalia macht die Notifications
    grim slurp wl-clipboard brightnessctl playerctl pavucontrol
    networkmanagerapplet
    # firefox lebt jetzt bei den uebrigen GUI-Apps in home/apps.nix
  ];
}
