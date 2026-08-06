{ config, pkgs, lib, inputs, ... }:
{

  imports = [
    ./apps.nix
    ./ssh.nix
    ./control-ui.nix
    ./hyprland.nix
    ./theme.nix
    ./fish.nix
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

  programs.noctalia = {
    enable = true;
    settings = {
      shell.font_family = "JetBrainsMono Nerd Font";
      theme = {
        mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "m3-tonal-spot";
        # Adaptive App-Theming: noctalia rendert seine Wallpaper-Palette in die
        # App-Configs (kitty-Farben + Hyprland-Border) bei jedem Palette-Wechsel.
        # Aktiviert die mitgelieferten Templates; Liste: `noctalia theme --list-templates`.
        templates = {
          enable_builtin_templates = true;
          builtin_ids = [ "kitty" "hyprland" ];
        };
      };
      wallpaper = {
  	enabled = true;
  	directory = "~/Pictures/Wallpapers";
  	transition_on_startup = true;   # setzt Wallpaper beim Boot, nicht erst nach Intervall
  	automation = {
    		enabled = true;
    		order = "random";
    		interval_seconds = 1800;
    		recursive = true;
	};
      };
    };
  };

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
    firefox
  ];
}
