# App-Theming (home-manager). Catppuccin Mocha als STATISCHE Basis fuer Launcher,
# Terminal, Filemanager. Shared -> fabricus + laptop.
# Notifications macht noctalia (mako-Config hier entfernt). Fuer kitty + Hyprland
# legt noctalia zusaetzlich seine Wallpaper-Palette drueber (siehe bfn.nix
# theme.templates) -> laeuft noctalia, gewinnt Material; sonst bleibt Catppuccin.
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    papirus-icon-theme  # Icons fuer fuzzel
  ];

  # Cursor-Theme (statt Default-Adwaita). Setzt XCursor + GTK + hyprcursor in einem.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 20;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # --- Filemanager: yazi (terminal, HJKL-gesteuert) ---
  programs.yazi.enable = true;

  # --- Launcher: fuzzel ---
  # Bleibt statisch Catppuccin: dient jetzt v.a. als dmenu-Backend fuer den
  # hypr-cheatsheet (SUPER+/). App-Launcher-Rolle kann spaeter noctalia uebernehmen.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12";
        prompt = "'  '";
        icon-theme = "Papirus-Dark";
        width = 34;
        lines = 10;
        horizontal-pad = 20;
        vertical-pad = 14;
        inner-pad = 8;
      };
      border = {
        width = 2;
        radius = 10;
      };
      colors = {
        background = "1e1e2eee";
        text = "cdd6f4ff";
        prompt = "bac2deff";
        match = "89b4faff";
        selection = "313244ff";
        selection-text = "cdd6f4ff";
        selection-match = "89b4faff";
        border = "cba6f7ff";
      };
    };
  };

  # --- Terminal: kitty (enable kommt aus bfn.nix) ---
  # Statische Catppuccin-Farben als Basis/Fallback ...
  programs.kitty.settings = {
    font_family = "JetBrainsMono Nerd Font";
    font_size = 12;
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
  # vesktop, 1Password) unter Wayland ihr prefers-color-scheme ab. Ein blosses
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
  };

  # Qt-Apps (z.B. qbittorrent-GUI, VLC) an die GTK-Einstellung koppeln, damit
  # nicht die Haelfte des Desktops hell bleibt.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
