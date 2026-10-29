# nvim -- SCHICHT 8: Tippen.
#
# Alles hier nimmt dir Tastendruecke ab, die sich immer gleich wiederholen:
# die schliessende Klammer, das schliessende Tag, die Import-Zeile. Nichts
# davon zeigt etwas an (das war Schicht 2), und nichts davon braucht einen
# Sprachserver -- ausser den Imports, die stehen deshalb in ./lsp.nix.
#
# Eingehaengt von ./config.nix, gilt also fuer beide Wege (home-manager und
# `nix run /etc/nixos#nvim`).
{
  # ---------------------------------------------------------------------------
  # nvim-autopairs -- Klammern und Anfuehrungszeichen schliessen
  # ---------------------------------------------------------------------------
  # `{` tippt `{}` mit dem Cursor dazwischen, Enter macht daraus
  #
  #   {
  #     |
  #   }
  #
  # Dasselbe fuer ( [ " ' `. Tippst du die schliessende Klammer trotzdem
  # selbst, springt der Cursor nur drueber, statt eine zweite einzufuegen --
  # die Gewohnheit kostet also nichts. Backspace direkt nach `{` loescht
  # beide Haelften.
  #
  # Die Enter-Logik (map_cr) ist der Default und kollidiert nicht mit
  # blink.cmp: das super-tab-Preset aus ./lsp.nix legt nichts auf Enter.
  plugins.nvim-autopairs = {
    enable = true;
    settings = {
      # Treesitter fragen, wo der Cursor steht: in einem String oder Kommentar
      # wird nichts gepaart. Sonst bekommt "it's" ein zweites Apostroph.
      check_ts = true;
    };
  };

  # ---------------------------------------------------------------------------
  # nvim-ts-autotag -- HTML-Tags schliessen und mitbenennen
  # ---------------------------------------------------------------------------
  # Drei Dinge, alle ueber den Treesitter-Baum statt per Regex:
  #   <div>        beim Tippen von `>` steht sofort `</div>` dahinter
  #   </           schliesst das naechste offene Tag, wenn du es nachtraeglich
  #                zumachst (z.B. nach einem eingefuegten Block)
  #   <div> -> <section>  das schliessende Tag benennt sich mit um
  #
  # Gilt auch fuer Angular-Templates: das Plugin bildet `htmlangular` (siehe
  # die filetype-Regel in ./ui.nix) von sich aus auf html ab. Ebenso fuer TSX
  # und Markdown.
  plugins.ts-autotag = {
    enable = true;
    # enable_close_on_slash ist upstream AUS -- die nixvim-Doku nennt true als
    # Default, das stimmt fuer die gepinnte Version nicht (geprueft im
    # Plugin-Quelltext, 29.10.2026). Genau das ist der `</`-Fall.
    settings.opts.enable_close_on_slash = true;
  };
}
