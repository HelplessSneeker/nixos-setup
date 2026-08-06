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
    cliphist       # Clipboard-History (SUPER+SHIFT+V)
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
    };
  };

  # SSH-Client-Config (1Password-Agent, Tailnet-Hosts) lebt in ./ssh.nix.

  # Deine echte git-Identitaet/Config kommt spaeter aus den dotfiles.
  # (Das Paket `git` liefert schon modules/system-base.nix.)
}
