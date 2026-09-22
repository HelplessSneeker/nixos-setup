-- Panel: alle Workspaces als Kachelraster. Bild = letzter sichtbarer Stand
-- (kommt aus shots.luau ueber noctalia.state), Text = Live-Daten aus hyprctl.
--
-- Die Aufteilung ist Absicht: das Bild darf alt sein, die Fensterliste nicht.
-- Wer die Uebersicht oeffnet, will wissen WO etwas liegt -- der Titel des
-- letzten Fensters beantwortet das auch dann, wenn das Vorschaubild von vorhin
-- stammt.

local workspaces = {}
local activeById = {}
local focusedWorkspace = nil
local monitorCount = 1
local status = "Lade ..."

local function numberSetting(key, fallback)
  local value = tonumber(noctalia.getConfig(key))
  if value == nil or value <= 0 then
    return fallback
  end
  return value
end

local function shotPaths()
  local raw = noctalia.state.get("shots")
  if type(raw) ~= "string" or raw == "" then
    return {}
  end
  local decoded = noctalia.json.decode(raw)
  if type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local function truncate(text, limit)
  if type(text) ~= "string" or text == "" then
    return ""
  end
  if #text <= limit then
    return text
  end
  return string.sub(text, 1, limit - 1) .. "…"
end

local function switchTo(workspaceId)
  -- `workspace <id>` holt den Workspace auf den Monitor, dem er gehoert, und
  -- fokussiert ihn. Bei mehreren Monitoren wandert damit der Fokus mit -- genau
  -- das will man beim Klick auf eine Kachel.
  noctalia.runAsync("hyprctl dispatch workspace " .. tostring(workspaceId))
  panel.close()
end

local function tile(workspace, shots)
  local width = math.floor(numberSetting("tile_width", 320))
  local height = math.floor(width * 9 / 16)
  local id = math.floor(workspace.id)
  local isActive = activeById[id] ~= nil
  local isFocused = focusedWorkspace == id

  local preview
  local path = shots[tostring(id)]
  if type(path) == "string" and path ~= "" then
    preview = ui.image({ path = path, width = width, height = height, fit = "contain", radius = 8 })
  else
    -- Noch kein Schuss: der Workspace war seit dem Start der Shell nie sichtbar.
    preview = ui.column({ width = width, height = height, radius = 8, fill = "surface_variant/0.5", align = "center", justify = "center" }, {
      ui.glyph({ name = "photo-off", size = 28, color = "on_surface/0.45" }),
    })
  end

  local heading = "Workspace " .. tostring(id)
  if type(workspace.name) == "string" and workspace.name ~= "" and workspace.name ~= tostring(id) then
    heading = workspace.name
  end

  local count = 0
  if type(workspace.windows) == "number" then
    count = math.floor(workspace.windows)
  end
  local subtitle
  if count == 0 then
    subtitle = "leer"
  elseif count == 1 then
    subtitle = truncate(workspace.lastwindowtitle, 34)
    if subtitle == "" then
      subtitle = "1 Fenster"
    end
  else
    subtitle = tostring(count) .. " Fenster · " .. truncate(workspace.lastwindowtitle, 24)
  end
  if monitorCount > 1 and type(workspace.monitor) == "string" and workspace.monitor ~= "" then
    subtitle = workspace.monitor .. " · " .. subtitle
  end

  local fill = "surface_variant/0.30"
  if isFocused then
    fill = "primary/0.22"
  elseif isActive then
    fill = "primary/0.10"
  end

  return ui.column({
    key = "ws-" .. tostring(id),
    gap = 6,
    padding = 8,
    radius = 12,
    fill = fill,
    -- Ein klickbarer Container statt eines Buttons: so ist die ganze Kachel das
    -- Ziel, Bild und Beschriftung eingeschlossen.
    onClick = function()
      switchTo(id)
    end,
  }, {
    preview,
    ui.label({ text = heading, fontWeight = "bold" }),
    ui.label({ text = subtitle, fontSize = 11, color = "on_surface/0.70", maxLines = 1, maxWidth = width }),
  })
end

local function render()
  local shots = shotPaths()
  local columns = math.floor(numberSetting("columns", 3))
  local rows = {}
  local current = {}

  for _, workspace in ipairs(workspaces) do
    table.insert(current, tile(workspace, shots))
    if #current == columns then
      table.insert(rows, ui.row({ gap = 12, align = "start" }, current))
      current = {}
    end
  end
  if #current > 0 then
    table.insert(rows, ui.row({ gap = 12, align = "start" }, current))
  end

  local body
  if #rows == 0 then
    body = ui.column({ flexGrow = 1, align = "center", justify = "center" }, {
      ui.label({ text = status, color = "on_surface/0.6" }),
    })
  else
    body = ui.scroll({ gap = 12, flexGrow = 1 }, rows)
  end

  panel.render(ui.column({ gap = 12, padding = 16, flexGrow = 1 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "layout-grid", size = 18, color = "primary" }),
      ui.label({ text = "Workspaces", fontSize = 18, fontWeight = "bold" }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = "Klick wechselt · Esc schliesst", fontSize = 11, color = "on_surface/0.55" }),
    }),
    ui.separator({}),
    body,
  }))
end

local function loadWorkspaces()
  noctalia.runAsync("hyprctl -j workspaces", function(result)
    if result.exitCode ~= 0 then
      status = "hyprctl -j workspaces: exit " .. tostring(result.exitCode)
      render()
      return
    end
    local decoded = noctalia.json.decode(result.stdout)
    if type(decoded) ~= "table" then
      status = "Antwort von hyprctl nicht lesbar"
      render()
      return
    end

    workspaces = {}
    for _, workspace in ipairs(decoded) do
      if type(workspace.id) == "number" and workspace.id > 0 then
        table.insert(workspaces, workspace)
      end
    end
    table.sort(workspaces, function(a, b)
      return a.id < b.id
    end)
    if #workspaces == 0 then
      status = "Keine Workspaces gemeldet"
    end
    render()
  end, 4000)
end

local function loadMonitors()
  noctalia.runAsync("hyprctl -j monitors", function(result)
    activeById = {}
    focusedWorkspace = nil
    monitorCount = 1
    if result.exitCode == 0 then
      local decoded = noctalia.json.decode(result.stdout)
      if type(decoded) == "table" then
        monitorCount = #decoded
        for _, monitor in ipairs(decoded) do
          local workspace = monitor.activeWorkspace
          if type(workspace) == "table" and type(workspace.id) == "number" then
            local id = math.floor(workspace.id)
            activeById[id] = true
            if monitor.focused == true then
              focusedWorkspace = id
            end
          end
        end
      end
    end
    -- Erst Monitore, dann Workspaces: die Hervorhebung der aktiven Kachel steht
    -- damit schon fest, wenn das Raster das erste Mal gezeichnet wird.
    loadWorkspaces()
  end, 4000)
end

function onOpen()
  -- Der Dienst pausiert, solange das hier steht -- sonst fotografiert er das
  -- eigene Panel.
  noctalia.state.set("panelOpen", "1")
  status = "Lade ..."
  render()
  loadMonitors()
end

function onClose()
  noctalia.state.set("panelOpen", "0")
end
