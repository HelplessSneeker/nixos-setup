{ config, pkgs, lib, ... }:
# Ladeschwellen fuer die beiden Akkus des ThinkPad T480.
#
# WARUM: Lithium-Ionen altert ueberproportional, wenn die Zelle dauerhaft auf
# 100 % gehalten wird. Der Laptop haengt viel am Netzteil -- ohne Deckel steht
# der Akku also praktisch permanent voll. 80 % kostet Laufzeit, die im
# Netzbetrieb ohnehin niemand braucht.
#
# NUR VOM LAPTOP-HOST IMPORTIERT, bewusst nicht im shared Stack: fabricus hat
# keinen Akku, dort waeren Service und udev-Regel tote Last.
#
# Warum von Hand und nicht ueber TLP: TLP kann das, schliesst sich aber mit
# power-profiles-daemon gegenseitig aus (siehe die Weiche in nixos-hardware,
# common/pc/laptop). PPD ist gesetzt, weil noctalias Power-Widget es als
# Backend erwartet -- also bleibt TLP aus und die Schwellen macht dieses Modul.
# Eine eigene NixOS-Option dafuer gibt es ausserhalb von TLP nicht.
#
# Verifiziert am 10.08.2026 auf der Maschine: `thinkpad_acpi` ist geladen,
# BAT0 und BAT1 haben beide charge_control_start_threshold und
# charge_control_end_threshold, beide standen auf 100.
let
  # Schwellen pro Akku in Prozent. start < end, sonst weist der Treiber ab.
  #
  # Der Startwert ist kein Schmuck: ohne ihn beginnt der Akku bei jedem
  # Prozentpunkt unter dem Deckel wieder zu laden -- also genau das staendige
  # Nachladen, das die Schwelle verhindern soll.
  #
  # BAT1 (Bay, SANYO 01AV425) ist kerngesund: 24,37 von 24,05 Wh Design = 101 %
  # bei 184 Zyklen (gemessen 15.09.2026). Fuer den bleibt 75/80 wie gehabt.
  #
  # BAT0 (intern, SMP 01AV421) ist am Lebensende: 4,07 von 24,00 Wh = 17 % bei
  # 1083 Zyklen. Bei so wenig Restkapazitaet ist die Spannungskurve gegen den
  # angezeigten Ladestand verschoben. Im Ruhezustand gemessen:
  #     80 % Anzeige -> 12,593 V = 4,198 V/Zelle  (Ladeschlussspannung!)
  #     75 % Anzeige -> 11,948 V = 3,983 V/Zelle
  # 4,2 V ist voll. Der 80er-Deckel hat BAT0 also dauerhaft auf der
  # schlechtesten Lagerbedingung gehalten -- eine Ladeschwelle, die der Gauge
  # nie erreicht, ist keine.
  #
  # 70 % ist bfns bewusst vorsichtiger erster Schritt (15.09.2026). Ob er
  # reicht, entscheidet die Ruhespannung bei 70 %: liegt sie noch ueber etwa
  # 4,05 V/Zelle, muss der Deckel weiter runter. Laufzeit kostet das praktisch
  # nichts, BAT0 traegt real 4 Wh von insgesamt 28.
  perBattery = {
    BAT0 = { start = 65; end = 70; };
    BAT1 = { start = 75; end = 80; };
  };

  # Fuer alles, was nicht in der Tabelle steht (getauschter Akku unter neuem
  # Namen, anderes Geraet): der bisherige konservative Wert.
  fallback = { start = 75; end = 80; };

  caseArms = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: v: "    ${name}) start=${toString v.start}; end=${toString v.end} ;;")
    perBattery);

  summary = lib.concatStringsSep ", " (lib.mapAttrsToList
    (name: v: "${name} ${toString v.start}/${toString v.end} %")
    perBattery);

  setThresholds = pkgs.writeShellScript "battery-charge-thresholds" ''
    for bat in /sys/class/power_supply/BAT*; do
      [ -w "$bat/charge_control_end_threshold" ] || continue

      # Nur bash-Builtins, kein basename und kein cat: das Skript laeuft auch
      # aus udev, und dort ist auf PATH kein Verlass.
      case "''${bat##*/}" in
    ${caseArms}
        *) start=${toString fallback.start}; end=${toString fallback.end} ;;
      esac

      # REIHENFOLGE ZAEHLT, und sie haengt an der Richtung: der Treiber lehnt
      # jeden Schreibvorgang ab, der start < end kurzzeitig verletzen wuerde.
      # Beim Absenken muss deshalb start zuerst runter, beim Anheben end
      # zuerst hoch. Die feste Reihenfolge "erst start, dann end" aus der
      # ersten Fassung hat nur funktioniert, weil damals nur gesenkt wurde --
      # ein spaeteres Zurueck auf 80 waere still gescheitert.
      read -r cur_end < "$bat/charge_control_end_threshold" || cur_end=100

      if [ "$end" -ge "$cur_end" ]; then
        echo "$end" > "$bat/charge_control_end_threshold"
        if [ -w "$bat/charge_control_start_threshold" ]; then
          echo "$start" > "$bat/charge_control_start_threshold"
        fi
      else
        if [ -w "$bat/charge_control_start_threshold" ]; then
          echo "$start" > "$bat/charge_control_start_threshold"
        fi
        echo "$end" > "$bat/charge_control_end_threshold"
      fi
    done
  '';
in
{
  # 1. Beim Booten.
  systemd.services.battery-charge-thresholds = {
    description = "ThinkPad-Ladeschwellen setzen (${summary})";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = setThresholds;
    };
  };

  # 2. Nach Suspend/Hibernate. Die Werte liegen zwar im EC und ueberleben das
  #    normalerweise -- aber "normalerweise" ist bei Firmware kein Verlass, und
  #    ein zweiter Aufruf kostet nichts.
  #    powerManagement.enable steht per NixOS-Default auf true, resumeCommands
  #    greift also ohne weiteres Zutun (gegen 26.05 geprueft: der config-Block
  #    haengt an mkIf cfg.enable).
  powerManagement.resumeCommands = "${setThresholds}";

  # 3. Wenn ein Akku auftaucht -- der T480 hat einen fest verbauten (BAT0) und
  #    einen wechselbaren (BAT1). Wird der im Betrieb getauscht, kommt er mit
  #    den Werkseinstellungen und braucht die Schwellen neu.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="BAT[0-9]*", ACTION=="add", RUN+="${setThresholds}"
  '';
}
