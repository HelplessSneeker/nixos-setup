# `procs` -- einmalige Prozess-/Lastuebersicht der lokalen Maschine.
# Geteiltes home-manager-Modul: gilt fuer fabricus UND fabricus-itinerans.
#
# Warum ein Binary und keine fish-Funktion: so laeuft `procs` auch in zsh, in
# Skripten und ueber `ssh fabricus procs` -- eine fish-Funktion koennte das
# nicht. Preis: `cheat` listet es nicht auf (das liest nur abbrs und
# ~/.config/fish/functions/).
#
# Der Ausgabe-Aufbau ist absichtlich derselbe wie beim /procs-Skill auf primus,
# damit Skitarii eine gepastete Ausgabe ohne Ruecksetzen liest.
#
# PATH: bewusst NICHT per writeShellApplication/makeBinPath gepinnt. Das Skript
# testet jedes optionale Werkzeug (docker, nvidia-smi, nixos-version) mit
# `command -v` und degradiert zu einer Zeile Text, wenn es fehlt -- das ist auf
# zwei unterschiedlichen Maschinen (NVIDIA-Desktop vs. Intel-Laptop) das
# Verhalten, das man will. ps/top/free/df/ss/systemctl kommen aus dem
# System-Profil und sind auf beiden Hosts da.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "procs" (builtins.readFile ./procs.sh))
  ];

  # Kurzform fuer den haeufigsten Aufruf. Abbreviations expandieren sichtbar --
  # du siehst beim Tippen, was wirklich laeuft.
  programs.fish.shellAbbrs.po = "procs";
}
