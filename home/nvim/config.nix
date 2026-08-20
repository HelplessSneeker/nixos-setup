# nvim -- SCHICHT 1: Basis.
#
# Diese Datei ist ein reines nixvim-Modul (Optionen ohne `programs.nixvim.`-
# Prefix). Das ist Absicht: sie wird an ZWEI Stellen eingehaengt --
#   1. home/nvim/default.nix  -> in home-manager, das ist der echte Editor
#   2. flake.nix packages.nvim -> als eigenstaendiges Paket zum Ausprobieren
# Punkt 2 ist der Grund fuer die Aufteilung: `nix run /etc/nixos#nvim` baut
# NUR den Editor (Sekunden) statt einer ganzen Systemgeneration. Damit kostet
# eine Aenderung hier keinen nixos-rebuild, solange du nur probierst.
#
# Aufbau in Schichten, jede fuer sich benutzbar:
#   1  Basis (hier)        Optionen, Leader, Keymaps, Farben, Clipboard
#   2  Sichtbarkeit        Statuszeile, Treesitter, which-key
#   3  Navigation          Fuzzy-Finder, Dateibaum/oil
#   4  LSP + Completion    ts_ls, basedpyright, nixd, lua_ls
#   5  Formatieren/Linten  conform, ruff
# Was hier NICHT steht, fehlt noch nicht -- es ist noch nicht dran.
{
  # --- Provider ---
  # Ruby und Python3 aus: das sind Bruecken fuer ALTE vimscript-Plugins, die
  # ihre Logik in Ruby/Python haben. Nichts aus dem Plan oben braucht sie, und
  # sie ziehen jeweils einen kompletten Interpreter in die Closure.
  # Gegenprobe im laufenden nvim: `:checkhealth provider` -- meldet es "not
  # available" fuer etwas, das du wirklich benutzt, hier wieder auf true.
  withRuby = false;
  withPython3 = false;

  # --- Leader ---
  # MUSS vor allem anderen gesetzt sein: nvim friert den Leader beim Anlegen
  # eines Keymaps ein. Wer ihn spaeter aendert, bekommt eine Mischung aus
  # altem und neuem Praefix. nixvim sortiert das selbst richtig ein, die Regel
  # ist trotzdem gut zu wissen, sobald du eigenes Lua dazuschreibst.
  #
  # Space als Leader, weil er unter beiden Haenden liegt und im Normal-Mode
  # sonst nur "ein Zeichen nach rechts" macht -- also nichts kostet.
  globals = {
    mapleader = " ";
    maplocalleader = " ";
  };

  opts = {
    # --- Zeilennummern ---
    # Beide zusammen ergeben "hybrid": die aktuelle Zeile zeigt ihre absolute
    # Nummer, alle anderen den Abstand. Das ist kein Deko-Feature, sondern die
    # Bedienung selbst -- du liest "6" neben einer Zeile und tippst d6j.
    number = true;
    relativenumber = true;

    # --- Einrueckung ---
    # 2 als Grundwert, weil dein Alltag (Nix, TypeScript, Lua) 2 benutzt.
    # Python will 4 -- das kommt in Schicht 5 automatisch vom Formatter, nicht
    # von Hand hier. Bis dahin: `:set sw=4 ts=4` fuer die Sitzung.
    expandtab = true; # Tab-Taste erzeugt Leerzeichen, kein \t
    shiftwidth = 2; # Breite von >> und <<
    tabstop = 2; # Wie breit ein vorhandenes \t dargestellt wird
    softtabstop = 2; # Wie viele Leerzeichen die Tab-Taste einfuegt
    smartindent = true;

    # --- Suche ---
    # ignorecase + smartcase zusammen: "foo" findet auch "Foo", "Foo" findet
    # nur "Foo". Ohne ignorecase waere smartcase wirkungslos, die beiden
    # gehoeren als Paar.
    ignorecase = true;
    smartcase = true;
    hlsearch = true; # Treffer bleiben markiert -- Ausschalten via <Esc>, s.u.
    incsearch = true; # Sprung schon waehrend des Tippens

    # --- Darstellung ---
    termguicolors = true; # 24-Bit-Farben. OHNE DAS sieht catppuccin falsch aus.
    cursorline = true;
    scrolloff = 8; # Nie naeher als 8 Zeilen an den Rand scrollen
    wrap = false; # Lange Zeilen laufen raus statt umzubrechen

    # Signspalte dauerhaft an. Klingt nach Kosmetik, ist aber gegen ein
    # konkretes Aergernis: ab Schicht 4 setzen LSP und Git dort Zeichen, und
    # eine Spalte, die auftaucht und verschwindet, schiebt bei jedem Tippen
    # den ganzen Text seitlich. Einmal Platz reservieren, Ruhe haben.
    signcolumn = "yes";

    # --- Splits ---
    # nvim-Default oeffnet neue Splits oben/links, was der Leserichtung
    # widerspricht. Beides umdrehen.
    splitbelow = true;
    splitright = true;

    # --- Persistenz & Timing ---
    # undofile: Undo-Historie ueberlebt das Schliessen der Datei. Landet unter
    # ~/.local/state/nvim/undo. Einmal gebraucht, nie wieder missen wollen.
    undofile = true;
    swapfile = false; # Kein .swp-Muell; undofile + Git decken den Fall ab
    updatetime = 250; # Wie schnell CursorHold feuert (Diagnostics, Git-Signs)
    timeoutlen = 300; # Wartezeit auf die Folgetaste einer Tastenfolge

    confirm = true; # :q bei ungespeichertem Puffer fragt, statt zu meckern
  };

  # --- Zwischenablage ---
  # register = "unnamedplus" haengt yank/paste an die SYSTEM-Zwischenablage,
  # d.h. y in nvim -> Ctrl+V in Firefox.
  #
  # Der Provider ist unter Wayland der eigentliche Punkt: nvim ruft ein
  # externes Programm, um an die Ablage zu kommen, und unter Wayland ist das
  # wl-copy/wl-paste. Ohne das kopiert nvim still ins Leere. wl-clipboard ist
  # ueber home/apps.nix ohnehin installiert -- hier wird es nvim bekannt
  # gemacht, das ist nicht dasselbe.
  clipboard = {
    register = "unnamedplus";
    providers.wl-copy.enable = true;
  };

  # --- Farbschema ---
  # Catppuccin Mocha, passend zu kitty aus home/theme.nix. Damit steht nvim
  # nicht farblich neben dem Terminal, in dem es laeuft.
  #
  # Bewusst STATISCH: kitty bekommt zusaetzlich eine noctalia-Palette per
  # include untergeschoben und faerbt sich mit dem Wallpaper mit. Fuer nvim
  # gibt es diesen Weg nicht -- das waere ein eigenes Projekt (Schicht "Kuer",
  # falls es dich je stoert).
  colorschemes.catppuccin = {
    enable = true;
    settings = {
      flavour = "mocha";
      transparent_background = false;
      # Terminalfarben von catppuccin setzen lassen, damit ein `:terminal`
      # im nvim nicht plötzlich in Default-Farben steht.
      term_colors = true;
    };
  };

  keymaps = [
    # Suchmarkierung loeschen. hlsearch laesst Treffer stehen, bis die naechste
    # Suche kommt -- das ist nach zwei Minuten nur noch Rauschen.
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.desc = "Suchmarkierung aus";
    }

    # Fenster-Navigation. Bewusst DASSELBE Muster wie deine Hyprland-Binds
    # (SUPER+HJKL): ein Handgriff fuer Compositor-Fenster und nvim-Splits,
    # nur mit Ctrl statt SUPER. Eine Gewohnheit statt zwei.
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Fenster links";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Fenster unten";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Fenster oben";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Fenster rechts";
    }

    # Aus dem Terminal-Mode zurueck in den Normal-Mode. Ohne das sitzt du in
    # `:terminal` fest -- der eingebaute Weg ist <C-\><C-n>, was niemand
    # freiwillig tippt.
    {
      mode = "t";
      key = "<Esc><Esc>";
      action = "<C-\\><C-n>";
      options.desc = "Terminal: Normal-Mode";
    }

    # Auswahl einruecken, OHNE dass die Markierung verlorengeht. Der Default
    # springt nach einem > zurueck in den Normal-Mode, man muss also gv
    # tippen, um nochmal einzuruecken. Hier bleibt die Auswahl stehen.
    {
      mode = "v";
      key = "<";
      action = "<gv";
      options.desc = "Ausruecken, Auswahl behalten";
    }
    {
      mode = "v";
      key = ">";
      action = ">gv";
      options.desc = "Einruecken, Auswahl behalten";
    }
  ];

  # --- Startzeit ---
  # Lua-Dateien vorkompiliert in den Store legen, statt sie bei jedem Start zu
  # parsen. Kostet Bauzeit, spart Startzeit. Faellt erst ab Schicht 3-4 ins
  # Gewicht, ist aber jetzt kostenlos mitgenommen.
  performance.byteCompileLua.enable = true;
}
