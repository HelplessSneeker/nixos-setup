{ config, pkgs, lib, ... }:
{
  home.username = "bfn";
  home.homeDirectory = "/home/bfn";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Benjamin Nößler";
    userEmail = "benjamin@noessler.at";
  };

  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.kitty.enable = true;

  home.packages = with pkgs; [
    gh nodejs_22 neovim
    ripgrep fd fzf bat eza jq btop tmux unzip wget
    waybar wofi mako hyprpaper hyprlock hypridle
    grim slurp wl-clipboard brightnessctl playerctl pavucontrol
    networkmanagerapplet
    firefox
  ];

  xdg.configFile."hypr/hyprland.conf".text = ''
    monitor=,preferred,auto,1
    input {
      kb_layout = de
    }
    $mod = SUPER
    exec-once = waybar
    exec-once = mako
    exec-once = hyprpaper
    bind = $mod, Return, exec, kitty
    bind = $mod, Q, killactive,
    bind = $mod, R, exec, wofi --show drun
    bind = $mod, F, fullscreen,
    bind = $mod, Space, togglefloating,
    bind = $mod, 1, workspace, 1
    bind = $mod, 2, workspace, 2
    bind = $mod, 3, workspace, 3
    bind = $mod SHIFT, 1, movetoworkspace, 1
    bind = $mod SHIFT, 2, movetoworkspace, 2
    bind = $mod SHIFT, 3, movetoworkspace, 3
    bind = $mod, left, movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up, movefocus, u
    bind = $mod, down, movefocus, d
  '';
}
