------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Pass-Down Pin Names
--
-- Keeps every input pass-down pin named after the node that feeds it: In_<source node>.
--
-- A pass-down pin is a pin on a container (state machine / blend tree), addressed as "Container.PinName". It stores no
-- link to its source, so the source is found by walking upstream connections: Container.In_X is fed either by a real
-- node's output pin in the parent graph (the source), or by the parent container's own In_X pin (one nesting level up,
-- keep walking). Every pin along such a chain resolves to the same source, so they all end up with the same name.
-- Output pass-down pins (Result) are fed from inside their container and are left alone.
--
-- * Automatic: renaming a node (mcNodeRenamed) renames every pass-down pin whose source is that node. The work runs on
--   the next idle tick, after Connect has finished its own rename.
-- * Manual: Frpg2 > Resync Pass-Down Pin Names renames every pin in the network whose name doesn't match its source.
------------------------------------------------------------------------------------------------------------------------

local kPinPrefix = "In_"
local kMaxResolveDepth = 64
local kRenameHandlerId = "FRPG2PassDownPinRenameHandler"

-- set while this script renames pins, so the mcNodeRenamed events those renames fire are ignored.
local isRenamingPins = false
-- new node paths waiting for the idle callback.
local pendingRenamedNodes = { }
local idleCallbackQueued = false

------------------------------------------------------------------------------------------------------------------------
-- string getLeafName(string nodePath)
------------------------------------------------------------------------------------------------------------------------
local getLeafName = function(nodePath)
  local _, leaf = splitNodePath(nodePath)
  if leaf == nil or leaf == "" then
    return nodePath
  end
  return leaf
end

------------------------------------------------------------------------------------------------------------------------
-- boolean isInside(string path, string container)
-- true when path is a descendant of container.
------------------------------------------------------------------------------------------------------------------------
local isInside = function(path, container)
  local prefix = container .. "|"
  return string.sub(path, 1, string.len(prefix)) == prefix
end

------------------------------------------------------------------------------------------------------------------------
-- string safeGetType(string path)
------------------------------------------------------------------------------------------------------------------------
local safeGetType = function(path)
  local ok, result = pcall(getType, path)
  if ok then
    return result
  end
  return nil
end

------------------------------------------------------------------------------------------------------------------------
-- table getUpstreamPins(string pinPath)
------------------------------------------------------------------------------------------------------------------------
local getUpstreamPins = function(pinPath)
  local ok, connections = pcall(listConnections, {
    Object = pinPath,
    Pins = true,
    Upstream = true,
    Downstream = false,
    ResolveReferences = false,
  })
  if not ok or type(connections) ~= "table" then
    return { }
  end
  return connections
end

------------------------------------------------------------------------------------------------------------------------
-- table listPassDownPins()
-- "Container.PinName" for every pin Connect reports as a PassDownPin. If it reports none (getType may not know pins),
-- falls back to every In_* pin on an object that has children, i.e. a container.
------------------------------------------------------------------------------------------------------------------------
local listPassDownPins = function()
  local typed = { }
  local guessed = { }

  for _, object in ipairs(ls()) do
    local ok, pins = pcall(listPins, object)
    if ok and type(pins) == "table" then
      local okChildren, children = pcall(listChildren, object)
      local isContainer = okChildren and type(children) == "table" and table.getn(children) > 0
      for _, pin in ipairs(pins) do
        local pinPath = object .. "." .. pin
        if safeGetType(pinPath) == "PassDownPin" then
          table.insert(typed, pinPath)
        elseif isContainer and string.sub(pin, 1, string.len(kPinPrefix)) == kPinPrefix then
          table.insert(guessed, pinPath)
        end
      end
    end
  end

  if table.getn(typed) > 0 then
    return typed
  end
  return guessed
end

------------------------------------------------------------------------------------------------------------------------
-- string, string resolveSource(string pinPath, number depth)
-- Returns the path of the node feeding the pass-down pin, or nil and a reason (unconnected, output pin, ...).
------------------------------------------------------------------------------------------------------------------------
local resolveSource
resolveSource = function(pinPath, depth)
  if depth > kMaxResolveDepth then
    return nil, "chain too deep"
  end

  local container = splitPinPath(pinPath)
  local connections = getUpstreamPins(pinPath)
  local count = table.getn(connections)
  if count == 0 then
    return nil, "not connected"
  end
  if count > 1 then
    return nil, "more than one input: " .. table.concat(connections, ", ")
  end

  local upstream = connections[1]
  local upstreamNode = splitPinPath(upstream)
  if upstreamNode == nil or upstreamNode == "" then
    return nil, "unexpected upstream " .. tostring(upstream)
  end

  -- fed from inside its own container: an output pass-down pin (Result).
  if isInside(upstreamNode, container) then
    return nil, "output pin"
  end

  -- fed by the enclosing container's own pass-down pin: walk one level out.
  if isInside(container, upstreamNode) then
    return resolveSource(upstream, depth + 1)
  end

  return upstreamNode, nil
end

------------------------------------------------------------------------------------------------------------------------
-- boolean nameMatches(string current, string expected)
-- expected, or expected with the _N suffix Connect adds when a sibling already has the name.
------------------------------------------------------------------------------------------------------------------------
local nameMatches = function(current, expected)
  if current == expected then
    return true
  end
  local prefix = expected .. "_"
  if string.sub(current, 1, string.len(prefix)) ~= prefix then
    return false
  end
  return string.find(string.sub(current, string.len(prefix) + 1), "^%d+$") ~= nil
end

------------------------------------------------------------------------------------------------------------------------
-- boolean renamePassDownPin(string pinPath, string newName)
------------------------------------------------------------------------------------------------------------------------
local renamePassDownPin = function(pinPath, newName)
  local container = splitPinPath(pinPath)

  -- the container already has a pin with that name: let Connect number it (it turns "_1" into the next free "_N").
  local okExists, exists = pcall(pinExists, container .. "." .. newName)
  if okExists and exists then
    newName = newName .. "_1"
  end

  local ok, result = pcall(rename, pinPath, newName)
  if not ok then
    app.warning(string.format("FRPG2: could not rename pass-down pin %s to %s: %s", pinPath, newName, tostring(result)))
    return false
  end

  app.info(string.format("FRPG2: renamed pass-down pin %s -> %s", pinPath, newName))
  return true
end

------------------------------------------------------------------------------------------------------------------------
-- number, number, number syncPassDownPinNames(table sourceNodes)
-- Renames every input pass-down pin whose name doesn't match its source. With sourceNodes (a set of node paths) only
-- pins fed by one of those nodes are touched. Returns the number of pins renamed, resolved to a source, and found.
------------------------------------------------------------------------------------------------------------------------
local syncPassDownPinNames = function(sourceNodes)
  local renamed = 0
  local resolved = 0
  local found = 0
  local unresolvedReported = 0

  isRenamingPins = true
  local ok, err = pcall(function()
    -- resolve everything before renaming anything, since a renamed pin no longer has the path an inner pin walks to.
    local work = { }
    local passDownPins = listPassDownPins()
    found = table.getn(passDownPins)
    for _, pinPath in ipairs(passDownPins) do
      local source, reason = resolveSource(pinPath, 0)
      if source ~= nil then
        resolved = resolved + 1
        if sourceNodes == nil or sourceNodes[source] then
          local _, pinName = splitPinPath(pinPath)
          local expected = kPinPrefix .. getLeafName(source)
          if not nameMatches(pinName, expected) then
            table.insert(work, { pin = pinPath, name = expected })
          end
        end
      elseif sourceNodes == nil and reason ~= "output pin" and unresolvedReported < 20 then
        unresolvedReported = unresolvedReported + 1
        app.warning(string.format("FRPG2: no source for pass-down pin %s (%s)", pinPath, reason))
      end
    end

    if table.getn(work) == 0 then
      return
    end

    undoBlock(function()
      for _, item in ipairs(work) do
        if renamePassDownPin(item.pin, item.name) then
          renamed = renamed + 1
        end
      end
    end)
  end)
  isRenamingPins = false

  if not ok then
    app.error(string.format("FRPG2: pass-down pin sync failed: %s", tostring(err)))
  end

  return renamed, resolved, found
end

------------------------------------------------------------------------------------------------------------------------
-- nil processPendingRenames()
------------------------------------------------------------------------------------------------------------------------
local processPendingRenames = function()
  idleCallbackQueued = false

  local sourceNodes = pendingRenamedNodes
  pendingRenamedNodes = { }

  if next(sourceNodes) == nil then
    return
  end

  syncPassDownPinNames(sourceNodes)
end

------------------------------------------------------------------------------------------------------------------------
-- nil onNodeRenamed(string oldPath, string newPath)
------------------------------------------------------------------------------------------------------------------------
local onNodeRenamed = function(oldPath, newPath)
  if isRenamingPins or type(newPath) ~= "string" then
    return
  end

  pendingRenamedNodes[newPath] = true

  if idleCallbackQueued then
    return
  end

  local mainFrame = ui.getWindow("MainFrame")
  if mainFrame ~= nil then
    idleCallbackQueued = true
    mainFrame:addIdleCallback(processPendingRenames)
  else
    processPendingRenames()
  end
end

registerEventHandler("mcNodeRenamed", onNodeRenamed, kRenameHandlerId)

------------------------------------------------------------------------------------------------------------------------
-- nil resyncFrpg2PassDownPinNames()
-- Frpg2 menu command: renames every mismatched pass-down pin in the open network.
------------------------------------------------------------------------------------------------------------------------
resyncFrpg2PassDownPinNames = function()
  local renamed, resolved, found = syncPassDownPinNames(nil)
  app.info(string.format("FRPG2: found %d pass-down pins, %d input pins with a source, renamed %d.", found, resolved, renamed))
end
