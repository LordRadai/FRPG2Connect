------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Pass-Down Pin Names
--
-- Keeps every PassDownPin named after the node that feeds it: In_<source node>. The source is found by walking the
-- pin's upstream connection out through any enclosing containers (nested pins resolve to the same source, so they
-- inherit the outer pin's name).
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
-- string getLeafName(string path)
------------------------------------------------------------------------------------------------------------------------
local getLeafName = function(path)
  local _, leaf = splitNodePath(path)
  if leaf == nil or leaf == "" then
    return path
  end
  return leaf
end

------------------------------------------------------------------------------------------------------------------------
-- boolean isAncestorOf(string ancestor, string path)
------------------------------------------------------------------------------------------------------------------------
local isAncestorOf = function(ancestor, path)
  local prefix = ancestor .. "|"
  return string.sub(path, 1, string.len(prefix)) == prefix
end

------------------------------------------------------------------------------------------------------------------------
-- string resolveSourceNode(string object, string passDownPin, number depth)
-- object is a PassDownPin or a pin path ("Node.Pin"). Returns the path of the node that ultimately feeds it, or nil
-- when it is unconnected or fed by more than one pin.
------------------------------------------------------------------------------------------------------------------------
local resolveSourceNode
resolveSourceNode = function(object, passDownPin, depth)
  if depth > kMaxResolveDepth then
    return nil
  end

  local connections = listConnections{
    Object = object,
    Pins = true,
    Upstream = true,
    Downstream = false,
    ResolveReferences = true,
  }
  if table.getn(connections) ~= 1 then
    return nil
  end

  local upstream = connections[1]

  -- fed by another pass-down pin: keep walking out.
  if getType(upstream) == "PassDownPin" then
    return resolveSourceNode(upstream, passDownPin, depth + 1)
  end

  local node = splitPinPath(upstream)
  if node == nil or node == "" then
    return nil
  end

  if getType(node) == "PassDownPin" then
    return resolveSourceNode(node, passDownPin, depth + 1)
  end

  -- fed by an input pin of one of the pass-down pin's own containers: that pin is the outer side of a pass-down pin,
  -- so carry on from whatever feeds it.
  if isAncestorOf(node, passDownPin) then
    return resolveSourceNode(upstream, passDownPin, depth + 1)
  end

  return node
end

------------------------------------------------------------------------------------------------------------------------
-- string, string getExpectedPinName(string passDownPin)
-- Returns the name the pin should have and the path of its source node, or nil when the pin has no single source.
------------------------------------------------------------------------------------------------------------------------
local getExpectedPinName = function(passDownPin)
  local source = resolveSourceNode(passDownPin, passDownPin, 0)
  if source == nil then
    return nil, nil
  end
  return kPinPrefix .. getLeafName(source), source
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
-- boolean renamePassDownPin(string passDownPin, string newName)
------------------------------------------------------------------------------------------------------------------------
local renamePassDownPin = function(passDownPin, newName)
  local parent = splitNodePath(passDownPin)
  local target = newName
  if parent ~= nil and parent ~= "" then
    target = parent .. "|" .. newName
  end

  -- a sibling already has the name: let Connect number it (it turns "_1" into the next free "_N").
  if objectExists(target) then
    newName = newName .. "_1"
  end

  local ok, result = pcall(rename, passDownPin, newName)
  if not ok then
    app.warning(string.format("FRPG2: could not rename pass-down pin %s to %s: %s", passDownPin, newName, tostring(result)))
    return false
  end

  app.info(string.format("FRPG2: renamed pass-down pin %s -> %s", passDownPin, tostring(result or newName)))
  return true
end

------------------------------------------------------------------------------------------------------------------------
-- number, number syncPassDownPinNames(table sourceNodes)
-- Renames every pass-down pin whose name doesn't match its source. With sourceNodes (a set of node paths) only pins
-- fed by one of those nodes are touched. Returns the number of pins renamed and the number checked.
------------------------------------------------------------------------------------------------------------------------
local syncPassDownPinNames = function(sourceNodes)
  local renamed = 0
  local checked = 0

  isRenamingPins = true
  local ok, err = pcall(function()
    undoBlock(function()
      local passDownPins = ls("PassDownPin")
      for _, passDownPin in ipairs(passDownPins) do
        local expected, source = getExpectedPinName(passDownPin)
        if expected ~= nil and (sourceNodes == nil or sourceNodes[source]) then
          checked = checked + 1
          if not nameMatches(getLeafName(passDownPin), expected) then
            if renamePassDownPin(passDownPin, expected) then
              renamed = renamed + 1
            end
          end
        end
      end
    end)
  end)
  isRenamingPins = false

  if not ok then
    app.error(string.format("FRPG2: pass-down pin sync failed: %s", tostring(err)))
  end

  return renamed, checked
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

  -- renaming a pass-down pin by hand is not a source change.
  if getType(newPath) == "PassDownPin" then
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
  local renamed, checked = syncPassDownPinNames(nil)
  app.info(string.format("FRPG2: checked %d connected pass-down pins, renamed %d.", checked, renamed))
end
