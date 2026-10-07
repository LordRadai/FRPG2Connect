------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Node Name References
--
-- Keeps names that refer to other nodes in sync with those nodes:
-- * every input pass-down pin is named after the node that feeds it: In_<source node>.
-- * every transition is named after its source and destination: <source>_<destination>, plus _1, _2, ... when several
--   transitions link the same pair (break-out transitions use their source transition's name).
--
-- A pass-down pin is a pin on a container (state machine / blend tree), addressed as "Container.PinName". It stores no
-- link to its source, so the source is found by walking upstream connections: Container.In_X is fed either by a real
-- node's output pin in the parent graph (the source), or by the parent container's own In_X pin (one nesting level up,
-- keep walking). Every pin along such a chain resolves to the same source, so they all end up with the same name.
-- Output pass-down pins (Result) are fed from inside their container and are left alone.
--
-- * Automatic: renaming a node (mcNodeRenamed) renames every pass-down pin whose source is that node and every
--   transition leaving or entering it. The work runs on the next idle tick, after Connect has finished its own rename.
-- * Manual: Frpg2 > Resync Node References renames every pin and transition in the network whose name doesn't match.
------------------------------------------------------------------------------------------------------------------------

local kPinPrefix = "In_"
local kMaxResolveDepth = 64
local kRenameHandlerId = "FRPG2RenameHandler"

-- set while this script renames pins or transitions, so the mcNodeRenamed events those renames fire are ignored.
local isRenaming = false
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
-- table getUpstreamPins(string pinPath, boolean resolveReferences)
------------------------------------------------------------------------------------------------------------------------
local getUpstreamPins = function(pinPath, resolveReferences)
  local ok, connections = pcall(listConnections, {
    Object = pinPath,
    Pins = true,
    Upstream = true,
    Downstream = false,
    ResolveReferences = resolveReferences,
  })
  if not ok or type(connections) ~= "table" then
    return { }
  end
  return connections
end

------------------------------------------------------------------------------------------------------------------------
-- boolean isStateInStateMachine(string object)
-- A state's pass-down pins are the state machine's own pins shared across all its states: they can't be renamed on the
-- state, renaming the state machine's pin renames them all.
------------------------------------------------------------------------------------------------------------------------
local isStateInStateMachine = function(object)
  local parent = splitNodePath(object)
  if parent == nil or parent == "" then
    return false
  end
  return safeGetType(parent) == "StateMachine"
end

------------------------------------------------------------------------------------------------------------------------
-- table listPassDownPins()
-- "Container.PinName" for every pin Connect reports as a PassDownPin. If it reports none (getType may not know pins),
-- falls back to every In_* pin on an object that has children, i.e. a container. Pins on states are skipped (see
-- isStateInStateMachine).
------------------------------------------------------------------------------------------------------------------------
local listPassDownPins = function()
  local typed = { }
  local guessed = { }

  for _, object in ipairs(ls()) do
    local ok, pins = false, nil
    if not isStateInStateMachine(object) then
      ok, pins = pcall(listPins, object)
    end
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
-- table splitPathSegments(string path)
------------------------------------------------------------------------------------------------------------------------
local splitPathSegments = function(path)
  local segments = { }
  for segment in string.gfind(path, "[^|]+") do
    table.insert(segments, segment)
  end
  return segments
end

------------------------------------------------------------------------------------------------------------------------
-- string, string getVisibleSource(string node, string container)
-- The node that feeds container from the graph the two share: node itself, or the ancestor of node that sits in that
-- graph (a container whose Result carries node's output out). Returns nil and a reason when node is inside container
-- (an output pin) or encloses it (one of the enclosing container's own pass-down pins).
------------------------------------------------------------------------------------------------------------------------
local getVisibleSource = function(node, container)
  if node == container or isInside(node, container) then
    return nil, "output pin"
  end

  local nodeSegments = splitPathSegments(node)
  local containerSegments = splitPathSegments(container)
  local common = 0
  while common < table.getn(nodeSegments) and common < table.getn(containerSegments)
    and nodeSegments[common + 1] == containerSegments[common + 1] do
    common = common + 1
  end

  if common == table.getn(nodeSegments) then
    return nil, "fed by enclosing container " .. node
  end

  local source = { }
  for i = 1, common + 1 do
    table.insert(source, nodeSegments[i])
  end
  return table.concat(source, "|"), nil
end

------------------------------------------------------------------------------------------------------------------------
-- string, string resolveSourceByWalking(string pinPath, number depth)
-- Fallback when Connect can't resolve the pin's references: follows the unresolved upstream connection, walking out
-- through enclosing containers' pass-down pins until it reaches a real node.
------------------------------------------------------------------------------------------------------------------------
local resolveSourceByWalking
resolveSourceByWalking = function(pinPath, depth)
  if depth > kMaxResolveDepth then
    return nil, "chain too deep"
  end

  local container, pinName = splitPinPath(pinPath)

  -- a state's pin is its state machine's pin: walk from that one.
  if isStateInStateMachine(container) then
    container = splitNodePath(container)
    pinPath = container .. "." .. pinName
  end

  local connections = getUpstreamPins(pinPath, false)
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

  -- fed by the enclosing container's own pass-down pin: walk one level out.
  if isInside(container, upstreamNode) then
    return resolveSourceByWalking(upstream, depth + 1)
  end

  return getVisibleSource(upstreamNode, container)
end

------------------------------------------------------------------------------------------------------------------------
-- string, string resolveSource(string pinPath)
-- Returns the path of the node feeding the pass-down pin, or nil and a reason (unconnected, output pin, ...).
-- Connect resolves chains of pass-down pins (pin fed by another container's pass-down pin) itself when asked to resolve
-- references; the node it lands on is mapped back to the node visible next to the pin's container.
------------------------------------------------------------------------------------------------------------------------
local resolveSource = function(pinPath)
  local container = splitPinPath(pinPath)
  local connections = getUpstreamPins(pinPath, true)
  local count = table.getn(connections)
  if count == 0 then
    return resolveSourceByWalking(pinPath, 0)
  end
  if count > 1 then
    return nil, "more than one input: " .. table.concat(connections, ", ")
  end

  local upstreamNode = splitPinPath(connections[1])
  if upstreamNode == nil or upstreamNode == "" then
    return resolveSourceByWalking(pinPath, 0)
  end
  return getVisibleSource(upstreamNode, container)
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

  isRenaming = true
  local ok, err = pcall(function()
    -- resolve everything before renaming anything, since a renamed pin no longer has the path an inner pin walks to.
    local work = { }
    local passDownPins = listPassDownPins()
    found = table.getn(passDownPins)
    for _, pinPath in ipairs(passDownPins) do
      local source, reason = resolveSource(pinPath)
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
  isRenaming = false

  if not ok then
    app.error(string.format("FRPG2: pass-down pin sync failed: %s", tostring(err)))
  end

  return renamed, resolved, found
end

------------------------------------------------------------------------------------------------------------------------
-- Transitions
--
-- A transition is named <source>_<destination> after the leaf names of the nodes it connects, with _1, _2, ... added
-- when more than one transition links the same pair. The source is the single upstream connection (a state, or another
-- transition for a break-out transition); the destination is the downstream connection that is a StateMachineNode
-- (downstream also lists the break-out transitions leaving this one).
------------------------------------------------------------------------------------------------------------------------

local kTempTransitionPrefix = "FRPG2TmpTransition"
local kMaxTransitionDepth = 64

------------------------------------------------------------------------------------------------------------------------
-- string safeGetBaseType(string path)
------------------------------------------------------------------------------------------------------------------------
local safeGetBaseType = function(path)
  local ok, _, baseType = pcall(getType, path)
  if ok then
    return baseType
  end
  return nil
end

------------------------------------------------------------------------------------------------------------------------
-- table listTransitions()
------------------------------------------------------------------------------------------------------------------------
local listTransitions = function()
  local transitions = { }
  for _, object in ipairs(ls()) do
    if safeGetBaseType(object) == "Transition" then
      table.insert(transitions, object)
    end
  end
  return transitions
end

------------------------------------------------------------------------------------------------------------------------
-- string, string resolveTransition(string transition)
-- Returns the source and destination paths of the transition, or nil when either can't be found.
------------------------------------------------------------------------------------------------------------------------
local resolveTransition = function(transition)
  local okUp, upstream = pcall(listConnections, { Object = transition, Upstream = true, Downstream = false })
  if not okUp or type(upstream) ~= "table" or table.getn(upstream) ~= 1 then
    return nil, nil
  end

  local okDown, downstream = pcall(listConnections, { Object = transition, Upstream = false, Downstream = true })
  if not okDown or type(downstream) ~= "table" then
    return nil, nil
  end

  for _, path in ipairs(downstream) do
    if safeGetBaseType(path) == "StateMachineNode" then
      return upstream[1], path
    end
  end
  return nil, nil
end

------------------------------------------------------------------------------------------------------------------------
-- number getTransitionDepth(string transition, table sources)
-- 0 for a transition leaving a state, 1 for a break-out from such a transition, and so on. sources maps each
-- transition to its source path.
------------------------------------------------------------------------------------------------------------------------
local getTransitionDepth = function(transition, sources)
  local depth = 0
  local source = sources[transition]
  while source ~= nil and sources[source] ~= nil and depth < kMaxTransitionDepth do
    depth = depth + 1
    source = sources[source]
  end
  return depth
end

------------------------------------------------------------------------------------------------------------------------
-- table planTransitionNames(table candidates)
-- candidates is a list of { path, parent, base }. Gives every group of candidates sharing a parent and base the names
-- base, base_1, base_2, ... (skipping names other children of the parent already use). Transitions that already hold
-- one of their group's names keep it. Returns a list of { path, name } for the transitions that must be renamed.
------------------------------------------------------------------------------------------------------------------------
local planTransitionNames = function(candidates)
  local candidateSet = { }
  local groups = { }
  local groupOrder = { }
  for _, item in ipairs(candidates) do
    candidateSet[item.path] = true
    local key = item.parent .. "|" .. item.base
    if groups[key] == nil then
      groups[key] = { parent = item.parent, base = item.base, items = { } }
      table.insert(groupOrder, key)
    end
    table.insert(groups[key].items, item)
  end

  -- names used by children of each parent that aren't being renamed here.
  local takenByParent = { }
  local getTaken = function(parent)
    if takenByParent[parent] == nil then
      local taken = { }
      local ok, children = pcall(listChildren, parent)
      if ok and type(children) == "table" then
        for _, child in ipairs(children) do
          if not candidateSet[child] then
            taken[getLeafName(child)] = true
          end
        end
      end
      takenByParent[parent] = taken
    end
    return takenByParent[parent]
  end

  local work = { }
  for _, key in ipairs(groupOrder) do
    local group = groups[key]
    local taken = getTaken(group.parent)

    local wanted = { }
    local wantedSet = { }
    local suffix = 0
    while table.getn(wanted) < table.getn(group.items) do
      local name = group.base
      if suffix > 0 then
        name = group.base .. "_" .. suffix
      end
      if not taken[name] then
        table.insert(wanted, name)
        wantedSet[name] = true
      end
      suffix = suffix + 1
    end

    local remaining = { }
    for _, item in ipairs(group.items) do
      local current = getLeafName(item.path)
      if wantedSet[current] then
        wantedSet[current] = nil
      else
        table.insert(remaining, item)
      end
    end
    table.sort(remaining, function(a, b) return a.path < b.path end)

    local index = 1
    for _, name in ipairs(wanted) do
      if wantedSet[name] then
        table.insert(work, { path = remaining[index].path, name = name })
        index = index + 1
      end
    end

    -- every name in the group is now used by a child of the parent.
    for _, name in ipairs(wanted) do
      taken[name] = true
    end
  end

  return work
end

------------------------------------------------------------------------------------------------------------------------
-- table, number applyTransitionNames(table work)
-- Renames each transition in two steps (to a temporary name, then to its final one) so names can be swapped between
-- transitions of the same parent. Returns a map of old path -> new path, and the number renamed.
------------------------------------------------------------------------------------------------------------------------
local applyTransitionNames = function(work)
  local newPaths = { }
  local renamed = 0

  local temp = { }
  local tempIndex = 0
  for _, item in ipairs(work) do
    local parent = splitNodePath(item.path)
    local tempName
    repeat
      tempIndex = tempIndex + 1
      tempName = kTempTransitionPrefix .. tempIndex
    until not objectExists(parent .. "|" .. tempName)

    local ok, result = pcall(rename, item.path, tempName)
    if ok then
      table.insert(temp, { old = item.path, path = result or (parent .. "|" .. tempName), name = item.name })
    else
      app.warning(string.format("FRPG2: could not rename transition %s to %s: %s", item.path, item.name, tostring(result)))
    end
  end

  for _, item in ipairs(temp) do
    local ok, result = pcall(rename, item.path, item.name)
    if ok then
      local parent = splitNodePath(item.path)
      newPaths[item.old] = result or (parent .. "|" .. item.name)
      renamed = renamed + 1
      app.info(string.format("FRPG2: renamed transition %s -> %s", item.old, item.name))
    else
      newPaths[item.old] = item.path
      app.warning(string.format("FRPG2: could not rename transition %s to %s (left as %s): %s",
        item.old, item.name, item.path, tostring(result)))
    end
  end

  return newPaths, renamed
end

------------------------------------------------------------------------------------------------------------------------
-- number, number syncTransitionNames(table changedNodes)
-- Renames every transition whose name doesn't match its source and destination. With changedNodes (a set of node
-- paths) only transitions leaving or entering one of those nodes are touched; a transition renamed this way counts as
-- changed for its break-out transitions. Returns the number of transitions renamed and found.
------------------------------------------------------------------------------------------------------------------------
local syncTransitionNames = function(changedNodes)
  local renamed = 0
  local found = 0

  isRenaming = true
  local ok, err = pcall(function()
    local transitions = listTransitions()
    found = table.getn(transitions)
    if found == 0 then
      return
    end

    local changed = nil
    if changedNodes ~= nil then
      changed = { }
      for path in pairs(changedNodes) do
        changed[path] = true
      end
    end

    -- break-out transitions are named after their source transition, so name sources first: one depth at a time.
    local sources = { }
    for _, transition in ipairs(transitions) do
      sources[transition] = resolveTransition(transition)
    end
    local levels = { }
    local maxDepth = 0
    for _, transition in ipairs(transitions) do
      local depth = getTransitionDepth(transition, sources)
      if levels[depth] == nil then
        levels[depth] = { }
      end
      table.insert(levels[depth], transition)
      if depth > maxDepth then
        maxDepth = depth
      end
    end

    undoBlock(function()
      for depth = 0, maxDepth do
        local candidates = { }
        for _, transition in ipairs(levels[depth] or { }) do
          -- resolve again: a source renamed at the previous depth has a new path.
          local source, dest = resolveTransition(transition)
          if source ~= nil and (changed == nil or changed[source] or changed[dest]) then
            table.insert(candidates, {
              path = transition,
              parent = splitNodePath(transition),
              base = getLeafName(source) .. "_" .. getLeafName(dest),
            })
          elseif source == nil and changed == nil then
            app.warning(string.format("FRPG2: no source or destination for transition %s", transition))
          end
        end

        local work = planTransitionNames(candidates)
        if table.getn(work) > 0 then
          local newPaths, count = applyTransitionNames(work)
          renamed = renamed + count
          if changed ~= nil then
            for _, newPath in pairs(newPaths) do
              changed[newPath] = true
            end
          end
        end
      end
    end)
  end)
  isRenaming = false

  if not ok then
    app.error(string.format("FRPG2: transition name sync failed: %s", tostring(err)))
  end

  return renamed, found
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

  syncTransitionNames(sourceNodes)
  syncPassDownPinNames(sourceNodes)
end

------------------------------------------------------------------------------------------------------------------------
-- nil onNodeRenamed(string oldPath, string newPath)
------------------------------------------------------------------------------------------------------------------------
local onNodeRenamed = function(oldPath, newPath)
  if isRenaming or type(newPath) ~= "string" then
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
-- nil resyncNodeNameRefs()
-- Frpg2 menu command: renames every mismatched transition and pass-down pin in the open network.
------------------------------------------------------------------------------------------------------------------------
resyncNodeNameRefs = function()
  local transitionsRenamed, transitionsFound = syncTransitionNames(nil)
  app.info(string.format("FRPG2: found %d transitions, renamed %d.", transitionsFound, transitionsRenamed))

  local renamed, resolved, found = syncPassDownPinNames(nil)
  app.info(string.format("FRPG2: found %d pass-down pins, %d input pins with a source, renamed %d.", found, resolved, renamed))
end