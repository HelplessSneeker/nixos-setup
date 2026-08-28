# Kalender-Client mit CalDAV-Schreibzugriff (Time-Blocking gegen Radicale).
#
# HOST-LOKAL IMPORTIERT, nicht im shared Stack aus flake.nix: der Auftrag vom
# 28.08.2026 galt dem Laptop. Auf fabricus laesst sich dasselbe Modul jederzeit
# durch eine Import-Zeile nachziehen -- es ist bewusst frei von
# Host-Annahmen (kein NVIDIA, kein Akku, kein Monitor-Layout).
#
# WARUM GTK/GNOME UND NICHT MERKURO/KDE:
# Diese Maschine faehrt Hyprland ohne Desktop-Environment, das einzige
# vorhandene Portal ist xdg-desktop-portal-gtk (modules/gui-apps.nix). Merkuro
# und KOrganizer speichern ihre Kalender nicht selbst, sondern ueber Akonadi --
# das bedeutet einen zusaetzlichen Dauerdienst (akonadi_control), eine eigene
# Datenbank (MariaDB/SQLite) und kwallet fuer die Passwoerter, alles ausserhalb
# einer Plasma-Session zusammengehalten. Der GNOME-Weg braucht dafuer genau
# einen D-Bus-Dienst (evolution-data-server) und den ohnehin nuetzlichen
# gnome-keyring. Weniger bewegliche Teile auf einer Maschine, die sonst kein
# GNOME hat.
#
# Beide Frontends unten teilen sich denselben evolution-data-server. Ein
# CalDAV-Konto wird also EINMAL angelegt und ist in beiden Apps sichtbar --
# deshalb kosten zwei Frontends fast nichts und bfn kann waehlen, welches sich
# beim Ziehen von 30-Minuten-Bloecken besser anfuehlt.
{ config, pkgs, lib, ... }:
{
  # --- Backend ---------------------------------------------------------------
  # evolution-data-server haelt Kalender/Kontakte und spricht CalDAV. Es ist ein
  # D-Bus-aktivierter Dienst, laeuft also nur, wenn eine App ihn ruft, und
  # braucht keine GNOME-Session. Ohne diese Option landen die .service-Dateien
  # nicht im Suchpfad des Session-Bus -- die Apps starten dann zwar, finden aber
  # keine Konten und melden "Unable to connect to the calendar".
  services.gnome.evolution-data-server.enable = true;

  # Passwortspeicher (org.freedesktop.secrets). EDS legt das CalDAV-Passwort
  # dort ab; ohne Keyring fragt jede App bei JEDEM Start neu danach.
  #
  # 1Password ist auf dieser Maschine zwar vorhanden (modules/gui-apps.nix),
  # aber kein Ersatz: es implementiert die Secret-Service-Schnittstelle nicht,
  # ueber die EDS Passwoerter sucht. Das Kalender-Passwort landet damit im
  # Keyring, der Master-Eintrag bleibt in bfns 1Password.
  services.gnome.gnome-keyring.enable = true;

  # Keyring beim Login mitentsperren. Der Anker ist greetd, weil das der
  # Login-Manager dieses Hosts ist (hosts/fabricus-itinerans/configuration.nix).
  # Fehlt die Zeile, existiert der Keyring zwar, ist aber gesperrt -- Symptom
  # ist ein Passwort-Dialog "Anmeldung entsperren" beim ersten Kalenderzugriff
  # nach jedem Boot, nicht etwa eine Fehlermeldung.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # --- Frontends -------------------------------------------------------------
  # Bewusst systemPackages und nicht home/apps.nix: die Datei ist ein SHARED
  # home-Modul und wuerde die Pakete auch auf fabricus einspielen. So bleibt
  # alles zum Thema Kalender an dieser einen host-lokal importierten Datei.
  environment.systemPackages = with pkgs; [
    # Primaer fuers Time-Blocking. Wochenansicht mit Stundenraster: Ziehen legt
    # einen Block an, Ziehen am Koerper verschiebt ihn, Ziehen an der Ober-/
    # Unterkante aendert die Dauer. Raster rastet auf 30 Minuten.
    # Farbe pro Kalender + Sichtbarkeits-Haken in der Seitenleiste -- damit sind
    # "Bloecke" und "echte Termine" getrennt einblendbar.
    gnome-calendar

    # Zweitmeinung am selben Backend. Evolution hat eine echte TAGES-Ansicht
    # (gnome-calendar kennt nur Woche/Monat/Jahr) und laesst die Rasterweite
    # einstellen, ist dafuer eine ganze Groupware-Suite statt einer Kalender-App.
    # Steht hier als Ausweichoption, falls sich gnome-calendar beim Ziehen zickig
    # anstellt; das Konto ist in beiden dasselbe.
    evolution

    # Keyring-GUI. Nicht Deko, sondern das Diagnosewerkzeug fuer den haeufigsten
    # Fehlerfall: ein falsch gespeichertes CalDAV-Passwort laesst sich hier
    # sehen und loeschen, statt es blind ueber die App neu zu setzen.
    seahorse
  ];
}
