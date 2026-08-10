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
  # start < end, sonst weist der Treiber den Wert zurueck.
  # Der Startwert ist kein Schmuck: ohne ihn beginnt der Akku bei jedem
  # Prozentpunkt unter dem Deckel wieder zu laden -- also genau das staendige
  # Nachladen, das die Schwelle verhindern soll.
  startPct = 75;
  endPct = 80;

  setThresholds = pkgs.writeShellScript "battery-charge-thresholds" ''
    for bat in /sys/class/power_supply/BAT*; do
      [ -w "$bat/charge_control_end_threshold" ] || continue

      # REIHENFOLGE ZAEHLT: erst start, dann end. Andersherum kann der Treiber
      # den Startwert ablehnen, weil er kurzzeitig ueber dem alten Endwert
      # laege.
      if [ -w "$bat/charge_control_start_threshold" ]; then
        echo ${toString startPct} > "$bat/charge_control_start_threshold"
      fi
      echo ${toString endPct} > "$bat/charge_control_end_threshold"
    done
  '';
in
{
  # 1. Beim Booten.
  systemd.services.battery-charge-thresholds = {
    description = "ThinkPad-Ladeschwellen auf ${toString startPct}/${toString endPct} % setzen";
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
