# nvim -- SCHICHT 4: LSP und Vervollstaendigung.
#
# Das ist der Sprung vom Editor zur IDE. Bis hierher hat nvim deinen Code
# angezeigt; ab jetzt VERSTEHT ihn jemand: ein Sprachserver liest das Projekt
# im Hintergrund, kennt Typen, Definitionen und Verwendungen -- und meldet
# Fehler, bevor du speicherst.
#
# Zwei Teile, die zusammengehoeren:
#   lsp.*             der Server und was er dir sagt (Fehler, Sprung, Doku)
#   plugins.blink-cmp die Vorschlagsliste beim Tippen, gespeist vom Server
# Ohne LSP schlaegt Vervollstaendigung nur Woerter aus dem Puffer vor -- das
# waere Rechtschreibhilfe, nicht Codeverstaendnis. Deshalb eine Schicht.
#
# Eingehaengt von ./config.nix.
{ pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # Die Sprachserver
  # ---------------------------------------------------------------------------
  # Hier laeuft der NEUE, native Weg: `lsp.servers.*` bildet nvims eigenes
  # `vim.lsp.config` ab (ab nvim 0.11). Der aeltere Weg in nixvim heisst
  # `plugins.lsp.servers.*` und braucht zusaetzlich nvim-lspconfig -- die
  # Unterscheidung ist wichtig, weil im Netz noch fast jede Anleitung die alte
  # Schreibweise zeigt. Beide existieren in nixvim 26.05 nebeneinander; wenn du
  # etwas kopierst, achte darauf, welche Variante gemeint ist.
  #
  # Die Server-Binaries kommen aus nixpkgs (die Zuordnung Name -> Paket steht in
  # nixvim unter modules/lsp/servers/packages.nix). Genau das ist der Punkt, an
  # dem Mason-basierte Setups auf NixOS scheitern: Mason laedt vorkompilierte
  # Binaries, die einen FHS-Loader erwarten, den es hier nicht gibt.
  # Die Server-DEFINITIONEN. Ohne die passiert gar nichts, und zwar lautlos.
  #
  # `lsp.servers.ts_ls.enable = true` unten erzeugt am Ende ein
  # `vim.lsp.enable("ts_ls")`. Dieser Aufruf sucht im runtimepath nach einer
  # Datei `lsp/ts_ls.lua` -- dort stehen Kommandozeile, Dateitypen und
  # Projektwurzel-Marker des Servers. nvim selbst bringt KEINE solchen Dateien
  # mit (geprueft: share/nvim/runtime/lsp/ existiert nicht), sie kommen aus
  # nvim-lspconfig.
  #
  # Fehlt das Plugin, ist der Server "aktiviert", hat aber kein cmd und keine
  # filetypes -- er wird also nie gestartet. Kein Fehler, keine Meldung, nur
  # keine Diagnostics. Genau das war der Zustand am 20.08.2026.
  #
  # nvim-lspconfig liefert hier NUR die Definitionen; konfiguriert und
  # eingeschaltet werden die Server ueber `lsp.*` (der native Weg). Der aeltere
  # `plugins.lsp` mit eigener setup()-Logik bleibt bewusst aus.
  plugins.lspconfig.enable = true;

  # nixpkgs-fmt fuer nixds formatting.command (unten). Wie bei ripgrep in
  # finder.nix: in deiner Shell ist es ueber `nix fmt` erreichbar, der
  # Sprachserver ruft es aber als eigenes Kommando auf und braucht es im PATH
  # des Editors -- besonders im Standalone-Paket ohne home-manager-Umgebung.
  extraPackages = [ pkgs.nixpkgs-fmt ];

  lsp.servers = {
    # TypeScript/JavaScript. Paket: typescript-language-server.
    # Deckt .ts/.tsx/.js/.jsx ab.
    ts_ls.enable = true;

    # Python. basedpyright statt pyright: gleiche Grundlage, aber mit
    # zusaetzlichen Pruefungen und -- der eigentliche Grund -- ohne die
    # proprietaeren Teile, die pyright an VS Code bindet.
    basedpyright.enable = true;

    # Nix. Kein Zufall, dass der hier steht: du editierst diese Konfiguration
    # taeglich.
    #
    # OHNE die settings unten kann nixd nur Syntax -- er weiss dann nicht, wo
    # nixpkgs liegt und welche Optionen es gibt. Erst damit beantwortet er
    # "gibt es pkgs.foo ueberhaupt?" und "heisst die Option wirklich so?".
    nixd = {
      enable = true;

      config.settings.nixd = {
        # Woher die Paketnamen kommen.
        #
        # Die nixd-Doku schlaegt `import <nixpkgs> { }` vor -- das geht hier
        # NICHT verlaesslich: <nixpkgs> kommt aus NIX_PATH, und auf einem
        # reinen Flake-System ist der oft leer oder zeigt auf einen alten
        # Channel. Stattdessen direkt der nixpkgs-Input DIESER Flake, damit
        # der Editor exakt die Paketmenge kennt, gegen die auch gebaut wird.
        nixpkgs.expr = ''import (builtins.getFlake "/etc/nixos").inputs.nixpkgs { }'';

        # Woher die Optionsnamen kommen.
        #
        # Der Ausdruck muss den HOSTNAMEN enthalten, und diese Datei ist
        # shared (fabricus und fabricus-itinerans lesen sie beide). Deshalb
        # wird er zur Laufzeit in Lua zusammengesetzt statt in Nix fixiert --
        # `__raw` heisst: nixvim gibt den Inhalt unveraendert als Lua-Code aus,
        # statt ihn als String zu quoten.
        #
        # Innen bewusst einfache Anfuehrungszeichen: Lua akzeptiert beide, und
        # so bleiben die doppelten fuer den Nix-Ausdruck frei -- ohne eine
        # einzige Escape-Sequenz.
        options.nixos.expr.__raw = ''
          '(builtins.getFlake "/etc/nixos").nixosConfigurations.' .. vim.uv.os_gethostname() .. '.options'
        '';

        # BEWUSST NICHT gesetzt: options.home_manager.
        # Der uebliche Ausdruck dafuer zeigt auf `homeConfigurations."user@host"`
        # -- die gibt es hier nicht. home-manager laeuft in dieser Flake als
        # NixOS-Modul (siehe flake.nix, mkHost), nicht standalone. Ein Ausdruck
        # ins Leere wuerde nixd nur bei jedem Start einen Evaluierungsfehler
        # bescheren. home-manager-Optionen bleiben damit unvervollstaendigt.

        # Formatierer fuer `vim.lsp.buf.format`. nixpkgs-fmt und nicht das
        # neuere nixfmt, weil flake.nix genau das als `formatter` gesetzt hat
        # -- sonst formatiert der Editor anders als `nix fmt` im selben Repo.
        formatting.command = [ "nixpkgs-fmt" ];
      };
    };

    # Lua. Zwei Gruende: das Cheatsheet-Plugin von noctalia ist Lua, und die
    # Hyprland-Migration nach Lua steht bei dir auf der Liste.
    lua_ls = {
      enable = true;

      # config landet 1:1 in vim.lsp.config. Ohne diese Zeile meldet lua_ls in
      # jeder nvim- oder Hyprland-Lua-Datei "Undefined global `vim`" --
      # `vim` existiert nur zur Laufzeit im Editor, der Server kann es nicht
      # wissen. Die Warnung waere korrekt und trotzdem nur Laerm.
      config.settings.Lua.diagnostics.globals = [ "vim" ];
    };
  };

  # ---------------------------------------------------------------------------
  # Was der Server dir sagt -- Darstellung der Diagnostics
  # ---------------------------------------------------------------------------
  # Das hier ist der Grund, warum dir bisher "keine Fehler angezeigt" wurden --
  # ab nvim 0.11 ist virtual_text NICHT mehr Standard. Ohne diesen Block
  # bekaemst du zwar Zeichen am Rand, aber keinen Text neben der Zeile.
  diagnostic.settings = {
    # Fehlertext direkt hinter der betroffenen Zeile.
    virtual_text = true;

    # Zeichen in der Signspalte -- der Spalte, die Schicht 1 reserviert hat.
    signs = true;

    # Bei mehreren Meldungen auf einer Zeile die schlimmste zuerst. Ohne das
    # verdeckt gelegentlich ein Hinweis einen echten Fehler.
    severity_sort = true;

    # Nicht waehrend des Tippens neu bewerten, sondern beim Verlassen des
    # Insert-Modus. Verhindert, dass eine halbfertige Zeile rot blinkt.
    update_in_insert = false;
  };

  # ---------------------------------------------------------------------------
  # Tastenbelegung -- gilt nur, wenn ein Server am Puffer haengt
  # ---------------------------------------------------------------------------
  # lsp.keymaps wird beim Attach registriert, also puffer-lokal. In einer
  # Textdatei ohne Server bleibt `gd` damit das normale vim-`gd`.
  #
  # lspBufAction ist eine Abkuerzung: der Eintrag wird zu vim.lsp.buf.<action>.
  lsp.keymaps = [
    {
      key = "gd";
      lspBufAction = "definition";
      options.desc = "Zur Definition";
    }
    {
      key = "gr";
      lspBufAction = "references";
      options.desc = "Alle Verwendungen";
    }
    {
      key = "gi";
      lspBufAction = "implementation";
      options.desc = "Zur Implementierung";
    }
    {
      key = "gy";
      lspBufAction = "type_definition";
      options.desc = "Zur Typdefinition";
    }
    # K ist vim-Konvention: normalerweise die man-Page zum Wort unterm Cursor,
    # mit LSP die Signatur samt Dokumentation. Zweimal K springt ins Fenster.
    {
      key = "K";
      lspBufAction = "hover";
      options.desc = "Dokumentation";
    }
    # Umbenennen ueber ALLE Dateien des Projekts, nicht nur die offene. Das ist
    # der Griff, den ein :%s/// nicht ersetzen kann -- der Server weiss, welches
    # `user` dieselbe Variable meint und welches nur gleich heisst.
    {
      key = "<leader>cr";
      lspBufAction = "rename";
      options.desc = "Umbenennen (projektweit)";
    }
    # Was der Server anzubieten hat: Import ergaenzen, unbenutzte Variable
    # entfernen, Typ automatisch einsetzen. Lohnt sich, bei jedem Fehler
    # einmal zu druecken.
    {
      key = "<leader>ca";
      lspBufAction = "code_action";
      options.desc = "Code-Aktion";
    }
  ];

  # Sprung zwischen Fehlern. Bewusst GLOBAL und nicht in lsp.keymaps: auch ohne
  # Sprachserver koennen Diagnostics im Puffer stehen (ab Schicht 5 z.B. vom
  # Linter), und dann soll die Taste trotzdem gehen.
  #
  # ]d / [d folgt demselben Muster wie ]h / [h aus Schicht 2 -- ] vorwaerts,
  # [ rueckwaerts.
  #
  # vim.diagnostic.jump statt goto_next/goto_prev: die beiden alten Funktionen
  # sind seit nvim 0.11 als veraltet markiert.
  keymaps = [
    {
      mode = "n";
      key = "]d";
      action = "<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<CR>";
      options.desc = "Naechster Fehler";
    }
    {
      mode = "n";
      key = "[d";
      action = "<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<CR>";
      options.desc = "Voriger Fehler";
    }
    # Die volle Meldung in einem Fenster -- fuer die Faelle, in denen der
    # virtual_text rechts abgeschnitten ist.
    {
      mode = "n";
      key = "<leader>cd";
      action = "<cmd>lua vim.diagnostic.open_float()<CR>";
      options.desc = "Fehler im Detail";
    }
  ];

  # ---------------------------------------------------------------------------
  # blink.cmp -- die Vorschlagsliste
  # ---------------------------------------------------------------------------
  # Vervollstaendigung waehrend des Tippens. blink statt des aelteren nvim-cmp:
  # die Suche laeuft in Rust statt Lua, was auf dem T480 zaehlt, und es bringt
  # Quellen, Snippets und Signaturhilfe schon mit -- bei nvim-cmp waere jede
  # Quelle ein eigenes Plugin.
  plugins.blink-cmp = {
    enable = true;

    settings = {
      # super-tab: Tab nimmt den markierten Vorschlag an, solange die Liste
      # offen ist, und ist sonst ein normaler Tab. Bewusst nicht "enter" --
      # dabei akzeptiert Enter den Vorschlag, was beim schnellen Schreiben
      # ungewollt Zeilenumbrueche frisst.
      # Navigieren in der Liste mit <C-n>/<C-p>, abbrechen mit <C-e>.
      keymap.preset = "super-tab";

      # Signatur der Funktion einblenden, waehrend du die Argumente tippst.
      signature.enabled = true;

      completion = {
        # Doku zum markierten Eintrag automatisch daneben zeigen, statt sie
        # erst auf Tastendruck zu holen.
        documentation.auto_show = true;
      };

      appearance = {
        # Die Icons vor den Eintraegen kommen aus der Nerd-Font, die ihr
        # ohnehin systemweit habt (JetBrainsMono Nerd Font aus
        # modules/system-base.nix). "normal" = einfache Zeichenbreite; bei
        # "mono" waeren die Icons schmaler, was in kitty falsch ausgerichtet
        # aussehen kann.
        nerd_font_variant = "normal";
      };
    };
  };
}
