# Docker ohne root (Rootless Docker) statt des System-Daemons.
# Shared: gilt fuer jeden Host, der diesen Modul-Stack bekommt.
#
# ANLASS (28.10.2026, Antivirus-Frage): bfn war in der Gruppe `docker`, und die
# ist root ohne Passwort -- `docker run -v /:/host ...` mountet das ganze
# Dateisystem, und das darf jedes Programm unter bfns Konto, auch ein
# boesartiges npm-Paket im postinstall. Rootless laeuft der Daemon als bfn;
# root im Container ist auf dem Host bfn, mehr nicht.
#
# Zweiter Gewinn: Der System-Daemon traegt fuer jedes `ports:` eigene
# iptables-Regeln ein, an denen die NixOS-Firewall vorbeischaut (DNAT, dann
# FORWARD, und die nixos-fw filtert nur input). Ein `ports: - '5432'` wie in
# n-track und jobradar stand damit aus dem LAN offen (Postgres, Passwort
# "secret"), am Laptop in jedem fremden WLAN, solange der Container lief.
# Rootless lauscht rootlesskit als normaler Prozess, und die Firewall aus
# modules/tailscale.nix greift: von aussen nur das Tailnet, lokal wie gehabt.
#
# Was sich aendert:
#   - Images, Container und Volumes liegen unter ~/.local/share/docker statt
#     /var/lib/docker. Der alte Bestand bleibt dort liegen, rootless sieht ihn
#     nicht. Fuer n-track und jobradar egal, Flyway legt das Schema neu an.
#   - Der Daemon ist ein User-Dienst (`systemctl --user status docker`) und
#     laeuft nur, solange bfn angemeldet ist.
#   - DOCKER_HOST setzt setSocketVariable auf $XDG_RUNTIME_DIR/docker.sock,
#     ueber /etc/profile, also erst in einer NEUEN Sitzung. Nach dem ersten
#     Rebuild damit einmal neu starten, dann stimmen auch die Gruppen.
#   - Ports unter 1024 kann ein Container nicht auf den Host legen.
#   - Die 65536 Sub-UIDs fuer die Container vergibt NixOS fuer normale User
#     von selbst (autoSubUidGidRange), newuidmap kommt als setuid-Wrapper aus
#     programs/shadow.nix. Beides am 28.10.2026 im gepinnten 26.05 nachgesehen.
{ lib, ... }:
{
  # Explizit aus statt nur weggelassen: Setzt ein Host es wieder auf true,
  # bricht die Evaluation mit "conflicting definition values" ab. Zurueck zum
  # System-Daemon also nur bewusst, und zwar hier.
  virtualisation.docker.enable = false;

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # Upstream startet den Dienst fuer jeden User ausser root (ConditionUser =
  # "!root"), also auch fuer den Agent-Account skitarii bei jeder SSH-Sitzung.
  # Der soll keine Container starten koennen (modules/agent-user.nix), also
  # nur fuer bfn.
  systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "bfn";
}
