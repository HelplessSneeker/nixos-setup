# Game-Dev-Toolchain (home-manager). Shared -> fabricus jetzt, laptop spaeter.
#
# Godot 4.7 kommt aus nixpkgs-unstable, weil das systemweit gepinnte 25.05 nur
# godot ~4.4 enthaelt (4.7 stable erst 18.06.2026). Nur DIESES Paket zieht aus
# unstable; das restliche System bleibt sauber auf 25.05.
{ pkgs, inputs, ... }:
let
  # Eigene, aktuelle nixpkgs-Instanz nur fuer godot. System-string bewusst
  # hardcodiert wie in der flake.nix (system = "x86_64-linux").
  unstable = inputs.nixpkgs-unstable.legacyPackages."x86_64-linux";
in
{
  home.packages = [
    # Godot 4.x (Mono/C#-freie Standard-Variante). Falls die Eval das Attribut
    # nicht findet: auf der Maschine pruefen -> `nix search nixpkgs-unstable godot`
    # (Kandidaten: godot_4, godot, godot_4-mono).
    unstable.godot_4
  ];
}
