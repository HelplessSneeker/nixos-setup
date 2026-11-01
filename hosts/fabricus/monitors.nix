# Monitor-Layout fabricus (Desktop).
#
# Statischer Fall: zwei fest verkabelte Schirme, das aendert sich praktisch nie.
# Bewusst getrennt vom Laptop-Pendant (hosts/fabricus-itinerans/monitors.nix) --
# die beiden Maschinen haben gegensaetzliche Anforderungen und teilen sich seit
# 12.08.2026 keine einzige Monitor-Zeile mehr. Vorher lag beides als
# if-isLaptop-Weiche in home/hyprland.nix.
#
# Eingebunden wird die erzeugte Datei per require("monitors") aus
# home/hyprland.nix (seit 01.11.2026 Lua, vorher monitors.conf per `source`).
# Dort steht KEINE hl.monitor-Regel, auch kein Catch-all -- dies hier ist die
# einzige Quelle fuer diesen Host.
{ ... }:
{
  home-manager.users.bfn.xdg.configFile."hypr/monitors.lua".text = ''
    -- Managed by home-manager (hosts/fabricus/monitors.nix)

    -- 2x BenQ EL2870U (28" 4k). scale 1.25 -> logisch 3072x1728 pro Schirm
    -- (teilt 3840/2160 sauber, kein Fractional-Blur). HDMI links, DP rechts daneben.
    hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "0x0",    scale = 1.25 })
    hl.monitor({ output = "DP-1",     mode = "3840x2160@60", position = "3072x0", scale = 1.25 })

    -- Alles Weitere (Beamer, dritter Schirm): rechts dran, gleiche Skalierung.
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })
  '';
}
