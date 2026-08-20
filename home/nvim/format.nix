# nvim -- SCHICHT 5: Formatieren und Linten.
#
# Die letzte Schicht der Grundausstattung. Zwei Dinge, die oft verwechselt
# werden:
#
#   FORMATIEREN  Wie der Code AUSSIEHT -- Einrueckung, Zeilenumbrueche,
#                Anfuehrungszeichen. Aendert nie die Bedeutung.
#   LINTEN       Was am Code FRAGWUERDIG ist -- unbenutzter Import, Variable
#                nie gelesen, gefaehrliches Muster. Aendert nichts, meldet nur.
#
# Formatieren macht hier conform, Linten machen zwei zusaetzliche
# Sprachserver. Das ist bewusst KEINE zweite Lint-Infrastruktur (nvim-lint o.ae.):
# Server bedeutet, die Meldungen laufen durch denselben Kanal wie die
# Typfehler aus Schicht 4 -- gleiche Darstellung, und ]d / [d springt ohne
# jede Zusatzarbeit auch durch Lint-Meldungen.
#
# Eingehaengt von ./config.nix.
{
  # ---------------------------------------------------------------------------
  # Linten ueber Sprachserver
  # ---------------------------------------------------------------------------
  lsp.servers = {
    # Python-Linter (und Formatierer, aber formatieren laesst hier conform).
    # ruff ergaenzt basedpyright, es ersetzt ihn nicht: basedpyright prueft
    # TYPEN, ruff prueft STIL und Fehlermuster (unbenutzte Importe, Shadowing,
    # totes except). Die beiden treten sich nicht auf die Fuesse.
    ruff.enable = true;

    # ESLint. Startet nur, wenn das Projekt eine eslint-Konfiguration hat --
    # in einem Projekt ohne eslint passiert also schlicht nichts, und das ist
    # richtig so. Paket: vscode-langservers-extracted.
    eslint.enable = true;
  };

  # ---------------------------------------------------------------------------
  # conform -- Formatieren
  # ---------------------------------------------------------------------------
  plugins.conform-nvim = {
    enable = true;

    # Holt die unten genannten Formatierer selbst aus nixpkgs und legt sie in
    # den PATH des Editors. Ohne das muesste jeder einzeln in extraPackages --
    # und ein fehlender faellt erst beim Speichern auf.
    autoInstall.enable = true;

    settings = {
      # Welcher Formatierer fuer welchen Dateityp.
      #
      # Die Namen sind conform-INTERN und nicht immer der Paketname
      # (`nixpkgs_fmt` mit Unterstrich, nicht `nixpkgs-fmt`). Alle unten sind
      # gegen conforms formatters/-Verzeichnis geprueft.
      formatters_by_ft = {
        # Die JS/TS-Familie samt allem, was prettier ohnehin kann.
        javascript = [ "prettier" ];
        javascriptreact = [ "prettier" ];
        typescript = [ "prettier" ];
        typescriptreact = [ "prettier" ];
        json = [ "prettier" ];
        jsonc = [ "prettier" ];
        css = [ "prettier" ];
        scss = [ "prettier" ];
        html = [ "prettier" ];
        yaml = [ "prettier" ];
        markdown = [ "prettier" ];

        # Python: ruffs Formatierer, nicht black. Gleiches Ergebnis in fast
        # allen Faellen, aber es ist dasselbe Werkzeug, das oben schon linted
        # -- ein Programm weniger im Spiel.
        python = [ "ruff_format" ];

        # Nix: nixpkgs_fmt, passend zu `formatter` in flake.nix und zu dem,
        # was nixd als formatting.command bekommt. Alle drei Wege muessen
        # dasselbe Werkzeug nehmen, sonst formatieren sie gegeneinander.
        nix = [ "nixpkgs_fmt" ];

        lua = [ "stylua" ];

        # Fallback fuer ALLE uebrigen Dateitypen (der Unterstrich ist conforms
        # Platzhalter). Kein echter Formatierer, nur zwei harmlose Aufraeumer:
        # Leerzeichen am Zeilenende weg, Leerzeilen am Dateiende weg.
        # Genau die Aenderungen, die sonst als Rauschen im git-diff landen.
        "_" = [
          "trim_whitespace"
          "trim_newlines"
        ];
      };

      # Beim Speichern formatieren.
      #
      # Bewusst eine FUNKTION und keine feste Tabelle: nur so laesst sich der
      # Schalter unten (<leader>cF) ueberhaupt abfragen. Mit einer festen
      # Tabelle formatiert conform immer -- der Umschalter waere dann eine
      # Taste, die sichtbar etwas meldet und nichts bewirkt.
      #
      # timeout_ms: prettier braucht auf dem T480 im ersten Lauf gern eine
      # Sekunde. Laeuft es laenger, bricht conform ab statt den Editor haengen
      # zu lassen -- gespeichert wird trotzdem, nur unformatiert.
      #
      # lsp_format = "fallback": gibt es fuer einen Dateityp KEINEN Eintrag
      # oben, darf stattdessen der Sprachserver formatieren (z.B. lua_ls).
      # Erst wenn auch der nichts kann, passiert nichts.
      #
      # vim.b[bufnr] wird mitgeprueft, damit sich die Automatik spaeter auch
      # fuer einen EINZELNEN Puffer abschalten laesst (:lua vim.b.disable_autoformat = true),
      # ohne sie global auszuschalten.
      format_on_save.__raw = ''
        function(bufnr)
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
          end
          return { timeout_ms = 3000, lsp_format = "fallback" }
        end
      '';
    };
  };

  keymaps = [
    # Von Hand formatieren -- fuer Dateien, bei denen das Speichern gerade
    # nicht formatieren soll, oder um nur einen markierten Bereich zu machen
    # (im visuellen Modus).
    {
      mode = [
        "n"
        "v"
      ];
      key = "<leader>cf";
      action = "<cmd>lua require('conform').format({ async = true, lsp_format = 'fallback' })<CR>";
      options.desc = "Formatieren";
    }

    # Automatik abschalten und wieder an.
    #
    # Der Fall dafuer kommt garantiert: ein fremdes Projekt ohne
    # prettier-Konfiguration, in dem dein Formatierer bei jedem Speichern die
    # halbe Datei umbaut und das git-diff unlesbar macht. Dann hier einmal
    # druecken, statt die Config anzufassen.
    #
    # vim.g.disable_autoformat ist keine eingebaute Variable, sondern ein
    # Schalter, den conform selbst abfragt -- so steht es in dessen Doku.
    # Gilt fuer die Sitzung, nicht dauerhaft.
    {
      mode = "n";
      key = "<leader>cF";
      action = "<cmd>lua vim.g.disable_autoformat = not vim.g.disable_autoformat; vim.notify('Auto-Format beim Speichern: ' .. (vim.g.disable_autoformat and 'AUS' or 'AN'))<CR>";
      options.desc = "Auto-Format umschalten";
    }
  ];
}
