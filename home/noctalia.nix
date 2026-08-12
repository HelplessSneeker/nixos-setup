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
  # fabricus-itinerans: eDP-1, 1920x1080 auf 310x170 mm = ebenfalls ~157 PPI,
  # aber in Hyprland auf scale 1.0 (1080p vertraegt kein fractional Scaling).
  # Logisch sind das volle 157 px/Zoll -> Faktor 157/96 = 1.63, also 34 -> 55
  # und 1.0 -> 1.6.
  #
  # Die alten Laptop-Werte (1.0 / 34) waren schlicht falsch gerechnet: sie
  # unterstellten 96 logische px/Zoll, was nur bei scale 1.63 zutraefe. Ergebnis
  # war eine Bar, die auf dem Laptop rund 40 % kleiner wirkte als auf dem
  # Desktop. Gegenprobe ueber den anderen Weg: 1.3 x 1.25 = 1.63, gleiches
  # Ergebnis -- damit sind beide Bars jetzt physisch gleich gross.
  #
  # `scale` skaliert den Widget-INHALT, `thickness` die Bar-HOEHE. Die beiden
  # haengen im Code nicht aneinander -- immer gemeinsam anpassen, sonst
  # sprengt der Inhalt die Bar oder schwimmt darin.
  # 1.45/50 statt der rechnerischen 1.63/55: die volle Paritaet war bfn nach
  # dem Sehen einen Tick zu gross (09.08.2026). Bleibt deutlich ueber den alten
  # 1.0/34, die schlicht falsch gerechnet waren.
  barScale = if isLaptop then 1.45 else 1.3;
  barThickness = if isLaptop then 50 else 44;
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

      # Kalender im Control-Center. Quelle ist Radicale auf personal-server
      # (cal.bfnoessler.at), seit 12.08.2026 der Master fuer alle Geraete.
      #
      # noctalia LIEST nur, es schreibt nicht: der CalendarService liefert laut
      # Quellcode einen "read-only event snapshot", der CalDavClient kennt genau
      # eine Methode (fetchEvents). Termine anlegen und aendern bleibt Sache von
      # Thunderbird bzw. DAVx5 am Handy. Aufgaben (VTODO) blendet der Parser
      # ohnehin aus, die Bar bleibt also frei davon.
      #
      # Das Passwort darf hier NICHT stehen: nixos-setup ist ein oeffentliches
      # Repo, und Flake-Quellen landen zusaetzlich im weltlesbaren Nix-Store.
      # Deshalb credential_source = "file" auf eine Datei ausserhalb des Stores.
      # Einmalig pro Maschine anlegen:
      #   mkdir -p ~/.config/noctalia
      #   install -m 600 /dev/null ~/.config/noctalia/caldav-password
      #   printf '%s' 'DAS-PASSWORT' > ~/.config/noctalia/caldav-password
      # printf statt echo ist Absicht: noctalia entfernt beim Lesen genau EIN
      # abschliessendes Newline und trimmt sonst nichts -- ein Leerzeichen waere
      # Teil des Passworts und der Login schluege fehl.
      calendar = {
        enabled = true;
        refresh_minutes = 15;

        # Der Tabellen-Schluessel ist die Account-ID. Sie muss [a-z0-9_] sein,
        # weil noctalia damit dauerhaft die Credential-Records identifiziert.
        account.privat = {
          type = "caldav";
          provider = "custom";   # kein Preset (icloud), eigener Server
          name = "Privat";       # Anzeigename -- das Feld heisst "name", NICHT display_name
          color = "#1a5fb4";     # gleiche Farbe wie im Radicale-Web-UI
          server_url = "https://cal.bfnoessler.at/";
          username = "bfn";
          credential_source = "file";
          password_file = "${config.home.homeDirectory}/.config/noctalia/caldav-password";
          # `calendars` bewusst weggelassen: leer bedeutet "alle gefundenen",
          # damit ein spaeter angelegter zweiter Kalender ohne Rebuild auftaucht.
        };
      };
    };
  };
}
