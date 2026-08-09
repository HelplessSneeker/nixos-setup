# Per-User Apps (home-manager). Shared home-Modul -> gilt fuer jeden Host,
# der home/bfn.nix zieht (fabricus jetzt, fabricus-itinerans spaeter).
{ config, pkgs, pkgsUnstable, lib, ... }:
let
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
              [TERMINAL, "-e", YAZI, path],
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
    firefox        # Default-Browser (SUPER+B). Brave am 06.08.2026 rausgeworfen:
                   # bfn will die transparentere Datenschutz-Story.
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

    # Mail. Accounts werden in der GUI eingerichtet, nicht deklarativ --
    # programs.thunderbird bringt zwar Profile/Accounts als Nix-Optionen, die
    # Passwoerter muessen trotzdem manuell rein.
    #
    # Aus unstable (153.0.1) statt 25.05 (146.0.1, Build vom 16.12.2025), weil
    # 146 unter Wayland beim Senden reproduzierbar abstuerzt. Crash-Signatur aus
    # bp-b28f2271-99be-4016-8331-bc57a0260806: Endlos-Rekursion in
    # AppWindow::Center (AppWindow.cpp:824) -> Stack Overflow -> SIGSEGV.
    # Ursache: unter Wayland darf ein Client sein Fenster nicht selbst
    # positionieren. TB zentriert den Sende-Fortschrittsdialog, der Compositor
    # meldet eine andere Position zurueck, TB zentriert erneut -> Schleife.
    # Vgl. Mozilla-Bug 1724656 ("phantom window is created when sending (wayland)").
    pkgsUnstable.thunderbird

    # FALLBACK, falls 153 unter Wayland immer noch crasht: Thunderbird ueber
    # XWayland zwingen. Zuverlaessig, aber auf 4k@1.25 sichtbar unschaerfer.
    # Dann die Zeile oben auskommentieren und diese hier aktivieren:
    # (pkgs.symlinkJoin {
    #   name = "thunderbird-xwayland";
    #   paths = [ pkgsUnstable.thunderbird ];
    #   nativeBuildInputs = [ pkgs.makeWrapper ];
    #   postBuild = "wrapProgram $out/bin/thunderbird --set MOZ_ENABLE_WAYLAND 0";
    # })
  ];

  # Neovim erstmal nur lauffaehig als Default-Editor.
  # Plugin-/LSP-/Theme-Config kommt spaeter aus deinen dotfiles.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

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
    exec = "kitty -e yazi %f";
    icon = "system-file-manager";
    terminal = false;
    categories = [ "System" "FileTools" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  # --- DBus-Aktivierung fuer den FileManager1-Shim (Punkt 9b) ---
  # Damit deckt yazi jetzt BEIDE Wege ab, die "Ordner oeffnen" nehmen kann:
  # den xdg-open-Weg (Desktop-Entry oben) und den DBus-Weg (dieser Service).
  #
  # Der Service startet den Shim erst, wenn ihn wirklich jemand ruft. Die
  # Datei landet unter ~/.local/share/dbus-1/services/ und damit im
  # Suchpfad der Session-Bus-Aktivierung, vor den systemweiten Diensten.
  #
  # Wenn hier je ein echter Dateimanager einzieht (nautilus, thunar), bringt
  # der denselben Bus-Namen mit -- dann diesen Block entfernen, sonst gewinnt
  # wer zuerst kommt.
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=${yaziFileManager1}/bin/yazi-filemanager1
  '';

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
