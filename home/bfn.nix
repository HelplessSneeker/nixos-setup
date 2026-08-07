{ config, pkgs, lib, inputs, ... }:
{

  imports = [
    ./apps.nix
    ./ssh.nix
    ./hyprland.nix
    ./theme.nix
    ./fish.nix
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

  # pnpm legt global installierte Pakete unter $PNPM_HOME ab. Ohne die Variable
  # verweigert `pnpm add -g` den Dienst ("Unable to find the global bin
  # directory") und will stattdessen `pnpm setup` laufen lassen -- das schreibt
  # in ~/.config/fish/config.fish, die home-manager als Store-Symlink verwaltet
  # (read-only). Also deklarativ setzen statt pnpm dran zu lassen.
  home.sessionVariables.PNPM_HOME = "${config.home.homeDirectory}/.local/share/pnpm";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/share/pnpm" ];

  home.packages = with pkgs; [
    gh nodejs_22
    # pnpm 10.15.1 aus 25.05 (geprueft am 07.08.2026 gegen den gepinnten
    # nixpkgs) -- kein unstable noetig. Bewusst NICHT ueber corepack: das
    # laedt die Manager zur Laufzeit nach und wird ab Node 25 nicht mehr
    # mitgeliefert; das Nix-Paket ist reproduzierbar und rollback-faehig.
    pnpm
    ripgrep fd fzf bat eza jq btop tmux unzip wget
    waybar hyprpaper hyprlock hypridle   # mako raus: noctalia macht die Notifications
    grim slurp wl-clipboard brightnessctl playerctl pavucontrol
    networkmanagerapplet
    # firefox lebt jetzt bei den uebrigen GUI-Apps in home/apps.nix
  ];
}
