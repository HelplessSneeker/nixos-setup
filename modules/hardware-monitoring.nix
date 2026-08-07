# Hardware-Fehler- und Sensor-Monitoring.
#
# ANLASS (08.08.2026): fabricus ist zwischen 06.08. 16:18 und 08.08. 00:55
# VIER MAL hart abgestuertzt -- jedes Mal mit identischer Machine Check
# Exception, Bank 5 (Execution Unit), Statuswort bea0000000000108 (VAL+UC+PCC).
# PCC = Processor Context Corrupt -> die CPU MUSS sofort anhalten.
#
# Der Fehler stand die ganze Zeit im Journal, aber als roher Hex-Dump, der nur
# beim naechsten Boot einmal auftaucht. Ohne rasdaemon merkt das niemand, bis
# jemand gezielt danach greppt. Genau das soll hier nicht nochmal passieren.
#
# Shared: von jedem Host importierbar, nichts board-spezifisches.
# Board-Sensoren (Super-I/O, Spannungen, Luefter) sind pro Host -- der
# it87-Teil fuer das Gigabyte B450 steht in hosts/fabricus/configuration.nix.
{ config, pkgs, lib, ... }:
{
  # --- rasdaemon: MCE/RAS-Fehler dekodieren und persistent mitschreiben ---
  #
  # Ohne das: Kernel schreibt einmalig Hex ins Journal, fertig.
  # Mit dem: SQLite-DB unter /var/lib/rasdaemon/ras-mc_event.db, abfragbar per
  #
  #   ras-mc-ctl --errors          # alle erfassten Fehler, dekodiert
  #   ras-mc-ctl --summary         # Zaehler pro Fehlerklasse
  #   ras-mc-ctl --error-count     # Speicherfehler pro DIMM
  #
  # WICHTIG -- was rasdaemon NICHT tut: es verhindert keinen einzigen Absturz.
  # Es macht nur sichtbar und nachvollziehbar, was die Hardware meldet.
  hardware.rasdaemon = {
    enable = true;
    record = true;   # in die SQLite-DB schreiben, nicht nur ins Journal
  };

  # --- lm_sensors: Temperaturen, Spannungen, Luefterdrehzahlen ---
  #
  # k10temp (CPU-Die) laedt der Kernel von selbst und liefert Tctl/Tccd1.
  # Alles andere -- Vcore, +12V, +5V, Luefter-RPM -- kommt erst mit dem
  # Super-I/O-Treiber des jeweiligen Boards (siehe Host-Config).
  environment.systemPackages = with pkgs; [ lm_sensors ];
}
