# Fish-Shell (home-manager). Shared -> fabricus + laptop.
# Login-Shell: System-Enable in modules/system-base.nix, shell-Zuweisung in
# hosts/*/configuration.nix. starship + nix-direnv haengen sich shell-uebergreifend
# ein (siehe bfn.nix). Autosuggestions + Syntax-Highlighting kann fish nativ.
{ config, pkgs, lib, ... }:
{
  # notify-send fuer das 'done'-Plugin (Notification via noctalia).
  home.packages = [ pkgs.libnotify ];

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting            # kein Begruessungs-Spam

      # --- Farben: Catppuccin Mocha (passt zu kitty/fuzzel/mako aus theme.nix) ---
      set -g fish_color_normal cdd6f4
      set -g fish_color_command 89b4fa
      set -g fish_color_param f2cdcd
      set -g fish_color_keyword f38ba8
      set -g fish_color_quote a6e3a1
      set -g fish_color_redirection f5c2e7
      set -g fish_color_end fab387
      set -g fish_color_comment 6c7086
      set -g fish_color_error f38ba8
      set -g fish_color_gray 6c7086
      set -g fish_color_selection --background=313244
      set -g fish_color_search_match --background=313244
      set -g fish_color_option a6e3a1
      set -g fish_color_operator f5c2e7
      set -g fish_color_escape eba0ac
      set -g fish_color_autosuggestion 6c7086
      set -g fish_color_cancel f38ba8
      set -g fish_pager_color_progress 6c7086
      set -g fish_pager_color_prefix f5c2e7
      set -g fish_pager_color_completion cdd6f4
      set -g fish_pager_color_description 6c7086
      set -g fish_pager_color_selected_background --background=313244
    '';

    # Abbreviations expandieren live beim Tippen -> du siehst das echte Kommando.
    shellAbbrs = {
      # eza (Icons brauchen die Nerd Font)
      ll = "eza -l --git --icons";
      la = "eza -la --git --icons";
      lt = "eza --tree --level=2 --icons";
      # git
      gs  = "git status";
      ga  = "git add";
      gc  = "git commit";
      gd  = "git diff";
      gl  = "git log --oneline -20";
      gp  = "git push";
      gco = "git checkout";
      gb  = "git branch";
      # nixos-rebuild (dein haeufigster Flow gerade)
      nrs = "sudo nixos-rebuild switch --flake /etc/nixos";
      nrb = "sudo nixos-rebuild build --flake /etc/nixos";
    };

    functions = {
      # mkdir + direkt reinwechseln
      mkcd = "mkdir -p $argv[1]; and cd $argv[1]";

      # Spickzettel: eigene Abbreviations + Funktionen + Verweis auf die
      # Hyprland-Keybinds (SUPER+/). Damit vergisst du dein eigenes Setup nicht.
      cheat = ''
        set_color --bold cyan; echo "── Abbreviations ──"; set_color normal
        echo "  (tippen + Leertaste -> expandiert sichtbar zum vollen Kommando)"
        abbr --show | string replace -r "^abbr -a -- " "  "
        echo
        set_color --bold cyan; echo "── Meine Funktionen ──"; set_color normal
        echo "  (eigene Kommandos; Definition ansehen: type <name>)"
        for f in ~/.config/fish/functions/*.fish
            printf "  %s\n" (basename $f .fish)
        end
        echo
        set_color --bold cyan; echo "── Tastenkürzel ──"; set_color normal
        printf "  %-14s %s\n" "Ctrl+R"     "History durchsuchen (fzf)"
        printf "  %-14s %s\n" "Ctrl+Alt+F" "Dateien/Ordner suchen (fzf)"
        printf "  %-14s %s\n" "Ctrl+Alt+P" "Prozesse suchen (fzf)"
        printf "  %-14s %s\n" "Ctrl+Alt+L" "git log durchsuchen (fzf)"
        printf "  %-14s %s\n" "Ctrl+Alt+S" "git status / Dateien (fzf)"
        printf "  %-14s %s\n" "Ctrl+V"     "Shell-Variablen suchen (fzf)"
        printf "  %-14s %s\n" "-> / Ctrl+F" "Autosuggestion annehmen"
        printf "  %-14s %s\n" "Alt+->"     "nur naechstes Wort annehmen"
        printf "  %-14s %s\n" "!! / !\$"   "letztes Kommando / letztes Argument (puffer)"
        printf "  %-14s %s\n" "..."        "wird zu ../..  (.... = ../../.., puffer)"
        printf "  %-14s %s\n" "Tab"        "Vervollstaendigung"
        echo
        set_color --bold cyan; echo "── Hyprland ──"; set_color normal
        echo "  SUPER+/        durchsuchbare Keybind-Liste (auch: hypr-cheatsheet)"
      '';
    };

    plugins = [
      # fzf-Integration: Ctrl+R History, Ctrl+Alt+F Dateien, Ctrl+Alt+P Prozesse,
      # git-Widgets. Nutzt dein fd/bat fuer Previews.
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish.src; }
      # Klammern/Quotes automatisch schliessen.
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      # Expansion: !! -> letztes Kommando, !$ -> letztes Argument, ... -> ../..
      { name = "puffer"; src = pkgs.fishPlugins.puffer.src; }
      # Fehlgeschlagene Kommandos aus der History raushalten.
      { name = "sponge"; src = pkgs.fishPlugins.sponge.src; }
      # Desktop-Notification (via noctalia), wenn ein langer Befehl fertig ist.
      { name = "done"; src = pkgs.fishPlugins.done.src; }
    ];
  };
}
