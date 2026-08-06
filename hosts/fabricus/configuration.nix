{ config, pkgs, lib, inputs, pkgsUnstable, ... }:
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

  # Hyprland + Wayland/NVIDIA-Env (NIXOS_OZONE_WL kommt aus modules/gui-apps.nix)
  #
  # Hyprland kommt bewusst aus nixpkgs-unstable (0.56.1), nicht aus 25.05 (0.49.0).
  # Grund: noctalia 5.0.0 ist gegen einen ~14 Monate neueren Compositor gebaut.
  # Unter 0.49 wird der Focus-Grab jedes Panels sofort gecleart -- Panels leben
  # 15-20 ms und schliessen wieder. Damit ist in der Bar alles tot, was
  # aufklappen muss (Launcher, Kalender, Media, Notifications, Clipboard,
  # Netzwerk, Control-Center, Session). Gegenprobe: `settings-open` ist ein
  # normales Fenster und geht sauber auf -> es liegt am Grab, nicht am Klick.
  #
  # Rueckweg, falls Hyprland nicht startet: alte NixOS-Generation im Bootloader.
  #
  # portalPackage MUSS mitgezogen werden -- ein 25.05-Portal neben einem
  # 0.56-Compositor bricht Screen-Sharing und Datei-Dialoge.
  programs.hyprland = {
    enable = true;
    package = pkgsUnstable.hyprland;
    portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;
  };
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
      # start-hyprland statt Hyprland: seit 0.5x will der Compositor ueber diesen
      # Wrapper gestartet werden (setzt systemd-User-Session + dbus sauber auf).
      # Direktstart erzeugt sonst bei jedem Login das Warn-Overlay
      # "Hyprland is being launched without start-hyprland".
      # Der Wrapper liegt im hyprland-Paket (/run/current-system/sw/bin/start-hyprland).
      # Rueckweg bei kaputtem Login: alte NixOS-Generation im Bootloader.
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
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
