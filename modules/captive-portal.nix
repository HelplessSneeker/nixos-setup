# Captive-Portal-Login in fremden WLANs (Hotel, Cafe, Bahn, Flughafen).
#
# DAS PROBLEM (gemessen auf fabricus-itinerans am 19.08.2026):
#   /etc/resolv.conf enthaelt genau einen Resolver -- 100.100.100.100, also
#   tailscaled selbst. Tailscale setzt das per accept-dns (`CorpDNS: true`) auf
#   jedem Netz, in das die Kiste kommt.
#
#   Ein Captive Portal funktioniert aber ueber DNS-Hijacking: der Hotspot
#   beantwortet JEDE Namensauflösung mit der IP seiner Anmeldeseite. Wenn alle
#   Anfragen an tailscaled gehen, sieht der Hotspot sie nie -- also kommt kein
#   Redirect, also oeffnet sich nie eine Login-Seite. Der Browser laeuft
#   stattdessen in Timeouts. Genau das Symptom, das bfn beschreibt.
#
#   tailscaled ERKENNT das Portal uebrigens (netcheck: DetectCaptivePortal
#   laeuft alle paar Minuten im Journal), es gibt den DNS deswegen aber nicht
#   frei. Das muss man ihm sagen.
#
# DIE LOESUNG: `wifi-portal` schaltet accept-dns kurz ab, oeffnet die
# Anmeldeseite, wartet auf echtes Internet und schaltet zurueck. Kein
# `tailscale down` -- das reisst alle Verbindungen ab (auch meine SSH-Session
# als skitarii); accept-dns ist der chirurgische Schnitt.
{ config, pkgs, lib, ... }:
let
  wifiPortal = pkgs.writeShellApplication {
    name = "wifi-portal";
    runtimeInputs = [
      config.services.tailscale.package
      pkgs.curl
      pkgs.libnotify
    ];
    # firefox bewusst NICHT in runtimeInputs: der laeuft ueber home.packages und
    # traegt dort die Vimium-Policy (home/apps.nix). Ein zweiter, system-weiter
    # Firefox im PATH waere ein anderer Build ohne diese Policy.
    # writeShellApplication haengt runtimeInputs nur VOR $PATH, der User-PATH
    # bleibt -- `firefox` findet also den richtigen.
    text = ''
      # Apples Hotspot-Check: liefert im offenen Netz exakt "Success", hinter
      # einem Portal einen Redirect auf dessen Anmeldeseite. Bewusst http:// --
      # ueber https koennte kein Portal umleiten, ohne das Zertifikat zu brechen.
      CHECK_URL="http://captive.apple.com/hotspot-detect.html"

      online() {
        curl -sf -m 4 "$CHECK_URL" 2>/dev/null | grep -q "Success"
      }

      restore_dns() {
        tailscale set --accept-dns=true || true
      }

      if online; then
        notify-send "WLAN" "Internet laeuft bereits -- kein Portal-Login noetig."
        exit 0
      fi

      notify-send "WLAN-Portal" "Tailscale-DNS pausiert, oeffne die Anmeldeseite..."
      tailscale set --accept-dns=false

      # Ab hier MUSS der DNS zurueck, egal wie das Skript endet (Erfolg,
      # Ctrl-C, Fehler). Ohne das haengt die Kiste ohne MagicDNS im Netz und
      # niemand weiss warum.
      trap restore_dns EXIT INT TERM

      # Kurz warten, bis resolvconf die DHCP-Resolver zurueckgeschrieben hat.
      sleep 2

      # Die echte Portal-URL steht im Location-Header des Redirects. Faellt der
      # aus (manche Portale kapern erst beim zweiten Request), tut es neverssl:
      # eine Seite, die es bewusst nur ueber http gibt und die deshalb nie aus
      # dem HSTS-Cache oder von HTTPS-Only weggebogen wird.
      portal=$(curl -s -o /dev/null -w '%{redirect_url}' -m 6 "$CHECK_URL" || true)
      if [ -z "$portal" ]; then
        portal="http://neverssl.com"
      fi

      # Privates Fenster: ein normales Fenster wuerde die Portal-Domain aus dem
      # Cache oder per HSTS auf https umbiegen, und dann bricht der Login ab.
      firefox --private-window "$portal" &

      # Bis zu 5 Minuten auf den Login warten. Danach greift der trap ohnehin.
      for _ in $(seq 1 60); do
        if online; then
          notify-send "WLAN-Portal" "Angemeldet -- Tailscale-DNS ist wieder aktiv."
          exit 0
        fi
        sleep 5
      done

      notify-send -u critical "WLAN-Portal" \
        "Nach 5 Minuten kein Internet. Tailscale-DNS wird trotzdem zurueckgeschaltet."
    '';
  };
in
{
  environment.systemPackages = [ wifiPortal ];

  # `tailscale set` will sonst root. Der operator-Flag gibt genau diesem User
  # die Erlaubnis, tailscaled zu steuern -- ohne sudo-Prompt mitten im
  # Portal-Ablauf, und ohne dem Skript ein NOPASSWD-Recht zu schnitzen.
  #
  # extraSetFlags (nicht extraUpFlags): `up` laeuft nur beim allerersten
  # Verbinden, `set` bei jedem Start von tailscaled-autoconnect. Ein Flag in
  # extraUpFlags waere auf beiden Hosts hier schlicht nie angewendet worden.
  services.tailscale.extraSetFlags = [ "--operator=bfn" ];
}
