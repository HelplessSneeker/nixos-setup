-- Bar-Knopf: oeffnet die Workspace-Uebersicht.
--
-- Praesentation steht in update() und nicht im Top-Level-Chunk, weil das dem
-- dokumentierten Muster entspricht: der Host ruft update() sicher erst, wenn die
-- Widget-Instanz existiert.

function update()
  -- Der Knopf hat keinen wechselnden Inhalt. Ein langes Intervall haelt ihn
  -- trotzdem selbstheilend (z.B. nach einem Reload), ohne zu ticken.
  noctalia.setUpdateInterval(600000)
  barWidget.setGlyph("layout-grid")
  barWidget.setTooltip("Workspace-Übersicht")
end

function onClick()
  -- Voll qualifizierte Entry-ID: <author>/<plugin>:<entry>. Ein blosses
  -- "overview" quittiert noctalia mit "unknown panel".
  noctalia.togglePanel("bfn/ws-overview:overview")
end
