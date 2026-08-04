{ config, pkgs, lib, inputs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Boot: eigener systemd-boot auf unserer EFI (sda3). Windows-EFI (sda1) bleibt unberührt.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fabricus";
  networking.networkmanager.enable = true;
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

  # Hyprland + Wayland/NVIDIA-Env (NIXOS_OZONE_WL kommt aus modules/desktop-apps.nix)
  programs.hyprland.enable = true;
  environment.sessionVariables = {
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

  # User. initialPassword entfernt (Account existiert; Passwort ist per `passwd` gesetzt).
  # Fuer einen NEUEN Host hier wieder `initialPassword` oder `hashedPasswordFile` setzen.
  # Login-Shell: fish (System-Enable in modules/system-base.nix).
  users.users.bfn = {
    isNormalUser = true;
    description = "Benjamin Nößler";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" ];
    shell = pkgs.fish;
  };
  programs.zsh.enable = true;

  virtualisation.docker.enable = true;
  services.openssh.enable = true;

  # Nur der Host-Extra-Font; noto + jetbrains-mono kommen aus modules/system-base.nix (Liste merged).
  fonts.packages = with pkgs; [ nerd-fonts.fira-code ];

  # System-Editor für root/TTY (neovim ist home-only für bfn).
  environment.systemPackages = with pkgs; [ vim ];

  zramSwap.enable = true;

  system.stateVersion = "25.05";
}
