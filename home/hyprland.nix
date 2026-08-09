# Hyprland-WM-Config (home-manager). Shared -> fabricus jetzt, laptop spaeter.
# Catppuccin Mocha, clean & ruhig: dezente Gaps, keine Fenster-Transparenz,
# kurze/snappy Animationen. Bindings sind ein frischer Aufbau (nicht 1:1 aus den
# alten dotfiles portiert), aber vim-HJKL + 10 Workspaces bleiben.
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    fuzzel     # App-Launcher (SUPER+Space)
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

    # Keybind-Spickzettel: liest die LIVE aktiven Hyprland-Binds (hyprctl) und
    # zeigt sie durchsuchbar in fuzzel. Kein Rot-Risiko, weil aus der laufenden
    # Session generiert statt aus einer Doku-Kopie. Auf SUPER+? gelegt.
    #
    # OFFEN: das ist der letzte Nutzer von fuzzel -- Launcher und Clipboard sind
    # seit 08.08.2026 noctalia-Panels. noctalia hat KEINEN dmenu-Modus (per
    # `noctalia msg --help` geprueft), die Optik bleibt hier also vorerst fremd.
    # Wege: Community-Plugin suchen, sonst ein eigenes fuzzel-Template fuer
    # noctalias Theming (fuzzel fehlt unter den 20 Builtin-Templates).
    (writeShellScriptBin "hypr-cheatsheet" ''
      hyprctl -j binds \
        | ${jq}/bin/jq -r '
            def mods(m):
              [ (if (m/64|floor)%2==1 then "SUPER" else empty end),
                (if (m/4|floor)%2==1  then "CTRL"  else empty end),
                (if (m/8|floor)%2==1  then "ALT"   else empty end),
                (if (m/1|floor)%2==1  then "SHIFT" else empty end) ] | join("+");
            .[]
            | (mods(.modmask)) as $m
            | ((if $m == "" then "" else $m + "+" end)
               + (if (.key|length) > 0 then .key else ("code:" + (.keycode|tostring)) end)) as $combo
            | $combo + "\t" + .dispatcher
              + (if (.arg|length) > 0 then " " + .arg else "" end)
          ' \
        | sort \
        | ${util-linux}/bin/column -t -s "$(printf "\t")" \
        | ${fuzzel}/bin/fuzzel --dmenu --prompt "keys> " --width 72 >/dev/null
    '')
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
    # fuer alles, was aufklappt. fuzzel bleibt vorerst als Paket installiert,
    # weil hypr-cheatsheet es noch als dmenu-Engine braucht (siehe oben).
    $menu        = noctalia msg panel-toggle launcher
    $browser     = firefox
    $mail        = thunderbird
    $fileManager = kitty -e yazi
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
    # Fenster & Session
    bind = $mainMod, Return, exec, $terminal
    bind = $mainMod, Space, exec, $menu
    bind = $mainMod, W, killactive
    bind = $mainMod SHIFT, Q, exit
    bind = $mainMod, F, fullscreen
    bind = $mainMod, V, togglefloating
    # togglesplit ist seit 0.56 kein eigener Dispatcher mehr, sondern eine
    # Layout-Message. SHIFT+P = pseudotile, ersetzt die weggefallene dwindle-Option.
    #
    # Pseudotile lag bis 08.08.2026 auf SUPER+P und kollidierte dort mit dem
    # 1Password-Bind weiter unten. Hyprland nimmt bei doppelt belegter Taste den
    # ERSTEN Treffer -- der 1Password-Bind war damit wirkungslos, ohne dass es
    # eine Fehlermeldung gegeben haette. Pseudotile ist der deutlich seltenere
    # Griff und zieht deshalb um; P bleibt bei Password.
    bind = $mainMod, T, layoutmsg, togglesplit
    bind = $mainMod SHIFT, P, pseudo

    # Fokus (vim HJKL)
    bind = $mainMod, H, movefocus, l
    bind = $mainMod, J, movefocus, d
    bind = $mainMod, K, movefocus, u
    bind = $mainMod, L, movefocus, r

    # Fenster verschieben -- jetzt symmetrisch zum Fokus-Block darueber.
    # SHIFT+H war bis 08.08.2026 fuer das Help-Menue reserviert, nach links
    # verschieben ging deshalb nur per Maus-Drag. Help sitzt jetzt auf SUPER+?.
    bind = $mainMod SHIFT, H, movewindow, l
    bind = $mainMod SHIFT, J, movewindow, d
    bind = $mainMod SHIFT, K, movewindow, u
    bind = $mainMod SHIFT, L, movewindow, r

    # Apps
    bind = $mainMod, B, exec, $browser
    bind = $mainMod, M, exec, $mail
    bind = $mainMod, E, exec, $fileManager
    bind = $mainMod, O, exec, obsidian
    bind = $mainMod, P, exec, 1password
    bind = $mainMod, D, exec, discord-web

    # System
    bind = $mainMod SHIFT, Escape, exec, hyprlock
    # Hilfe auf SUPER+ss. Voraus gingen zwei tote Varianten: `SHIFT, question`
    # und `SHIFT, ssharp`. Gelernt (verifiziert im Test 09.08.2026): auf
    # de-Layout ist ? = Shift+ss, aber Hyprland matcht hier den Keysym der
    # BASIS-Ebene -- also `ssharp` OHNE SHIFT im Modifier-Feld. Ein Bind auf den
    # geshifteten Keysym feuert nie, und zwar kommentarlos.
    bind = $mainMod, ssharp, exec, hypr-cheatsheet
    bind = $mainMod, C, exec, grimblast --notify copysave area
    bind = $mainMod CTRL, C, exec, grimblast --notify copysave screen
    bind = $mainMod SHIFT, C, exec, hyprpicker -a
    # Clipboard-History: noctalias Panel statt cliphist+fuzzel (siehe Autostart).
    # Panel-ID `clipboard` ist eine begruendete Annahme -- so heisst das Widget in
    # der Bar-Config, und die Hilfe nennt `launcher` und `control-center` als
    # Beispiel-IDs. Stimmt sie nicht, antwortet noctalia mit
    # `unknown panel "clipboard"` statt irgendwas kaputtzumachen.
    bind = $mainMod SHIFT, V, exec, noctalia msg panel-toggle clipboard
    # noctalia-Einstellungen
    bind = $mainMod SHIFT, E, exec, noctalia msg settings-toggle
    bind = $mainMod SHIFT, R, exec, hyprctl reload

    # Workspaces
    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod, 6, workspace, 6
    bind = $mainMod, 7, workspace, 7
    bind = $mainMod, 8, workspace, 8
    bind = $mainMod, 9, workspace, 9
    bind = $mainMod, 0, workspace, 10

    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3
    bind = $mainMod SHIFT, 4, movetoworkspace, 4
    bind = $mainMod SHIFT, 5, movetoworkspace, 5
    bind = $mainMod SHIFT, 6, movetoworkspace, 6
    bind = $mainMod SHIFT, 7, movetoworkspace, 7
    bind = $mainMod SHIFT, 8, movetoworkspace, 8
    bind = $mainMod SHIFT, 9, movetoworkspace, 9
    bind = $mainMod SHIFT, 0, movetoworkspace, 10

    bind = $mainMod, mouse_down, workspace, e+1
    bind = $mainMod, mouse_up, workspace, e-1

    # SUPER+Tab oeffnet noctalias Fenster-Switcher statt blind einen Workspace
    # weiterzuschalten (bfn 09.08.2026: getestet, reicht ihm -- damit ist
    # hyprshell vom Tisch und wir sparen uns einen dritten UI-Stack mit eigenem
    # Launcher und eigener Clipboard-History).
    #
    # SUPER+SHIFT+Tab ist bewusst WEG statt auf `workspace, e-1` zu bleiben:
    # bei offenem Switcher ist Shift+Tab das Rueckwaertsblaettern IM Switcher,
    # ein Hyprland-Bind wuerde dort dazwischenfunken. Workspace-Blaettern per
    # Tastatur geht weiter ueber SUPER+1..0, per Maus ueber SUPER+Scroll.
    bind = $mainMod, Tab, exec, noctalia msg window-switcher

    # Scratchpad
    bind = $mainMod, S, togglespecialworkspace, magic
    bind = $mainMod SHIFT, S, movetoworkspace, special:magic

    # Maus: move/resize per Drag
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # Media & Helligkeit
    # SPACE stand hier im Modifier-Feld, ist aber kein Modifier -- der Bind war
    # damit ungueltig und hat nie ausgeloest. 08.08.2026 auf SUPER ALT korrigiert.
    bind = SUPER ALT, W, exec, noctalia msg wallpaper-next
    bindel = ,XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = ,XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindel = ,XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindel = ,XF86MonBrightnessUp,   exec, brightnessctl -e4 -n2 set 5%+
    bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
    bindl  = ,XF86AudioNext,  exec, playerctl next
    bindl  = ,XF86AudioPause, exec, playerctl play-pause
    bindl  = ,XF86AudioPlay,  exec, playerctl play-pause
    bindl  = ,XF86AudioPrev,  exec, playerctl previous
  '';
}
