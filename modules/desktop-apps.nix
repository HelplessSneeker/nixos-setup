# Desktop-Apps & Wayland-Integration auf System-Ebene. Shared.
{ config, pkgs, lib, ... }:
{
  # 1Password — GUI + CLI ueber die offiziellen NixOS-Module.
  # WICHTIG: nicht als rohes pkgs._1password-gui in environment.systemPackages!
  # Nur ueber diese Module bekommt die GUI den setuid-Helper + polkit-Policy,
  # sonst funktioniert Unlock / Browser-Integration / SSH-Agent nicht sauber.
  programs._1password.enable = true;          # CLI: `op`
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "bfn" ];           # erlaubt bfn System-Auth/Unlock
  };

  # Electron/Chromium nativ auf Wayland (Brave, Obsidian, 1Password-GUI).
  # Ohne das laufen die Apps ueber XWayland -> unscharf, schlechtes Scaling.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # XDG-Portal fuer Hyprland: Datei-Dialoge (Upload/Anhaenge) + Screen-Sharing.
  # ACHTUNG: Falls dein Hyprland-Modul xdg.portal schon setzt -> hier weglassen,
  # sonst "attribute already defined". Erst pruefen: grep -rn 'xdg.portal' .
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
