-- Dienst: haelt pro Workspace ein Vorschaubild seines letzten sichtbaren Standes.
--
-- WARUM NICHT LIVE: ein Compositor rendert nur, was zu sehen ist. grim (wlr-
-- screencopy) kann deshalb ausschliesslich den GERADE SICHTBAREN Inhalt eines
-- Outputs abgreifen -- ein Workspace im Hintergrund existiert als Fensterliste,
-- aber nicht als Bild. Echte Live-Thumbnails aller Workspaces kann nur ein
-- Hyprland-Plugin (hyprexpo/Hyprspace), das im Compositor selbst rendert.
-- Also: regelmaessig den sichtbaren Workspace abschiessen und das Bild behalten.
-- Jede Kachel zeigt damit "so sah der aus, als du ihn zuletzt offen hattest".
--
-- Die Bilder liegen unter $XDG_RUNTIME_DIR (tmpfs, also RAM): sie ueberleben den
-- Reboot bewusst nicht und kosten die SSD nichts.
--
-- Bewusst KEIN --!strict und keine Typannotationen: die Entry-Punkte sind
-- globale Funktionen, die der Host aufruft, und genau das mag Luaus strict-Modus
-- nicht. Plain Lua haelt das Plugin ausserdem gegen aeltere API-Stufen kompatibel.

local runtimeDir = noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp"
local shotDir = runtimeDir .. "/noctalia-ws-overview"
noctalia.mkdirAll(shotDir)

-- [wsId] = 0|1. Wechselnder Dateiname pro Aufnahme, und das ist kein Detail:
-- der Bild-Cache der Shell adressiert ueber den Pfad. Schreibt man immer auf
-- denselben Namen, zeigt das Panel womoeglich weiter die alte Textur.
local flip = {}
local shots = {}
local inFlight = false

local function numberSetting(key, fallback)
  local value = tonumber(noctalia.getConfig(key))
  if value == nil or value <= 0 then
    return fallback
  end
  return value
end

local function applyInterval()
  noctalia.setUpdateInterval(math.floor(numberSetting("interval_seconds", 5) * 1000))
end

local function publish()
  local encoded = noctalia.json.encode(shots)
  if encoded ~= nil then
    -- Als JSON-String statt als Tabelle: noctalia.state liest hier ein anderer
    -- Luau-VM (das Panel), und ein String ist dabei der stabilste Vertrag.
    noctalia.state.set("shots", encoded)
  end
end

local function capture(outputName, workspaceId)
  local seq = 0
  if flip[workspaceId] == 0 then
    seq = 1
  end
  local path = string.format("%s/ws-%d-%d.png", shotDir, workspaceId, seq)
  -- -l 1: schnellste PNG-Kompressionsstufe. Wir schreiben alle paar Sekunden;
  -- Dateigroesse ist im tmpfs egal, CPU-Zeit nicht.
  local cmd = string.format(
    "grim -o '%s' -s %s -l 1 '%s'",
    outputName,
    tostring(numberSetting("capture_scale", 0.25)),
    path
  )
  noctalia.runAsync(cmd, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("ws-overview: grim " .. outputName .. " -> exit " .. tostring(result.exitCode) .. " " .. tostring(result.stderr))
      return
    end
    flip[workspaceId] = seq
    shots[tostring(workspaceId)] = path
    publish()
  end, 8000)
end

function update()
  applyInterval()

  -- Nie schiessen, solange die Uebersicht offen ist: das Panel liegt als
  -- Layer-Surface UEBER dem Output und waere sonst selbst mit im Bild.
  if noctalia.state.get("panelOpen") == "1" then
    return
  end
  if inFlight then
    return
  end

  inFlight = true
  noctalia.runAsync("hyprctl -j monitors", function(result)
    inFlight = false
    if result.exitCode ~= 0 then
      return
    end
    local monitors = noctalia.json.decode(result.stdout)
    if type(monitors) ~= "table" then
      return
    end
    for _, monitor in ipairs(monitors) do
      local workspace = monitor.activeWorkspace
      -- Negative IDs sind Special-Workspaces (Scratchpad) -- die haben in einer
      -- Workspace-Uebersicht nichts verloren.
      if type(monitor.name) == "string"
        and type(workspace) == "table"
        and type(workspace.id) == "number"
        and workspace.id > 0
        and monitor.disabled ~= true
      then
        capture(monitor.name, math.floor(workspace.id))
      end
    end
  end, 4000)
end

-- Ohne diese Funktion startet die Shell den Dienst bei jeder Einstellungs-
-- aenderung komplett neu. Mit ihr bleibt der Stand im Speicher (flip/shots).
function onConfigChanged()
  applyInterval()
end
