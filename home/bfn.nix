{ config, pkgs, lib, inputs, ... }:
{

  imports = [
    ./apps.nix
    ./ssh.nix
    ./hyprland.nix
    ./theme.nix
    ./fish.nix
    ./gaming.nix
    ./noctalia.nix
    inputs.noctalia.homeModules.default
  ];

  home.username = "bfn";
  home.homeDirectory = "/home/bfn";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Benjamin Nößler";
    userEmail = "benjamin@noessler.at";
  };

  # programs.noctalia (Theming, Wallpaper, Bar-Layout) lebt jetzt in ./noctalia.nix

  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.kitty.enable = true;

  home.packages = with pkgs; [
    gh nodejs_22
    ripgrep fd fzf bat eza jq btop tmux unzip wget
    waybar hyprpaper hyprlock hypridle   # mako raus: noctalia macht die Notifications
    grim slurp wl-clipboard brightnessctl playerctl pavucontrol
    networkmanagerapplet
    # firefox lebt jetzt bei den uebrigen GUI-Apps in home/apps.nix
  ];
}
