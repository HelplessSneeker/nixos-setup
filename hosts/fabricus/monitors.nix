# Monitor-Layout fabricus (Desktop).
#
# Statischer Fall: zwei fest verkabelte Schirme, das aendert sich praktisch nie.
# Bewusst getrennt vom Laptop-Pendant (hosts/fabricus-itinerans/monitors.nix) --
# die beiden Maschinen haben gegensaetzliche Anforderungen und teilen sich seit
# 12.08.2026 keine einzige Monitor-Zeile mehr. Vorher lag beides als
# if-isLaptop-Weiche in home/hyprland.nix.
#
# Eingebunden wird die erzeugte Datei per `source = ~/.config/hypr/monitors.conf`
# aus home/hyprland.nix. Dort steht KEINE monitor=-Regel mehr, auch kein
# Catch-all -- dies hier ist die einzige Quelle fuer diesen Host.
{ ... }:
{
  home-manager.users.bfn.xdg.configFile."hypr/monitors.conf".text = ''
    # Managed by home-manager (hosts/fabricus/monitors.nix)

    # 2x BenQ EL2870U (28" 4k). scale 1.25 -> logisch 3072x1728 pro Schirm
    # (teilt 3840/2160 sauber, kein Fractional-Blur). HDMI links, DP rechts daneben.
    monitor = HDMI-A-1, 3840x2160@60, 0x0, 1.25
    monitor = DP-1,     3840x2160@60, 3072x0, 1.25

    # Alles Weitere (Beamer, dritter Schirm): rechts dran, gleiche Skalierung.
    monitor = ,preferred,auto,1.25
  '';
}
