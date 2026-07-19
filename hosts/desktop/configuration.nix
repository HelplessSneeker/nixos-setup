{ config, pkgs, lib, inputs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Boot: eigener systemd-boot auf unserer EFI (sda3). Windows-EFI (sda1) bleibt unberührt.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fabricus";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "de_AT.UTF-8";
  i18n.extraLocaleSettings.LC_MESSAGES = "en_US.UTF-8";
  console.keyMap = "de";
  services.xserver.xkb.layout = "de";

  # NVIDIA
  nixpkgs.config.allowUnfree = true;
  hardware.graphics = { enable = true; enable32Bit = true; };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Hyprland + Wayland/NVIDIA-Env
  programs.hyprland.enable = true;
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  # Login-Manager
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      user = "greeter";
    };
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };

  # User (Passwort nach erstem Login mit `passwd` ändern!)
  users.users.bfn = {
    isNormalUser = true;
    description = "Benjamin Nößler";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
  };
  programs.zsh.enable = true;

  services.tailscale.enable = true;
  virtualisation.docker.enable = true;
  services.openssh.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts noto-fonts-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  environment.systemPackages = with pkgs; [ git vim wget curl ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 30d"; };

  zramSwap.enable = true;

  system.stateVersion = "25.05";
}
