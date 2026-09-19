# Tailscale — kanonischer "Modern Setup" nach NixOS-Wiki (nftables-nativ).
# Shared: von jedem Host importierbar (fabricus jetzt, laptop spaeter).
#
# Loest das rx=0 / einweg-Problem vom 21.07.2026:
#  - allowedUDPPorts  -> laesst eingehendes Tailscale-UDP am WAN-Interface rein
#  - nftables-nativ    -> tailscale setzt seine eigenen Firewall-Regeln sauber
#  - checkReversePath  -> rpfilter droppt sonst Wireguard-Inbound
{ config, pkgs, lib, ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ config.services.tailscale.interfaceName ]; # tailscale0
    allowedUDPPorts   = [ config.services.tailscale.port ];          # 41641
    checkReversePath  = "loose";
  };

  # tailscaled zwingen, nftables direkt zu nutzen (iptables-compat-Bruch vermeiden)
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # --- Tailscale SSH ---------------------------------------------------------
  # tailscaled faengt Port 22 auf dem Tailnet-Interface ab und authentifiziert
  # ueber die Tailnet-Identitaet statt ueber sshd und authorized_keys. Damit
  # entscheidet die SSH-Policy der Tailnet-ACL, wer herein darf -- inklusive
  # `check` (Browser-Bestaetigung durch bfn), das auf cogitator-prime und
  # personal-server schon so laeuft.
  #
  # bfn hat das am 19.09.2026 um 15:01 imperativ gesetzt
  # (journal: `EditPrefs: MaskedPrefs{RunSSH=true}`). Hier deklarativ
  # nachgezogen, aus zwei Gruenden: fabricus-itinerans bekaeme es sonst nie,
  # und ein Prefs-Reset (neuer State, `tailscale up` mit anderen Flags) nimmt
  # es still wieder weg -- zusammen mit dem geloeschten Agent-Key waere das
  # ein Totalausfall des Zugangs statt eines Downgrades.
  #
  # extraSetFlags, nicht extraUpFlags: `up` laeuft nur beim allerersten
  # Verbinden. Begruendung steht ausfuehrlich in modules/captive-portal.nix,
  # das dort `--operator=bfn` setzt. NixOS fuehrt die Listen beider Module
  # zusammen -- tailscaled-set.service ruft am Ende
  # `tailscale set --operator=bfn --ssh` auf.
  services.tailscale.extraSetFlags = [ "--ssh" ];
}
