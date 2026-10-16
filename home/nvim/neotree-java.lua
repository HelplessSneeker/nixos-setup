-- Java-Pakete in neo-tree, eingehaengt von ./finder.nix.
--
-- Zwei Teile:
--   before_render  schaltet group_empty_dirs ein, wenn die Baumwurzel ein
--                  Java-Projekt ist. Dann wird aus com/ > example/ > app/
--                  EINE Zeile -- dasselbe, was IntelliJ "compact middle
--                  packages" nennt.
--   name, icon     zeigen Ordner unterhalb von src/<set>/java (oder kotlin)
--                  als Paket an: Punkte statt Schraegstriche, Paket-Icon.
--
-- Die Paket-Darstellung haengt nur am Pfad, nicht an der Erkennung: was unter
-- src/main/java liegt, IST ein Paket, egal wo der Baum gerade wurzelt.
local M = {}

local common = require("neo-tree.sources.common.components")

-- Build-Dateien, an denen ein Java-Projekt erkannt wird.
local markers = {
  ["pom.xml"] = true,
  ["build.gradle"] = true,
  ["build.gradle.kts"] = true,
  ["settings.gradle"] = true,
  ["settings.gradle.kts"] = true,
}

-- Eine Ebene tief mitgesucht: <leader>e wurzelt am Git-Repo, und da liegt das
-- Maven-Projekt oft in einem Unterordner (backend/pom.xml). Tiefer nicht --
-- die Pruefung laeuft vor jedem Zeichnen, und in einem Repo ohne Java soll
-- sie nicht durch node_modules wandern. Ergebnis pro Wurzel gemerkt.
local cache = {}

function M.is_java_root(path)
  if not path then
    return false
  end
  if cache[path] == nil then
    local found = false
    for name, type in vim.fs.dir(path, { depth = 2 }) do
      if type == "file" and markers[vim.fs.basename(name)] then
        found = true
        break
      end
    end
    cache[path] = found
  end
  return cache[path]
end

function M.before_render(state)
  state.group_empty_dirs = M.is_java_root(state.path)
end

-- Liefert den Paketteil eines Ordnerpfads ("com/example/app") oder nil.
-- `.-` matcht so kurz wie moeglich, also die ERSTE Quellwurzel im Pfad.
local function package_path(path)
  for _, lang in ipairs({ "java", "kotlin" }) do
    local rel = path:match("/src/[^/]+/" .. lang .. "/(.+)$")
    if rel then
      return rel
    end
  end
end

-- Anzeigename fuer einen Paketordner. node.name ist bei gruppierten Ordnern
-- schon "com/example/app" -- oder "java/com/example/app", wenn die
-- Quellwurzel selbst nur ein Kind hatte und mit eingeklappt wurde. Der Teil
-- bis zur Quellwurzel bleibt ein Pfad, der Paketteil bekommt Punkte:
-- "java/com.example.app".
local function package_name(node)
  if node.type ~= "directory" or node:get_depth() == 1 then
    return nil
  end
  local rel = package_path(node.path)
  if not rel then
    return nil
  end
  local name_parts = vim.split(node.name, "/", { plain = true })
  local pkg_count = #vim.split(rel, "/", { plain = true })
  local split = math.max(#name_parts - pkg_count, 0)
  local pkg = table.concat(name_parts, ".", split + 1)
  if split == 0 then
    return pkg
  end
  return table.concat(name_parts, "/", 1, split) .. "/" .. pkg
end

function M.name(config, node, state)
  local result = common.name(config, node, state)
  local display = package_name(node)
  if display then
    -- common.name haengt hinter den Namen ggf. "/" und Padding an; das
    -- bleibt erhalten, nur der Name vorne wird getauscht.
    result.text = display .. result.text:sub(#node.name + 1)
  end
  return result
end

function M.icon(config, node, state)
  local result = common.icon(config, node, state)
  -- Leere Pakete behalten das Leerer-Ordner-Icon -- die Info ist wertvoller.
  local empty = node.loaded and not node:has_children()
  if package_name(node) and not empty then
    result.text = (node:is_expanded() and "󰏖" or "󰏗") .. " "
  end
  return result
end

return M
