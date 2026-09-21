# Monitor-Layout fabricus-itinerans (Laptop).
#
# AB 21.09.2026 SCHREIBT DIESE DATEI KEIN LAYOUT MEHR.
#
# Das Layout lebt in ~/.config/hypr/monitors.conf, und diese Datei gehoert
# jetzt **nwg-displays**, nicht home-manager. home/hyprland.nix zieht sie
# unveraendert per `source` herein.
#
# --- WARUM DER DEKLARATIVE WEG HIER AUFGEGEBEN IST ---------------------------
#
# Der Laptop haengt mal am Dock zuhause, mal an einem Beamer, mal an einem
# fremden Dock, mal an gar nichts. Drei Anlaeufe haben gezeigt, dass sich das
# nicht sinnvoll deklarieren laesst:
#
#   1. Feste Connector-Namen (DP-4, DP-5): die Namen haengen an Dock und
#      Kabelport und aendern sich regelmaessig. Am 18.09.2026 stand deshalb
#      eine Regel fuer DP-6 in der Datei, einen Connector, den es auf der
#      Maschine gar nicht gibt.
#   2. `desc:`-Matching auf die EDID-Kennung: traegt hier nicht, weil beide
#      externen Schirme denselben Hersteller-/Modellstring melden (BK550Y) und
#      Hyprland die Seriennummer nicht entgegennimmt.
#   3. Catch-all mit `auto-right` (Stand vom 21.09. frueh): verhindert zwar
#      zuverlaessig, dass zwei Outputs uebereinander landen -- legt aber nicht
#      fest, WELCHER der beiden gleichen Schirme links steht. Ergebnis war eine
#      Anordnung, die nicht ueberlappt, aber trotzdem falsch ist.
#
# Es gibt schlicht kein stabiles Merkmal, das bfns Schirme in der richtigen
# Reihenfolge unterscheidet und das eine Config vorab kennen koennte. Also
# uebernimmt das ein Werkzeug zur Laufzeit, mit den Augen des Benutzers.
#
# --- WAS NWG-DISPLAYS MACHT --------------------------------------------------
#
# GTK-Oberflaeche, Schirme per Drag-and-drop anordnen, danach "Apply". Pro
# Output einstellbar: Aufloesung, Bildwiederholrate, Scale, Drehung, an/aus --
# deckt also auch den Fall mit ab, dass unterwegs ein Schirm mit anderer
# Aufloesung dranhaengt.
#
# Es schreibt per Default exakt nach ~/.config/hypr/monitors.conf, also genau
# dorthin, wo home/hyprland.nix ohnehin schon `source =` hinzeigt. Deswegen
# braucht es keinen `-m`-Pfad und keine Aenderung an hyprland.nix.
#
# "Apply" wirkt sofort, ein `hyprctl reload` ist NICHT noetig -- von bfn am
# 21.09.2026 im Betrieb bestaetigt.
#
# WICHTIG, falls jemand spaeter an den Hyprland-Settings dreht: genau das haengt
# daran, dass `disable_autoreload` NICHT auf true steht. Wird es gesetzt, wirkt
# "Apply" erst nach einem manuellen Reload. Aktuell nirgends im Flake gesetzt.
#
# nwg-displays legt zusaetzlich ~/.config/hypr/workspaces.conf an (Zuordnung
# Workspace -> Output). Die wird bewusst NICHT gesourct: die Workspace-Binds
# stehen in home/hyprland.nix und sollen dort bleiben. Die Datei liegt dann
# ungenutzt herum, das ist harmlos.
#
# --- PREIS, BEWUSST AKZEPTIERT -----------------------------------------------
#
# monitors.conf ist ab jetzt veraenderlicher Zustand auf der Maschine und
# steht nicht mehr im Flake. Ein frisch aufgesetzter Laptop hat die Datei
# nicht; Hyprland warnt dann nur ueber das fehlende `source` (dasselbe
# Verhalten wie bei noctalia.conf, steht so in home/hyprland.nix) und faehrt
# alle Schirme mit seinen Defaults hoch. Ein Durchlauf von nwg-displays stellt
# das in einer Minute her.
#
# DASSELBE GILT BEIM ERSTEN REBUILD NACH DIESER AENDERUNG: home-manager raeumt
# seinen alten Symlink weg, die Datei ist einmalig weg, und die Schirme
# springen auf die Default-Anordnung. Einmal nwg-displays starten, anordnen,
# "Apply" -- danach bleibt es liegen.
#
# Ist eine Anordnung es wert, aufgehoben zu werden (z. B. das Dock zuhause),
# gehoert eine Kopie der Datei ins Repo -- als Kopie, nicht als generierte
# Quelle. Sonst ist man wieder bei Punkt 1 oben.
#
# Der Desktop bleibt unberuehrt: hosts/fabricus/monitors.nix erzeugt sein
# Layout weiter deklarativ ueber home-manager. Dort stehen zwei feste Schirme
# an festen Ports, das ist der Fall, fuer den Deklaration gemacht ist.
{ pkgs, ... }:
{
  # Hier statt in home/apps.nix, weil es reines Laptop-Werkzeug ist: der
  # Desktop haette nichts davon und koennte seine monitors.conf ohnehin nicht
  # ueberschreiben (die ist dort ein read-only Store-Symlink).
  #
  # Aufruf ueber SUPER+SHIFT+M, siehe home/hyprland.nix.
  environment.systemPackages = [ pkgs.nwg-displays ];
}
