# Hyprland-WM-Config (home-manager). Shared -> fabricus jetzt, laptop spaeter.
# Catppuccin Mocha, clean & ruhig: dezente Gaps, keine Fenster-Transparenz,
# kurze/snappy Animationen. Bindings sind ein frischer Aufbau (nicht 1:1 aus den
# alten dotfiles portiert), aber vim-HJKL + 10 Workspaces bleiben.
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    fuzzel     # App-Launcher (SUPER+Space)
    grimblast  # Screenshot-Wrapper (Print)

    # Keybind-Spickzettel: liest die LIVE aktiven Hyprland-Binds (hyprctl) und
    # zeigt sie durchsuchbar in fuzzel. Kein Rot-Risiko, weil aus der laufenden
    # Session generiert statt aus einer Doku-Kopie. Auf SUPER+/ gelegt.
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
    monitor = ,preferred,auto,1

    ### Programme ###
    $terminal    = kitty
    $menu        = fuzzel
    $browser     = brave
    $fileManager = kitty -e yazi
    $mainMod     = SUPER

    ### Autostart ###
    #exec-once = waybar
    #exec-once = mako
    exec-once = noctalia
    exec-once = 1password --silent
    exec-once = wl-paste --watch cliphist store   # Clipboard-History mitschreiben

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
        pseudotile = true
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
    bind = $mainMod, T, togglesplit

    # Fokus (vim HJKL)
    bind = $mainMod, H, movefocus, l
    bind = $mainMod, J, movefocus, d
    bind = $mainMod, K, movefocus, u
    bind = $mainMod, L, movefocus, r

    # Fenster verschieben (SHIFT+H frei fuer Help-Menue -> links per Maus-Drag)
    bind = $mainMod SHIFT, J, movewindow, d
    bind = $mainMod SHIFT, K, movewindow, u
    bind = $mainMod SHIFT, L, movewindow, r

    # Apps
    bind = $mainMod, B, exec, $browser
    bind = $mainMod, E, exec, $fileManager
    bind = $mainMod, O, exec, obsidian
    bind = $mainMod, P, exec, 1password
    bind = $mainMod SHIFT, D, exec, vesktop

    # System
    bind = $mainMod SHIFT, Escape, exec, hyprlock
    bind = $mainMod SHIFT, H, exec, hypr-cheatsheet
    bind = $mainMod, Slash, exec, hypr-cheatsheet
    bind = $mainMod, C, exec, hyprpicker -a
    bind = $mainMod SHIFT, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy
    bind = $mainMod SHIFT, R, exec, hyprctl reload
    bind = , Print, exec, grimblast --notify copysave area
    bind = $mainMod, Print, exec, grimblast --notify copysave screen

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
    bind = $mainMod, Tab, workspace, e+1
    bind = $mainMod SHIFT, Tab, workspace, e-1

    # Scratchpad
    bind = $mainMod, S, togglespecialworkspace, magic
    bind = $mainMod SHIFT, S, movetoworkspace, special:magic

    # Maus: move/resize per Drag
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # Media & Helligkeit
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
