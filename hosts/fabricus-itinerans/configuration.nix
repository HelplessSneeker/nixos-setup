{ config, pkgs, lib, inputs, pkgsUnstable, ... }:
# fabricus-itinerans -- der mobile Ableger von fabricus, auf cachus-rex-Hardware
# (Kaby Lake-R, Intel UHD 620). Teilt sich den kompletten Modul-Stack aus
# flake.nix mit dem Desktop; hier steht ausschliesslich, was sich zwischen den
# beiden Maschinen unterscheidet.
#
# BEWUSST NICHT importiert: ../../modules/gaming.nix. Steam/Proton auf einer
# UHD 620 waere Selbstbetrug -- das Modul bleibt desktop-only (siehe den
# Import-Block in hosts/fabricus/configuration.nix).
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480

    # Citrix Workspace -- ABSICHTLICH AUS bis nach dem ersten Boot.
    #
    # Das Modul zieht seinen Tarball ueber `requireFile`, die Datei muss also im
    # Store DIESER Maschine liegen. Waehrend `nixos-install` ist der Ziel-Store
    # /mnt und dort liegt sie garantiert nicht -- mit aktivem Import scheitert
    # die Installation, nicht erst irgendein spaeterer Rebuild.
    #
    # Phase 2, nach dem ersten Boot: Tarball laden + `nix-prefetch-url` (die
    # Schritte stehen oben in modules/citrix.nix), dann diese Zeile
    # einkommentieren und `nixos-rebuild switch`.
    # ../../modules/citrix.nix
  ];

  # --- Boot ------------------------------------------------------------------
  # systemd-boot auf der EFI-Partition, LUKS-Root analog fabricus.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # nixos-generate-config hat diese Zeile bei der Installation am 09.08.2026
  # NICHT geschrieben -- obwohl der Container offen, gemountet und aktiv war.
  # Ohne sie findet der initrd cryptroot nicht und der Boot bleibt stehen.
  # Sie steht bewusst HIER und nicht in hardware-configuration.nix: die Datei
  # traegt "Do not modify", ein spaeteres nixos-generate-config wuerde die
  # Ergaenzung also kommentarlos wieder verschlucken.
  boot.initrd.luks.devices."cryptroot".device =
    "/dev/disk/by-uuid/72e63b77-27ad-428e-89eb-7ab42fab2e63";

  # nixos-generate-config mountet /boot mit fmask/dmask 0022, damit ist der
  # Random-Seed von systemd-boot world-readable -- der Installer warnt beim
  # Schreiben genau darueber. 0077 macht ESP und Inhalt root-only.
  # mkForce, weil hardware-configuration.nix die Liste bereits definiert und
  # zwei Definitionen sonst zu einer widerspruechlichen Mount-Zeile mergen.
  fileSystems."/boot".options = lib.mkForce [ "fmask=0077" "dmask=0077" ];

  networking.hostName = "fabricus-itinerans";
  networking.networkmanager.enable = true;
  services.xserver.xkb.layout = "de";

  nixpkgs.config.allowUnfree = true;

  # --- Firmware --------------------------------------------------------------
  # NICHT KOSMETISCH. Der Default ist `false`, und hardware-configuration.nix
  # haengt den Intel-Microcode per mkDefault genau an diese Option. Ohne sie:
  #   - kein iwlwifi-Firmware-Blob  -> das WLAN existiert schlicht nicht
  #   - kein CPU-Microcode-Update   -> Kaby Lake ohne die Spectre-Mitigations
  # Auf fabricus ist das nie aufgefallen, weil dort Ethernet am Kabel haengt und
  # der NVIDIA-Blob einen eigenen Weg geht.
  hardware.enableRedistributableFirmware = true;

  # --- Grafik: Intel Kaby Lake-R (UHD 620, Gen9.5) ---------------------------
  # Kein videoDrivers-Eintrag noetig: der i915 ist im Kernel und wird erkannt.
  # Deshalb hier auch KEIN Gegenstueck zum NVIDIA-Env-Block des Desktops --
  # LIBVA_DRIVER_NAME zeigt auf iHD statt nvidia.
  #
  # intel-media-driver (iHD) ist der aktuelle VAAPI-Treiber und deckt Gen8+ ab,
  # also auch Kaby Lake. Falls Hardware-Decoding in Firefox spinnt, ist der
  # Gegentest der alte i965: pkgs.intel-vaapi-driver + LIBVA_DRIVER_NAME=i965.
  # Verifikation nach dem ersten Rebuild:  nix-shell -p libva-utils --run vainfo
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libvdpau-va-gl      # VDPAU-only-Apps auf VAAPI umbiegen
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # --- Hyprland --------------------------------------------------------------
  # Version + portalPackage identisch zum Desktop gepinnt. Das ist keine freie
  # Wahl: noctalia 5.0.0 braucht den 0.56er Compositor, unter 25.05 (0.49)
  # sterben saemtliche aufklappenden Panels der Bar nach 15-20 ms. Ausfuehrliche
  # Begruendung steht in hosts/fabricus/configuration.nix.
  programs.hyprland = {
    enable = true;
    package = pkgsUnstable.hyprland;
    portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;
  };

  # --- Laptop-Energie --------------------------------------------------------
  # power-profiles-daemon statt TLP: spielt sauber mit systemd/logind zusammen
  # und ist das, was noctalias Power-Widget als Backend erwartet. Die beiden
  # schliessen sich gegenseitig aus -- nie beide gleichzeitig aktivieren.
  services.power-profiles-daemon.enable = true;

  # thermald ist Intel-spezifisch und regelt die Thermik aktiv, statt die CPU
  # erst am harten Throttle-Punkt abfangen zu lassen.
  services.thermald.enable = true;

  # Akkustand fuer noctalias Battery-Widget (liest ueber upower, nicht /sys).
  services.upower.enable = true;

  # Deckel zu -> Suspend. Am externen Netzteil bewusst `ignore`: sonst schlaeft
  # die Kiste weg, sobald man sie zugeklappt an einen Monitor haengt.
  #
  # Seit 26.05 heisst das services.logind.settings.Login.* und traegt die
  # ECHTEN logind.conf-Direktivnamen (HandleLidSwitch...), nicht mehr die
  # camelCase-Aliase. Die alten Namen funktionieren noch, warnen aber beim
  # Evaluieren -- dieselbe Umstellung wie bei programs.ssh in home/ssh.nix.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore";
  };

  # --- Bluetooth -------------------------------------------------------------
  # Am Desktop bewusst weggelassen (kein Adapter), hier onboard vorhanden.
  # blueman ist das Backend, das noctalias Bluetooth-Widget anspricht.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # --- Helligkeitstasten -----------------------------------------------------
  # brightnessctl liegt in home/bfn.nix (home.packages) -- damit ist zwar das
  # Binary da, aber NICHT die udev-Regel aus dem Paket, denn die zieht nur ueber
  # services.udev.packages. Ohne sie darf ein normaler User nicht nach
  # /sys/class/backlight schreiben und die XF86MonBrightness-Binds aus
  # home/hyprland.nix laufen still ins Leere.
  services.udev.packages = [ pkgs.brightnessctl ];

  # --- Login-Manager ---------------------------------------------------------
  # start-hyprland statt Hyprland: der Wrapper setzt systemd-User-Session +
  # dbus sauber auf, Direktstart erzeugt sonst bei jedem Login das Warn-Overlay.
  # Rueckweg bei kaputtem Login: alte NixOS-Generation im Bootloader.
  services.greetd = {
    enable = true;
    settings.default_session = {
      # pkgs.tuigreet, nicht pkgs.greetd.tuigreet -- in 26.05 umbenannt, analog
      # hosts/fabricus/configuration.nix. Der alte Pfad baut noch, warnt aber.
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      user = "greeter";
    };
  };

  # --- User ------------------------------------------------------------------
  # BEWUSST OHNE initialPassword/hashedPassword: dieses Repo ist PUBLIC.
  # Das Passwort wird waehrend der Installation im Chroot gesetzt --
  #   nixos-enter --root /mnt -- passwd bfn
  # -- und ueberlebt, weil users.mutableUsers auf dem Default (true) steht.
  # Ohne diesen Schritt kommst du am greetd-Prompt nicht rein.
  users.users.bfn = {
    isNormalUser = true;
    description = "Benjamin Nößler";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" ];
    shell = pkgs.fish;

    # Siehe hosts/fabricus/configuration.nix -- derselbe Key, damit der Weg
    # Laptop <-> Desktop in beide Richtungen offen ist.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdHqQP/7i5iIK4hBcLnjzvvQKFiD7xHH9+o7x95i58a openclaw-lab"
    ];
  };
  programs.zsh.enable = true;

  virtualisation.docker.enable = true;
  services.openssh.enable = true;

  # Host-Extra-Font; noto + jetbrains-mono kommen aus modules/system-base.nix.
  fonts.packages = with pkgs; [ nerd-fonts.fira-code ];

  # System-Editor fuer root/TTY (neovim ist home-only fuer bfn).
  environment.systemPackages = with pkgs; [ vim ];

  # --- Swap: zwei Ebenen, zwei Aufgaben ---------------------------------------
  # Anders als fabricus (nur zram, kein Hibernate), weil das hier ein Laptop ist.
  #
  # 1. zram  -- komprimierter Swap IM RAM. Faengt den Alltags-Ueberlauf ab und
  #    ist dabei um Groessenordnungen schneller als die NVMe. Prioritaet 5
  #    (NixOS-Default) und damit hoeher als die der Platten-Swap -> wird zuerst
  #    benutzt. Fuer Hibernate prinzipiell unbrauchbar: liegt selbst im RAM.
  # 2. lv-swap auf der Platte -- 20 GB, also >= den 16 GB RAM. Existiert
  #    ausschliesslich als Ablage fuer das Hibernate-Abbild und laeuft im
  #    Alltag wegen der niedrigeren Prioritaet praktisch leer mit.
  #
  # Der swapDevices-Eintrag selbst kommt aus hardware-configuration.nix
  # (nixos-generate-config findet die aktive Swap beim Installieren).
  zramSwap.enable = true;

  # Ohne resumeDevice weiss der Kernel beim Booten nicht, WO das Abbild liegt --
  # er bootet dann einfach frisch durch und die Sitzung ist still weg. Bewusst
  # der LVM-Pfad und keine UUID: VG und LV benennen wir beim Partitionieren
  # selbst, der Pfad steht damit schon vor der Installation fest. Eine UUID
  # gaebe es erst nach dem mkswap.
  # Beides liegt im LUKS-Container -> das Hibernate-Abbild ist mitverschluesselt.
  boot.resumeDevice = "/dev/vg0/swap";

  # 26.05, weil dieser Host am 09.08.2026 frisch mit 26.05 installiert wurde
  # (nicht von 25.05 hochgezogen). Anders als auf fabricus, wo 25.05 steht.
  system.stateVersion = "26.05";
}
