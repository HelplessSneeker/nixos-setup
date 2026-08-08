{ config, lib, osConfig, ... }:

# noctalia: Shell-Theming + Bar-Layout.
#
# Wichtig zum Verstaendnis der Bar-Config:
#   - `bar.default.start/center/end` sind Listen von WIDGET-NAMEN.
#   - Ein Name wird zuerst in `[widget.<name>]` gesucht; gibt es dort keinen
#     Eintrag, wird der Name selbst als Widget-TYP interpretiert.
#   - Per-Widget-Optionen leben deshalb NICHT in der Bar-Liste, sondern in
#     einem eigenen `widget.<name>`-Block.
# Optionsnamen sind gegen den gepinnten noctalia-Rev verifiziert
# (`noctalia config export full` + src/shell/bar/widget_factory.cpp).

let
  # home/ ist zwischen fabricus (Desktop) und dem geplanten
  # fabricus-itinerans (Laptop) geteilt. Akku, Bluetooth und Helligkeit
  # haben auf dem Desktop keine Datenquelle -- /sys/class/power_supply und
  # /sys/class/backlight sind leer, bluez laeuft nicht. Die Widgets waren
  # deshalb sichtbar, aber tot. Auf dem Laptop kommen sie zurueck.
  isLaptop = osConfig.networking.hostName == "fabricus-itinerans";

  # Bar-Groesse ist reine Display-Sache und gehoert deshalb pro Host gesetzt.
  # fabricus: 2x BenQ EL2870U, 28" 4k = ~157 PPI, in Hyprland auf scale 1.25.
  # Logisch bleiben damit ~126 px/Zoll -- noctalias Defaults (thickness 34,
  # scale 1.0) sind aber gegen 96 px/Zoll gezeichnet. Faktor 126/96 = 1.31,
  # daher 34 -> 44 und 1.0 -> 1.3.
  # `scale` skaliert den Widget-INHALT, `thickness` die Bar-HOEHE. Die beiden
  # haengen im Code nicht aneinander -- immer gemeinsam anpassen, sonst
  # sprengt der Inhalt die Bar oder schwimmt darin.
  barScale = if isLaptop then 1.0 else 1.3;
  barThickness = if isLaptop then 34 else 44;
in
{
  programs.noctalia = {
    enable = true;
    settings = {
      shell.font_family = "JetBrainsMono Nerd Font";

      # Clipboard-History. Lief bisher nebenher (das Bar-Widget war da), ist seit
      # 08.08.2026 aber die EINZIGE -- cliphist ist raus, siehe home/hyprland.nix.
      # Deshalb hier explizit statt auf den Default zu vertrauen.
      # `clipboard_history_max_entries` bewusst NICHT gesetzt: der Default ist
      # unbekannt und funktioniert, ein geratener Wert waere eine Verhaltens-
      # aenderung ohne Anlass. Zum Nachjustieren: SUPER+SHIFT+E -> Einstellungen.
      shell.clipboard_enabled = true;

      theme = {
        mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "m3-tonal-spot";
        # Adaptive App-Theming: noctalia rendert seine Wallpaper-Palette in die
        # App-Configs (kitty-Farben + Hyprland-Border) bei jedem Palette-Wechsel.
        # Aktiviert die mitgelieferten Templates; Liste: `noctalia theme --list-templates`.
        templates = {
          enable_builtin_templates = true;
          builtin_ids = [ "kitty" "hyprland" ];
        };
      };

      wallpaper = {
        enabled = true;
        directory = "~/Pictures/Wallpapers";
        transition_on_startup = true;   # setzt Wallpaper beim Boot, nicht erst nach Intervall
        automation = {
          enabled = true;
          order = "random";
          interval_seconds = 1800;
          recursive = true;
        };
      };

      # Bisher war die Bar ueberhaupt nicht konfiguriert -- noctalia fuhr seine
      # Stock-Defaults ("no [bar.*] defined, using defaults" im Log). Die Listen
      # hier sind exakt diese Defaults, nur um die drei Laptop-Widgets bereinigt.
      bar.default = {
        scale = barScale;
        thickness = barThickness;

        start = [ "launcher" "wallpaper" "workspaces" ];
        center = [ "clock" ];
        end =
          [ "media" "tray" "notifications" "clipboard" "network" ]
          ++ lib.optional isLaptop "bluetooth"
          ++ [ "volume" ]
          ++ lib.optional isLaptop "brightness"
          ++ lib.optional isLaptop "battery"
          ++ [ "control-center" "session" ];
      };

      widget = {
        # Uhrzeit oben, Datum darunter. Der Clock-Widget bricht am \n in eine
        # zweite, kleiner gesetzte Zeile um und skaliert automatisch herunter,
        # falls es nicht in die Bar-Hoehe passt.
        # Der Tooltip (Hover) gibt das ausgeschriebene Datum -- Hover
        # funktioniert unabhaengig von den Klick-Panels.
        clock = {
          type = "clock";
          format = "{:%H:%M}\n{:%d.%m.%Y}";
          tooltip_format = "{:%A, %d. %B %Y}";
        };

        # hide_when_no_media: Widget verschwindet komplett aus dem Layout,
        # wenn kein MPRIS-Player aktiv ist.
        # title_scroll = "on_hover": laengere Titel scrollen beim Drueberfahren
        # durch, statt abgeschnitten zu werden.
        media = {
          type = "media";
          hide_when_no_media = true;
          title_scroll = "on_hover";
        };
      };
    };
  };
}
