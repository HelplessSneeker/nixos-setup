{
  description = "bfn NixOS config (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Bewusst KEIN follows: noctalia braucht sein eigenes nixpkgs-unstable
    # (C++23-Deps), sonst bricht der Build gegen 25.05.
    noctalia.url = "github:noctalia-dev/noctalia";

    # Nur fuer einzelne Bleeding-Edge-Pakete (godot 4.7, claude-code): 25.05
    # liefert nur godot ~4.4 / claude-code 1.0.85. Bewusst KEIN follows -> eigene,
    # aktuelle nixpkgs-Instanz.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
          # Eigener, rechtloser Account fuer den OpenClaw-Agent. Bewusst im
          # shared Stack: der Laptop-Host soll dieselbe Policy erben.
          ./modules/agent-user.nix
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
        # fabricus-itinerans = mkHost ./hosts/fabricus-itinerans/configuration.nix;   # wenn cachus-rex dran ist
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    };
}
