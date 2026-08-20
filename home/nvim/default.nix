# nvim-Einhaengung in home-manager.
#
# Diese Datei macht nur eins: die eigentliche Config (./config.nix) unter
# programs.nixvim einhaengen und die Wrapper-Optionen setzen. Die Trennung
# ist gewollt -- config.nix bleibt dadurch prefix-frei und ist im
# Standalone-Paket aus flake.nix wiederverwendbar.
{ inputs, ... }:
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  programs.nixvim = {
    enable = true;

    # ACHTUNG, das ist keine Stilfrage: nixvim setzt eine Assertion
    #   assertion = !config.programs.neovim.enable
    # Die beiden Module schliessen sich aus, weil beide ein nvim ins Profil
    # legen wollen. Der alte `programs.neovim`-Block in home/apps.nix ist
    # deshalb im selben Commit entfernt worden -- nicht auskommentiert
    # wiederbeleben, ohne das hier abzuschalten.
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true; # `vimdiff a b` -> nvim -d a b

    imports = [ ./config.nix ];
  };
}
