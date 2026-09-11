# Hyprland-WM-Config (home-manager). Shared -> fabricus jetzt, laptop spaeter.
# Catppuccin Mocha, clean & ruhig: dezente Gaps, keine Fenster-Transparenz,
# kurze/snappy Animationen. Bindings sind ein frischer Aufbau (nicht 1:1 aus den
# alten dotfiles portiert), aber vim-HJKL + 10 Workspaces bleiben.
{ config, pkgs, lib, osConfig, ... }:

# Der Monitor-Block wohnt seit 12.08.2026 NICHT mehr hier, sondern je Host in
# hosts/<host>/monitors.nix -- die beiden Faelle haben gegensaetzliche
# Anforderungen (Desktop statisch, Laptop je nach Dock/Beamer) und teilen sich
# keine einzige Zeile mehr. Eingebunden wird das ueber `source` weiter unten.
# Die isLaptop-Weiche bleibt, sie traegt noch die Trackpad-Gesten.
let
  isLaptop = osConfig.networking.hostName == "fabricus-itinerans";

  # Ablage fuer Screenshots (bfn 07.09.2026). grimblast legt das Verzeichnis
  # NICHT selbst an -- es baut den Dateinamen als "$DEFAULT_TARGET_DIR/<datum>.png"
  # und laesst grim darauf los; fehlt der Ordner, scheitert der Schuss.
  # Deshalb weiter unten die home.activation.
  screenshotDir = "${config.home.homeDirectory}/Pictures/screenshots";

  # Trackpad-Gesten -- nur der Laptop hat ueberhaupt ein Trackpad.
  #
  # Syntax ist die NEUE aus Hyprland 0.51+ (hier laeuft 0.56.1, verifiziert:
  # start-hyprland zeigt auf hyprland-0.56.1). Der alte Block
  #   gestures { workspace_swipe = true; workspace_swipe_fingers = 3 }
  # ist weg -- stattdessen:
  #   gesture = <finger>, <richtung>, [mod:MOD], [scale:X], <aktion> [args]
  # Richtungen: left/right/up/down/horizontal/vertical/swipe/pinch(in|out),
  # Aktionen u.a. workspace, special, move, resize, close, fullscreen,
  # float, cursorZoom, scrollMove, dispatcher, unset.
  # Quelle: handleGesture() in src/config/legacy/ConfigManager.cpp des Tags.
  #
  # `horizontal` deckt BEIDE Richtungen ab -- absichtlich keine zwei Zeilen
  # fuer left und right: der Parser lehnt das zweite mit "Gesture will be
  # overshadowed by a previous gesture" ab.
  gestureBlock =
    if isLaptop then ''

      ### Trackpad ###
      # 3 Finger horizontal = Workspace wechseln (kontinuierlich, mit Animation).
      gesture = 3, horizontal, workspace
    '' else "";
in
{
  # Screenshot-Ordner anlegen. Bewusst NICHT ueber xdg.userDirs: das Modul
  # schreibt ~/.config/user-dirs.dirs komplett neu (Store-Symlink, read-only)
  # und wuerde bestehende Eintraege dieser Datei ueberschreiben.
  home.activation.screenshotDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg screenshotDir}
  '';

  home.packages = with pkgs; [
    grimblast  # Screenshot-Wrapper (Print)

    # Discord als Website (SUPER+D). vesktop ist am 09.08.2026 rausgeflogen:
    # Screenshare war dort nicht zu retten. Ursache war NICHT der Client,
    # sondern xdg-desktop-portal-hyprland 1.4.1 -- "Out of buffers" ist normale
    # Backpressure, das Portal renegotiiert dabei aber den Buffer-Pool und
    # zerstoert den Frame-Callback, womit die Session stirbt (Issue #423, Fix in
    # PR #424 gemerged 06.08.2026, aber in KEINEM Release: v1.4.1 ist vom
    # 29.07.2026). Firefox loest den Bug nie aus, weil er die Buffer schnell
    # genug zurueckgibt -- im Gegentest am 09.08.2026 hat er sauber gestreamt,
    # auf demselben Portal und Treiber.
    #
    # Das Skript ersetzt vesktops Single-Instance-Verhalten: ein zweiter Druck
    # holt das bestehende Fenster nach vorn, statt ein weiteres zu oeffnen.
    # Grenze: gematcht wird ueber den FENSTERTITEL. Ein Firefox-Fenster, in dem
    # Discord nur einer von mehreren Tabs ist, wird nur getroffen, solange der
    # Discord-Tab aktiv ist. Fuer den gedachten Gebrauch (eigenes Fenster, per
    # --new-window erzeugt) passt das.
    (writeShellScriptBin "discord-web" ''
      if hyprctl -j clients \
           | ${jq}/bin/jq -e 'any(.[]; .title | test("Discord"))' >/dev/null; then
        hyprctl dispatch focuswindow 'title:.*Discord.*'
      else
        firefox --new-window https://discord.com/app
      fi
    '')

    # Rebuild per Tastendruck (bfn 11.09.2026, SUPER+R / SUPER+SHIFT+R).
    #
    # Bewusst ein Skript und keine `sh -c`-Kette im Bind: es braucht ein
    # Argument (--pull), eine Auswertung des Rueckgabecodes und ein Fenster,
    # das nach dem Lauf offen bleibt. Ohne das Letzte sieht man weder Fehler
    # noch Erfolg -- kitty schliesst sich, sobald das Kommando durch ist.
    #
    # Die Abbreviation `nrs` in home/fish.nix bleibt unveraendert: eine fish-
    # Abbreviation ist Text, der im Prompt expandiert wird, und von aussen
    # nicht aufrufbar. Beide Wege fuehren dasselbe Kommando aus.
    #
    # sudo kommt bewusst OHNE Store-Pfad: das setuid-Binary liegt im Wrapper
    # unter /run/wrappers/bin, das sudo aus dem Store waere nicht setuid und
    # damit wirkungslos. git dagegen mit Store-Pfad, wie beim discord-web-
    # Skript darueber.
    (writeShellScriptBin "nixos-switch" ''
      set -u

      if [ "''${1:-}" = "--pull" ]; then
        echo ":: git pull --ff-only in /etc/nixos"
        # --ff-only ist Absicht: liegen dort lokale Commits oder Aenderungen,
        # die einen Merge braeuchten, soll der Lauf STEHEN statt zu mergen.
        # /etc/nixos gehoert bfn, der Pull laeuft deshalb ohne sudo.
        if ! ${git}/bin/git -C /etc/nixos pull --ff-only; then
          echo
          echo "!! git pull fehlgeschlagen -- es wird NICHT gebaut."
          printf 'Fenster schliessen: Enter. '
          read -r _
          exit 1
        fi
        echo
      fi

      sudo nixos-rebuild switch --flake /etc/nixos
      rc=$?

      echo
      if [ "$rc" -eq 0 ]; then
        echo ":: switch erfolgreich (rc=0)"
      else
        echo "!! switch fehlgeschlagen (rc=$rc)"
      fi
      printf 'Fenster schliessen: Enter. '
      read -r _
      exit "$rc"
    '')

    # Der selbstgebaute hypr-cheatsheet ist am 09.08.2026 rausgeflogen. Ersetzt
    # durch das noctalia-Plugin kenn/keybind-cheatsheet -- gleiche Idee (Binds
    # live statt aus einer Doku-Kopie), aber im noctalia-Design statt in fuzzel.
    # Das Plugin liest hyprland.conf direkt (Einstellung hyprland_parser=conf),
    # es braucht also weder Lua noch hyprctl-Parsing von Hand. Mit dem Ausbau
    # verliert fuzzel seinen letzten Nutzer und fliegt ebenfalls raus.
  ];

  xdg.configFile."hypr/hyprland.conf".text = ''
    # Managed by home-manager (nixos-prep/home/hyprland.nix)
    # Catppuccin Mocha - clean & ruhig

    ### Monitor ###
    # Host-spezifisch, deshalb ausgelagert: hosts/<host>/monitors.nix schreibt
    # diese Datei (xdg.configFile, also Store-Symlink und read-only). Sie ist
    # der EINZIGE Ort mit monitor=-Regeln -- hier steht bewusst keine, auch kein
    # Catch-all, sonst gewinnt je nach Reihenfolge mal die eine, mal die andere.
    # Fehlt die Datei, warnt Hyprland nur (wie bei noctalia.conf weiter unten).
    source = ~/.config/hypr/monitors.conf

    ### Programme ###
    $terminal    = kitty
    # Suche/Launcher ist ab 08.08.2026 noctalias Panel statt fuzzel -- ein Stack
    # fuer alles, was aufklappt. Seit 09.08.2026 ist fuzzel auch als Paket weg,
    # weil die Hilfe auf das noctalia-Plugin umgezogen ist (war der letzte Nutzer).
    $menu        = noctalia msg panel-toggle launcher
    $browser     = firefox
    $mail        = thunderbird
    # --override=confirm_os_window_close=0: kitty fragt sonst beim Schliessen
    # (SUPER+W) nach, weil im Fenster noch yazi laeuft. Bewusst nur hier und
    # nicht global -- bei einem Terminal mit laufendem Build will man die Frage.
    $fileManager = kitty --override=confirm_os_window_close=0 -e yazi
    $mainMod     = SUPER

    ### Autostart ###
    #exec-once = waybar
    #exec-once = mako
    exec-once = noctalia
    exec-once = 1password --silent
    # polkit-Authentication-Agent. Ohne ihn lehnt polkitd jede Anfrage sofort
    # ab -- kein Dialog, keine Fehlermeldung. Betrifft jede polkit-Aktion der
    # Session; aufgefallen ist es an 1Passwords Unlock per Systemauth, der
    # deshalb nie funktioniert hat. Hintergrund und Messung in home/apps.nix.
    #
    # soteria statt hyprpolkitagent (09.09.2026, Optik). Der erste Anlauf lief
    # funktional einwandfrei, sah aber ungethemt aus -- und das hat einen
    # nachvollziehbaren Grund: hyprpolkitagent ist Qt/QML. home/theme.nix
    # koppelt Qt per `qt.platformTheme.name = "gtk3"` ans GTK-Theme, aber das
    # greift nur fuer QWidget-Apps (qbittorrent, VLC). QtQuick-Controls laufen
    # nicht ueber QStyle und ignorieren die Kopplung, der Dialog blieb also
    # hell. soteria ist GTK -- es nimmt Adwaita-dark aus home/theme.nix direkt.
    #
    # exec-once statt der systemd-User-Unit des home-manager-Moduls: die
    # haengt an graphical-session.target, das diese Session nie erreicht. Als
    # exec-once-Kind von Hyprland erbt der Agent ausserdem WAYLAND_DISPLAY &
    # Co. garantiert -- der User-Manager kennt diese Variablen hier nicht.
    #
    # Voller Store-Pfad wie bei den Nachbarn oben: haelt die Zeile unabhaengig
    # davon, ob das Paket je in home.packages landet.
    exec-once = ${pkgs.soteria}/bin/soteria
    # cliphist-Mitschnitt hier entfernt (08.08.2026): noctalia bringt eine
    # EIGENE Clipboard-History mit und nutzt cliphist nachweislich nicht (im
    # noctalia-5.0.0-Binary kommt weder `cliphist` noch `wl-paste` vor). Beides
    # parallel hiess: zwei unabhaengige Historien mit unterschiedlichem Inhalt,
    # je nachdem ob man die Bar oder SUPER+V benutzt hat.

    ### Look ###
    general {
        gaps_in = 4
        gaps_out = 8
        border_size = 2
        col.active_border = rgba(89b4faee) rgba(cba6f7ee) 45deg
        col.inactive_border = rgba(45475aaa)
        layout = dwindle
        resize_on_border = true
    }

    decoration {
        rounding = 10
        active_opacity = 1.0
        inactive_opacity = 1.0
        blur {
            enabled = true
            size = 4
            passes = 2
            vibrancy = 0.15
        }
        shadow {
            enabled = true
            range = 12
            render_power = 2
            color = rgba(11111baa)
        }
    }

    animations {
        enabled = true
        bezier = easeOut, 0.16, 1, 0.3, 1
        animation = windows,    1, 3, easeOut
        animation = windowsOut, 1, 3, easeOut, popin 80%
        animation = fade,       1, 3, easeOut
        animation = border,     1, 5, easeOut
        animation = workspaces, 1, 3, easeOut, slide
    }

    dwindle {
        # pseudotile: in Hyprland 0.56 als Config-Option entfernt (weder unter
        # dwindle:, general: noch misc: -- per --verify-config geprueft).
        # Pseudotiling gibt es weiter als Dispatcher `pseudo`, siehe Keybinds.
        preserve_split = true
    }

    misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
    }

    input {
        kb_layout = de
        follow_mouse = 1
        sensitivity = 0
        touchpad {
            natural_scroll = true
        }
    }
${gestureBlock}
    ### Color Management: wp-cm-v1 auf Version 1 begrenzen ###
    # Hyprland 0.56 bietet wp-color-management-v1 in Version 2 an. Firefox 146
    # implementiert nur v1 -- dort hat wp_image_description_v1 exakt zwei Events
    # (failed, ready). Hyprland schickt ein v2-Event, Firefox kennt Opcode 2 nicht
    # -> "Wayland protocol error: interface 'wp_image_description_v1' has no
    # event 2" -> Wayland killt den Client hart (rc=11, Minidump).
    # Verifiziert 06.08.2026: unter Wayland rc=11 reproduzierbar (auch mit frischem
    # Profil), mit MOZ_ENABLE_WAYLAND=0 rc=0. Also compositor-seitig, nicht Firefox.
    # Diese Option laesst Color Management AN, deckelt nur die Protokoll-Version.
    # Greift NUR nach Compositor-Neustart (Globals werden beim Start advertised) --
    # `hyprctl keyword` reicht nicht.
    experimental {
        wp_cm_1_2 = false
    }
    # Fallback, falls das nicht reicht: Color Management ganz aus (kostet HDR).
    # render {
    #     cm_enabled = false
    # }

    ### Adaptive Theming (noctalia) ###
    # noctalia rendert seine Material-Palette nach ~/.config/hypr/noctalia.conf und
    # ueberschreibt damit die statischen Border-Farben aus general{} oben (source =
    # last-wins). Fehlt die Datei (erster Boot / noctalia aus), warnt Hyprland nur
    # und behaelt die Catppuccin-Werte. Live-Recolor beim Wallpaper-Wechsel braucht
    # ggf. ein `hyprctl reload`, weil noctalias apply.sh die read-only HM-conf nicht
    # selbst nachladen kann.
    source = ~/.config/hypr/noctalia.conf

    ### Keybindings ###
    #
    # Jeder Bind traegt einen Klartext-Kommentar am Zeilenende. Das ist kein
    # Schmuck: das keybind-cheatsheet-Plugin liest genau dieses Muster --
    # `# "Text"` am Zeilenende, Zeile MUSS auf das Anfuehrungszeichen enden
    # (service.luau, extractTrailingDescription). Ohne den Kommentar landet der
    # Bind im Panel unter "without description" und zeigt nur den rohen
    # Dispatcher, also z.B. "Launch $menu" statt "Anwendungen suchen".
    #
    # NICHT `bindd` verwenden, obwohl Hyprland das koennte: der Parser des
    # Plugins splittet Bind-Zeilen auf 4 Felder, `bindd` hat 5 -- die
    # Beschreibung landet dann im Dispatcher-Feld und die Anzeige ist kaputt.
    #
    # Fenster & Session
    bind = $mainMod, Return, exec, $terminal  # "Terminal öffnen"
    bind = $mainMod, Space, exec, $menu  # "Anwendungen suchen und starten"
    bind = $mainMod, W, killactive  # "Aktives Fenster schließen"
    bind = $mainMod SHIFT, Q, exit  # "Hyprland beenden (abmelden)"
    bind = $mainMod, F, fullscreen  # "Vollbild an/aus"
    # V-Paar am 27.08.2026 getauscht (bfn): der Zwischenablage-Verlauf ist der
    # haeufigere Griff und sitzt jetzt auf dem ungeshifteten SUPER+V (unten im
    # System-Block), togglefloating rueckt auf SHIFT.
    bind = $mainMod SHIFT, V, togglefloating  # "Fenster schweben lassen / einrasten"
    # togglesplit ist seit 0.56 kein eigener Dispatcher mehr, sondern eine
    # Layout-Message. SHIFT+P = pseudotile, ersetzt die weggefallene dwindle-Option.
    #
    # Pseudotile lag bis 08.08.2026 auf SUPER+P und kollidierte dort mit dem
    # 1Password-Bind weiter unten. Hyprland nimmt bei doppelt belegter Taste den
    # ERSTEN Treffer -- der 1Password-Bind war damit wirkungslos, ohne dass es
    # eine Fehlermeldung gegeben haette. Pseudotile ist der deutlich seltenere
    # Griff und zieht deshalb um; P bleibt bei Password.
    bind = $mainMod, T, layoutmsg, togglesplit  # "Teilung drehen: nebeneinander <-> übereinander"
    bind = $mainMod SHIFT, P, pseudo  # "Pseudo-Kachelung an/aus"

    # Fokus (vim HJKL)
    bind = $mainMod, H, movefocus, l  # "Fokus nach links"
    bind = $mainMod, J, movefocus, d  # "Fokus nach unten"
    bind = $mainMod, K, movefocus, u  # "Fokus nach oben"
    bind = $mainMod, L, movefocus, r  # "Fokus nach rechts"

    # Fenster verschieben -- jetzt symmetrisch zum Fokus-Block darueber.
    # SHIFT+H war bis 08.08.2026 fuer das Help-Menue reserviert, nach links
    # verschieben ging deshalb nur per Maus-Drag. Help sitzt jetzt auf SUPER+?.
    bind = $mainMod SHIFT, H, movewindow, l  # "Fenster nach links verschieben"
    bind = $mainMod SHIFT, J, movewindow, d  # "Fenster nach unten verschieben"
    bind = $mainMod SHIFT, K, movewindow, u  # "Fenster nach oben verschieben"
    bind = $mainMod SHIFT, L, movewindow, r  # "Fenster nach rechts verschieben"

    # Apps
    bind = $mainMod, B, exec, $browser  # "Browser (Firefox)"
    bind = $mainMod, M, exec, $mail  # "Mail (Thunderbird)"
    bind = $mainMod, E, exec, $fileManager  # "Dateimanager (yazi im Terminal)"
    bind = $mainMod, O, exec, obsidian  # "Obsidian (Notizen)"
    bind = $mainMod, P, exec, 1password  # "1Password"
    bind = $mainMod, D, exec, discord-web  # "Discord (Website in Firefox)"
    # Editor im Terminal. Bewusst OHNE das --override=confirm_os_window_close=0
    # aus $fileManager: bei yazi ist die Rueckfrage beim Schliessen laestig, bei
    # nvim ist sie die letzte Warnung vor ungespeicherten Puffern.
    bind = $mainMod, N, exec, $terminal -e nvim  # "Neovim (Editor im Terminal)"
    # SUPER+G (lazygit) gab es am 27.08.2026 fuer ein paar Stunden und ist
    # wieder weg -- Begruendung bei der `lg`-Abbreviation in home/fish.nix.
    # Kurzform: ein Bind startet ein Fenster ohne Kontext und muss sich das
    # Repo aus einer Notiz holen; die Shell hat den Kontext schon.

    # System
    bind = $mainMod SHIFT, Escape, exec, hyprlock  # "Bildschirm sperren"
    # Hilfe auf SUPER+ss. Voraus gingen zwei tote Varianten: `SHIFT, question`
    # und `SHIFT, ssharp`. Gelernt (verifiziert im Test 09.08.2026): auf
    # de-Layout ist ? = Shift+ss, aber Hyprland matcht hier den Keysym der
    # BASIS-Ebene -- also `ssharp` OHNE SHIFT im Modifier-Feld. Ein Bind auf den
    # geshifteten Keysym feuert nie, und zwar kommentarlos.
    #
    # Die Panel-ID ist voll qualifiziert (<plugin-id>:<panel-id>) -- ein blosses
    # `cheatsheet` quittiert noctalia mit `unknown panel`.
    bind = $mainMod, ssharp, exec, noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet  # "Diese Tastenkürzel-Übersicht"
    # Screenshots landen seit 07.09.2026 in ~/Pictures/screenshots statt lose
    # im Bilder-Ordner. Der Weg ist DEFAULT_TARGET_DIR und nicht die Session-
    # Variable XDG_SCREENSHOTS_DIR: grimblast prueft DEFAULT_TARGET_DIR ZUERST
    # und ueberspringt dann das Einlesen von user-dirs.dirs komplett -- damit
    # haengt das Ziel an keiner Datei, die ich nicht kontrolliere, und wirkt
    # sofort nach `hyprctl reload` statt erst nach dem naechsten Login (env =
    # wird nur beim Compositor-Start gesetzt). Die Zuweisung vor dem Befehl
    # traegt Hyprland, weil es exec ueber `/bin/sh -c` startet.
    bind = $mainMod, C, exec, DEFAULT_TARGET_DIR=${screenshotDir} grimblast --notify copysave area  # "Screenshot: Bereich auswählen"
    bind = $mainMod CTRL, C, exec, DEFAULT_TARGET_DIR=${screenshotDir} grimblast --notify copysave screen  # "Screenshot: ganzer Bildschirm"
    bind = $mainMod SHIFT, C, exec, hyprpicker -a  # "Farbe vom Bildschirm aufnehmen"
    # Clipboard-History: noctalias Panel statt cliphist+fuzzel (siehe Autostart).
    # Panel-ID `clipboard` ist seit 09.08.2026 bestaetigt -- noctalia listet bei
    # einer falschen ID alle gueltigen auf, das ist der billigste Weg sie zu
    # pruefen (`noctalia msg panel-toggle bloedsinn`).
    # Liegt seit 27.08.2026 auf SUPER+V statt SUPER+SHIFT+V, siehe Tausch oben.
    bind = $mainMod, V, exec, noctalia msg panel-toggle clipboard  # "Zwischenablage-Verlauf"
    # Benachrichtigungen. Es gibt in noctalia 5.0.0 KEIN eigenstaendiges
    # Notification-Panel -- die Historie ist ein TAB des Control-Centers. Der
    # Aufruf nimmt deshalb zwei Argumente: Panel, dann Tab. Verifiziert gegen
    # das gepinnte Binary: die vordefinierten Widget-Aktionen enthalten exakt
    # `panel-toggle control-center notifications` (daneben home, calendar,
    # audio, network, bluetooth, weather, system, monitor, power).
    bind = $mainMod SHIFT, N, exec, noctalia msg panel-toggle control-center notifications  # "Benachrichtigungen"
    bind = $mainMod SHIFT, E, exec, noctalia msg settings-toggle  # "noctalia-Einstellungen"
    # hyprctl reload ist am 11.09.2026 von SUPER+SHIFT+R auf SUPER ALT+R
    # umgezogen -- SUPER+SHIFT+R ist jetzt der Rebuild (unten). Die beiden
    # haetten sich sonst still gegenseitig verschluckt: bei doppelt belegter
    # Taste nimmt Hyprland kommentarlos den ERSTEN Treffer (dieselbe Falle wie
    # 08.08.2026 bei SUPER+P/pseudo). SUPER ALT ist als Modifier hier schon in
    # Gebrauch (Wallpaper, ganz unten).
    bind = SUPER ALT, R, exec, hyprctl reload  # "Hyprland-Konfiguration neu laden"

    # NixOS neu bauen, ohne ins Terminal zu wechseln (bfn 11.09.2026).
    # Beide Binds oeffnen bewusst ein eigenes kitty-Fenster: sudo fragt nach
    # dem Passwort, und der Build-Output ist das Einzige, woran man sieht, ob
    # der switch durch ist. Was das Skript genau tut, steht bei nixos-switch
    # weiter oben in dieser Datei.
    bind = $mainMod, R, exec, $terminal --title "nixos-rebuild switch" -e nixos-switch  # "NixOS neu bauen (nixos-rebuild switch)"
    bind = $mainMod SHIFT, R, exec, $terminal --title "git pull + nixos-rebuild switch" -e nixos-switch --pull  # "NixOS: erst git pull, dann neu bauen"
    # Fremdes WLAN mit Anmeldeseite. Ohne das Skript kommt die Seite nie hoch:
    # Tailscale haelt den DNS auf 100.100.100.100, das Portal kann seinen
    # Redirect also gar nicht ausliefern. Begruendung im Kopf von
    # modules/captive-portal.nix.
    bind = $mainMod SHIFT, W, exec, wifi-portal  # "WLAN-Anmeldeseite öffnen (Hotel, Café, Bahn)"

    # Workspaces
    bind = $mainMod, 1, workspace, 1  # "Zu Workspace 1"
    bind = $mainMod, 2, workspace, 2  # "Zu Workspace 2"
    bind = $mainMod, 3, workspace, 3  # "Zu Workspace 3"
    bind = $mainMod, 4, workspace, 4  # "Zu Workspace 4"
    bind = $mainMod, 5, workspace, 5  # "Zu Workspace 5"
    bind = $mainMod, 6, workspace, 6  # "Zu Workspace 6"
    bind = $mainMod, 7, workspace, 7  # "Zu Workspace 7"
    bind = $mainMod, 8, workspace, 8  # "Zu Workspace 8"
    bind = $mainMod, 9, workspace, 9  # "Zu Workspace 9"
    bind = $mainMod, 0, workspace, 10  # "Zu Workspace 10"

    bind = $mainMod SHIFT, 1, movetoworkspace, 1  # "Fenster auf Workspace 1"
    bind = $mainMod SHIFT, 2, movetoworkspace, 2  # "Fenster auf Workspace 2"
    bind = $mainMod SHIFT, 3, movetoworkspace, 3  # "Fenster auf Workspace 3"
    bind = $mainMod SHIFT, 4, movetoworkspace, 4  # "Fenster auf Workspace 4"
    bind = $mainMod SHIFT, 5, movetoworkspace, 5  # "Fenster auf Workspace 5"
    bind = $mainMod SHIFT, 6, movetoworkspace, 6  # "Fenster auf Workspace 6"
    bind = $mainMod SHIFT, 7, movetoworkspace, 7  # "Fenster auf Workspace 7"
    bind = $mainMod SHIFT, 8, movetoworkspace, 8  # "Fenster auf Workspace 8"
    bind = $mainMod SHIFT, 9, movetoworkspace, 9  # "Fenster auf Workspace 9"
    bind = $mainMod SHIFT, 0, movetoworkspace, 10  # "Fenster auf Workspace 10"

    bind = $mainMod, mouse_down, workspace, e+1  # "Nächster Workspace (Mausrad)"
    bind = $mainMod, mouse_up, workspace, e-1  # "Voriger Workspace (Mausrad)"

    # Tastatur-Aequivalent zum 3-Finger-Wisch (bfn 07.09.2026), seit
    # 11.09.2026 monitor-lokal: `m±1` statt `e±1`.
    #
    # Der Unterschied zaehlt erst mit zwei Bildschirmen. Beide Formen laufen
    # durch denselben Parser, aber `e` setzt onAllMonitors -- die Liste der
    # Sprungziele sind dann die Workspaces ALLER Monitore, und wer dort landet,
    # nimmt den Fokus auf den Nachbarmonitor mit. `m` filtert auf
    # `ws->m_monitor == focusState()->monitor()`, bleibt also auf dem
    # fokussierten Bildschirm -- und ist exakt das, was der Wisch tut:
    # CUnifiedWorkspaceSwipeGesture holt seine Ziele als "m-1"/"m+1" (mit
    # gestures:workspace_swipe_use_r waeren es "r±1", Default ist aus).
    # Geprueft im Quelltext des laufenden Tags v0.56.1, nicht in der Doku:
    # src/helpers/MiscFunctions.cpp (getWorkspaceIDNameFromString) und
    # src/managers/input/UnifiedWorkspaceSwipeGesture.cpp.
    #
    # Zwei Eigenheiten, die dabei aufgefallen sind:
    #   * `m±1` springt NUR auf bestehende Workspaces, legt also nie einen
    #     neuen an. Ein neuer kommt per SUPER++ (unten).
    #   * Es WICKELT am Ende der Liste um (currentItem % validWSes.size()).
    #     Der Kommentar, der hier bis 11.09.2026 stand ("kein Wrap-around"),
    #     war falsch -- `e±1` laeuft durch denselben Modulo und wickelt
    #     genauso. Der Wisch legt an dieser Stelle stattdessen einen neuen
    #     Workspace an (gestures:workspace_swipe_create_new, Default an); das
    #     ist der eine Punkt, in dem Tastatur und Trackpad sich unterscheiden.
    bind = $mainMod, left, workspace, m-1  # "Voriger Workspace (auf diesem Bildschirm)"
    bind = $mainMod, right, workspace, m+1  # "Nächster Workspace (auf diesem Bildschirm)"

    # Dasselbe mit Fenster im Schlepptau (bfn 07.09.2026). `movetoworkspace`
    # (nicht ...silent) nimmt den Fokus mit -- man landet beim Fenster, wie bei
    # SUPER+SHIFT+1..0 darueber. `m±1` aus demselben Grund wie eine Zeile
    # darueber: das Fenster bleibt auf dem Bildschirm, auf dem es war.
    bind = $mainMod SHIFT, left, movetoworkspace, m-1  # "Fenster einen Workspace nach links"
    bind = $mainMod SHIFT, right, movetoworkspace, m+1  # "Fenster einen Workspace nach rechts"

    # Neuer leerer Workspace auf dem fokussierten Bildschirm (bfn 11.09.2026).
    # `emptynm` liest der Parser buchstabenweise: n = der naechste freie HINTER
    # dem aktuellen (ohne n waere es die niedrigste freie Nummer ueberhaupt,
    # also eine Luecke weiter vorn), m = keine Nummer, die per workspace-Regel
    # an einen anderen Monitor gebunden ist. Damit fuehlt es sich an wie der
    # Wisch nach rechts ueber das Ende hinaus.
    #
    # Taste: auf dem de-Layout liegt `+` auf der BASIS-Ebene, der Bind heisst
    # deshalb `plus` -- dieselbe Regel wie bei `ssharp` weiter oben, und aus
    # demselben Grund steht SHIFT hier nicht im Modifier-Feld.
    bind = $mainMod, plus, workspace, emptynm  # "Neuer leerer Workspace auf diesem Bildschirm"

    # SUPER+Tab oeffnet noctalias Fenster-Switcher statt blind einen Workspace
    # weiterzuschalten (bfn 09.08.2026: getestet, reicht ihm -- damit ist
    # hyprshell vom Tisch und wir sparen uns einen dritten UI-Stack mit eigenem
    # Launcher und eigener Clipboard-History).
    #
    # SUPER+SHIFT+Tab ist bewusst WEG statt auf `workspace, e-1` zu bleiben:
    # bei offenem Switcher ist Shift+Tab das Rueckwaertsblaettern IM Switcher,
    # ein Hyprland-Bind wuerde dort dazwischenfunken. Workspace-Blaettern per
    # Tastatur geht weiter ueber SUPER+1..0, per Maus ueber SUPER+Scroll.
    bind = $mainMod, Tab, exec, noctalia msg window-switcher  # "Fenster-Umschalter (alle offenen Fenster)"

    # Scratchpad
    bind = $mainMod, S, togglespecialworkspace, magic  # "Scratchpad ein-/ausblenden"
    bind = $mainMod SHIFT, S, movetoworkspace, special:magic  # "Fenster ins Scratchpad legen"

    # Maus: move/resize per Drag
    bindm = $mainMod, mouse:272, movewindow  # "Fenster ziehen (linke Maustaste)"
    bindm = $mainMod, mouse:273, resizewindow  # "Fenstergröße ziehen (rechte Maustaste)"

    # Media & Helligkeit
    # SPACE stand hier im Modifier-Feld, ist aber kein Modifier -- der Bind war
    # damit ungueltig und hat nie ausgeloest. 08.08.2026 auf SUPER ALT korrigiert.
    bind = SUPER ALT, W, exec, noctalia msg wallpaper-next  # "Nächstes Hintergrundbild"
    bindel = ,XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+  # "Lautstärke +5%"
    bindel = ,XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-  # "Lautstärke -5%"
    bindel = ,XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle  # "Stumm an/aus"
    bindel = ,XF86MonBrightnessUp,   exec, brightnessctl -e4 -n2 set 5%+  # "Helligkeit +5%"
    bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-  # "Helligkeit -5%"
    bindl  = ,XF86AudioNext,  exec, playerctl next  # "Nächster Titel"
    bindl  = ,XF86AudioPause, exec, playerctl play-pause  # "Wiedergabe pausieren/fortsetzen"
    bindl  = ,XF86AudioPlay,  exec, playerctl play-pause  # "Wiedergabe pausieren/fortsetzen"
    bindl  = ,XF86AudioPrev,  exec, playerctl previous  # "Voriger Titel"
  '';
}
