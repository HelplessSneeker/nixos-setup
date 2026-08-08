# Citrix Workspace App -- Zugang zum Firmen-Desktop im Homeoffice.
#
# BEWUSST NICHT im shared Modul-Stack von flake.nix, sondern Import pro Host.
# Grund: das Paket holt seinen Tarball ueber `requireFile` -- Citrix laesst kein
# automatisches Herunterladen zu (EULA), die Datei muss VORHER von Hand im Store
# der jeweiligen Maschine liegen. Haengt das Modul im shared Stack, blockiert ein
# fehlender Tarball jeden Rebuild auf jedem Host, auch dort wo niemand Citrix
# braucht.
#
# --- Einmalig pro Maschine, VOR dem ersten Rebuild mit diesem Modul: ---
#
#   1. linuxx64-26.04.0.105.tar.gz laden von
#      https://www.citrix.com/downloads/workspace-app/betas-and-tech-previews/workspace-app-tp-gcc11-for-linux.html
#      Ja, die Tech-Preview-Seite. nixpkgs paketiert die GCC-11-Linie, weil die
#      normale GA-Linie gegen libsoup 2.4 / webkitgtk 4.0 linkt -- beides ist aus
#      nixpkgs entfernt.
#
#   2. nix-prefetch-url file://$PWD/linuxx64-26.04.0.105.tar.gz
#      Muss exakt 1kl6b1ldjd9gb6cmvhxf6ggvc3amq1kz0qwjlb1fp6dxx0pivwm8 ausgeben.
#      Weicht der Hash ab, hast du einen anderen Build erwischt (Citrix schiebt
#      unter derselben Seite neue Versionen nach) -- dann gegen den Pin in
#      nixpkgs-unstable abgleichen statt den Hash hier zu "reparieren".
#
#   3. Tarball behalten (z.B. in ~/). `nix-collect-garbage` raeumt ihn aus dem
#      Store, danach scheitert der naechste Rebuild wieder mit der
#      requireFile-Meldung -- mit der Datei zur Hand ist Schritt 2 ein Einzeiler.
#
# Der Store ist pro Maschine: fuer Desktop und Laptop faellt das jeweils
# getrennt an (oder einmal machen und `nix copy` benutzen).
{ config, pkgs, pkgsUnstable, lib, ... }:
{
  # Aus unstable, nicht aus 25.05: dort ist `citrix_workspace` auf 24.11.0.85
  # (Nov 2024) eingefroren, haengt an webkitgtk_4_0 + libsoup 2.4 und ist sowohl
  # bei Citrix als auch downstream EOL -- den passenden Tarball gibt es nur noch
  # ueber Citrix' Legacy-Seite. unstable liefert 26.04.0.105 gegen libsoup 3 /
  # webkitgtk 4.1. Attributname seit 17.06.2026 mit BINDESTRICH,
  # `citrix_workspace` ist nur noch ein warnender Alias.
  #
  # SYSTEM-Ebene, bewusst nicht home.packages: das Paket liefert
  # share/mime/packages/Citrix-mime_types.xml mit, und nur aus
  # environment.systemPackages baut NixOS (xdg.mime, per Default an) die
  # Shared-MIME-Datenbank neu. Ohne die kennt der Desktop den Typ
  # application/x-ica nicht -- dann ist die aus dem Browser geladene .ica-Datei
  # fuer Firefox ein anonymer Blob und Citrix taucht im "Oeffnen mit" nicht auf.
  # Der Handler-Eintrag dazu steht in home/apps.nix (xdg.mimeApps).
  environment.systemPackages = [ pkgsUnstable.citrix-workspace ];

  # XWayland muss NICHT extra angefasst werden: wfica ist ein X11-Client, und
  # der nixpkgs-Wrapper setzt dafuer schon GDK_BACKEND=x11 + EGL_PLATFORM=x11.
  # Ohne die beiden greift Mesas EGL-Loader beim Start nach dem Wayland-Backend
  # und wfica segfaultet (nixpkgs#540102).

  # --- Zwei Dinge, die erst der erste echte Verbindungsversuch klaert ---
  #
  # Firmen-CA: liefert das Gateway ein intern signiertes Zertifikat aus, bricht
  # die Verbindung mit einem TLS-Fehler ab (klassisch "SSL error 61"). Der
  # vorgesehene Weg waere
  #   (pkgsUnstable.citrix-workspace.override { extraCerts = [ ./firma-ca.pem ]; })
  # ACHTUNG: dieses Repo ist PUBLIC. Eine Firmen-Root-CA hier drin gibt interne
  # PKI- und Hostnamen preis. Also erst pruefen, ob es ueberhaupt noetig ist --
  # und wenn ja, den Weg vorher besprechen.
  #
  # Smartcard-/Token-Login: dafuer fehlt der PC/SC-Daemon. Das Paket ist darauf
  # vorbereitet (libpcsclite haengt im LD_PRELOAD des Wrappers), der Dienst
  # selbst ist hier bewusst aus, solange nicht feststeht, dass die Firma das
  # nutzt -- ein laufender Daemon fuer nicht vorhandene Hardware ist nur Angriffsflaeche:
  # services.pcscd.enable = true;
}
