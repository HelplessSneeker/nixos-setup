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
      pkgs.coreutils # date -Is, tail, mkdir fuers Log
      pkgs.gnugrep
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
      LOG_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/wifi-portal.log"

      mkdir -p "$(dirname "$LOG_FILE")"
      # Log auf die letzten 200 Zeilen eindampfen, damit die Datei nicht
      # unbegrenzt waechst. Kein logrotate fuer 20 Zeilen pro Lauf.
      if [ -f "$LOG_FILE" ]; then
        tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
      fi

      log() {
        printf '%s  %s\n' "$(date -Is)" "$*" >> "$LOG_FILE"
      }

      # Benachrichtigung ist Beiwerk, die DNS-Logik ist der Zweck. Ohne diesen
      # Wrapper reisst ein fehlschlagendes notify-send via `set -e` das ganze
      # Skript mit -- gefunden am 19.08.2026 beim Testlauf ohne Desktop-Session
      # ("GDBus.Error ... The name is not activatable"). Derselbe Fall trifft
      # jede Session, in der gerade kein Notification-Daemon laeuft.
      notify() {
        notify-send "$@" 2>/dev/null || log "notify-send nicht erreichbar: $*"
      }

      # --ipv4 ist kein Detail, sondern der Fix vom 19.08.2026: der erste
      # Versuch dieses Skripts meldete faelschlich "Portal", weil das WLAN in
      # genau dem Moment IPv6-Adressen dazubekam (tailscaled-Journal:
      # "LinkChange: major ... HaveV6: false->true"). Happy Eyeballs lief in die
      # halb-fertige v6-Route, curl timeoutete, das Skript schloss auf ein
      # Portal. Captive-Portal-Erkennung ist ohnehin ein v4-Thema.
      online() {
        curl -sf --ipv4 -m 6 "$CHECK_URL" 2>/dev/null | grep -q "Success"
      }

      # Ein einzelner Fehlschlag ist noch kein Portal -- meistens ist es ein
      # Interface, das gerade umkonfiguriert wird. Erst drei Fehlschlaege in
      # Folge gelten.
      online_stable() {
        for _ in 1 2 3; do
          if online; then
            return 0
          fi
          sleep 2
        done
        return 1
      }

      # Steht ein Resolver in resolv.conf, der NICHT tailscaled ist? Genau das
      # ist die Bedingung dafuer, dass ein Portal seinen DNS-Hijack ueberhaupt
      # ausliefern kann.
      has_local_resolver() {
        grep -E '^nameserver' /etc/resolv.conf 2>/dev/null \
          | grep -qvE '100\.100\.100\.100|fd7a:115c:a1e0::53'
      }

      restore_dns() {
        tailscale set --accept-dns=true || true
        log "accept-dns zurueck auf true"
      }

      log "--- Start"

      if online_stable; then
        log "Internet laeuft -- kein Portal-Login noetig, Abbruch"
        notify "WLAN" "Internet laeuft bereits -- kein Portal-Login noetig."
        exit 0
      fi

      log "kein Internet nach 3 Versuchen -> Portal vermutet"
      notify "WLAN-Portal" "Tailscale-DNS pausiert, oeffne die Anmeldeseite..."
      tailscale set --accept-dns=false

      # Ab hier MUSS der DNS zurueck, egal wie das Skript endet (Erfolg,
      # Ctrl-C, Fehler). Ohne das haengt die Kiste ohne MagicDNS im Netz und
      # niemand weiss warum.
      trap restore_dns EXIT INT TERM

      # NICHT blind schlafen. Der erste Entwurf hatte hier `sleep 2` und hat
      # Firefox losgeschickt, bevor resolvconf die DHCP-Resolver zurueck hatte
      # -- der Browser zeigte dann eine DNS-Fehlerseite und laedt die von
      # selbst nie neu. Also warten, bis der Resolver wirklich steht.
      dns_ok=0
      for _ in $(seq 1 20); do
        if has_local_resolver; then
          dns_ok=1
          break
        fi
        sleep 1
      done

      if [ "$dns_ok" -eq 0 ]; then
        log "FEHLER: nach 20s kein lokaler Resolver in /etc/resolv.conf"
        notify -u critical "WLAN-Portal" \
          "Der lokale DNS kam nicht zurueck. Abbruch, Tailscale-DNS bleibt aktiv."
        exit 1
      fi
      log "lokaler Resolver da: $(grep -E '^nameserver' /etc/resolv.conf | tr '\n' ' ')"

      # Die echte Portal-URL steht im Location-Header des Redirects.
      #
      # Faellt der aus, wird BEWUSST dieselbe CHECK_URL geoeffnet und nicht
      # neverssl.com: der Hotspot hat genau diese Adresse eben noch abgefangen,
      # sie ist also der zuverlaessigste Weg in sein Portal. neverssl.com stand
      # hier im ersten Entwurf und setzt zusaetzlich voraus, dass eine fremde
      # Domain aufgeloest wird -- ein Schritt mehr, der schiefgehen kann.
      portal=$(curl -s --ipv4 -o /dev/null -w '%{redirect_url}' -m 6 "$CHECK_URL" || true)
      if [ -z "$portal" ]; then
        portal="$CHECK_URL"
        log "kein Redirect erkannt, oeffne CHECK_URL direkt"
      else
        log "Portal-URL aus Redirect: $portal"
      fi

      # Privates Fenster: ein normales Fenster wuerde die Portal-Domain aus dem
      # Cache oder per HSTS auf https umbiegen, und dann bricht der Login ab.
      firefox --private-window "$portal" &

      # Bis zu 5 Minuten auf den Login warten. Danach greift der trap ohnehin.
      for _ in $(seq 1 60); do
        if online; then
          log "Login erkannt, Internet steht"
          notify "WLAN-Portal" "Angemeldet -- Tailscale-DNS ist wieder aktiv."
          exit 0
        fi
        sleep 5
      done

      log "Timeout: nach 5 Minuten kein Internet"
      notify -u critical "WLAN-Portal" \
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
