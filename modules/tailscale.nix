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
    # Tailworm (25.10.2026): Ueber SSH-Forwarding auf Unix-Sockets kommt eine
    # ganz normale Tailscale-SSH-Sitzung an root (docker.sock liegt hier).
    # Bis der gepatchte Client laeuft, ist Forwarding aus, so empfiehlt es
    # Tailscale selbst (tailscale.com/ssh-investigation-update). Kostet
    # `ssh -L` und `ssh -J` ueber diesen Rechner, also auch primus -> lfcs-lab.
    # nixos-26.05 hat noch 1.98.10; der Patch kommt wohl nur ueber unstable.
    "TS_SSH_DISABLE_FORWARDING=1"
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

  # --- Coolify-Dashboard nur uebers Tailnet ----------------------------------
  # Seit 23.10.2026 (php2shell-Nacharbeit) beantwortet coolify.bfnoessler.at aus
  # dem Internet nur noch /webhooks/ (GitHub-Deploys), alles andere gibt 403.
  # Der Filter sitzt in Traefik auf personal-server
  # (/data/coolify/proxy/dynamic/coolify-tailnet-only.yaml) und laesst das
  # Tailnet durch. Dieser Eintrag schickt den Namen auf diesen Rechnern direkt
  # an personal-servers Tailnet-IP: gleiche Adresse, gleiches Zertifikat,
  # Echtzeit-Logs und Terminal wie bisher. Ohne Tailscale ist das Dashboard
  # dann nicht erreichbar, das ist Absicht. Geraete ohne Eintrag (Handy):
  # http://personal-server:8000. Aendert sich die Tailnet-IP von
  # personal-server, hier nachziehen.
  networking.hosts."100.116.251.104" = [ "coolify.bfnoessler.at" ];
}
