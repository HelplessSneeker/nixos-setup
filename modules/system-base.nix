# System-Basis: Locale, Zeit, Tastatur, Audio, Fonts, Dev-CLI, Nix-Hygiene.
# Shared: von jedem Host importierbar. Nichts hier ist host-spezifisch.
{ config, pkgs, lib, ... }:
{
  # --- Locale / Zeit / Tastatur (Oesterreich) ---
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "de_AT.UTF-8";
  # Programme/Logs auf Englisch, Formate (Datum/Zahlen/Waehrung) oesterreichisch.
  i18n.extraLocaleSettings = {
    LC_MESSAGES = "en_US.UTF-8";
    LC_TIME     = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NUMERIC  = "de_AT.UTF-8";
    LC_PAPER    = "de_AT.UTF-8";
  };
  console.keyMap = "de";   # TTY-Tastatur (vor dem Login / im Notfall-Shell)
  # Hyprland-Layout (kb_layout = de) setzt dein Hyprland-Home-Modul, nicht das hier.

  # --- Shell: fish ---
  # System-Ebene ist noetig, damit fish als Login-Shell die Nix-Umgebung sauber
  # sourced (Profile-Pfade, vendor completions). Die Login-Shell-Zuweisung selbst
  # steht pro Host in hosts/*/configuration.nix (users.users.bfn.shell).
  programs.fish.enable = true;

  # --- Audio: PipeWire (ersetzt PulseAudio) ---
  security.rtkit.enable = true;   # Realtime-Prioritaet fuer den Audio-Daemon
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;          # Pulse-kompatible Apps laufen unveraendert weiter
  };

  # --- Fonts ---
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      # In nixpkgs 26.05 umbenannt: noto-fonts-emoji -> noto-fonts-color-emoji.
      # Der alte Name ist keine Warnung, sondern ein harter Fehler (throw), der
      # den gesamten Rebuild abbricht.
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono    # Icons fuer Waybar / nvim / Terminal
    ];
  };

  # --- Basis-Dev-CLI (systemweit, damit auch root/TTY sie hat) ---
  environment.systemPackages = with pkgs; [
    git
    ripgrep
    fd
    jq
    curl
    wget
    unzip
    htop
    tree
  ];

  # --- Nix-Store-Hygiene ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;    # dedupliziert identische Store-Pfade

  # --- Ausdauer bei Downloads, die NICHT aus dem Binary-Cache kommen ---
  #
  # Anlass (09.08.2026): der NVIDIA-Treiber. Er ist unfree und darf deshalb
  # NICHT auf cache.nixos.org liegen -- jede Maschine laedt das .run-Archiv
  # (404 MB) selbst bei NVIDIA. Von hier aus laufen alle NVIDIA-Mirrors
  # zwischen 20 kB/s und 1 MB/s und brechen dabei staendig mit
  # "SSL_read: unexpected eof" ab; von einem Hetzner-Server dieselbe Datei mit
  # 34 MB/s. Es liegt also an der Strecke hierhin, nicht an NVIDIA.
  #
  # Entscheidend: curl setzt abgebrochene Transfers fort ("Resuming transfer
  # from byte position ..."). Mit genug Versuchen arbeitet sich der Download
  # also hoch, statt bei Null neu zu beginnen. Der Default von 5 Versuchen
  # reicht dafuer nicht -- 25 schon, und sie kosten nichts, solange nichts
  # abbricht.
  #
  # stalled-download-timeout: ein Transfer gilt erst nach 10 Minuten ohne
  # jeden Fortschritt als tot (Default 5). Bei 20 kB/s ist "langsam" sonst
  # schnell mit "haengt" verwechselt.
  nix.settings.download-attempts = 25;
  nix.settings.stalled-download-timeout = 600;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";      # alte Generationen automatisch aufraeumen
  };
}
