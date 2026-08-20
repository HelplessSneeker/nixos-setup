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
  ];
}
