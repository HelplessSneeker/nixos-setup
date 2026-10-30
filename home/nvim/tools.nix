# nvim -- SCHICHT 7: Werkzeuge.
#
# Bis Schicht 6 ging es um den Editor selbst. Hier kommt dazu, wofuer du
# sonst nvim verlassen wuerdest: eine Shell auf einem Server als Tab, oder
# seine Dateien in oil.
#
# Bewusst KEIN HTTP-Client im Editor. kulala (Postman als .http-Datei) war am
# 22.10.2026 auf einem Test-Branch drin und flog wieder raus: curl im
# Terminal ist simpler.
#
# Eingehaengt von ./config.nix.
{ lib, pkgs, ... }:
let
  # Host-Wahl fuer die beiden SSH-Tasten unten. Liest die Host-Aliase zur
  # LAUFZEIT aus ~/.ssh/config, die home/ssh.nix erzeugt. Ein neuer Host dort
  # taucht hier von selbst auf, es gibt keine zweite Liste zu pflegen -- und
  # auf jedem Rechner stehen genau die Hosts, die er auch kennt.
  #
  # Nur schlichte Namen (Buchstaben, Ziffern, - und _) kommen in die Liste.
  # Das laesst Muster wie `Host *` aus, die kein Ziel sind, und github.com,
  # das keine Shell annimmt -- und der Name kann unten ohne Quoting in die
  # Kommandozeile.
  #
  # `open` ist Lua-Code, der `host` benutzt. vim.schedule, weil das
  # Auswahlfenster beim Schliessen den Modus zuruecksetzt -- ein startinsert
  # direkt im Callback ginge dabei verloren.
  sshPick = open: ''
    function()
      local config = vim.fn.expand("~/.ssh/config")
      if vim.fn.filereadable(config) == 0 then
        return vim.notify("Keine ~/.ssh/config", vim.log.levels.WARN)
      end
      local hosts = {}
      for _, line in ipairs(vim.fn.readfile(config)) do
        for name in (line:match("^%s*[Hh]ost%s+(.+)") or ""):gmatch("%S+") do
          if name:match("^[%w_-]+$") then
            table.insert(hosts, name)
          end
        end
      end
      vim.ui.select(hosts, { prompt = "SSH-Host" }, function(host)
        if host then
          vim.schedule(function()
            ${open}
          end)
        end
      end)
    end
  '';
in
{
  # vim.ui.select als telescope-Fenster statt der nummerierten Liste unten in
  # der Kommandozeile. vim.ui.select ist nvims eingebaute "waehle eins"-
  # Funktion, die Umstellung gilt also fuer alles, was sie benutzt: die
  # SSH-Hosts unten, aber auch die Code-Aktionen (<leader>ca) aus Schicht 4.
  # Tippen filtert die Liste, Enter waehlt.
  plugins.telescope.extensions.ui-select.enable = true;

  # ---------------------------------------------------------------------------
  # SSH
  # ---------------------------------------------------------------------------
  # Zwei Tasten, beide fragen zuerst nach dem Host:
  #
  #   <leader>s  Shell auf dem Host als eigener Tab, wie `:terminal ssh primus`
  #              von Hand. Aus dem Tippen raus mit <Esc><Esc> (Schicht 1),
  #              danach ist es ein Puffer wie jeder andere: <S-h>/<S-l>
  #              blaettert, <leader>bd schliesst.
  #   <leader>S  Das Home des Hosts in oil (Schicht 3), als waere es ein
  #              lokaler Ordner. Dateien oeffnen, umbenennen, loeschen -- und
  #              :w schreibt direkt zurueck, mit DEINER Config und ohne dass auf
  #              dem Server ein nvim liegen muss.
  #
  # Fuer eine laengere Sitzung ist kitty trotzdem der bessere Ort: in nvims
  # Terminal liegen zwei Modi uebereinander, und Vollbild-Programme wie htop
  # streiten mit diesem nvim um <Esc>. Der eigentliche Gewinn ist oil.
  #
  # oil-Pfade von Hand: oil-ssh://primus/ ist das Home, oil-ssh://primus//etc/
  # ist absolut. oil schreibt mit den Rechten deines Users, fuer /etc bleibt
  # sudoedit in der Shell. Sprachserver starten in solchen Puffern nicht --
  # sie laufen lokal und saehen die Datei gar nicht.
  #
  # Fix aus oil-Upstream fuer genau diese Dateien (22.10.2026). oil 2.15.0
  # haelt jeden Puffer mit oil-ssh://-Namen fuer einen oil-Ordner, auch eine
  # ganz normale Datei auf dem Server. Geht daneben ein neues Fenster auf --
  # das Vorschlagsmenue von blink beim Tippen, ein :vsplit --, meldet oil
  # "Oil split could not find parent window ... report a bug on github".
  # Behoben in Commit 548587d, einen Monat nach 2.15.0, und nixpkgs hat
  # noch 2.15.0. Ab oil 2.16 ist der Fix drin, die Bedingung greift dann
  # nicht mehr, und der Block kann weg.
  plugins.oil.package = pkgs.vimPlugins.oil-nvim.overrideAttrs (old: {
    patches =
      (old.patches or [ ])
      ++ lib.optional (lib.versionOlder old.version "2.16") (
        pkgs.fetchpatch {
          url = "https://github.com/stevearc/oil.nvim/commit/548587d68b55e632d8a69c92cefd981f360634fa.patch";
          hash = "sha256-OyBBQY0V7lzGLV5CoyBZ44LzvLKkAIJDViB+tXxFrCg=";
        }
      );
  });

  # ---------------------------------------------------------------------------
  # lazygit (30.10.2026, bfn-Notiz 27.10.: "lazygit in nvim implementieren")
  # ---------------------------------------------------------------------------
  # <leader>gg oeffnet lazygit in einem schwebenden Fenster, und zwar im Repo
  # der Datei, die du gerade offen hast, nicht im Ordner, in dem nvim
  # gestartet wurde. Derselbe Gedanke wie `lg` in home/fish.nix: der Kontext
  # ist schon da (dort das Verzeichnis der Shell, hier der Puffer), es muss
  # nichts geraten werden. Dem Hyprland-Bind SUPER+G fehlte genau der, er
  # flog am 27.08.2026 wieder raus.
  #
  # Das Fenster kommt von snacks.nvim. `e` auf einer Datei in lazygit
  # schliesst lazygit und oeffnet die Datei in DIESEM nvim, statt ein zweites
  # nvim im Fenster zu starten (snacks setzt lazygits editPreset nvim-remote).
  # Die Datei kommt dabei in einen neuen Tab (oben rechts 1 2), so macht es
  # lazygits Vorgabe; zurueck mit gT, zu mit :tabclose.
  # Von snacks ist sonst nichts an: seine Module sind einzeln einzuschalten,
  # und hier ist keins eingeschaltet. Raus aus lazygit: q.
  plugins.snacks.enable = true;

  keymaps = [
    {
      mode = "n";
      key = "<leader>gg";
      action.__raw = ''
        function()
          -- Ordner des Puffers: oil -> der angezeigte Ordner, eine Datei ->
          -- ihr Ordner, Terminal, Startseite, neo-tree -> das Arbeitsverzeichnis.
          -- Was auf einem Server liegt (oil-ssh://), hat hier kein Repo.
          local name = vim.api.nvim_buf_get_name(0)
          local dir
          if vim.bo.filetype == "oil" then
            dir = require("oil").get_current_dir()
            if not dir then
              return vim.notify("lazygit: der Ordner liegt nicht lokal", vim.log.levels.WARN)
            end
          elseif vim.bo.buftype ~= "" or name == "" then
            dir = vim.fn.getcwd()
          elseif name:match("^%a[%w+.-]*://") then
            return vim.notify("lazygit: die Datei liegt nicht lokal", vim.log.levels.WARN)
          else
            dir = vim.fs.dirname(name)
          end
          if not vim.fs.root(dir, ".git") then
            return vim.notify("lazygit: kein Git-Repo in " .. dir, vim.log.levels.WARN)
          end
          require("snacks").lazygit({ cwd = dir })
        end
      '';
      options.desc = "lazygit (Repo der Datei)";
    }
    {
      mode = "n";
      key = "<leader>s";
      # Genau `:terminal ssh <host>`. Der Tab heisst dann auch so (ssh primus)
      # -- bei zwei offenen Shells sieht man, welche wohin geht.
      action.__raw = sshPick ''
        vim.cmd.terminal("ssh " .. host)
        vim.cmd.startinsert()
      '';
      options.desc = "SSH: Shell";
    }
    {
      mode = "n";
      key = "<leader>S";
      action.__raw = sshPick ''vim.cmd.edit("oil-ssh://" .. host .. "/")'';
      options.desc = "SSH: Dateien (oil)";
    }
  ];
}
