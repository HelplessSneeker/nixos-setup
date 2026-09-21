# Monitor-Layout fabricus-itinerans (Laptop).
#
# Der bewegliche Fall: Dock zuhause, Beamer unterwegs, mal nur das interne
# Panel. Deshalb eine eigene Datei -- der Desktop bleibt unberuehrt.
#
# Aendern: Werte editieren -> `nixos-rebuild switch`. Falls Hyprland die neue
# Datei nicht von selbst zieht (sie haengt per `source` an einem Store-Symlink,
# der sich beim Rebuild aendert): `hyprctl reload`.
#
# --- LEITIDEE seit 21.09.2026: KEINE Connector-Namen mehr ---------------------
#
# Bis hierher stand fuer jeden externen Schirm eine eigene Regel mit seinem
# Connector-Namen (DP-4, DP-5) und darunter ein Catch-all mit `auto`. Das ist
# aus zwei Gruenden aufgegeben:
#
#   1. Die Namen sind NICHT stabil. Sie haengen daran, an welchem Port des
#      Docks welches Kabel steckt und welches Dock ueberhaupt dranhaengt --
#      zuhause andere als in Feldkirchen, beim Kunden wieder andere. Eine
#      Regel auf einen Namen zu schreiben, den man beim naechsten Andocken
#      nicht mehr hat, ist eine Regel, die nie greift.
#
#   2. Feste Regel + Catch-all `auto` KOENNEN KOLLIDIEREN. `auto` haengt einen
#      Schirm rechts an den bisher rechtesten AKTIVIERTEN an. Beim Kaltstart
#      kommen die Schirme meist in der Reihenfolge, in der die Regeln passen,
#      und es faellt nicht auf. Beim Hotplug im Resume (Deckel auf, Dock wieder
#      dran) kann die Reihenfolge kippen: der namenlose Schirm landet per `auto`
#      auf 1920x0, danach setzt die feste Regel den zweiten auf dieselbe
#      Koordinate. Zwei Outputs auf identischen Koordinaten -- und eine
#      layer-shell-Bar wie noctalia ueberlebt das nicht zuverlaessig.
#
# Der Ersatz ist `auto-right` statt `auto` im Catch-all. Die Richtung ist
# deterministisch, jeder neue Schirm haengt sich rechts an den bisherigen
# Verbund, Ueberlappung ist damit konstruktiv ausgeschlossen -- unabhaengig
# davon, wie die Connector heissen und in welcher Reihenfolge sie auftauchen.
#
# Nur `eDP-1` bleibt benannt: das interne Panel ist der einzige Output, dessen
# Name sich nie aendert, und es soll immer links bei 0x0 stehen.
#
# --- WAS `desc:` HIER NICHT LOEST --------------------------------------------
#
# Hyprland kann Schirme statt ueber den Connector auch ueber die EDID-Kennung
# ansprechen (`monitor = desc:<Hersteller> <Modell>, ...`). Das waere der
# uebliche Ausweg aus wechselnden Connector-Namen -- hier aber nicht:
#
#   Connector | EDID-Groesse   | Seriennummer  | Produktcode  (12.08.2026)
#   ----------+----------------+---------------+------------
#   DP-4      | 60x34 cm (27") | 007NTGYBV575  | 0x5b42
#   DP-5      | 48x27 cm (22") | 912NTHM8B985  | 0x5b40
#   eDP-1     | 31x17 cm (14") | LG LP140WF6-SPB7 -- internes T480-Panel
#
# Beide externen Schirme melden denselben Hersteller-/Modellstring ("BK550Y",
# LG). Unterscheidbar sind sie nur ueber die Seriennummer -- und die nimmt
# Hyprland in `desc:` nicht entgegen. `desc:` wuerde also beide gleichzeitig
# treffen und ist als Unterscheidungsmerkmal wertlos.
#
# --- PREIS DIESER LOESUNG, bewusst in Kauf genommen ---------------------------
#
# Welcher der beiden gleichen Externen links und welcher rechts landet, ist
# nicht mehr festgelegt -- sie sind fuer den Compositor ununterscheidbar.
# Sitzen sie vertauscht: Kabel am Dock tauschen, oder zur Laufzeit ohne Rebuild
#   hyprctl keyword monitor "DP-4,preferred,3840x0,1"
# (Connector-Namen dafuer aus `hyprctl monitors`). Das ist der Tausch von
# "manchmal vertauscht" gegen "manchmal uebereinander" -- und uebereinander war
# der Fall, der die Shell zerlegt hat.
{ ... }:
{
  home-manager.users.bfn.xdg.configFile."hypr/monitors.conf".text = ''
    # Managed by home-manager (hosts/fabricus-itinerans/monitors.nix)

    # Internes Panel: einziger Output mit stabilem Namen, steht immer ganz
    # links bei 0x0. Deckel zu / Panel aus: Zeile durch
    # `monitor = eDP-1, disable` ersetzen -- die externen Schirme ruecken dann
    # von selbst nach, weil sie relativ platziert werden.
    monitor = eDP-1, preferred, 0x0, 1

    # ALLES ANDERE -- Dock zuhause, Beamer, fremdes Dock, egal wie der
    # Connector heisst: native Aufloesung, scale 1, deterministisch rechts
    # angehaengt. `auto-right` statt `auto`: gleiche Platzierung, aber mit
    # garantierter Richtung statt "Hyprland entscheidet".
    #
    # scale 1 ueberall, KEIN 1.25 wie am Desktop -- die 1.25 dort teilt 4k
    # sauber auf, auf 1080p waere derselbe Faktor fractional und damit unscharf.
    monitor = , preferred, auto-right, 1
  '';
}
