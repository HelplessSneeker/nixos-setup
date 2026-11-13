# Hyprland-WM-Config (home-manager). Shared -> fabricus jetzt, laptop spaeter.
# Catppuccin Mocha, clean & ruhig: dezente Gaps, keine Fenster-Transparenz,
# kurze/snappy Animationen. Bindings sind ein frischer Aufbau (nicht 1:1 aus den
# alten dotfiles portiert), aber vim-HJKL + 10 Workspaces bleiben.
{ config, pkgs, lib, osConfig, ... }:

# Der Monitor-Block wohnt seit 12.08.2026 NICHT mehr hier, sondern je Host in
# hosts/<host>/monitors.nix -- die beiden Faelle haben gegensaetzliche
# Anforderungen (Desktop statisch, Laptop je nach Dock/Beamer) und teilen sich
# keine einzige Zeile mehr. Eingebunden wird das ueber require("monitors")
# weiter unten (seit 01.11.2026 Lua, vorher `source`).
# Die isLaptop-Weiche bleibt, sie traegt noch die Trackpad-Gesten.
let
  isLaptop = osConfig.networking.hostName == "fabricus-itinerans";

  # Blur-Durchgaenge je Host (Optik-Runde 01.11.2026): die UHD 620 am Laptop
  # bekommt einen weniger als die RTX 2060 am Desktop.
  blurPasses = if isLaptop then 2 else 3;

  # Ablage fuer Screenshots (bfn 07.09.2026). grimblast legt das Verzeichnis
  # NICHT selbst an -- es baut den Dateinamen als "$DEFAULT_TARGET_DIR/<datum>.png"
  # und laesst grim darauf los; fehlt der Ordner, scheitert der Schuss.
  # Deshalb weiter unten die home.activation.
  screenshotDir = "${config.home.homeDirectory}/Pictures/screenshots";

  # SUPER+Return: neues Terminal im Verzeichnis des fokussierten kitty (bfn
  # 15.10.2026). Kein Widerspruch zur lazygit-Lehre in home/fish.nix -- dort
  # holte sich ein Bind den Kontext aus einer Notizdatei (Vermutung), hier ist
  # er das fokussierte Fenster selbst: dessen Shell-Prozess und /proc/<pid>/cwd.
  # Jeder kitty-Start ist ein eigener Prozess (kein --single-instance), die pid
  # aus hyprctl gehoert also genau zu diesem Fenster; sein Kind (ausser kittys
  # eigenen kitten-Helfern) ist fish. Laeuft in fish gerade nvim o.ae., zaehlt trotzdem fishs cwd. Ist kein
  # kitty fokussiert oder das Verzeichnis weg -> normales Terminal im Home.
  # hyprctl bewusst aus dem PATH: muss zur laufenden Hyprland-Version passen.
  terminalHere = pkgs.writeShellScript "terminal-here" ''
    dir=""
    pid=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r 'select(.class == "kitty") | .pid')
    if [ -n "$pid" ]; then
      # Nicht einfach `pgrep -n -P`: kitty startet neben der Shell eigene
      # Helfer (`kitten __atexit__`, `kitten __watch_conf__`), und der juengste
      # davon ist der Watcher -- dessen cwd ist immer das Startverzeichnis
      # (gemessen 15.10.2026, erster Versuch landete deshalb stets im Home).
      child=$(${pkgs.procps}/bin/ps -o pid=,comm= --ppid "$pid" \
        | ${pkgs.gawk}/bin/awk '$2 != "kitten" { p = $1 } END { print p }')
      [ -n "$child" ] && dir=$(${pkgs.coreutils}/bin/readlink "/proc/$child/cwd")
    fi
    if [ -n "$dir" ] && [ -d "$dir" ]; then
      exec kitty --directory "$dir"
    fi
    exec kitty
  '';

  # Trackpad-Gesten -- nur der Laptop hat ueberhaupt ein Trackpad.
  #
  # Seit 01.11.2026 Lua (hl.gesture), Felder laut hl.meta.lua aus dem
  # 0.57-Paket: fingers, direction, action (+ mods, scale, ...). Richtungen
  # wie zuvor left/right/up/down/horizontal/vertical/swipe/pinch.
  #
  # `horizontal` deckt BEIDE Richtungen ab -- absichtlich keine zwei Gesten
  # fuer left und right: die zweite wuerde von der ersten ueberschattet
  # (so lehnte es der .conf-Parser bis 0.56 ab).
  gestureBlock =
    if isLaptop then ''

      -- 3 Finger horizontal = Workspace wechseln (kontinuierlich, mit Animation).
      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    '' else "";

  # Monitor-Anordnung als GUI -- nur am Laptop, weil nur dort die Schirme
  # wechseln. Der Desktop erzeugt sein Layout weiter deklarativ und koennte
  # seine monitors.conf gar nicht ueberschreiben (read-only Store-Symlink).
  #
  # Warum ein Werkzeug statt einer Regel: die Connector-Namen aendern sich mit
  # Dock und Kabelport, und bfns beide externen Schirme sind ueber die EDID
  # nicht unterscheidbar (gleicher Hersteller-/Modellstring "BK550Y"). Damit
  # gibt es kein stabiles Merkmal, an dem eine Config die Reihenfolge vorab
  # festmachen koennte. Die lange Begruendung steht in
  # hosts/fabricus-itinerans/monitors.nix, die auch das Paket installiert.
  #
  # nwg-displays schreibt sein Ergebnis seit 0.4.3 zusaetzlich als
  # ~/.config/hypr/monitors.lua (neben der alten monitors.conf) -- genau das
  # Modul, das die hyprland.lua weiter unten per require("monitors") laedt.
  # 26.05 hat 0.4.3, passt also.
  monitorToolBind =
    if isLaptop then ''
      hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("nwg-displays"), { description = "Monitore anordnen (Drag-and-drop, dann Apply)" })
    '' else "";

  # Startinhalt fuer ~/.config/hypr/monitors.lua am Laptop, siehe
  # home.activation.seedMonitorsLua weiter unten. Wird nur benutzt, wenn die
  # Datei fehlt -- nwg-displays ueberschreibt sie beim ersten "Apply".
  monitorsSeed = pkgs.writeText "monitors-seed.lua" ''
    -- Notnagel-Layout, angelegt von home/hyprland.nix beim ersten Start.
    -- Ab dem ersten "Apply" in nwg-displays (SUPER+SHIFT+M) gehoert diese
    -- Datei dem Werkzeug -- hier steht dann nichts davon mehr drin.
    --
    -- Bewusst ohne Connector-Namen fuer die externen Schirme: die aendern
    -- sich am Laptop mit Dock und Kabelport. auto-right haengt jeden
    -- unbekannten Schirm deterministisch rechts an, damit kann nichts
    -- uebereinander landen.
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
    hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = 1 })
  '';

  # Aufpasser fuer noctalia (30.09.2026). noctalia ist Bar UND Sperrbildschirm.
  # Stirbt es, waehrend die Session gesperrt ist, bleibt Hyprland absichtlich
  # gesperrt -- ohne Oberflaeche zum Entsperren, nur tty2 + Reboot halfen.
  # Passiert am 30.09. um 09:56: Deckel zu und Dock ab in derselben Sekunde,
  # die Outputs verschwinden mitten im Lock-Aufbau, noctalia 5.0.0 steigt mit
  # `invalid object 62` / `fatal: failed to dispatch pending Wayland events` aus.
  #
  # Die Schleife startet noctalia neu, solange der Compositor lebt. Nach einem
  # Absturz (rc != 0) sperrt sie sofort wieder: nur so uebernimmt der neue
  # Prozess eine verwaiste Sperre. SUPER ALT+N schickt SIGTERM, das faengt
  # noctalia ab und endet mit rc 0 (gemessen 30.09.2026, nicht 143 wie zuerst
  # angenommen) -- dieser Weg sperrt also nicht. Die Uebernahme braucht
  # misc:allow_session_lock_restore. Nebenwirkung: auch ein Absturz
  # im entsperrten Zustand endet mit Sperrbildschirm -- bewusst, lieber einmal
  # zu viel entsperren als eine offene Session.
  #
  # Keine systemd-User-Unit, Begruendung beim Autostart unten. Bremse: mehr als
  # 5 Neustarts in 60 s -> aufgeben, damit ein kaputtes noctalia nicht im
  # Sekundentakt das Journal flutet.
  noctaliaSupervisor = pkgs.writeShellScript "noctalia-supervisor" ''
    restarts=0
    window_start=$(${pkgs.coreutils}/bin/date +%s)
    while :; do
      ${pkgs.systemd}/bin/systemd-cat -t noctalia noctalia
      rc=$?
      # Compositor weg (Logout/Shutdown) -> nicht neu starten.
      [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || exit 0

      now=$(${pkgs.coreutils}/bin/date +%s)
      if [ $((now - window_start)) -gt 60 ]; then
        window_start=$now
        restarts=0
      fi
      restarts=$((restarts + 1))
      if [ "$restarts" -gt 5 ]; then
        echo "noctalia: $restarts Neustarts in 60 s, gebe auf (rc=$rc)" \
          | ${pkgs.systemd}/bin/systemd-cat -t noctalia -p err
        exit 1
      fi
      echo "noctalia beendet (rc=$rc), starte neu" \
        | ${pkgs.systemd}/bin/systemd-cat -t noctalia -p warning
      sleep 1

      if [ "$rc" -ne 0 ]; then
        # Sperre erst absetzen, wenn der neue Prozess die IPC bedient.
        (
          for _ in $(${pkgs.coreutils}/bin/seq 20); do
            sleep 0.5
            noctalia msg session lock >/dev/null 2>&1 && exit 0
          done
          echo "noctalia: Wiedersperren nach Absturz gescheitert" \
            | ${pkgs.systemd}/bin/systemd-cat -t noctalia -p err
        ) &
      fi
    done
  '';

  # Kommentarzeilen fliegen beim Bauen aus der hyprland.lua (seit 09.10.2026,
  # damals noch fuer die .conf). Grund ist das keybind-cheatsheet-Plugin: es
  # liest die Datei beim noctalia-Start in EINEM Luau-Aufruf mit 100 ms
  # CPU-Budget ('chunk', luau_host.cpp). Mit ~275 Kommentarzeilen riss es das
  # Budget bei jedem Start seit mindestens 21.09. (Journal: "exceeded its CPU
  # budget"), und das Panel zeigte still den Cache vom letzten Erfolg.
  # Im Lua-Modus holt das Plugin die Binds live per `hyprctl binds -j` und
  # scannt die Datei nur noch nach Kategorien und `description`-Feldern --
  # weniger Arbeit, aber dieselbe Budget-Falle, also bleibt das Strippen.
  #
  # Ausnahme: Zeilen der Form `-- 1. Name` bleiben stehen. Genau daraus baut
  # das Plugin im Lua-Modus seine Kategorien (README des Plugins). Deshalb
  # gilt umgekehrt: kein Doku-Kommentar in der Lua-Config darf mit
  # `-- <Zahl>. ` anfangen, sonst wird er zur Kategorie.
  # Die Kommentare bleiben HIER die Doku; die erzeugte Datei liest niemand.
  stripComments = text: lib.concatStringsSep "\n"
    (builtins.filter
      (l: builtins.match "[[:space:]]*--.*" l == null
        || builtins.match "[[:space:]]*-- [0-9]+\\. .*" l != null)
      (lib.splitString "\n" text));
in
{
  # Screenshot-Ordner anlegen. Bewusst NICHT ueber xdg.userDirs: das Modul
  # schreibt ~/.config/user-dirs.dirs komplett neu (Store-Symlink, read-only)
  # und wuerde bestehende Eintraege dieser Datei ueberschreiben.
  home.activation.screenshotDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg screenshotDir}
  '';

  # monitors.lua anlegen, falls sie fehlt -- NUR am Laptop, wo nwg-displays
  # die Datei besitzt und home-manager sie deshalb nicht mehr erzeugt.
  #
  # Ein Fehler ist das Fehlen seit der Lua-Config nicht mehr: hyprland.lua
  # laedt das Modul per pcall (siehe dort), anders als das `source` der
  # .conf, das bei fehlender Datei als "source= globbing error" rot im Bild
  # stand (21.09.2026). Ohne Datei faehrt Hyprland aber alle Schirme mit
  # seinen Defaults hoch, und die koennen am Dock uebereinander liegen --
  # deshalb trotzdem der Notnagel. Die alte monitors.conf von nwg-displays
  # bleibt liegen und wird nicht mehr gelesen; der erste "Apply" nach dem
  # Umstieg schreibt beide neu.
  #
  # Der Inhalt hier ist bewusst nur ein Notnagel fuer den allerersten Start:
  # internes Panel links, alles andere deterministisch rechts angehaengt, keine
  # Connector-Namen. Sobald bfn einmal SUPER+SHIFT+M drueckt und "Apply"
  # klickt, ueberschreibt nwg-displays die Datei -- danach fasst diese
  # Aktivierung sie nie wieder an, weil sie dann existiert.
  # Keine isLaptop-Weiche noetig, und bewusst keine: am Desktop erzeugt
  # home-manager die Datei weiterhin selbst, sie existiert dort also zum
  # Zeitpunkt dieser Aktivierung (writeBoundary liegt nach dem Verlinken) und
  # die Bedingung unten greift gar nicht erst. Eine mkIf-Weiche auf einem
  # DAG-Eintrag waere nur eine zusaetzliche Stelle, die brechen kann.
  home.activation.seedMonitorsLua = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/hypr/monitors.lua" ]; then
      run mkdir -p "$HOME/.config/hypr"
      run cp ${monitorsSeed} "$HOME/.config/hypr/monitors.lua"
      run chmod 644 "$HOME/.config/hypr/monitors.lua"
    fi
  '';

  # seedNoctaliaConf ist am 01.11.2026 entfallen: noctalias Theme kommt jetzt
  # als noctalia.lua und wird per pcall geladen, eine fehlende Datei ist
  # also kein Config-Fehler mehr. Die alte ~/.config/hypr/noctalia.conf
  # bleibt liegen und wird nicht mehr gelesen.

  home.packages = with pkgs; [
    grimblast  # Screenshot-Wrapper (Print)

    # Discord als Website (SUPER+D). vesktop ist am 09.08.2026 rausgeflogen:
    # Screenshare war dort nicht zu retten. Ursache war NICHT der Client,
    # sondern xdg-desktop-portal-hyprland 1.4.1 -- "Out of buffers" ist normale
    # Backpressure, das Portal renegotiiert dabei aber den Buffer-Pool und
    # zerstoert den Frame-Callback, womit die Session stirbt (Issue #423, Fix in
    # PR #424 gemerged 06.08.2026, aber in KEINEM Release: v1.4.1 ist vom
    # 29.07.2026). Firefox loest den Bug nie aus, weil er die Buffer schnell
    # genug zurueckgibt -- im Gegentest am 09.08.2026 hat er sauber gestreamt,
    # auf demselben Portal und Treiber.
    #
    # Das Skript ersetzt vesktops Single-Instance-Verhalten: ein zweiter Druck
    # holt das bestehende Fenster nach vorn, statt ein weiteres zu oeffnen.
    # Grenze: gematcht wird ueber den FENSTERTITEL. Ein Firefox-Fenster, in dem
    # Discord nur einer von mehreren Tabs ist, wird nur getroffen, solange der
    # Discord-Tab aktiv ist. Fuer den gedachten Gebrauch (eigenes Fenster, per
    # --new-window erzeugt) passt das.
    (writeShellScriptBin "discord-web" ''
      if hyprctl -j clients \
           | ${jq}/bin/jq -e 'any(.[]; .title | test("Discord"))' >/dev/null; then
        # Dispatch-Syntax seit 0.57 ist ein Lua-Ausdruck; die alte Form
        # `hyprctl dispatch focuswindow 'title:...'` gibt es nicht mehr.
        hyprctl dispatch 'hl.dsp.focus({ window = "title:.*Discord.*" })'
      else
        firefox --new-window https://discord.com/app
      fi
    '')

    # Rebuild per Tastendruck (bfn 11.09.2026, SUPER+R / SUPER+SHIFT+R).
    #
    # Bewusst ein Skript und keine `sh -c`-Kette im Bind: es braucht ein
    # Argument (--pull), eine Auswertung des Rueckgabecodes und ein Fenster,
    # das nach dem Lauf offen bleibt. Ohne das Letzte sieht man weder Fehler
    # noch Erfolg -- kitty schliesst sich, sobald das Kommando durch ist.
    #
    # Die Abbreviation `nrs` in home/fish.nix bleibt unveraendert: eine fish-
    # Abbreviation ist Text, der im Prompt expandiert wird, und von aussen
    # nicht aufrufbar. Beide Wege fuehren dasselbe Kommando aus.
    #
    # sudo kommt bewusst OHNE Store-Pfad: das setuid-Binary liegt im Wrapper
    # unter /run/wrappers/bin, das sudo aus dem Store waere nicht setuid und
    # damit wirkungslos. git dagegen mit Store-Pfad, wie beim discord-web-
    # Skript darueber.
    (writeShellScriptBin "nixos-switch" ''
      set -u

      if [ "''${1:-}" = "--pull" ]; then
        echo ":: git pull --ff-only in /etc/nixos"
        # --ff-only ist Absicht: liegen dort lokale Commits oder Aenderungen,
        # die einen Merge braeuchten, soll der Lauf STEHEN statt zu mergen.
        # /etc/nixos gehoert bfn, der Pull laeuft deshalb ohne sudo.
        if ! ${git}/bin/git -C /etc/nixos pull --ff-only; then
          echo
          echo "!! git pull fehlgeschlagen -- es wird NICHT gebaut."
          printf 'Fenster schliessen: Enter. '
          read -r _
          exit 1
        fi
        echo
      fi

      sudo nixos-rebuild switch --flake /etc/nixos
      rc=$?

      echo
      if [ "$rc" -eq 0 ]; then
        echo ":: switch erfolgreich (rc=0)"
      else
        echo "!! switch fehlgeschlagen (rc=$rc)"
      fi
      printf 'Fenster schliessen: Enter. '
      read -r _
      exit "$rc"
    '')

    # Der selbstgebaute hypr-cheatsheet ist am 09.08.2026 rausgeflogen. Ersetzt
    # durch das noctalia-Plugin kenn/keybind-cheatsheet -- gleiche Idee (Binds
    # live statt aus einer Doku-Kopie), aber im noctalia-Design statt in fuzzel.
    # Seit der Lua-Config (01.11.2026) liest das Plugin die Binds live ueber
    # `hyprctl binds -j` (Parser-Modus auto/lua) samt `description`-Feld und
    # holt sich die Kategorien aus `-- 1. Name`-Zeilen der hyprland.lua.
    # Bis dahin las es die hyprland.conf als Text. Mit dem Ausbau
    # verliert fuzzel seinen letzten Nutzer und fliegt ebenfalls raus.
  ];

  # Seit 01.11.2026 Lua statt hyprland.conf. Hyprland 0.57 liest KEINE .conf
  # mehr (ab 0.56 nur noch mit Deprecation-Leiste) und legt beim ersten Start
  # ohne hyprland.lua eine Beispiel-Config an -- genau das hat am 01.11. die
  # Session zerlegt (Runbook in Skitariis Memory, 2026-11-01). Die Uebersetzung
  # ist 1:1, Verhalten soll sich nicht aendern. Quelle fuer die API:
  # share/hypr/stubs/hl.meta.lua im 0.57-Paket (Typen aller Optionen) und die
  # Dispatcher-Seite des Wikis fuer v0.57.0.
  #
  # Rueckweg: alte NixOS-Generation booten. Die hyprland.lua ist ein
  # home-manager-Symlink, die alte Generation raeumt ihn beim Aktivieren also
  # selbst weg -- anders als die Beispiel-Config vom 01.11., die als echte
  # Datei im Home lag und jeden Rollback ueberlebt hat.
  xdg.configFile."hypr/hyprland.lua".text = stripComments ''
    -- Managed by home-manager (home/hyprland.nix)
    -- Catppuccin Mocha - clean & ruhig

    -- Monitore: aus ~/.config/hypr/monitors.lua. Wer sie schreibt, ist je Host
    -- verschieden:
    --   fabricus            -> hosts/fabricus/monitors.nix, deklarativ ueber
    --                          home-manager (Store-Symlink, read-only).
    --   fabricus-itinerans  -> nwg-displays, per Hand (SUPER+SHIFT+M). Eine
    --                          echte, veraenderliche Datei; Begruendung in
    --                          hosts/fabricus-itinerans/monitors.nix.
    -- Hier steht bewusst keine hl.monitor-Regel, auch kein Catch-all.
    --
    -- pcall, weil require auf ein fehlendes Modul in Lua ein echter Fehler
    -- ist und den Rest dieser Datei abbrechen wuerde. So fehlt im
    -- schlimmsten Fall nur das Layout, nicht die ganze Config.
    local ok_monitors, err_monitors = pcall(require, "monitors")
    if not ok_monitors then
        hl.notification.create({ text = "monitors.lua fehlt oder ist kaputt: " .. tostring(err_monitors), timeout = 10000 })
    end

    -- Programme
    local terminal    = "kitty"
    -- Suche/Launcher ist noctalias Panel (seit 08.08.2026, fuzzel ist weg).
    local menu        = "noctalia msg panel-toggle launcher"
    local browser     = "firefox"
    local mail        = "thunderbird"
    -- --override=confirm_os_window_close=0: kitty fragt sonst beim Schliessen
    -- (SUPER+W) nach, weil im Fenster noch yazi laeuft. Bewusst nur hier und
    -- nicht global -- bei einem Terminal mit laufendem Build will man die Frage.
    local fileManager = "kitty --override=confirm_os_window_close=0 -e yazi"
    local mainMod     = "SUPER"

    -- Autostart. Seit 0.57 kein exec-once mehr, sondern das Event
    -- hyprland.start -- feuert genau einmal pro Compositor-Start, nicht bei
    -- jedem Reload.
    hl.on("hyprland.start", function()
        -- noctalia im Aufpasser (noctaliaSupervisor, let-Block oben): startet
        -- es nach Absturz neu, sperrt dann wieder, und haengt es per
        -- systemd-cat ans Journal statt an das tmpfs-Log von Hyprland
        -- (21.09.2026). Lesen: journalctl --user -t noctalia -b (als bfn)
        -- bzw. journalctl _UID=1000 -t noctalia -b (als Agent).
        --
        -- Keine systemd-User-Unit: graphical-session.target wird in dieser
        -- Session nie erreicht, und der User-Manager kennt WAYLAND_DISPLAY
        -- hier nicht. Als Kind von Hyprland erbt alles hier die Umgebung.
        hl.exec_cmd("${noctaliaSupervisor}")
        hl.exec_cmd("1password --silent")
        -- polkit-Agent. Ohne ihn lehnt polkitd jede Anfrage sofort ab, ohne
        -- Dialog (aufgefallen am 1Password-Unlock per Systemauth). soteria
        -- statt hyprpolkitagent, weil GTK und damit gethemt (09.09.2026).
        hl.exec_cmd("${pkgs.soteria}/bin/soteria")
    end)

    -- Look
    hl.config({
        -- Optik-Runde 01.11.2026 (bfn): angelehnt an die verbreiteten
        -- Material-3-Rices (end-4/illogical-impulse, caelestia), aber ohne
        -- deren Fenster-Transparenz -- "clean & ruhig" bleibt. Etwas mehr Luft,
        -- weichere Ecken, Schatten als Fokus-Hinweis, MD3-Kurven unten.
        general = {
            gaps_in = 5,
            gaps_out = 12,
            border_size = 2,
            col = {
                active_border = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 },
                inactive_border = "rgba(45475aaa)",
            },
            layout = "dwindle",
            resize_on_border = true,
        },

        decoration = {
            rounding = 12,
            -- 2 = runde Ecke, hoeher = "Squircle" wie bei GNOME/macOS.
            rounding_power = 2.5,
            -- Bewusst keine Fenster-Transparenz (Lesbarkeit auf 4k).
            active_opacity = 1.0,
            inactive_opacity = 1.0,
            -- Abdunkeln hinter dem Scratchpad (SUPER+S), damit es sich vom
            -- Rest abhebt.
            dim_special = 0.3,
            blur = {
                enabled = true,
                size = 6,
                -- Laptop (UHD 620) mit einem Durchgang weniger, der Blur
                -- kostet pro Pass GPU-Zeit bei jedem Neuzeichnen.
                passes = ${toString blurPasses},
                -- Rauschen + etwas weniger Kontrast/Helligkeit: der Blur
                -- wirkt wie Milchglas statt wie verwaschen (end-4-Werte).
                noise = 0.01,
                contrast = 0.9,
                brightness = 0.85,
                vibrancy = 0.17,
                -- Popups (Kontextmenues) und Scratchpad mitblurren.
                popups = true,
                special = true,
                xray = false,
            },
            -- Weicher, breiter Schatten am aktiven Fenster, kaum einer an
            -- inaktiven: der Fokus ist ohne Abdunkeln sofort erkennbar.
            shadow = {
                enabled = true,
                range = 24,
                render_power = 3,
                color = "rgba(11111bb0)",
                color_inactive = "rgba(11111b40)",
            },
        },

        animations = {
            enabled = true,
        },

        dwindle = {
            -- pseudotile gibt es als Option seit 0.56 nicht mehr, nur noch als
            -- Dispatcher (SUPER+SHIFT+P unten).
            preserve_split = true,
        },

        misc = {
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            -- Ein neuer Lock-Client darf eine verwaiste Sperre uebernehmen,
            -- statt dass nur noch tty2 + Reboot bleiben (30.09.2026, siehe
            -- noctaliaSupervisor). Notweg von tty2, falls auch der scheitert:
            --   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
            allow_session_lock_restore = true,
        },

        input = {
            kb_layout = "de",
            follow_mouse = 1,
            sensitivity = 0,
            touchpad = {
                natural_scroll = true,
            },
        },

        -- wp-color-management-v1 auf Version 1 begrenzen (06.08.2026).
        -- Hyprland bietet v2 an, Firefox 146 kannte nur v1 und wurde bei
        -- Opcode 2 hart gekillt ("wp_image_description_v1 has no event 2").
        -- Color Management bleibt an, nur die Protokoll-Version ist
        -- gedeckelt. Greift nur nach Compositor-Neustart. Ob Firefox 159 das
        -- noch braucht, ist ungeprueft -- solange es nicht stoert, bleibt es.
        experimental = {
            wp_cm_1_2 = false,
        },
    })

    -- Kurven aus Material 3 (wie end-4 und caelestia): decel fuer alles,
    -- was erscheint, accel fuer alles, was verschwindet, standard fuer
    -- Bewegung. Geschwindigkeiten in Zehntelsekunden, bewusst eher kurz.
    hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
    hl.curve("md3_decel",    { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
    hl.curve("md3_accel",    { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
    hl.curve("menu_decel",   { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
    hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4,   bezier = "md3_decel",    style = "popin 80%" })
    hl.animation({ leaf = "windowsOut",       enabled = true, speed = 2.5, bezier = "md3_accel",    style = "popin 80%" })
    hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4,   bezier = "md3_standard" })
    hl.animation({ leaf = "fade",             enabled = true, speed = 3,   bezier = "md3_decel" })
    hl.animation({ leaf = "border",           enabled = true, speed = 6,   bezier = "md3_standard" })
    -- noctalia animiert seine Panels selbst; hier nur ein kurzes Einblenden,
    -- sonst laufen zwei Animationen uebereinander.
    hl.animation({ leaf = "layers",           enabled = true, speed = 2.5, bezier = "md3_decel",    style = "fade" })
    hl.animation({ leaf = "workspaces",       enabled = true, speed = 4,   bezier = "menu_decel",   style = "slidefade 15%" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,   bezier = "md3_decel",    style = "slidefadevert 15%" })
${gestureBlock}
    -- Adaptive Theming (noctalia). noctalia rendert seine Material-Palette
    -- nach ~/.config/hypr/noctalia.lua (sein Lua-Template, seit noctalia 5.x)
    -- und ueberschreibt mit apply_theme() die Border-Farben von oben. Ihr
    -- eigener Weg waere, `require("noctalia").apply_theme()` an diese Datei
    -- anzuhaengen -- das scheitert am read-only Store-Symlink (gleiche Lage
    -- wie bei der kitty.conf), deshalb steht der Aufruf hier selbst.
    -- pcall, weil die Datei auf einem frischen System beim ersten Start noch
    -- fehlt; dann bleiben die Catppuccin-Werte. Live-Recolor beim
    -- Wallpaper-Wechsel braucht ggf. ein `hyprctl reload`.
    -- Der Aufruf steht absichtlich als woertliches `require("noctalia")` da:
    -- noctalias apply.sh sucht genau diesen Text (grep -F) und versucht sonst
    -- bei jedem Theme-Wechsel, ihn an die read-only Datei anzuhaengen.
    local ok_noctalia, noctalia_theme = pcall(function() return require("noctalia") end)
    if ok_noctalia and type(noctalia_theme) == "table" and noctalia_theme.apply_theme then
        noctalia_theme.apply_theme()
    end

    -- Keybindings.
    --
    -- Jeder Bind traegt ein `description`-Feld. Davon lebt das
    -- keybind-cheatsheet-Plugin: es holt die Binds live per `hyprctl binds -j`
    -- und zeigt die Beschreibung statt des rohen Dispatchers. Die
    -- `-- N. Name`-Zeilen sind seine Kategorien und ueberleben als einzige
    -- Kommentare das stripComments (let-Block oben).
    --
    -- Doppelt belegte Tasten: Hyprland nimmt kommentarlos den ERSTEN Treffer
    -- (08.08.2026 SUPER+P, 11.09.2026 SUPER+SHIFT+R). Vor jedem neuen Bind
    -- nach der Taste suchen.

    -- 1. Fenster & Session
    hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("${terminalHere}"), { description = "Terminal öffnen (im Ordner des aktiven Terminals)" })
    hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu), { description = "Anwendungen suchen und starten" })
    hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Aktives Fenster schließen" })
    hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Hyprland beenden (abmelden)" })
    hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(), { description = "Vollbild an/aus" })
    -- V-Paar am 27.08.2026 getauscht (bfn): Zwischenablage auf SUPER+V (System),
    -- schweben lassen auf SHIFT.
    hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }), { description = "Fenster schweben lassen / einrasten" })
    -- togglesplit ist eine Layout-Message. Pseudotile auf SHIFT+P, weil P
    -- 1Password gehoert (08.08.2026).
    hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"), { description = "Teilung drehen: nebeneinander <-> übereinander" })
    hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo(), { description = "Pseudo-Kachelung an/aus" })

    -- 2. Fokus & Verschieben
    hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }), { description = "Fokus nach links" })
    hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }), { description = "Fokus nach unten" })
    hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }), { description = "Fokus nach oben" })
    hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { description = "Fokus nach rechts" })
    hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }), { description = "Fenster nach links verschieben" })
    hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }), { description = "Fenster nach unten verschieben" })
    hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }), { description = "Fenster nach oben verschieben" })
    hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }), { description = "Fenster nach rechts verschieben" })

    -- 3. Programme
    hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), { description = "Browser (Firefox)" })
    hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(mail), { description = "Mail (Thunderbird)" })
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "Dateimanager (yazi im Terminal)" })
    hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian"), { description = "Obsidian (Notizen)" })
    hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("1password"), { description = "1Password" })
    hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("discord-web"), { description = "Discord (Website in Firefox)" })
    -- nvim bewusst OHNE confirm_os_window_close=0: die Rueckfrage ist hier die
    -- letzte Warnung vor ungespeicherten Puffern.
    hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(terminal .. " -e nvim"), { description = "Neovim (Editor im Terminal)" })

    -- 4. System
    -- btop statt des alten `procs` (09.10.2026); ohne Rueckfrage beim Schliessen.
    hl.bind(mainMod .. " + U", hl.dsp.exec_cmd(terminal .. " --override=confirm_os_window_close=0 -e btop"), { description = "Prozess-Übersicht (btop)" })
    hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("hyprlock"), { description = "Bildschirm sperren" })
    -- Hilfe auf SUPER+ss: auf dem de-Layout ist ? = Shift+ss, gematcht wird
    -- aber der Keysym der BASIS-Ebene -- also `ssharp` ohne SHIFT (09.08.2026).
    -- Panel-ID voll qualifiziert, ein blosses `cheatsheet` kennt noctalia nicht.
    hl.bind(mainMod .. " + ssharp", hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"), { description = "Diese Tastenkürzel-Übersicht" })
    -- Screenshots nach ~/Pictures/screenshots. DEFAULT_TARGET_DIR statt
    -- XDG_SCREENSHOTS_DIR, weil grimblast es zuerst prueft (07.09.2026);
    -- traegt, weil exec_cmd ueber `sh -c` startet.
    hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("DEFAULT_TARGET_DIR=${screenshotDir} grimblast --notify copysave area"), { description = "Screenshot: Bereich auswählen" })
    hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("DEFAULT_TARGET_DIR=${screenshotDir} grimblast --notify copysave screen"), { description = "Screenshot: ganzer Bildschirm" })
    hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Farbe vom Bildschirm aufnehmen" })
    -- noctalias Clipboard-History (cliphist ist seit 08.08.2026 raus).
    hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"), { description = "Zwischenablage-Verlauf" })
    -- Benachrichtigungen sind ein TAB des Control-Centers: Panel, dann Tab.
    hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"), { description = "Benachrichtigungen" })
    hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("noctalia msg settings-toggle"), { description = "noctalia-Einstellungen" })
    -- Notbremse, falls noctalia haengt (29.09.2026). Prozessname ist der des
    -- Nix-Wrappers, auf 15 Zeichen gekuerzt. Nur pkill: neu startet der
    -- noctaliaSupervisor, ein eigenes `noctalia` hier gaebe zwei Instanzen.
    hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("pkill -x .noctalia-wrapp"), { description = "noctalia neu starten (Bar weg)" })
    hl.bind("SUPER + ALT + R", hl.dsp.reload_config(), { description = "Hyprland-Konfiguration neu laden" })
    -- Rebuild per Taste (11.09.2026): eigenes kitty-Fenster, weil sudo fragt
    -- und der Build-Output das Einzige ist, woran man den Erfolg sieht.
    hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(terminal .. ' --title "nixos-rebuild switch" -e nixos-switch'), { description = "NixOS neu bauen (nixos-rebuild switch)" })
    hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(terminal .. ' --title "git pull + nixos-rebuild switch" -e nixos-switch --pull'), { description = "NixOS: erst git pull, dann neu bauen" })
    -- Captive-Portal-WLAN, Begruendung in modules/captive-portal.nix.
    hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("wifi-portal"), { description = "WLAN-Anmeldeseite öffnen (Hotel, Café, Bahn)" })
${monitorToolBind}
    -- 5. Workspaces
    -- SUPER+1..0 -> Workspace 1..10, mit SHIFT nimmt das Fenster mit.
    -- follow = true entspricht dem alten movetoworkspace (nicht ...silent):
    -- man landet beim Fenster.
    for i = 1, 10 do
        local key = i % 10
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Zu Workspace " .. i })
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), { description = "Fenster auf Workspace " .. i })
    end

    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Nächster Workspace (Mausrad)" })
    hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Voriger Workspace (Mausrad)" })

    -- Tastatur-Aequivalent zum 3-Finger-Wisch, monitor-lokal (`m` statt `e`,
    -- 11.09.2026): bleibt auf dem fokussierten Bildschirm. Springt nur auf
    -- bestehende Workspaces und wickelt am Ende um.
    hl.bind(mainMod .. " + left", hl.dsp.focus({ workspace = "m-1" }), { description = "Voriger Workspace (auf diesem Bildschirm)" })
    hl.bind(mainMod .. " + right", hl.dsp.focus({ workspace = "m+1" }), { description = "Nächster Workspace (auf diesem Bildschirm)" })
    hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ workspace = "m-1", follow = true }), { description = "Fenster einen Workspace nach links" })
    hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "m+1", follow = true }), { description = "Fenster einen Workspace nach rechts" })

    -- Neuer leerer Workspace hinter dem aktuellen, auf diesem Bildschirm
    -- (`emptynm`, 11.09.2026). `plus` liegt auf dem de-Layout auf der
    -- Basis-Ebene, also ohne SHIFT (gleiche Regel wie ssharp).
    hl.bind(mainMod .. " + plus", hl.dsp.focus({ workspace = "emptynm" }), { description = "Neuer leerer Workspace auf diesem Bildschirm" })

    -- noctalias Fenster-Switcher. SUPER+SHIFT+Tab bleibt bewusst frei: dort
    -- blaettert der offene Switcher rueckwaerts (09.08.2026).
    hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("noctalia msg window-switcher"), { description = "Fenster-Umschalter (alle offenen Fenster)" })

    -- Scratchpad. toggle_special nimmt den Namen OHNE `special:`, window.move
    -- braucht ihn MIT (Wiki 0.57, Dispatchers).
    hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Scratchpad ein-/ausblenden" })
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }), { description = "Fenster ins Scratchpad legen" })

    -- 6. Maus & Medien
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Fenster ziehen (linke Maustaste)" })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Fenstergröße ziehen (rechte Maustaste)" })
    hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("noctalia msg wallpaper-next"), { description = "Nächstes Hintergrundbild" })
    -- bindel = locked + repeating, bindl = locked.
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Lautstärke +5%" })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, description = "Lautstärke -5%" })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true, description = "Stumm an/aus" })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Helligkeit +5%" })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Helligkeit -5%" })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Nächster Titel" })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Wiedergabe pausieren/fortsetzen" })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Wiedergabe pausieren/fortsetzen" })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Voriger Titel" })
  '';
}
