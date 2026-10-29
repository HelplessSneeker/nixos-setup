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
let
  # jdtls-Einstellungen, zweimal gebraucht (siehe jdtls unten).
  javaSettings.java = {
    # Gegen welches JDK der Projektcode geprueft wird -- getrennt vom JDK, auf
    # dem jdtls selbst laeuft. Dasselbe pkgs.jdk21 wie programs.java in
    # home/bfn.nix, damit Editor und `mvn` dieselbe Standardbibliothek sehen.
    # Der Name muss exakt "JavaSE-21" lauten, jdtls kennt nur diese Bezeichner.
    configuration.runtimes = [
      {
        name = "JavaSE-21";
        path = "${pkgs.jdk21.home}";
        default = true;
      }
    ];
    # Quell-JARs der Abhaengigkeiten mitladen. Erst damit zeigt K auf
    # @SpringBootApplication die Javadoc und gd den echten Spring-Quelltext
    # statt einer dekompilierten Klasse ohne Kommentare.
    maven.downloadSources = true;
    # Inlay-Hints (siehe lsp.inlayHints unten): der Typ hinter `var` und
    # hinter Lambda-Parametern. Parameternamen bewusst AUS -- mit "literals"
    # bekaeme jedes println("...") ein `x:` davor, das ist Laerm.
    inlayHints = {
      variableTypes.enabled = true;
      parameterTypes.enabled = true;
      parameterNames.enabled = "none";
    };
  };

  # Was ts_ls als Inlay-Hint zeigt. Gilt fuer TypeScript und JavaScript gleich,
  # deshalb einmal hier und unten zweimal eingesetzt. Ohne diesen Block meldet
  # ts_ls GAR KEINE Hints -- anders als basedpyright, das von sich aus welche
  # schickt.
  tsInlayHints = {
    # Abgeleitete Typen dort, wo du keinen hingeschrieben hast:
    # `const user = await load()` bekommt grau `: User` dahinter.
    includeInlayVariableTypeHints = true;
    # ... aber nicht, wenn der Name es schon sagt (`const user: User`).
    includeInlayVariableTypeHintsWhenTypeMatchesName = false;
    includeInlayFunctionLikeReturnTypeHints = true;
    includeInlayPropertyDeclarationTypeHints = true;
    # Parameter von Callbacks: `.map((u) => ...)` zeigt den Typ von `u`.
    includeInlayFunctionParameterTypeHints = true;
    # Parameternamen AUS, wie bei Java. Getestet 29.10.2026: mit "literals"
    # steht vor jedem console.log("...") ein `...data:`.
    includeInlayParameterNameHints = "none";
    includeInlayEnumMemberValueHints = true;
  };
in
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
    ts_ls = {
      enable = true;
      config.settings = {
        typescript.inlayHints = tsInlayHints;
        javascript.inlayHints = tsInlayHints;
      };
    };

    # Angular (22.10.2026). Paket: angular-language-server, derselbe Server
    # wie in VS Codes Angular-Extension. Er versteht die Templates: Fehler wie
    # ein vertippter Property-Name schon im HTML, Vorschlaege fuer Signale und
    # Inputs, gd vom Template in die Komponente.
    #
    # Laeuft NEBEN ts_ls, nicht statt ihm: ts_ls macht das TypeScript,
    # angularls das, was Angular daraus macht. Er startet nur in einem Projekt
    # mit angular.json -- im Java-Backend passiert also nichts.
    #
    # Ohne `npm install` im Frontend findet er @angular/core nicht und meldet
    # nur Fehler, genau wie ts_ls. Den Angular-Sprachdienst bringt das Paket
    # selbst mit (Version 21.2), TypeScript nimmt er aus dem Projekt.
    angularls.enable = true;

    # CSS und SCSS, also die Styles der Komponenten: Vorschlaege fuer
    # Eigenschaften und Werte, Fehler bei Tippfehlern wie `colr`. Paket:
    # vscode-langservers-extracted, das ESLint aus Schicht 5 schon mitbringt.
    cssls.enable = true;

    # Reines HTML ausserhalb von Angular (29.10.2026): Vorschlaege fuer Tags
    # und Attribute, Fehler bei kaputtem Markup. Gleiches Paket wie cssls.
    # Angular-Templates (htmlangular) bleiben bei angularls -- html meldet sich
    # dort nicht, sonst kaeme jeder Vorschlag doppelt. Das Schliessen von Tags
    # macht nicht der Server, sondern ts-autotag in ./editing.nix.
    html.enable = true;

    # Emmet (29.10.2026): Kuerzel, die zu fertigem Markup werden.
    # `div.card>h2+ul>li*3` tippen, den Vorschlag mit Tab annehmen, und da
    # steht das komplette Geruest samt Einrueckung. `p.lead{Text}` fuellt auch
    # gleich den Inhalt. Laeuft als Sprachserver, deshalb erscheint das Ergebnis
    # als ganz normaler Eintrag in der blink-Liste -- keine eigene Taste.
    #
    # Dateitypen enger als die lspconfig-Vorgabe: dort sind auch css/scss
    # dabei, und dann schlaegt emmet bei jedem zweiten Buchstaben eine
    # CSS-Abkuerzung vor (`m` -> `margin: ;`). cssls kann das besser.
    emmet_language_server = {
      enable = true;
      config.filetypes = [
        "html"
        "htmlangular"
        "javascriptreact"
        "typescriptreact"
      ];
    };

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
      config.settings.Lua = {
        diagnostics.globals = [ "vim" ];
        # Ohne das schickt lua_ls keine Inlay-Hints.
        hint.enable = true;
      };
    };

    # Java. Paket: jdt-language-server (Eclipse JDT LS, das Herz von VS Codes
    # Java-Extension). Laeuft selbst auf dem JDK, das nixpkgs ihm fest
    # einbaut -- unabhaengig davon, welches java gerade im PATH steht.
    #
    # Bewusst der native Weg und NICHT nvim-jdtls, das sonst ueberall
    # empfohlen wird. nvim-jdtls startet den Server per ftplugin selbst, waere
    # also ein zweiter Mechanismus neben lsp.servers. Was es zusaetzlich kann
    # (Test-Runner, Debugger-Anbindung, Refactorings wie "Methode
    # extrahieren"), braucht das Bewerbungsprojekt erst mal nicht. Die eine
    # Luecke, die der native Weg hat, schliesst der autoCmd unter diesem
    # Block.
    #
    # Projektwurzel und Arbeitsverzeichnis regelt die Definition aus
    # nvim-lspconfig: Wurzel ist der Ordner mit mvnw/pom.xml, der Index pro
    # Projekt liegt unter ~/.cache/nvim/jdtls/workspace/<ordnername>. Haengt
    # der Server mal in einem kaputten Zustand: Ordner loeschen, nvim neu
    # starten. Maven-Projekte importiert jdtls von selbst.
    #
    # Der erste Start in einem Projekt dauert: jdtls laedt die Abhaengigkeiten
    # samt Quellen und baut den Index. Bis dahin keine Diagnostics -- kein
    # Fehler, nur Geduld (Fortschritt: :LspLog oder `:checkhealth vim.lsp`).
    jdtls = {
      enable = true;
      config = {
        init_options = {
          # Ohne das liefert jdtls fuer Spruenge in eine Bibliothek (gd auf
          # @SpringBootApplication) gar nichts. Mit ihm kommt eine jdt://-
          # Adresse zurueck -- die oeffnet der autoCmd unten.
          extendedClientCapabilities.classFileContentsSupport = true;
          # Schon beim Start, nicht erst per didChangeConfiguration danach --
          # sonst importiert jdtls das Projekt zweimal.
          settings = javaSettings;
        };
        settings = javaSettings;
      };
    };
  };

  # jdt://-Adressen oeffnen. Eine Klasse aus einem JAR ist keine Datei auf der
  # Platte; jdtls liefert ihren Quelltext auf Anfrage (java/classFileContents).
  # Ohne diesen Handler oeffnet gd auf eine Spring-Klasse einen leeren Puffer.
  # Genau das ist der Teil, den sonst nvim-jdtls mitbringt.
  #
  # buftype=nofile VOR filetype=java: vim.lsp.enable haengt Server nur an
  # Puffer mit echter Datei. Sonst startete fuer jeden geoeffneten JAR-Puffer
  # ein ZWEITER jdtls ohne Projekt. Stattdessen wird der laufende Server
  # angehaengt, damit K und gd auch in der Spring-Klasse weiter gehen.
  autoCmd = [
    {
      event = "BufReadCmd";
      pattern = "jdt://*";
      callback.__raw = ''
        function(args)
          local buf = args.buf
          local client = vim.lsp.get_clients({ name = "jdtls" })[1]
          vim.bo[buf].buftype = "nofile"
          vim.bo[buf].swapfile = false
          if not client then
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "// jdtls laeuft nicht" })
            return
          end
          local res = client:request_sync("java/classFileContents", { uri = args.match }, 10000, buf)
          local text = res and res.result
            or ("// jdtls lieferte keinen Quelltext: " .. vim.inspect(res and res.err))
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
          vim.bo[buf].modifiable = false
          vim.bo[buf].filetype = "java"
          vim.lsp.buf_attach_client(buf, client.id)
        end
      '';
    }
  ];

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
  # Inlay-Hints -- Typen und Parameternamen grau im Code
  # ---------------------------------------------------------------------------
  # Der Server schreibt, was er abgeleitet hat, direkt in die Zeile, ohne dass
  # es im Text steht: `const total = sum(items)` zeigt `: number`. Was genau
  # erscheint, stellt jeder Server selbst ein (tsInlayHints/javaSettings oben,
  # basedpyright von sich aus). An per Default, aus mit <leader>ct, wenn es
  # beim Lesen stoert.
  lsp.inlayHints.enable = true;

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
    # Imports der ganzen Datei in einem Griff: fehlende ergaenzen, unbenutzte
    # entfernen, sortieren. Was der jeweilige Server dafuer anbietet, ist
    # verschieden -- ts_ls hat drei getrennte Aktionen (addMissingImports,
    # removeUnusedImports, organizeImports; letzteres sortiert dort NUR),
    # jdtls macht mit organizeImports alles wie Eclipses Strg+Shift+O, ruff
    # sortiert nur. Die Funktion fragt deshalb nacheinander alle drei Arten bei
    # jedem Server an und nimmt, was kommt.
    #
    # Synchron statt ueber vim.lsp.buf.code_action: das waere asynchron, und
    # zwei Aufrufe hintereinander rechneten beide auf dem alten Text -- der
    # zweite wuerde den ersten zerschiessen.
    #
    # Ein einzelnes Import beim Tippen braucht diese Taste nicht: einen
    # Vorschlag aus der blink-Liste mit Tab annehmen, und die Import-Zeile
    # kommt mit. Ist das Wort schon ausgeschrieben und rot, <leader>ca auf ihm.
    {
      key = "<leader>ci";
      action.__raw = ''
        function()
          local buf = vim.api.nvim_get_current_buf()
          local last = vim.api.nvim_buf_line_count(buf)
          local done = 0
          for _, kind in ipairs({ "source.addMissingImports", "source.removeUnusedImports", "source.organizeImports" }) do
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, method = "textDocument/codeAction" })) do
              local res = client:request_sync("textDocument/codeAction", {
                textDocument = vim.lsp.util.make_text_document_params(buf),
                range = { start = { line = 0, character = 0 }, ["end"] = { line = last, character = 0 } },
                context = { only = { kind }, diagnostics = {}, triggerKind = 1 },
              }, 5000, buf)
              for _, action in ipairs(res and res.result or {}) do
                if action.kind and (action.kind == kind or vim.startswith(action.kind, kind .. ".")) then
                  if not action.edit and not action.command and client:supports_method("codeAction/resolve") then
                    local r = client:request_sync("codeAction/resolve", action, 5000, buf)
                    action = r and r.result or action
                  end
                  if action.edit then
                    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
                  end
                  local cmd = action.command
                  if type(cmd) == "table" then
                    client:exec_cmd(cmd, { bufnr = buf })
                  end
                  done = done + 1
                end
              end
            end
          end
          if done == 0 then
            vim.notify("Kein Server bietet hier Import-Aktionen an", vim.log.levels.INFO)
          end
        end
      '';
      options.desc = "Imports ergaenzen + aufraeumen";
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
    # Inlay-Hints an/aus, fuer alle Puffer. Bewusst global statt pro Puffer:
    # wer sie beim Lesen stoerend findet, findet sie es in der naechsten Datei
    # auch.
    {
      mode = "n";
      key = "<leader>ct";
      action = "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>";
      options.desc = "Typen einblenden an/aus";
    }
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
