# App-Theming (home-manager). Catppuccin Mocha als STATISCHE Basis fuer Launcher,
# Terminal, Filemanager. Shared -> fabricus + laptop.
# Notifications macht noctalia (mako-Config hier entfernt). Fuer kitty + Hyprland
# legt noctalia zusaetzlich seine Wallpaper-Palette drueber (siehe bfn.nix
# theme.templates) -> laeuft noctalia, gewinnt Material; sonst bleibt Catppuccin.
{ config, pkgs, lib, osConfig, ... }:

# Dieselbe isLaptop-Weiche wie in home/hyprland.nix und home/noctalia.nix.
#
# Warum Groessen ueberhaupt host-abhaengig sind: fabricus laeuft auf scale 1.25,
# der Laptop auf scale 1.0 (1080p vertraegt kein fractional Scaling ohne echte
# Unschaerfe). Beide Panels haben fast dieselbe Pixeldichte (~157 dpi) -- ein
# identischer Zahlenwert erscheint auf dem Laptop deshalb rund 20 % kleiner.
# Die Laptop-Werte sind die Desktop-Werte mal 1.25, also gleiche PHYSISCHE
# Groesse auf beiden Maschinen.
let
  isLaptop = osConfig.networking.hostName == "fabricus-itinerans";
in
{
  home.packages = with pkgs; [
    papirus-icon-theme  # System-Icon-Set fuer GTK-Apps. Kam urspruenglich wegen
                        # fuzzel rein und bleibt nach dessen Ausbau: ein
                        # Icon-Theme braucht der Desktop unabhaengig davon.
  ];

  # Cursor-Theme (statt Default-Adwaita). Setzt XCursor + GTK + hyprcursor in einem.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = if isLaptop then 24 else 20;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # --- Filemanager: yazi (terminal, HJKL-gesteuert) ---
  programs.yazi = {
    enable = true;
    # Ab home-manager 26.05 heisst der Shell-Wrapper per Default `y` statt `yy`.
    # Hier bewusst beim alten Namen: `yy` sitzt im Muskelgedaechtnis, und ein
    # Kanal-Upgrade ist der falsche Moment, um Kommandonamen zu aendern.
    # Umstellen ist ein Einzeiler, wenn du `y` lieber magst.
    shellWrapperName = "yy";
  };

  # fuzzel ist am 09.08.2026 komplett rausgeflogen. Es war zuletzt nur noch
  # dmenu-Backend fuer den hypr-cheatsheet; seit das keybind-cheatsheet-Plugin
  # die Hilfe im noctalia-Design uebernimmt, hat es keinen Nutzer mehr. Launcher
  # und Clipboard liefen schon seit 08.08.2026 ueber noctalia-Panels.

  # --- Terminal: kitty (enable kommt aus bfn.nix) ---
  # Statische Catppuccin-Farben als Basis/Fallback ...
  programs.kitty.settings = {
    font_family = "JetBrainsMono Nerd Font";
    font_size = if isLaptop then 15 else 12;
    background_opacity = "0.95";
    window_padding_width = 8;
    cursor_shape = "beam";
    # Catppuccin Mocha
    foreground = "#cdd6f4";
    background = "#1e1e2e";
    selection_foreground = "#1e1e2e";
    selection_background = "#f5e0dc";
    cursor = "#f5e0dc";
    cursor_text_color = "#1e1e2e";
    url_color = "#f5e0dc";
    color0 = "#45475a";
    color8 = "#585b70";
    color1 = "#f38ba8";
    color9 = "#f38ba8";
    color2 = "#a6e3a1";
    color10 = "#a6e3a1";
    color3 = "#f9e2af";
    color11 = "#f9e2af";
    color4 = "#89b4fa";
    color12 = "#89b4fa";
    color5 = "#f5c2e7";
    color13 = "#f5c2e7";
    color6 = "#94e2d5";
    color14 = "#94e2d5";
    color7 = "#bac2de";
    color15 = "#a6adc8";
  };

  # ... und darueber die noctalia-Palette. Der include steht am Ende der kitty.conf
  # (home-manager haengt extraConfig hinten an) und ueberschreibt damit die Farben
  # oben, sobald noctalia die Datei gerendert hat. Fehlt sie, warnt kitty nur und
  # behaelt die Catppuccin-Basis.
  programs.kitty.extraConfig = "include themes/noctalia.conf";

  # --- Dark Mode als Systemvorgabe ---
  # Der eigentliche Schalter ist die dconf-Key color-scheme=prefer-dark. Den liest
  # xdg-desktop-portal-gtk aus und beantwortet damit die Portal-Settings-API --
  # ueber die fragen Firefox, Thunderbird und alle Electron-Apps (Obsidian,
  # 1Password) unter Wayland ihr prefers-color-scheme ab. Ein blosses
  # GTK-Theme reicht dafuer NICHT.
  # Braucht `programs.dconf.enable = true` auf System-Ebene (modules/gui-apps.nix),
  # sonst existiert die dconf-Datenbank nicht und der Wert verpufft.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # GTK selbst: dark-Variante fuer GTK3/GTK4-Apps (Datei-Dialoge, nm-applet,
  # pavucontrol). gtk-application-prefer-dark-theme deckt die Apps ab, die kein
  # eigenes -dark-Theme laden, aber die Hint auswerten.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;

    # Ab home-manager 26.05 ist der Default fuer gtk4.theme `null` statt
    # `config.gtk.theme`. Hier bewusst der bisherige Wert, explizit gesetzt:
    # das haelt die Optik der GTK4-Apps exakt so wie sie war und macht nebenbei
    # die Rebuild-Warnung weg. Auf `null` umzustellen ist eine Optik-
    # Entscheidung (GTK4-Apps wuerden dann libadwaita-Standard nehmen) und
    # gehoert nicht in ein Kanal-Upgrade.
    gtk4.theme = config.gtk.theme;
  };

  # Qt-Apps (z.B. qbittorrent-GUI, VLC) an die GTK-Einstellung koppeln, damit
  # nicht die Haelfte des Desktops hell bleibt.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
