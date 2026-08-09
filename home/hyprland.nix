# Hyprland-WM-Config (home-manager). Shared -> fabricus jetzt, laptop spaeter.
# Catppuccin Mocha, clean & ruhig: dezente Gaps, keine Fenster-Transparenz,
# kurze/snappy Animationen. Bindings sind ein frischer Aufbau (nicht 1:1 aus den
# alten dotfiles portiert), aber vim-HJKL + 10 Workspaces bleiben.
{ config, pkgs, lib, ... }:
{
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
    # 2x BenQ EL2870U (28" 4k). scale 1.25 -> logisch 3072x1728 pro Schirm
    # (teilt 3840/2160 sauber, kein Fractional-Blur). HDMI links, DP rechts daneben.
    monitor = HDMI-A-1, 3840x2160@60, 0x0, 1.25
    monitor = DP-1,     3840x2160@60, 3072x0, 1.25
    monitor = ,preferred,auto,1.25

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
    # cliphist-Mitschnitt hier entfernt (08.08.2026): noctalia bringt eine
    # EIGENE Clipboard-History mit und nutzt cliphist nachweislich nicht (im
    # noctalia-5.0.0-Binary kommt weder `cliphist` noch `wl-paste` vor). Beides
    # parallel hiess: zwei unabhaengige Historien mit unterschiedlichem Inhalt,
    # je nachdem ob man die Bar oder SUPER+SHIFT+V benutzt hat.

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
    bind = $mainMod, V, togglefloating  # "Fenster schweben lassen / einrasten"
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
    bind = $mainMod, C, exec, grimblast --notify copysave area  # "Screenshot: Bereich auswählen"
    bind = $mainMod CTRL, C, exec, grimblast --notify copysave screen  # "Screenshot: ganzer Bildschirm"
    bind = $mainMod SHIFT, C, exec, hyprpicker -a  # "Farbe vom Bildschirm aufnehmen"
    # Clipboard-History: noctalias Panel statt cliphist+fuzzel (siehe Autostart).
    # Panel-ID `clipboard` ist seit 09.08.2026 bestaetigt -- noctalia listet bei
    # einer falschen ID alle gueltigen auf, das ist der billigste Weg sie zu
    # pruefen (`noctalia msg panel-toggle bloedsinn`).
    bind = $mainMod SHIFT, V, exec, noctalia msg panel-toggle clipboard  # "Zwischenablage-Verlauf"
    bind = $mainMod SHIFT, E, exec, noctalia msg settings-toggle  # "noctalia-Einstellungen"
    bind = $mainMod SHIFT, R, exec, hyprctl reload  # "Hyprland-Konfiguration neu laden"

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
