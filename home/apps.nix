# Per-User Apps (home-manager). Shared home-Modul -> gilt fuer jeden Host,
# der home/bfn.nix zieht (fabricus jetzt, fabricus-itinerans spaeter).
{ config, pkgs, pkgsUnstable, lib, ... }:
{
  home.packages = with pkgs; [
    firefox        # Default-Browser (SUPER+B). Brave am 06.08.2026 rausgeworfen:
                   # bfn will die transparentere Datenschutz-Story.
    obsidian
    vesktop        # Discord-Client, nativ Wayland (Screenshare + Themes)
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

      "x-scheme-handler/discord" = "vesktop.desktop";

      # Verzeichnisse in yazi (Eintrag oben). Deckt den xdg-open-Weg ab, also
      # Klicks auf Verzeichnis-Links. Firefox' "Enthaltenden Ordner oeffnen"
      # nach einem Download geht NICHT hierueber, sondern ueber die DBus-
      # Schnittstelle org.freedesktop.FileManager1 -- die liefern nur echte
      # GUI-Dateimanager mit, yazi nicht. Dafuer braucht es einen eigenen
      # kleinen DBus-Dienst; steht noch aus.
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
