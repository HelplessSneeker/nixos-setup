# SSH-Haertung. Shared: gilt fuer jeden Host im Modul-Stack.
#
# Ausgangslage vor 07.08.2026 (auf fabricus vorgefunden):
#   - `services.openssh.enable = true` zieht `openFirewall = true` nach sich
#     -> Port 22 global offen, also auch auf eno1 (LAN 192.168.0.60)
#   - PasswordAuthentication + KbdInteractiveAuthentication standen auf `yes`
#   => jedes Geraet im Heimnetz konnte Passwoerter gegen bfn durchprobieren.
{ lib, config, ... }:
{
  # --- 1. Keine LAN-Exposition -----------------------------------------------
  # tailscale0 ist in modules/tailscale.nix bereits `trustedInterface` (= alle
  # Ports frei). Port 22 muss deshalb NICHT global geoeffnet werden -- SSH ueber
  # das Tailnet laeuft weiter, vom LAN aus ist dicht.
  # Preis: bei totem Tailscale kein SSH. Auf einem Desktop, vor dem man sitzt,
  # ist das der richtige Tausch; auf einem Remote-Host waere es einer zu viel.
  services.openssh.openFirewall = false;

  # --- 2. Nur Keys, keine Passwoerter ----------------------------------------
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # --- 3. Keys nur noch deklarativ -------------------------------------------
  # sshd las bisher BEIDE Pfade: %h/.ssh/authorized_keys und
  # /etc/ssh/authorized_keys.d/%u. Genau daran ist am 07.08.2026 die
  # Zugangstrennung fast gescheitert -- der Agent-Key lag doppelt, und das
  # Entfernen des deklarativen Eintrags liess die handgelegte Kopie offen.
  #
  # mkForce ist noetig, KEIN Schmuck: die NixOS-Option ist eine Liste und
  # sshd.nix setzt die Defaults im config-Block. Ohne mkForce wuerde unser Wert
  # nur ANGEHAENGT -- der Home-Pfad bliebe aktiv und die Aenderung waere
  # wirkungslos, ohne dass irgendwas warnt.
  services.openssh.authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];

  # Serverseitige Beschraenkung des Agent-Accounts. Dieselben Optionen stehen
  # zwar schon in der authorized_keys-Zeile (modules/agent-user.nix), aber nur
  # dort -- driftet die Datei, sind sie weg. Der Match-Block gilt unabhaengig
  # davon. Zwei Schlösser, ein Schlüsselbund.
  #
  # ACHTUNG beim Erweitern: alles nach `Match` gilt NUR fuer diesen Block.
  # Kuenftige extraConfig-Zeilen gehoeren VOR den Match-Block, sonst landen sie
  # unbemerkt in der skitarii-Regel. Deshalb steht Match hier bewusst zuletzt.
  services.openssh.extraConfig = ''
    Match User skitarii
      AllowTcpForwarding no
      AllowAgentForwarding no
      PermitTunnel no
      X11Forwarding no
  '';

  # --- 4. Nix-Daemon nicht fuer jeden ----------------------------------------
  # Stand vorher auf `*`: der Agent konnte beliebige Derivations bauen und in
  # den Store ziehen. Kein root (trusted-users bleibt korrekt nur root), aber
  # CPU, Plattenplatz und fremder Code im Store ohne Not.
  nix.settings.allowed-users = [ "bfn" "root" ];
}
