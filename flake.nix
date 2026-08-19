{
  description = "bfn NixOS config (multi-host)";

  inputs = {
    # 26.05 seit 09.08.2026. Davor 25.05, das seit Ende 2025 EOL ist -- also
    # ohne Sicherheitsupdates. Der Sprung ueberspringt 25.11; NixOS traegt das,
    # die Breaking Changes beider Releases summieren sich aber. Geprueft und
    # relevant fuer diese Config waren zwei:
    #   1. Der DBus-Default wechselt auf dbus-broker (26.05). Betrifft die
    #      Aktivierung des FileManager1-Shims in home/apps.nix. Ausserdem ist
    #      services.dbus.implementation ein "switch inhibitor" -- der Wechsel
    #      braucht einen REBOOT, ein switch allein reicht nicht.
    #   2. Das NVIDIA-Modul wurde umgebaut (neues nvidia-x11-Output-Layout,
    #      EGL-ICDs aus Source statt Vendor-Binaries, neue Option
    #      hardware.nvidia.branch). package/open bleiben gueltig.
    # Unkritisch, weil hier nicht benutzt: AcceptEnv-Typwechsel, PostgreSQL-,
    # Nextcloud-, Stalwart- und taskchampion-Defaults.
    #
    # system.stateVersion bleibt bewusst auf dem Installationswert je Host und
    # wird NICHT mitgezogen -- die Option markiert den Stand, gegen den
    # Datenmigrationen laufen, nicht die nixpkgs-Version.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      # MUSS zur nixpkgs-Release passen, sonst driften Modul-Optionen.
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Bewusst KEIN follows: noctalia braucht sein eigenes nixpkgs-unstable
    # (C++23-Deps).
    noctalia.url = "github:noctalia-dev/noctalia";

    # Bleibt auch nach dem 26.05-Umstieg noetig, das ist geprueft: 26.05 hat
    # Hyprland nur in 0.55.4, hier laeuft 0.56.1. Ebenso godot 4.7,
    # claude-code und citrix-workspace. Bewusst KEIN follows -> eigene,
    # aktuelle nixpkgs-Instanz.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Hardware-Quirks fuer den ThinkPad T480 (nur vom Laptop-Host importiert).
    # Modulkette am 09.08.2026 gegen upstream gelesen, sie bringt:
    #   - services.throttled        gegen Lenovos BIOS-Power-Limit-Drosselung
    #   - TrackPoint + emulateWheel mittlere Taste halten = scrollen
    #   - i915-Kernelparams         enable_guc=2, enable_fbc=1, enable_psr=2
    #   - hardware.intelgpu         vaapiDriver=intel-media-driver,
    #                               computeRuntime=legacy (Gen9.5 will die alte)
    #   - services.fstrim, i915 im initrd, Microcode-Default
    #
    # Der frueher hier notierte Verdacht gegen hardware.intelgpu.vaapiDriver hat
    # sich aufgeloest: die Option wird von nixos-hardware SELBST deklariert
    # (common/gpu/intel), haengt also an keiner nixpkgs-Release.
    # Ebenfalls geprueft: common/pc/laptop setzt services.tlp nur per
    # `mkDefault (!power-profiles-daemon.enable)` -- die Host-Config schaltet
    # PPD ein, TLP bleibt damit aus. Kein Konflikt.
    # Im Auge behalten: throttled laeuft dann parallel zu thermald (anderer
    # Job -- MSR-Power-Limits vs. Thermik), und enable_psr=2 ist der erste
    # Verdaechtige, falls das Panel je flackert.
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

      # Eine einzige unstable-Instanz fuer alle Module, die daraus ziehen.
      # WICHTIG: als `import` mit config, nicht als `legacyPackages` --
      # legacyPackages traegt keine config, damit scheitert jedes unfree Paket
      # (z.B. claude-code) an "Package ... has an unfree license".
      pkgsUnstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # Gemeinsamer Modul-Stack fuer jeden Host. Host-spezifisches
      # (NVIDIA, hardware-config, hostName) lebt im jeweiligen hostModule.
      mkHost = hostModule: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgsUnstable; };
        modules = [
          hostModule
          ./modules/system-base.nix
          ./modules/tailscale.nix
          ./modules/gui-apps.nix
          # rasdaemon + lm_sensors. Shared, weil "Hardware meldet Fehler und
          # keiner sieht es" auf jeder Maschine gleich schlecht ist.
          ./modules/hardware-monitoring.nix
          # Eigener, rechtloser Account fuer den OpenClaw-Agent. Bewusst im
          # shared Stack: der Laptop-Host soll dieselbe Policy erben.
          ./modules/agent-user.nix
          ./modules/ssh-hardening.nix
          # `wifi-portal` fuer Captive-Portal-WLANs (SUPER+SHIFT+W). Shared,
          # obwohl praktisch nur der Laptop in fremde Netze kommt: der Keybind
          # lebt im gemeinsamen home/hyprland.nix, und ein Bind, dessen Kommando
          # auf einem Host fehlt, taucht im Cheatsheet trotzdem auf und laeuft
          # dann ins Leere. Ein ungenutztes Skript ist billiger als das.
          ./modules/captive-portal.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Bestehende, nicht von HM verwaltete Dotfiles nicht als Fehler
            # behandeln, sondern zur Seite legen (z.B. die alte, per GUI
            # gepflegte ~/.config/mimeapps.list). Ohne das bricht die
            # Aktivierung mit "Existing file ... is in the way" ab.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit inputs pkgsUnstable; };
            home-manager.users.bfn = import ./home/bfn.nix;
          }
        ];
      };
    in
    {
      # Output-Namen sind bewusst IDENTISCH mit dem jeweiligen networking.hostName.
      # Damit findet `nixos-rebuild --flake /etc/nixos` ohne #attribut von selbst
      # den richtigen Host (es faellt auf nixosConfigurations.<hostname> zurueck)
      # -- die fish-Abbrevs nrs/nrb funktionieren so auf jeder Maschine gleich.
      nixosConfigurations = {
        fabricus = mkHost ./hosts/fabricus/configuration.nix;
        # Aktiv seit 09.08.2026 -- die hardware-configuration.nix aus der
        # Installation liegt jetzt im Repo.
        fabricus-itinerans = mkHost ./hosts/fabricus-itinerans/configuration.nix;
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    };
}
