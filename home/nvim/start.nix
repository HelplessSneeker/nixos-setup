# nvim -- SCHICHT 6: Start.
#
# Was passiert, bevor du eine Datei offen hast. Zwei Faelle:
#   `nvim`            Startbildschirm mit Projekten, Suche, zuletzt Geoeffnetem
#   `nvim <ordner>`   Seitenleiste (neo-tree, siehe ./finder.nix) und nvim
#                     arbeitet ab sofort IN diesem Ordner
#
# Eingehaengt von ./config.nix.
{
  # ---------------------------------------------------------------------------
  # dashboard-nvim -- der Startbildschirm
  # ---------------------------------------------------------------------------
  # Erscheint nur bei `nvim` ohne Argumente. Jede Zeile ist eine Taste, die
  # direkt den passenden telescope-Picker oeffnet -- dieselben Picker wie unter
  # <leader>f..., nur ohne Leader.
  plugins.dashboard = {
    enable = true;

    settings = {
      theme = "hyper";

      config = {
        # Die eigene Projektliste des Dashboards kennt nur Projekte, die du
        # schon einmal UEBER das Dashboard geoeffnet hast. `p` unten fragt
        # stattdessen ~/projects direkt ab -- eine Quelle statt zwei.
        project.enable = false;

        # Ohne das zeigt "hyper" eine Plugin-Statistik von lazy.nvim, das es
        # hier nicht gibt (nixvim laedt Plugins aus dem Store).
        packages.enable = false;

        mru = {
          limit = 8;
          cwd_only = false;
        };

        shortcut = [
          {
            desc = " Projekte";
            group = "Label";
            action = "Telescope project";
            key = "p";
          }
          {
            desc = " Datei";
            group = "Label";
            action = "Telescope find_files";
            key = "f";
          }
          {
            desc = " Zuletzt";
            group = "Label";
            action = "Telescope oldfiles";
            key = "r";
          }
          {
            desc = " Text";
            group = "Label";
            action = "Telescope live_grep";
            key = "g";
          }
          {
            desc = "󰅚 Beenden";
            group = "DiagnosticError";
            action = "qa";
            key = "q";
          }
        ];

        footer = [ "" ];
      };
    };
  };

  # telescope-project legt beim Laden ~/.local/share/nvim/telescope-projects.txt
  # an, aber nicht das Verzeichnis davor. Fehlt es (frisches Home, neuer
  # Laptop), bricht die GANZE init.lua an dieser Stelle ab -- ausprobiert am
  # 13.10.2026. Deshalb vorher anlegen; existiert es, passiert nichts.
  extraConfigLuaPre = ''
    vim.fn.mkdir(vim.fn.stdpath("data"), "p")
  '';

  # ---------------------------------------------------------------------------
  # `nvim <ordner>` -- in den Ordner wechseln
  # ---------------------------------------------------------------------------
  # nvim zeigt ein Verzeichnis-Argument nur an, es wechselt nicht hinein. Ein
  # `nvim ~/projects/quant` aus dem Home heraus liesse telescope also weiter
  # im Home suchen. Hier: genau ein Argument, und das ist ein Verzeichnis ->
  # dorthin wechseln, bevor neo-tree oder telescope etwas anfangen.
  autoCmd = [
    {
      event = "VimEnter";
      callback.__raw = ''
        function()
          local arg = vim.fn.argv(0)
          if vim.fn.argc() == 1 and vim.fn.isdirectory(arg) == 1 then
            vim.cmd.cd(vim.fn.fnameescape(arg))
          end
        end
      '';
    }
  ];
}
