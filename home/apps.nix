# Per-User Apps (home-manager). Shared home-Modul.
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    brave
    obsidian
    vesktop        # Discord-Client, nativ Wayland (Screenshare + Themes)
    wl-clipboard   # Clipboard-Bridge fuer nvim/Terminal unter Wayland
    cliphist       # Clipboard-History (SUPER+SHIFT+V)
    hyprpicker     # Farb-Picker (SUPER+C)
  ];

  # Neovim erstmal nur lauffaehig als Default-Editor.
  # Plugin-/LSP-/Theme-Config kommt spaeter aus deinen dotfiles.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # SSH nutzt den 1Password-Agent statt eines Keys auf der Platte.
  # Der Socket kommt vom System-Modul (modules/desktop-apps.nix, programs._1password-gui);
  # hier zeigt nur ~/.ssh/config drauf. WICHTIG: in der 1Password-GUI einmalig
  # Settings -> Developer -> "Use the SSH agent" aktivieren, sonst existiert der Socket nicht.
  programs.ssh = {
    enable = true;
    matchBlocks."*".extraOptions.IdentityAgent = "~/.1password/agent.sock";
  };

  # Deine echte git-Identitaet/Config kommt spaeter aus den dotfiles.
  # (Das Paket `git` liefert schon modules/system-base.nix.)
}
