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
}
