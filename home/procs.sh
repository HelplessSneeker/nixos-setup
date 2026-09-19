#!/usr/bin/env bash
# `procs` -- einmalige Prozess- und Lastuebersicht der LOKALEN Maschine.
#
# Ausschliesslich lesend: kein einziger mutierender Befehl, kein sudo, kein
# Netzwerkzugriff. Darf jederzeit blind ausgefuehrt werden.
#
# Das Ausgabeformat ist absichtlich identisch zum /procs-Skill auf primus --
# die Ausgabe kann 1:1 in den Chat gepastet werden, Skitarii liest sie dann
# ohne Ruecksetzen.
#
# Aufruf:  procs [-n N] [--short]
#   -n N      Laenge der Top-Listen (default 8)
#   --short   ohne nvidia-smi, ohne docker stats, ohne Portliste

set -o pipefail

TOP_N=8
MODE=full

usage() {
  cat <<'EOF'
procs -- Prozess-/Lastuebersicht dieser Maschine (rein lesend)

  procs              volle Uebersicht, Top 8
  procs -n 15        laengere Top-Listen
  procs --short      ohne GPU, docker stats und Ports (schneller)

Abschnitte: HOST, NIX, MEMORY, DISK, TOP CPU, TOP RAM, [HAENGENDE PROZESSE],
SYSTEMD, [GPU], [DOCKER], [LISTEN].
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n)        TOP_N="${2:-8}"; shift 2 ;;
    -n*)       TOP_N="${1#-n}"; shift ;;
    -s|--short) MODE=short; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         printf 'procs: unbekanntes Argument "%s"\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$TOP_N" in
  ''|*[!0-9]*) printf 'procs: -n braucht eine Zahl\n' >&2; exit 2 ;;
esac

r()  { timeout 8 "$@" 2>/dev/null; }
hr() { printf '\n## %s\n' "$1"; }

# Selbst rechnen statt `uptime -p`: das `uptime` im NixOS-26.05-System-Profil
# kennt `-p` nicht ("invalid option -- 'p'", geprueft 19.09.2026 auf fabricus)
# und lieferte damit still eine leere Zeile.
uptime_h() {
  awk '{s=int($1); d=int(s/86400); h=int(s%86400/3600); m=int(s%3600/60);
        if (d) printf "%dd %dh %dm", d, h, m; else if (h) printf "%dh %dm", h, m;
        else printf "%dm", m}' /proc/uptime
}

# ---------------------------------------------------------------- Host ------
os_name=$( . /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unbekannt}" )
n_total=$(find /proc -maxdepth 1 -regex '/proc/[0-9]+' 2>/dev/null | wc -l)
n_zombie=$(ps -eo stat= 2>/dev/null | grep -c '^Z')
n_dstate=$(ps -eo stat= 2>/dev/null | grep -c '^D')

printf '## HOST\n'
printf 'host:    %s\n' "$(hostname)"
printf 'user:    %s (%s)\n' "$(id -un)" "$(id -nG 2>/dev/null | tr ' ' ',')"
printf 'os:      %s / kernel %s\n' "$os_name" "$(uname -r)"
printf 'uptime:  %s\n' "$(uptime_h)"
printf 'load:    %s  (cores: %s)\n' "$(cut -d' ' -f1-3 /proc/loadavg)" "$(nproc 2>/dev/null)"
printf 'procs:   %s gesamt, %s zombie, %s uninterruptible(D)\n' "$n_total" "$n_zombie" "$n_dstate"

# ----------------------------------------------------------------- Nix ------
# Auf NixOS ist "warum ist die Kiste gerade langsam" ueberdurchschnittlich oft
# ein laufender Build. Generation + Aktivierungszeitpunkt beantworten ausserdem
# "seit wann ist das so" ohne Umweg ueber das Journal.
hr NIX
if [ -e /nix/var/nix/profiles/system ]; then
  gen_link=$(readlink /nix/var/nix/profiles/system 2>/dev/null)   # system-52-link
  gen=${gen_link#system-}; gen=${gen%-link}
  printf 'generation:  %s\n' "${gen:-?}"
  printf 'aktiviert:   %s\n' "$(stat -c %y /nix/var/nix/profiles/system 2>/dev/null | cut -d. -f1)"
fi
command -v nixos-version >/dev/null 2>&1 && printf 'nixos:       %s\n' "$(r nixos-version)"
n_build=$(pgrep -c -f 'nix-daemon.*worker|nix-build|nixos-rebuild' 2>/dev/null || true)
if [ "${n_build:-0}" -gt 0 ]; then
  printf 'BUILD LAEUFT: %s Prozess(e) --\n' "$n_build"
  r pgrep -a -f 'nix-daemon.*worker|nix-build|nixos-rebuild' | head -5 | cut -c1-150
else
  printf 'build:       kein nix-Build aktiv\n'
fi

# -------------------------------------------------------------- Memory ------
hr MEMORY
free -h 2>/dev/null | sed -n '1,3p'

# ---------------------------------------------------------------- Disk ------
hr DISK
df -h -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay 2>/dev/null | head -10

# ------------------------------------------------------------ Prozesse ------
PS_FMT='pid,user:10,pcpu,pmem,rss,etime,args'

# CPU kommt aus `top`, nicht aus `ps`: ps-%CPU ist der Mittelwert ueber die
# gesamte Lebenszeit eines Prozesses. Frisch gestartete Prozesse stehen darin
# mit ~100 % ganz oben und verdraengen echte Last. tops zweiter Durchlauf misst
# ein echtes Intervall.
hr "TOP ${TOP_N} CPU (Intervallmessung)"
if command -v top >/dev/null 2>&1; then
  timeout 15 top -b -n 2 -d 0.7 -c -w 200 2>/dev/null \
    | awk '/^ *PID +USER/{c++} c==2' | head -n "$((TOP_N + 1))" | cut -c1-150
else
  ps -eo "$PS_FMT" --sort=-pcpu 2>/dev/null | head -n "$((TOP_N + 1))" | cut -c1-150
fi

hr "TOP ${TOP_N} RAM (rss in KB)"
ps -eo "$PS_FMT" --sort=-rss 2>/dev/null | head -n "$((TOP_N + 1))" | cut -c1-150

if [ "${n_zombie:-0}" -gt 0 ] || [ "${n_dstate:-0}" -gt 0 ]; then
  hr "HAENGENDE PROZESSE (Z/D)"
  ps -eo pid,ppid,stat,etime,args 2>/dev/null | awk 'NR==1 || $3 ~ /^[ZD]/' | head -15 | cut -c1-150
fi

# ------------------------------------------------------------- systemd ------
# Auf dem Desktop sind die USER-Units die interessanteren: Hyprland-Portals,
# pipewire, noctalia haengen dort, nicht im System-Manager.
hr SYSTEMD
if command -v systemctl >/dev/null 2>&1; then
  failed_sys=$(r systemctl --failed --no-legend --plain | grep -c .)
  printf 'failed (system): %s\n' "${failed_sys:-?}"
  [ "${failed_sys:-0}" -gt 0 ] && r systemctl --failed --no-legend --plain | head -10
  failed_usr=$(r systemctl --user --failed --no-legend --plain | grep -c .)
  printf 'failed (user):   %s\n' "${failed_usr:-?}"
  [ "${failed_usr:-0}" -gt 0 ] && r systemctl --user --failed --no-legend --plain | head -10
else
  printf 'kein systemd\n'
fi

# ----------------------------------------------------------------- GPU ------
if [ "$MODE" = full ] && command -v nvidia-smi >/dev/null 2>&1; then
  hr GPU
  r nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
    --format=csv,noheader | head -4
  gpu_apps=$(r nvidia-smi --query-compute-apps=pid,process_name,used_memory \
    --format=csv,noheader | head -8)
  if [ -n "$gpu_apps" ]; then
    printf -- '-- compute/graphics apps --\n%s\n' "$gpu_apps"
  fi
fi

# -------------------------------------------------------------- Docker ------
hr DOCKER
if ! command -v docker >/dev/null 2>&1; then
  printf 'kein docker auf diesem Host\n'
elif ! r docker info >/dev/null; then
  printf 'docker installiert, Daemon fuer %s NICHT erreichbar (keine docker-Gruppe / socket denied)\n' "$(id -un)"
else
  n_run=$(r docker ps -q | grep -c .)
  n_all=$(r docker ps -aq | grep -c .)
  printf 'container: %s laufend / %s gesamt\n' "$n_run" "$n_all"
  r docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}' | head -40
  if [ "$MODE" = full ] && [ "${n_run:-0}" -gt 0 ]; then
    printf -- '-- stats (CPU/MEM) --\n'
    timeout 25 docker stats --no-stream \
      --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>/dev/null | head -40
  fi
fi

# --------------------------------------------------------------- Ports ------
if [ "$MODE" = full ]; then
  hr "LISTEN (tcp)"
  r ss -tlnH | awk '{print $4}' | sort -u | head -25
fi
