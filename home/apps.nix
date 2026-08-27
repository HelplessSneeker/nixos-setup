# Per-User Apps (home-manager). Shared home-Modul -> gilt fuer jeden Host,
# der home/bfn.nix zieht (fabricus jetzt, fabricus-itinerans spaeter).
{ config, pkgs, pkgsUnstable, lib, ... }:
let
  # HIER STAND firefoxStartUrl = "https://duckduckgo.com/", raus am 27.08.2026.
  # Startseite und Home-Button sind seitdem wieder Firefox' eigene (about:home,
  # "Firefox Start"). Die Homepage-Policy ist ersatzlos entfernt, nicht auf
  # about:home umgestellt -- keine Policy heisst "Firefox entscheidet", und
  # genau das war der Wunsch.
  #
  # Falls beim ersten Start trotzdem noch DuckDuckGo kommt: die alte Policy war
  # ohne `Locked` gesetzt, hat also nur den Default gesetzt. Hat bfn die Seite
  # irgendwann per GUI bestaetigt, liegt der Wert als BENUTZER-Pref im Profil
  # und ueberlebt den Ausbau. Weg damit: Einstellungen -> Startseite ->
  # "Standard wiederherstellen".

  # --- org.freedesktop.FileManager1 -> yazi (Punkt 9b) ---
  # Firefox' "Enthaltenden Ordner oeffnen" geht NICHT ueber xdg-open, sondern
  # ruft per DBus org.freedesktop.FileManager1.ShowItems. Das Interface liefern
  # nur echte GUI-Dateimanager mit; yazi hat es nicht und wird es absehbar auch
  # nicht bekommen (Upstream-Issues sxyazi/yazi#1120 und #1698, beide offen).
  # Auf fabricus beansprucht den Namen bisher niemand -- der Aufruf scheitert
  # also hart, ohne Fallback auf den inode/directory-Handler.
  #
  # Dieser Shim beansprucht den Namen und uebersetzt die drei Methoden auf
  # "yazi im Terminal". DBus-aktiviert (Service-File unten): er startet erst,
  # wenn ihn jemand ruft, und beendet sich nach IDLE_SECONDS wieder -- kein
  # Dauerlaeufer.
  #
  # ShowItems bekommt Datei-URIs, nicht Ordner. yazi kann damit direkt umgehen:
  # `yazi /pfad/datei` oeffnet das Elternverzeichnis mit der Datei unter dem
  # Cursor -- genau die Semantik, die die Spec verlangt.
  #
  # pygobject statt dbus-python: liegt auf dieser Maschine ohnehin schon im
  # Store (GTK-Stack), kostet also keine zusaetzliche Closure.
  yaziFileManager1 =
    let
      python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

      # Nur das nackte Skript -- der ausfuehrbare Wrapper kommt unten.
      #
      # Grund (Fehlschlag vom 09.08.2026): `python3.withPackages [ pygobject3 ]`
      # liefert die Python-Bindings, aber NICHT die GObject-Introspection-
      # Typelibs. Ohne die bricht schon `gi.require_version("Gio", "2.0")` mit
      # `ValueError: Namespace Gio not available`. Die .typelib-Dateien liegen
      # in glib, und zwar im out-Output -- `${pkgs.glib}` allein zeigt bei
      # diesem Paket auf den bin-Output und waere der falsche Pfad.
      script = pkgs.writeScript "yazi-filemanager1-unwrapped" ''
      #!${python}/bin/python3
      # Uebersetzt org.freedesktop.FileManager1 auf yazi im Terminal.
      import subprocess
      import sys
      import urllib.parse

      import gi

      gi.require_version("Gio", "2.0")
      from gi.repository import Gio, GLib

      TERMINAL = "${pkgs.kitty}/bin/kitty"
      # Ohne das fragt kitty beim Schliessen (SUPER+W) nach, weil im Fenster
      # noch yazi laeuft -- confirm_os_window_close steht per Default auf -1.
      # Gezielt pro Fenster abgeschaltet statt global: bei einem Terminal mit
      # laufendem Build oder SSH ist die Rueckfrage weiterhin erwuenscht.
      NO_CLOSE_PROMPT = "--override=confirm_os_window_close=0"
      YAZI = "${pkgs.yazi}/bin/yazi"
      BUS_NAME = "org.freedesktop.FileManager1"
      OBJECT_PATH = "/org/freedesktop/FileManager1"
      IDLE_SECONDS = 20

      NODE_XML = """
      <node>
        <interface name="org.freedesktop.FileManager1">
          <method name="ShowFolders">
            <arg type="as" name="URIs" direction="in"/>
            <arg type="s" name="StartupId" direction="in"/>
          </method>
          <method name="ShowItems">
            <arg type="as" name="URIs" direction="in"/>
            <arg type="s" name="StartupId" direction="in"/>
          </method>
          <method name="ShowItemProperties">
            <arg type="as" name="URIs" direction="in"/>
            <arg type="s" name="StartupId" direction="in"/>
          </method>
        </interface>
      </node>
      """

      loop = GLib.MainLoop()
      idle_source = None


      def stop():
          loop.quit()
          return GLib.SOURCE_REMOVE


      def reset_idle():
          # Nach der letzten Anfrage noch kurz warten, dann beenden. Ein neuer
          # Aufruf startet uns per DBus-Aktivierung ohnehin wieder.
          global idle_source
          if idle_source is not None:
              GLib.source_remove(idle_source)
          idle_source = GLib.timeout_add_seconds(IDLE_SECONDS, stop)


      def uri_to_path(uri):
          parsed = urllib.parse.urlparse(uri)
          if parsed.scheme == "":
              return uri
          if parsed.scheme != "file":
              return None
          return urllib.parse.unquote(parsed.path)


      def open_in_yazi(path):
          subprocess.Popen(
              [TERMINAL, NO_CLOSE_PROMPT, "-e", YAZI, path],
              start_new_session=True,
              stdin=subprocess.DEVNULL,
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
          )


      def on_call(_conn, _sender, _path, _iface, method, params, invocation):
          reset_idle()
          if method not in ("ShowFolders", "ShowItems", "ShowItemProperties"):
              invocation.return_dbus_error(
                  "org.freedesktop.DBus.Error.UnknownMethod", method
              )
              return
          uris = params[0] if len(params) > 0 else []
          for uri in uris:
              path = uri_to_path(uri)
              if path:
                  open_in_yazi(path)
          # ShowItemProperties kann yazi nicht -- wir zeigen die Datei, statt den
          # Aufruf ins Leere laufen zu lassen. Bewusste Naeherung.
          invocation.return_value(None)


      def on_bus_acquired(connection, _name):
          node = Gio.DBusNodeInfo.new_for_xml(NODE_XML)
          connection.register_object(OBJECT_PATH, node.interfaces[0], on_call, None, None)


      def on_name_lost(_connection, _name):
          # Ein echter Dateimanager haelt den Namen schon -- dann raus hier.
          sys.exit(1)


      Gio.bus_own_name(
          Gio.BusType.SESSION,
          BUS_NAME,
          Gio.BusNameOwnerFlags.NONE,
          on_bus_acquired,
          None,
          on_name_lost,
      )

      reset_idle()
      loop.run()
      '';
    in
    pkgs.runCommandLocal "yazi-filemanager1" {
      nativeBuildInputs = [ pkgs.makeWrapper ];
    } ''
      mkdir -p $out/bin
      makeWrapper ${script} $out/bin/yazi-filemanager1 \
        --set GI_TYPELIB_PATH ${pkgs.glib.out}/lib/girepository-1.0
    '';
in
{
  home.packages = with pkgs; [
    # Default-Browser (SUPER+B). Brave am 06.08.2026 rausgeworfen: bfn will die
    # transparentere Datenschutz-Story.
    #
    # extraPolicies statt programs.firefox: das home-manager-Modul wuerde das
    # ganze Profil uebernehmen (search, bookmarks, prefs) und bfns per GUI
    # gepflegten Stand ueberschreiben. Der Wrapper legt stattdessen nur
    # /etc/firefox/policies/policies.json neben den Binary -- Enterprise-Policy,
    # die Firefox beim Start liest. Profil bleibt unangetastet.
    (firefox.override {
      extraPolicies = {
        ExtensionSettings = {
          # Vimium ("Vimium FF", 2.4.2, MIT). GUID aus der AMO-API geholt, nicht
          # geraten -- eine falsche GUID installiert kommentarlos nichts.
          #   curl -s https://addons.mozilla.org/api/v5/addons/addon/vimium-ff/
          #
          # force_installed = bfn kann es in about:addons NICHT deaktivieren
          # oder deinstallieren. Bewusst so: sonst driftet der Zustand von der
          # Config weg. Zum Loswerden: diesen Block entfernen + rebuild.
          # Fuer einzelne Seiten reicht Vimiums eigene Blocklist (SUPER-Taste
          # `i` schaltet in den Insert-Modus, Esc zurueck).
          "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
            installation_mode = "force_installed";
            default_area = "menupanel";
          };

          # New Tab Override: raus am 27.08.2026 auf bfns Wunsch.
          #
          # ERSTER ANLAUF WAR ZU WENIG, und das ist der eigentliche Merksatz
          # hier: den Eintrag aus ExtensionSettings zu LOESCHEN deinstalliert
          # nichts. Firefox hoert damit nur auf, die Erweiterung zu erzwingen --
          # das bereits installierte Add-on bleibt im Profil liegen und wirkt
          # weiter. Genau so ist es beim Rebuild am 27.08. passiert.
          #
          # `blocked` ist der dokumentierte Weg: Firefox entfernt die
          # Erweiterung beim naechsten Start und laesst sie auch nicht von Hand
          # wieder installieren. Der Eintrag muss deshalb STEHEN BLEIBEN --
          # entfernt man ihn spaeter, ist das kein Aufraeumen, sondern gibt die
          # Installation wieder frei.
          #
          # Was mit dem Ausbau zurueckkommt, damit es niemanden ueberrascht:
          #   - Vimium greift auf about:newtab NICHT (Firefox laesst auf
          #     about:*-Seiten keine Erweiterung mitlesen) -- kein j, kein f,
          #     kein o im leeren Tab.
          #   - Strg+T setzt den Cursor wieder in die Adresszeile (das war der
          #     Preis von focus_website und ist jetzt der Normalzustand).
          #   - about:newtab zeigt wieder Firefox' Kacheln/Sponsored Shortcuts;
          #     abschaltbar in den Einstellungen oder per Zahnrad rechts oben
          #     auf der Seite selbst.
          # Zum Wiederbeleben braucht es die Erweiterung erneut: die Policy
          # `NewTabPage` ist im Firefox-Schema ein reiner Boolean (an/aus,
          # "aus" = leere Seite) und kann keine URL setzen; der einzige
          # unterstuetzte Weg zu einer echten Seite im neuen Tab ist
          # chrome_url_overrides.newtab, und das kann nur eine Erweiterung.
          "newtaboverride@agenedia.com" = {
            installation_mode = "blocked";
            blocked_install_message = "New Tab Override ist per NixOS-Config deaktiviert (home/apps.nix).";
          };
        };

        # Die `Homepage`-Policy (URL + StartPage) ist am 27.08.2026 entfernt --
        # Begruendung oben im let-Block, wo firefoxStartUrl stand.

        # --- Standard-Suchmaschine: Brave Search (27.08.2026) ---
        #
        # Brave Search ist in Firefox NICHT eingebaut, muss also erst per `Add`
        # angelegt und dann per `Default` gesetzt werden. Beide Felder in EINER
        # Policy -- `Default` verweist auf den `Name` von oben.
        #
        # WARUM DAS AUF DIESEM FIREFOX UEBERHAUPT GEHT: die SearchEngines-Policy
        # war jahrelang ESR-only und auf dem Release-Kanal wirkungslos. Seit
        # Firefox 139 gilt sie in allen Kanaelen (Mozillas Admin-Referenz,
        # nachgelesen 27.08.2026). Hier laeuft 153 -- passt. Falls die Suche
        # trotzdem auf DuckDuckGo bleibt: about:policies zeigt, ob die Policy
        # angekommen und gueltig ist.
        #
        # Alle vier Werte stammen aus Braves EIGENEM OpenSearch-Descriptor
        # (https://search.brave.com/opensearch.xml), nicht aus einer Anleitung.
        # Such- und Suggest-URL am 27.08.2026 gegen den Server geprueft: Suche
        # 200, Suggest liefert das erwartete JSON-Array.
        #
        # Die Icon-URL ist Braves inhaltsadressierter CDN-Pfad aus demselben
        # Descriptor. Stirbt sie irgendwann, zeigt Firefox ein generisches Icon
        # -- rein kosmetisch, die Suche laeuft weiter.
        SearchEngines = {
          Add = [
            {
              Name = "Brave";
              URLTemplate = "https://search.brave.com/search?q={searchTerms}";
              SuggestURLTemplate = "https://search.brave.com/api/suggest?q={searchTerms}";
              Method = "GET";
              # Kuerzel fuer die Adresszeile: `br <suchbegriff>` sucht gezielt
              # bei Brave, auch wenn der Default mal woanders steht.
              Alias = "br";
              Description = "Brave Search: private, independent, open";
              IconURL = "https://cdn.search.brave.com/serp/v1/static/brand/12832ccf4a94a6fe2ecc75f7ee0df48677abeab018d165ce25b7414477384367-favicon-96x96.png";
            }
          ];
          Default = "Brave";

          # `Remove` bewusst NICHT gesetzt: DuckDuckGo, Google & Co bleiben in
          # der Liste erhalten und sind ueber ihre Kuerzel weiter erreichbar.
          # Nur der Default wandert.
          #
          # `DefaultPrivate` ebenfalls nicht gesetzt -- ohne den Schluessel
          # benutzt das private Fenster denselben Default. Ein abweichender
          # Wert waere eine Entscheidung, keine Vervollstaendigung.
        };

        # Der `3rdparty.Extensions`-Block war ausschliesslich die deklarative
        # Konfiguration von New Tab Override (type = "homepage",
        # focus_website = true). Mit der Erweiterung ist er ebenfalls raus --
        # ein Eintrag fuer eine nicht installierte Erweiterung waere toter
        # Ballast, den beim naechsten Lesen jemand fuer aktiv haelt.
      };
    })
    obsidian
                   # vesktop am 09.08.2026 rausgeworfen: Screenshare war unter
                   # xdph 1.4.1 nicht zu retten (Portal-Bug, s. hyprland.nix bei
                   # SUPER+D). Discord laeuft jetzt als Website in Firefox --
                   # dort funktioniert Streamen nachweislich.
    yaziFileManager1  # DBus-Shim: org.freedesktop.FileManager1 -> yazi.
                      # Steht bewusst auch im PATH, damit man ihn zum Testen
                      # von Hand starten und die Fehlermeldung sehen kann.
    wl-clipboard   # Clipboard-Bridge fuer nvim/Terminal unter Wayland
                   # (bleibt! nvim/Terminal brauchen wl-copy/wl-paste direkt --
                   #  unabhaengig davon, wer die History fuehrt)
    hyprpicker     # Farb-Picker (SUPER+C)

    # Mail. Accounts werden in der GUI eingerichtet, nicht deklarativ --
    # programs.thunderbird bringt zwar Profile/Accounts als Nix-Optionen, die
    # Passwoerter muessen trotzdem manuell rein.
    #
    # Steht seit 20.08.2026 wieder im Release-Kanal. Vorgeschichte: kam am
    # 06.08. nach unstable, weil 25.05 auf 146.0.1 (Build 16.12.2025) fest hing
    # und 146 unter Wayland beim Senden reproduzierbar abstuerzte --
    # Crash-Signatur bp-b28f2271-99be-4016-8331-bc57a0260806: Endlos-Rekursion
    # in AppWindow::Center (AppWindow.cpp:824) -> Stack Overflow -> SIGSEGV.
    # Ursache: unter Wayland darf ein Client sein Fenster nicht selbst
    # positionieren; TB zentriert den Sende-Fortschrittsdialog, der Compositor
    # meldet eine andere Position zurueck, TB zentriert erneut -> Schleife.
    # Vgl. Mozilla-Bug 1724656 ("phantom window is created when sending
    # (wayland)").
    #
    # Der Grund ist mit dem 26.05-Umstieg weg: an den gelockten Revisionen
    # liefern nixos-26.05 (ee48b147) und nixpkgs-unstable (104240a7) beide
    # thunderbird = thunderbird-latest = 153.0.1 -- identisch, also kein
    # Versionsverlust. Zurueckgeholt, weil ein Mail-Client sicherheitskritisch
    # ist: NUR der Release-Kanal bekommt Security-Backports, ein
    # unstable-Paket haengt exakt auf dem Stand, den flake.lock festhaelt.
    # So kommen TB-Sicherheitsupdates jetzt mit demselben
    # `nix flake update nixpkgs home-manager`, das ohnehin faellig ist.
    #
    # Falls der Wayland-Crash je wiederkommt: erst pruefen, ob unstable
    # ueberhaupt neuer ist (packages.nix im nixpkgs-Repo, Attribut
    # thunderbird-latest) -- war es am 20.08.2026 nicht.
    thunderbird

    # FALLBACK, falls 153 unter Wayland doch noch crasht: Thunderbird ueber
    # XWayland zwingen. Zuverlaessig, aber auf 4k@1.25 sichtbar unschaerfer.
    # Dann die Zeile oben auskommentieren und diese hier aktivieren:
    # (pkgs.symlinkJoin {
    #   name = "thunderbird-xwayland";
    #   paths = [ pkgs.thunderbird ];
    #   nativeBuildInputs = [ pkgs.makeWrapper ];
    #   postBuild = "wrapProgram $out/bin/thunderbird --set MOZ_ENABLE_WAYLAND 0";
    # })
  ] ++ [
    # --- Pakete aus nixpkgs-unstable ---
    # pkgsUnstable wird zentral in flake.nix gebaut (import mit allowUnfree) und
    # per extraSpecialArgs reingereicht. NICHT auf legacyPackages umbauen: das
    # traegt keine config, damit scheitert jedes unfree Paket (claude-code).

    # Claude Code CLI. 25.05 ist auf v1.0.85 (Mitte 2025) eingefroren,
    # unstable liefert v2.x. Unfree.
    pkgsUnstable.claude-code

    # Godot 4.x (Mono/C#-freie Standard-Variante). 25.05 hat nur ~4.4,
    # 4.7 stable kam erst 18.06.2026. Falls die Eval das Attribut nicht findet:
    # auf der Maschine pruefen -> `nix search nixpkgs-unstable godot`
    # (Kandidaten: godot_4, godot, godot_4-mono).
    pkgsUnstable.godot_4

    # Thunderbird stand hier bis 20.08.2026 und ist zurueck in den
    # Release-Kanal gewandert (siehe Kommentar oben im pkgs-Block) --
    # unstable liefert keine neuere Version mehr, wohl aber schlechtere
    # Security-Pflege.
  ];

  # Neovim ist am 20.08.2026 nach home/nvim/ umgezogen (nixvim statt des
  # nackten programs.neovim). Hier steht bewusst KEIN auskommentierter Rest:
  # nixvim setzt eine Assertion gegen programs.neovim.enable, ein
  # wiederbelebter Block wuerde den Rebuild abbrechen, nicht nur doppeln.
  # withRuby/withPython3 stehen dort jetzt auf false -- siehe Begruendung in
  # home/nvim/config.nix.

  # --- Dateimanager-Eintrag fuer yazi ---
  # yazi ist ein TUI und bringt selbst keine .desktop-Datei mit. Ohne die kann
  # xdg-open Verzeichnisse nicht zuordnen -- "Ordner oeffnen" aus Firefox &Co
  # lief deshalb bisher ins Leere. Das Paket selbst kommt aus home/theme.nix
  # (programs.yazi.enable).
  #
  # terminal = false ist Absicht: kitty IST hier schon das Terminal. Mit true
  # wuerde der Launcher noch ein zweites drumherum starten.
  # %f statt %u ist ebenfalls Absicht: yazi will einen Pfad, keine file://-URI --
  # %f laesst den Aufrufer die URI vorher aufloesen.
  xdg.desktopEntries.yazi-filemanager = {
    name = "Dateien (yazi)";
    genericName = "Dateimanager";
    comment = "Verzeichnis in yazi oeffnen";
    # --override=confirm_os_window_close=0: sonst fragt kitty beim Schliessen
    # nach, weil yazi noch laeuft. Nur fuer dieses Fenster, nicht global.
    exec = "kitty --override=confirm_os_window_close=0 -e yazi %f";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "System" "FileTools" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  # --- DBus-Aktivierung fuer den FileManager1-Shim (Punkt 9b) ---
  # Damit deckt yazi BEIDE Wege ab, die "Ordner oeffnen" nehmen kann: den
  # xdg-open-Weg (Desktop-Entry oben) und den DBus-Weg (hier).
  #
  # Die Aktivierung laeuft ueber systemd statt direkt ueber Exec, und das ist
  # kein Stil, sondern ein Bugfix (09.08.2026): der dbus-daemon liest die
  # .service-Dateien einmal und cached sie fuer die Lebensdauer der Session.
  # Stand ein Store-Pfad in Exec=, startete er nach jedem Rebuild weiter die
  # ALTE Ableitung -- auch nach ReloadConfig, das nur die Bus-Konfiguration
  # neu liest, nicht die Aktivierungsdatenbank. Kostete eine Fehlersuche, in
  # der die Datei auf der Platte laengst richtig war.
  #
  # Mit SystemdService= enthaelt diese Datei keinen Store-Pfad mehr und
  # aendert sich nie wieder. Was sich aendert, ist die systemd-Unit, und die
  # laedt home-manager bei jeder Aktivierung sauber neu. Nebenbei landen
  # Tracebacks damit unter `journalctl --user -u yazi-filemanager1`.
  #
  # Exec= bleibt Pflicht im Dateiformat und zeigt bewusst auf einen stabilen
  # Pfad statt in den Store -- es wird nur benutzt, wenn systemd fehlt.
  #
  # Wenn hier je ein echter Dateimanager einzieht (nautilus, thunar), bringt
  # der denselben Bus-Namen mit -- dann diesen Block und die Unit entfernen,
  # sonst gewinnt wer zuerst kommt.
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=/run/current-system/sw/bin/false
    SystemdService=yazi-filemanager1.service
  '';

  systemd.user.services.yazi-filemanager1 = {
    Unit = {
      Description = "org.freedesktop.FileManager1 auf yazi abbilden";
      # Kein Install/WantedBy: der Dienst wird ausschliesslich per DBus
      # aktiviert und beendet sich nach Leerlauf wieder selbst.
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.FileManager1";
      ExecStart = "${yaziFileManager1}/bin/yazi-filemanager1";
    };
  };

  # --- Default-Anwendungen (xdg-open / Link-Klicks aus anderen Apps) ---
  # Muss deklarativ sein, seit Brave raus ist: die alte, per GUI gepflegte
  # ~/.config/mimeapps.list zeigte http/https noch auf brave-browser.desktop --
  # das Paket existiert nicht mehr, Links waeren also ins Leere gelaufen.
  # mailto zeigte auf ein von Thunderbird selbst erzeugtes userapp-*.desktop;
  # hier jetzt sauber auf thunderbird.desktop.
  # ACHTUNG: home-manager macht daraus einen Store-Symlink -> "Als Standard
  # setzen"-Buttons in GUIs koennen die Datei nicht mehr schreiben. Aenderungen
  # ab jetzt hier in der Config.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html"                = "firefox.desktop";
      "x-scheme-handler/http"    = "firefox.desktop";
      "x-scheme-handler/https"   = "firefox.desktop";
      "x-scheme-handler/about"   = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";

      "x-scheme-handler/mailto"  = "thunderbird.desktop";
      "message/rfc822"           = "thunderbird.desktop";
      "x-scheme-handler/mid"     = "thunderbird.desktop";

      # discord:// hatte vesktop als Handler -- mit dem Paket ist der Eintrag
      # weg. Firefox versteht das Schema nicht, ein Ersatz waere also nur ein
      # toter Eintrag. Einladungs- und Channel-Links sind ohnehin https und
      # laufen ueber den firefox.desktop-Handler oben.

      # Verzeichnisse in yazi (Eintrag oben). Deckt den xdg-open-Weg ab, also
      # Klicks auf Verzeichnis-Links. Firefox' "Enthaltenden Ordner oeffnen"
      # nach einem Download laeuft NICHT hierueber, sondern ueber DBus
      # (org.freedesktop.FileManager1) -- dafuer gibt es seit 09.08.2026 den
      # Shim oben. Beide Wege landen bei yazi.
      "inode/directory" = "yazi-filemanager.desktop";

      # Citrix: die aus dem Firmen-Portal geladene .ica-Datei an den
      # ICA-Adapter uebergeben, statt sie nur im Download-Ordner abzulegen.
      # wfica.desktop kommt aus dem Paket (Exec zeigt dort auf bin/adapter, der
      # startet wfica). Greift nur auf Hosts, die modules/citrix.nix
      # importieren -- ein Eintrag ohne passende .desktop-Datei ist folgenlos.
      "application/x-ica" = "wfica.desktop";
    };
  };

  # SSH-Client-Config (1Password-Agent, Tailnet-Hosts) lebt in ./ssh.nix.

  # Deine echte git-Identitaet/Config kommt spaeter aus den dotfiles.
  # (Das Paket `git` liefert schon modules/system-base.nix.)
}
