# Gaming auf User-Ebene: Overlay-Config + optionale Launcher.
#
# ACHTUNG: Wird NICHT von home/bfn.nix importiert (das ist shared und gilt
# auch fuer einen kuenftigen Laptop-Host). Der Import kommt aus
# modules/gaming.nix, das wiederum nur hosts/fabricus zieht -- Gaming ist
# reine Stand-PC-Sache. Der System-Teil (Steam, Proton-GE, GameMode,
# Gamescope) steht ebenfalls dort.
{ config, pkgs, lib, ... }:
{
  # MangoHud-Overlay. Schreibt ~/.config/MangoHud/MangoHud.conf deklarativ.
  # Aufruf pro Spiel als Steam-Launch-Option:  mangohud %command%
  # (enableSessionWide bleibt aus -- das wuerde das Overlay in JEDE
  # Vulkan/OpenGL-App zwingen, auch in Firefox und den Compositor.)
  programs.mangohud = {
    enable = true;
    settings = {
      fps = true;
      frametime = true;
      frame_timing = 1;

      gpu_stats = true;
      gpu_temp = true;
      gpu_power = true;
      vram = true; # RTX 2060 hat nur 6 GB -- der interessanteste Wert hier

      cpu_stats = true;
      cpu_temp = true;
      ram = true;

      position = "top-left";
      font_size = 22;
      background_alpha = 0.4;

      # Im Spiel ein-/ausblenden bzw. Logging fuer Vergleichsmessungen.
      toggle_hud = "Shift_R+F12";
      toggle_logging = "Shift_L+F2";
    };
  };

  home.packages = with pkgs; [
    # --- Launcher ausserhalb von Steam: bewusst noch nicht aktiv ---
    # Erst reinnehmen, was du wirklich brauchst -- jeder zieht einen eigenen
    # Wine-/Runtime-Stack nach (je ~1-3 GB Store).
    #
    # heroic     # Epic Games + GOG + Amazon Prime Gaming
    # lutris     # Universal-Launcher (GOG, Battle.net, Emulatoren, Custom-Wine)
    # bottles    # Wine-Prefix-Verwaltung mit GUI, gut fuer einzelne Windows-Apps
    # protonup-qt # nur noetig, wenn du GE-Builds AUSSERHALB von Nix pflegen willst
    #             # (extraCompatPackages in modules/gaming.nix macht das schon)
  ];
}
