# nvim -- SCHICHT 3: Navigation.
#
# Bis hierher konntest du eine Datei bearbeiten, die schon offen ist. Diese
# Schicht beantwortet die Frage davor: WELCHE Datei, und wo steht das, was ich
# suche.
#
# Zwei Werkzeuge fuer zwei verschiedene Fragen:
#   telescope  "ich weiss ungefaehr WAS ich suche"  -> tippen, filtern, springen
#   oil        "ich will sehen WAS DA IST"          -> Verzeichnis durchgehen
#
# Eingehaengt von ./config.nix.
{ pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # telescope -- Fuzzy-Finder
  # ---------------------------------------------------------------------------
  # Ein Fenster mit Eingabezeile, Trefferliste und Vorschau. Du tippst
  # Bruchstuecke ("usrctr" findet "UserController"), die Liste filtert sich
  # live, Enter springt hin.
  #
  # Der wichtigste Eintrag ist <leader>fg (live_grep): Volltextsuche ueber das
  # ganze Projekt, waehrend du tippst. Das ersetzt den Wechsel ins Terminal
  # fuer `rg irgendwas` -- inklusive Sprung an die Fundstelle.
  plugins.telescope = {
    enable = true;

    extensions = {
      # Sortierung in C statt Lua. Merkbar, sobald ein Projekt ein paar tausend
      # Dateien hat -- und auf dem T480 lohnt jede eingesparte Rechnung.
      #
      # Auf anderen Distributionen ist das die Stelle, an der man ein
      # `make`-Kommando ausfuehren muss; hier ist es eine fertige Ableitung.
      fzf-native.enable = true;
    };

    # telescope bringt eine eigene keymaps-Option mit: links die Taste, rechts
    # der Name des "Pickers". Das ist kuerzer und weniger fehleranfaellig als
    # der Umweg ueber <cmd>Telescope ...<CR> in den globalen keymaps.
    keymaps = {
      "<leader>ff" = {
        action = "find_files";
        options.desc = "Dateien";
      };
      "<leader>fg" = {
        action = "live_grep";
        options.desc = "Text im Projekt";
      };
      "<leader>fb" = {
        action = "buffers";
        options.desc = "Offene Puffer";
      };
      "<leader>fr" = {
        action = "oldfiles";
        options.desc = "Zuletzt geoeffnet";
      };
      # Sucht das Wort, auf dem der Cursor steht -- ohne es abzutippen.
      "<leader>fw" = {
        action = "grep_string";
        options.desc = "Wort unter Cursor";
      };
      # Durchsucht die eingebaute Hilfe. Zusammen mit den farbigen vimdoc-
      # Dateien aus Schicht 2 der schnellste Weg, etwas ueber vim selbst
      # nachzuschlagen.
      "<leader>fh" = {
        action = "help_tags";
        options.desc = "Hilfe durchsuchen";
      };
      # Listet ALLE aktiven Keymaps, durchsuchbar. Das ist die Nachschlage-
      # Variante zu which-key: which-key zeigt, was JETZT geht, das hier
      # beantwortet "gab es da nicht was mit...?".
      "<leader>fk" = {
        action = "keymaps";
        options.desc = "Keymaps durchsuchen";
      };
    };
  };

  # ripgrep und fd explizit fuer nvim bereitstellen.
  #
  # In deiner Shell liegen beide laengst (home/bfn.nix), telescope wuerde also
  # so oder so funktionieren. Der Grund steht trotzdem hier: das
  # Standalone-Paket aus flake.nix (`nix run /etc/nixos#nvim`) laeuft OHNE
  # home-manager-Umgebung. Ohne diese Zeile faende live_grep dort kein rg und
  # meldete nur "no results" -- ein Fehler, der wie ein leeres Projekt aussieht.
  #
  # telescope selbst deklariert als Abhaengigkeit nur `bat` (fuer die Vorschau).
  extraPackages = [
    pkgs.ripgrep
    pkgs.fd
  ];

  # ---------------------------------------------------------------------------
  # oil -- Verzeichnisse als Text
  # ---------------------------------------------------------------------------
  # Bewusst KEIN Sidebar-Dateibaum (neo-tree, nvim-tree). oil oeffnet ein
  # Verzeichnis als ganz normalen Puffer: eine Zeile pro Eintrag. Umbenennen
  # heisst Zeile editieren, Loeschen heisst Zeile loeschen, Anlegen heisst neue
  # Zeile -- und `:w` fuehrt es aus.
  #
  # Das passt zu deinem Setup: du benutzt bewusst yazi statt eines GUI-
  # Dateimanagers, und massenhaftes Umbenennen mit vim-Bordmitteln (Makro,
  # Visual-Block, :s) ist genau das, was ein Sidebar-Baum nicht kann.
  #
  # oil ersetzt netrw (nvims eingebauten Explorer) per Default -- ein
  # aufgerufenes Verzeichnis landet also automatisch in oil.
  plugins.oil.enable = true;

  # ---------------------------------------------------------------------------
  # neo-tree -- die Seitenleiste
  # ---------------------------------------------------------------------------
  # Der klassische Dateibaum links. Ergaenzt oil, ersetzt es nicht: oil ist zum
  # ARBEITEN in einem Verzeichnis (umbenennen, loeschen als Text), neo-tree zum
  # UEBERBLICKEN eines Projekts -- Baum aufklappen, sehen wo was liegt,
  # nebenbei den Git-Status jeder Datei ablesen.
  plugins.neo-tree = {
    enable = true;

    settings = {
      # Fenster schliessen, wenn der Baum das letzte offene ist. Ohne das
      # bleibt beim Beenden eine leere Seitenleiste stehen.
      close_if_last_window = true;

      filesystem = {
        # WICHTIG, sonst streiten sich zwei Plugins um dieselbe Aufgabe:
        # neo-tree wuerde per Default netrw kapern ("open_default") und damit
        # jedes geoeffnete Verzeichnis an sich ziehen -- genau das macht aber
        # schon oil (Schicht 3, `-`). Wer gewinnt, haengt sonst an der
        # Ladereihenfolge, was ein schoen unzuverlaessiger Fehler waere.
        #
        # "disabled" heisst: neo-tree kommt NUR, wenn du es rufst.
        hijack_netrw_behavior = "disabled";

        # Der Baum markiert automatisch die Datei, in der du gerade bist --
        # praktisch, wenn du per Fuzzy-Finder irgendwohin gesprungen bist und
        # wissen willst, wo das im Projekt liegt.
        # leave_dirs_open: dabei aufgeklappte Ordner bleiben offen, statt
        # hinter dir wieder zuzuklappen.
        follow_current_file = {
          enabled = true;
          leave_dirs_open = true;
        };

        # Per Default koppelt neo-tree seine Wurzel an vims Arbeitsverzeichnis
        # -- in BEIDE Richtungen. Es wuerde also beim Oeffnen den cwd
        # umsetzen, und damit stillschweigend aendern, wo telescope sucht.
        # Hier bewusst aus: die Tasten unten geben das Verzeichnis explizit
        # vor, und sonst aendert sich nichts hinter deinem Ruecken.
        bind_to_cwd = false;
      };
    };
  };

  keymaps = [
    # `-` ist die oil-Konvention: oeffnet das VERZEICHNIS der aktuellen Datei,
    # mit dem Cursor auf ihr. Danach nochmal `-` geht eine Ebene hoeher.
    # Zurueck zur Datei mit <C-o> (vims Sprungliste, kein oil-Feature).
    {
      mode = "n";
      key = "-";
      action = "<cmd>Oil<CR>";
      options.desc = "Verzeichnis oeffnen (oil)";
    }

    # --- Seitenleiste ---
    # Zwei Tasten, zwei Wurzeln -- dieselbe Aufteilung wie in LazyVim:
    #
    #   <leader>e  Wurzel = PROJEKT. vim.fs.root sucht vom aktuellen Puffer
    #              aufwaerts das erste Verzeichnis mit `.git` -- also das
    #              Repo, egal wie tief du gerade drinsteckst. Gibt es keins
    #              (Datei ausserhalb eines Repos), faellt es auf den cwd
    #              zurueck, statt gar nichts zu tun.
    #
    #   <leader>E  Wurzel = ARBEITSVERZEICHNIS, also der Ordner, in dem du
    #              nvim gestartet hast. Der Unterschied faellt genau dann auf,
    #              wenn du nvim in einem Unterordner startest oder eine Datei
    #              ausserhalb des Repos offen hast.
    #
    # `toggle` heisst: dieselbe Taste schliesst die Leiste wieder.
    # `reveal` deckt die aktuelle Datei im Baum auf und stellt den Cursor
    # darauf.
    {
      mode = "n";
      key = "<leader>e";
      action.__raw = ''
        function()
          local root = vim.fs.root(0, ".git") or vim.uv.cwd()
          vim.cmd("Neotree toggle reveal dir=" .. vim.fn.fnameescape(root))
        end
      '';
      options.desc = "Seitenleiste (Projekt)";
    }
    {
      mode = "n";
      key = "<leader>E";
      action.__raw = ''
        function()
          vim.cmd("Neotree toggle reveal dir=" .. vim.fn.fnameescape(vim.uv.cwd()))
        end
      '';
      options.desc = "Seitenleiste (Arbeitsverzeichnis)";
    }
  ];
}
