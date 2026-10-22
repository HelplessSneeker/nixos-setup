# nvim -- SCHICHT 2: Sichtbarkeit.
#
# Vier Plugins, die alle dasselbe tun: sie zeigen dir etwas, das nvim schon
# weiss, aber bisher fuer sich behalten hat. Keins davon aendert, WIE du
# tippst -- das war Schicht 1. Deshalb sind sie zusammen eine Schicht.
#
# Eingehaengt von ./config.nix, gilt also fuer beide Wege (home-manager und
# `nix run /etc/nixos#nvim`).
{ config, ... }:
{
  # ---------------------------------------------------------------------------
  # Treesitter -- echtes Syntax-Highlighting
  # ---------------------------------------------------------------------------
  # Bisher faerbt nvim per Regex: es sucht Muster im Text und rät. Treesitter
  # parst die Datei stattdessen zu einem Syntaxbaum. Der Unterschied ist am
  # deutlichsten dort, wo Regex prinzipiell scheitert -- verschachtelte
  # Template-Strings, JSX, eingebettetes SQL, Markdown mit Codebloecken.
  #
  # Auf NixOS ist das der bequeme Fall: die Parser sind vorkompilierte
  # Ableitungen aus nixpkgs. Nicht-Nix-Setups lassen nvim die Parser beim
  # ersten Oeffnen mit gcc bauen -- das ist die Stelle, an der Mason-basierte
  # Konfigurationen hier scheitern.
  plugins.treesitter = {
    enable = true;

    # Das eigentliche Feature.
    highlight.enable = true;

    # Einruecken anhand des Syntaxbaums statt per Heuristik. Bewusst AN, aber
    # als erster Verdaechtiger vermerkt: falls sich `=` oder `o` in einer
    # Sprache je falsch anfuehlt, hier testweise auf false.
    indent.enable = true;

    # Falten NICHT aktiviert (Default). Treesitter-Folding ist gut, aber es
    # klappt beim Oeffnen erstmal alles zu, was ohne Gewoehnung irritiert.
    # Wenn du es willst: folding.enable = true;

    # --- Welche Sprachen ---
    # Der Default waere `package.allGrammars` -- rund 300 Parser, mehrere
    # hundert MB Store. Hier stattdessen eine Auswahl, die deinen Alltag
    # abdeckt.
    #
    # Fehlt eine Sprache, ist das KEIN Fehler: Treesitter faellt fuer diese
    # Datei still auf das alte Regex-Highlighting zurueck. Nachtragen ist
    # eine Zeile -- Namen stehen in nixpkgs unter
    # pkgs/applications/editors/vim/plugins/nvim-treesitter/generated.nix
    # (alle unten sind dagegen geprueft).
    grammarPackages =
      let
        g = config.plugins.treesitter.package.grammarPlugins;
      in
      [
        # Deine Sprachen
        g.typescript
        g.tsx # eigener Parser, NICHT in typescript enthalten
        g.javascript
        g.python

        # Was du taeglich editierst
        g.nix
        g.lua # auch die Voraussetzung fuer die Hyprland-Lua-Migration
        g.bash

        # Doku und Konfiguration
        g.markdown
        g.markdown_inline # Inline-Spans; markdown allein faerbt nur Bloecke
        g.json
        g.yaml
        g.toml
        g.dockerfile
        # HTML mitten in Markdown (<!-- Kommentare -->, <br>). Ohne den Parser
        # laesst render-markdown (unten) solche Stellen roh stehen.
        g.html

        # Git -- greift, wenn nvim als $EDITOR fuer commit/rebase aufgeht
        g.gitcommit
        g.git_config
        g.diff

        # nvim selbst: vimdoc faerbt die eingebaute Hilfe (:help), query die
        # Treesitter-Abfragen, regex wird von anderen Parsern als Injection
        # benutzt (z.B. ein Regex-Literal in JS).
        g.vim
        g.vimdoc
        g.query
        g.regex
      ];
  };

  # ---------------------------------------------------------------------------
  # render-markdown -- Markdown gerendert statt als Quelltext (22.10.2026)
  # ---------------------------------------------------------------------------
  # Ueberschriften, Tabellen, Checkboxen, Codebloecke, Obsidian-Callouts
  # (> [!note]) und [[Wikilinks]] erscheinen im Puffer so, wie sie gemeint
  # sind -- wie die Live-Vorschau in Obsidian. Die Datei bleibt dabei
  # unveraendert, das Plugin legt nur Markierungen ueber den Text. Es baut auf
  # den markdown-Parsern von Treesitter oben auf.
  #
  # preset = "obsidian" heisst: in jedem Modus rendern, auch beim Tippen. Roh
  # bleibt nur die Zeile mit dem Cursor, damit du siehst, was du schreibst.
  # Ohne das Preset waere im Insert-Mode die ganze Datei roh.
  # Fuer eine Sitzung abschalten: `:RenderMarkdown toggle`.
  #
  # Eine Grenze setzt nvim selbst, kein Plugin kommt drumherum: mit `wrap`
  # (Schicht 1) bricht verdeckter Text an der alten Stelle um. Tabellen mit
  # Links sehen dann zerrupft aus -- `:set nowrap` fuer die Sitzung hilft.
  plugins.render-markdown = {
    enable = true;

    settings = {
      preset = "obsidian";

      # Vorschlaege fuer Checkboxen (- [ ]) und Callouts (> [!...]) in der
      # blink-Liste aus Schicht 4. Laeuft als eingebauter Sprachserver, der
      # nur an Markdown-Puffern haengt -- blink braucht dafuer nichts extra.
      completions.lsp.enabled = true;

      # Formeln ($...$) braeuchten ein externes Konvertierprogramm (utftex
      # oder latex2text). Ohne eins warnt :checkhealth bei jedem Aufruf, und
      # gerendert wuerde trotzdem nichts.
      latex.enabled = false;
    };
  };

  # ---------------------------------------------------------------------------
  # which-key -- zeigt dir deine eigenen Tastenkuerzel
  # ---------------------------------------------------------------------------
  # Nach <leader> (Space) und kurzem Zoegern klappt ein Fenster auf und listet,
  # was jetzt gedrueckt werden kann -- mit genau den Beschreibungen, die in
  # jedem Keymap unter options.desc stehen.
  #
  # Fuer dich ist das der eigentliche Hebel dieser Schicht: ab Schicht 4 kommen
  # ein paar Dutzend Bindings dazu, und du lernst sie beim Benutzen statt sie
  # auswendig zu koennen.
  #
  # Anders als dein Hyprland-Cheatsheet liest which-key die Keymaps ZUR
  # LAUFZEIT aus nvim. Es kann also nicht veralten -- der Neu-lade-Fallstrick
  # von dort existiert hier nicht.
  plugins.which-key = {
    enable = true;

    settings = {
      # Wartezeit bis das Fenster kommt. Das ist NICHT timeoutlen (300 ms aus
      # Schicht 1) -- which-key hat eine eigene, kuerzere Verzoegerung, damit
      # das Fenster nicht bei jedem fluessig getippten Kuerzel aufblitzt.
      delay = 250;

      # Gruppen benennen. Ohne das zeigt which-key bei <leader>h nur "+2 keys"
      # -- mit Namen steht dort "Git-Hunks". Zahlt sich mit jeder weiteren
      # Schicht mehr aus.
      #
      # __unkeyed-1 ist eine nixvim-Konvention, keine Marotte: which-key
      # erwartet in Lua eine Tabelle, in der die Taste OHNE Schluessel steht
      # ({ "<leader>h", group = "..." }). Nix kennt keine gemischten
      # Listen/Records, deshalb dieser Platzhaltername -- er wird beim
      # Erzeugen des Lua-Codes wieder entfernt.
      # ALLE Gruppen stehen hier, auch die fuer Plugins aus anderen Schichten
      # (z.B. <leader>f aus finder.nix). Das ist Absicht und kein Schlamperei:
      # `settings` ist ein freeform-Attrset vom Typ `anything`, und der kann
      # Listen aus zwei Modulen NICHT zusammenfuehren -- eine zweite
      # spec-Definition in einer anderen Datei gaebe einen Konflikt beim Eval.
      # Eine Liste, ein Ort.
      spec = [
        {
          __unkeyed-1 = "<leader>b";
          group = "Tabs";
        }
        {
          __unkeyed-1 = "<leader>c";
          group = "Code";
        }
        {
          __unkeyed-1 = "<leader>f";
          group = "Finden";
        }
        {
          __unkeyed-1 = "<leader>h";
          group = "Git-Hunks";
        }
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # lualine -- Statuszeile
  # ---------------------------------------------------------------------------
  # Modus, Dateiname, Git-Branch, Position. Der praktische Nutzen ist der
  # Modus-Indikator: du bist nie im Zweifel, ob dein Tippen gerade Text
  # schreibt oder Kommandos ausloest.
  #
  # settings bleibt leer -- die Vorgaben sind gut, und theme faellt automatisch
  # auf das aktive Farbschema (catppuccin). Eigene Sektionen lohnen erst,
  # wenn es etwas anzuzeigen gibt, das noch fehlt (z.B. LSP-Status ab
  # Schicht 4).
  plugins.lualine.enable = true;

  # Dateityp-Icons (die kleinen Symbole vor Dateinamen in telescope, lualine
  # und oil). Kommt aus der Nerd-Font, die systemweit ohnehin installiert ist.
  #
  # EXPLIZIT gesetzt, obwohl telescope es auch selbst aktivieren wuerde: genau
  # diese automatische Aktivierung ist in nixvim deprecated und warnt bei jedem
  # Eval ("This plugin was enabled automatically ... This behaviour is
  # deprecated"). Aufgefallen beim Eval-Test zu Schicht 4 -- eingeschleppt hat
  # es Schicht 3.
  plugins.web-devicons.enable = true;

  # ---------------------------------------------------------------------------
  # bufferline -- Tabs oben (16.10.2026)
  # ---------------------------------------------------------------------------
  # Eine Leiste mit allen offenen Dateien, wie die Tabs in IntelliJ/VS Code.
  # Technisch sind das vims PUFFER, nicht vims eigene Tabs (:tabnew): die sind
  # in vim ganze Fensteranordnungen, nicht "eine Datei pro Reiter" -- wer sie
  # als Datei-Tabs benutzt, kaempft gegen den Editor.
  #
  # Jede Datei, die du oeffnest (gd, telescope, neo-tree), bekommt damit einen
  # Reiter. Tasten unten bei den keymaps: <S-h>/<S-l> blaettern, <leader>bd
  # schliesst.
  plugins.bufferline = {
    enable = true;
    settings.options = {
      # Fehler/Warnungen vom Sprachserver als Zahl am Reiter.
      diagnostics = "nvim_lsp";

      # Ueber der neo-tree-Seitenleiste keinen Reiter zeichnen, sondern die
      # Leiste dort einruecken -- sonst klebt der erste Tab ueber dem Baum.
      offsets = [
        {
          filetype = "neo-tree";
          text = "Dateien";
          highlight = "Directory";
          text_align = "left";
          separator = true;
        }
      ];

      # Das x am Reiter (Maus) schliesst ueber mini.bufremove, siehe unten.
      close_command.__raw = ''function(n) require("mini.bufremove").delete(n, false) end'';
      right_mouse_command.__raw = ''function(n) require("mini.bufremove").delete(n, false) end'';
    };
  };

  # Puffer schliessen, OHNE das Fenster zu schliessen. Vims :bdelete nimmt das
  # Fenster mit, wenn darin die letzte Datei war -- mit der neo-tree-Leiste
  # daneben bliebe dann nur noch der Baum uebrig, ueber die ganze Breite.
  # mini.bufremove zeigt stattdessen den naechsten Puffer im selben Fenster.
  plugins.mini-bufremove.enable = true;

  # ---------------------------------------------------------------------------
  # gitsigns -- Aenderungen am Rand
  # ---------------------------------------------------------------------------
  # Zeigt pro Zeile, was sich gegenueber dem letzten Commit geaendert hat, in
  # der Signspalte -- also genau in der Spalte, die Schicht 1 schon fest
  # reserviert hat (signcolumn = "yes"). Deshalb springt hier auch nichts, wenn
  # die Zeichen auftauchen.
  plugins.gitsigns.enable = true;

  # Keymaps zu gitsigns. Bewusst hier und nicht in config.nix: sie gehoeren
  # zum Plugin, und wenn das Plugin je rausfliegt, geht die passende
  # Tastenbelegung mit derselben Datei.
  #
  # ]h / [h folgt der vim-Konvention "] = naechstes, [ = voriges" (wie ]c bei
  # diff oder ]q in der Quickfix-Liste). Ab Schicht 4 kommt ]d/[d fuer
  # Diagnostics dazu -- dasselbe Muster.
  keymaps = [
    {
      mode = "n";
      key = "]h";
      action = "<cmd>Gitsigns next_hunk<CR>";
      options.desc = "Naechste Aenderung";
    }
    {
      mode = "n";
      key = "[h";
      action = "<cmd>Gitsigns prev_hunk<CR>";
      options.desc = "Vorige Aenderung";
    }
    {
      mode = "n";
      key = "<leader>hp";
      action = "<cmd>Gitsigns preview_hunk<CR>";
      options.desc = "Aenderung ansehen";
    }
    {
      mode = "n";
      key = "<leader>hb";
      action = "<cmd>Gitsigns blame_line<CR>";
      options.desc = "Wer war das? (blame)";
    }

    # --- Tabs (bufferline) ---
    # <S-h>/<S-l> wie in LazyVim. Ersetzt vims H/L (Cursor an den oberen/
    # unteren Bildschirmrand) -- die braucht kaum jemand, zum Springen gibt
    # es <C-u>/<C-d>.
    {
      mode = "n";
      key = "<S-h>";
      action = "<cmd>BufferLineCyclePrev<CR>";
      options.desc = "Tab links";
    }
    {
      mode = "n";
      key = "<S-l>";
      action = "<cmd>BufferLineCycleNext<CR>";
      options.desc = "Tab rechts";
    }
    {
      mode = "n";
      key = "<leader>bd";
      action.__raw = ''function() require("mini.bufremove").delete(0, false) end'';
      options.desc = "Tab schliessen";
    }
    {
      mode = "n";
      key = "<leader>bo";
      action = "<cmd>BufferLineCloseOthers<CR>";
      options.desc = "Alle anderen Tabs schliessen";
    }
    # Blendet an jedem Reiter einen Buchstaben ein, Tippen springt hin --
    # schneller als blaettern, sobald mehr als vier Tabs offen sind.
    {
      mode = "n";
      key = "<leader>bp";
      action = "<cmd>BufferLinePick<CR>";
      options.desc = "Tab waehlen";
    }
    # Tab mit nach links/rechts schieben, um die Reihenfolge zu ordnen.
    {
      mode = "n";
      key = "<leader>b<";
      action = "<cmd>BufferLineMovePrev<CR>";
      options.desc = "Tab nach links schieben";
    }
    {
      mode = "n";
      key = "<leader>b>";
      action = "<cmd>BufferLineMoveNext<CR>";
      options.desc = "Tab nach rechts schieben";
    }
  ];
}
