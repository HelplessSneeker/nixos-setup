{ config, pkgs, lib, inputs, pkgsUnstable, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # Gaming (Steam/Proton, GameMode, Gamescope, MangoHud). Nur hier, nicht im
    # shared Stack in flake.nix -- der Laptop-Host soll das nicht bekommen.
    # Der home-manager-Teil haengt am Modul selbst und kommt automatisch mit.
    ../../modules/gaming.nix
    # Citrix Workspace. Ebenfalls per-Host statt shared -- das Modul erklaert
    # warum (requireFile: Tarball muss vorher von Hand in den Store).
    # OHNE den Prefetch-Schritt scheitert jeder Rebuild dieses Hosts.
    ../../modules/citrix.nix
  ];

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

    # Offene Kernelmodule. Kam am 08.08.2026 als Screenshare-Versuch rein und
    # hat daran nichts geaendert (Ursache war der Portal-Bug, s. home/apps.nix)
    # -- bleibt aber bewusst an: die RTX 2060 ist Turing, NVIDIA empfiehlt die
    # offenen Module ab dieser Generation selbst, und sie laufen hier seit dem
    # Reboot am 09.08.2026 unauffaellig. Zurueckdrehen kostet einen weiteren
    # Reboot (Kernelmodul), ohne dass ein Problem dafuer spraeche.
    open = true;

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

    # Screen-Sharing-Versuch 1 (AQ_NO_MODIFIERS = "1") stand hier und ist am
    # 08.08.2026 im Test durchgefallen -- wieder entfernt, damit sich keine
    # wirkungslosen Env-Variablen ansammeln. Weiter mit Versuch 2 oben bei
    # hardware.nvidia.open.
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

    # bfns eigener SSH-Zugang. Seit der Haertung vom 07.08.2026 liest sshd nur
    # noch /etc/ssh/authorized_keys.d/%u (modules/ssh-hardening.nix) und
    # Passwort-Auth ist aus -- ein von Hand nach ~/.ssh/authorized_keys gelegter
    # Key zieht also NICHT mehr. Deklarativ ist ab jetzt der einzige Weg rein,
    # und ohne diesen Eintrag kaeme bfn vom Laptop gar nicht auf den Desktop
    # (dort stand bislang ausschliesslich der Agent-Key).
    # Ein PUBLIC key gehoert nicht zu den Secrets und darf im Repo stehen.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdHqQP/7i5iIK4hBcLnjzvvQKFiD7xHH9+o7x95i58a openclaw-lab"
    ];
  };
  programs.zsh.enable = true;

  virtualisation.docker.enable = true;
  services.openssh.enable = true;

  # Nur der Host-Extra-Font; noto + jetbrains-mono kommen aus modules/system-base.nix (Liste merged).
  fonts.packages = with pkgs; [ nerd-fonts.fira-code ];

  # System-Editor für root/TTY (neovim ist home-only für bfn).
  environment.systemPackages = with pkgs; [ vim ];

  # --- Board-Sensoren: Gigabyte B450 AORUS M (Super-I/O ITE IT8686E) ---
  #
  # Board-spezifisch, deshalb hier und nicht in modules/hardware-monitoring.nix.
  # Liefert Vcore, +12V, +5V, 3.3V und Luefter-RPM -- also genau die Werte, mit
  # denen sich ein Netzteil-/VRM-Verdacht bei den MCE-Abstuerzen (08.08.2026)
  # belegen oder ausschliessen laesst. k10temp allein zeigt nur die Die-Temp.
  #
  # ignore_resource_conflict: Gigabyte-ACPI reklamiert den I/O-Bereich des
  # Super-I/O fuer sich, der Treiber weigert sich dann zu binden. Der Parameter
  # ist der uebliche Weg drumherum.
  #
  # NICHT GARANTIERT: ob der Mainline-it87 das IT8686E auf genau diesem Board
  # sauber erkennt, weiss ich erst nach dem Rebuild. Verifikation:
  #   lsmod | grep it87   und   sensors
  # Bindet er nicht, bleibt es folgenlos (Modul laedt einfach nicht) -- dann
  # diese vier Zeilen wieder rauswerfen.
  boot.kernelModules = [ "it87" ];
  boot.extraModprobeConfig = ''
    options it87 ignore_resource_conflict=1
  '';

  zramSwap.enable = true;

  # BLEIBT auf 25.05, auch nachdem die Flake am 09.08.2026 auf nixpkgs 26.05
  # gezogen ist. Das ist kein vergessener Wert: stateVersion markiert den Stand,
  # gegen den zustandsbehaftete Defaults und Datenmigrationen laufen (Datenbank-
  # Layouts, Verzeichnispfade). Hochsetzen wuerde solche Migrationen scharf
  # schalten, ohne dass jemand die Daten migriert hat.
  # Auf fabricus-itinerans steht hier 26.05 -- korrekt, weil dort frisch
  # installiert wurde.
  system.stateVersion = "25.05";
}
