# Site-Specific-Browser Launcher fuer die OpenClaw Control UI (Primus, ueber Tailnet).
# Shared home-Modul -> identisch auf fabricus und spaeter cachus-rex.
#
# Startet Brave im --app-Modus: eigenes Fenster OHNE Tab-/URL-Leiste, fuehlt sich
# an wie eine native App. Nutzt bewusst das Default-Brave-Profil, damit die
# bestehende Gateway-Auth + das Device-Pairing weiterverwendet werden (kein
# separates --user-data-dir -> sonst muesstest du neu pairen/einloggen).
#
# --class setzt app_id/WM_CLASS auf "primus-control-ui"; StartupWMClass matcht das,
# damit Icon-Zuordnung + Hyprland-Fensterregeln greifen. Beispiel-Regel fuer
# hyprland.conf, falls du der Control UI einen festen Workspace geben willst:
#   windowrulev2 = workspace 3, class:^(primus-control-ui)$
{ config, pkgs, lib, ... }:
{
  xdg.desktopEntries.primus-control-ui = {
    name = "Primus Control UI";
    genericName = "OpenClaw Dashboard";
    comment = "OpenClaw Gateway Control UI ueber Tailnet";
    exec = "${pkgs.brave}/bin/brave --app=https://primus.tail872491.ts.net/ --class=primus-control-ui";
    icon = "brave-browser";
    terminal = false;
    categories = [ "Network" ];
    settings.StartupWMClass = "primus-control-ui";
  };
}
