# Monitor-Layout fabricus-itinerans (Laptop).
#
# Der bewegliche Fall: Dock zuhause, Beamer unterwegs, mal nur das interne
# Panel. Deshalb eine eigene Datei -- Layout aendern heisst hier nur, die
# Koordinaten unten zu tauschen, ohne den Desktop anzufassen.
#
# Aendern: Werte editieren -> `nixos-rebuild switch`. Falls Hyprland die neue
# Datei nicht von selbst zieht (sie haengt per `source` an einem Store-Symlink,
# der sich beim Rebuild aendert): `hyprctl reload`.
#
# --- Was am Dock haengt (verifiziert 12.08.2026 ueber /sys/class/drm/*/edid) ---
#
#   Connector | EDID-Groesse   | Seriennummer  | Produktcode
#   ----------+----------------+---------------+------------
#   DP-4      | 60x34 cm (27") | 007NTGYBV575  | 0x5b42
#   DP-5      | 48x27 cm (22") | 912NTHM8B985  | 0x5b40
#   eDP-1     | 31x17 cm (14") | LG LP140WF6-SPB7 -- internes T480-Panel
#
# Beide externen Schirme melden denselben EDID-Namensstring ("BK550Y", LG) und
# beide fahren 1920x1080 -- sie sind ueber den Namen NICHT unterscheidbar, nur
# ueber Connector bzw. Seriennummer. Die Seriennummer steht auf dem Aufkleber
# hinten am Geraet, falls die Zuordnung unten mal nicht stimmt.
#
# WICHTIG, das war der urspruengliche Fehler: hier stand frueher nur
# `monitor = , preferred, auto, 1` fuer beide Externen. `auto` haengt jeden
# neuen Schirm rechts an den bisher rechtesten -- in Erkennungsreihenfolge,
# nicht in der Reihenfolge, in der sie auf dem Tisch stehen. Feste Koordinaten
# sind der Fix; das Catch-all bleibt nur fuer unbekannte Schirme uebrig.
#
# REIHENFOLGE AENDERN: nur die x-Offsets neu vergeben, in Schritten von 1920
# (alle drei Schirme sind 1920 logische px breit, scale 1). Aktuell 0 / 1920 /
# 3840. Ueberlappende Offsets sind der Fehler, den man vermeiden will; Luecken
# sind unkritisch, der Zeiger springt dann nur ueber den Zwischenraum.
{ ... }:
{
  home-manager.users.bfn.xdg.configFile."hypr/monitors.conf".text = ''
    # Managed by home-manager (hosts/fabricus-itinerans/monitors.nix)

    # Dock-Aufstellung von links nach rechts, alle drei oberkantenbuendig:
    #
    #   [ eDP-1 14" ][ DP-5 22" ][ DP-4 27" ]
    #   0        1920         3840        5760
    #
    # scale 1 ueberall, KEIN 1.25 wie am Desktop -- die 1.25 dort teilt 4k
    # sauber auf, auf 1080p waere derselbe Faktor fractional und damit unscharf.
    # Deshalb ist jeder Schirm genau 1920 logische px breit, auch der 27er.
    #Feldkircheken Bildschirme 
#	monitor = DP-5,  1680x1050@59.954, -1680x0, 1
#	monitor = DP-3,  1680x1050@59.954, -3360x0, 1

	monitor = DP-5,  preferred, 1920x0, 1
	monitor = DP-4,  preferred, 3840x0, 1

    # Internes Panel ganz links, bei 0x0 -- NICHT mittig darunter.
    # Deckel zu / Panel aus: die eDP-1-Zeile durch `monitor = eDP-1, disable`
    # ersetzen. Die beiden Externen behalten dabei ihre Offsets, die Flaeche
    # beginnt dann erst bei 1920 -- unproblematisch, links davon liegt schlicht
    # kein Schirm mehr. Kein Nachruecken noetig.
    monitor = eDP-1, preferred, 0x0, 1

    # Unbekannter Schirm (Beamer, fremdes Dock): rechts dran, native Aufloesung.
    monitor = , preferred, auto, 1
  '';
}
