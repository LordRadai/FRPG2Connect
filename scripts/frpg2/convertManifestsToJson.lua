-- Global table to store registered nodes
local registered_nodes = {}
local registered_state_machines = {}
local registered_state_machine_nodes = {}
local registered_physics_nodes = {}
local registered_conditions = {}
local registered_transitions = {}
local registered_messages = {}
local registered_notes = {}

-- Function to register a node with a given name and table
function registerNode(name, node_table)
    registered_nodes[name] = node_table
end

-- Function to register a state machine with a given name and table
function registerStateMachine(name, state_machine_table)
    registered_state_machines[name] = state_machine_table
end

-- Function to register a state machine node with a given name and table
function registerStateMachineNode(name, state_machine_node_table)
    registered_state_machine_nodes[name] = state_machine_node_table
end

-- Function to register a condition with a given name and table
function registerCondition(name, condition_table)
    registered_conditions[name] = condition_table
end

-- Function to register a physics node with a given name and table
function registerPhysicsNode(name, physics_node_table)
    registered_physics_nodes[name] = physics_node_table
end

-- Function to register a transition with a given name and table
function registerTransition(name, transition_table)
    registered_transitions[name] = transition_table
end

-- Function to register a message with a given name and table
function registerMessage(name, message_table)
    registered_messages[name] = message_table
end

-- Function to register a note with a given name and table
function registerNote(name, note_table)
    registered_notes[name] = note_table
end

-- Helper function to escape special characters in strings
local function escape_string(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

local function is_array_table(t)
    if type(t) ~= "table" then
        return false
    end

    local max = 0
    local count = 0

    for k, _ in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        if k > max then
            max = k
        end
        count = count + 1
    end

    return max == count
end

-- Function to convert a Lua table to a JSON string
local function table_to_json(tbl)
    local indent_char = "    "  -- 4 spaces for indentation
    local result = {}

    local function serialize(value, indent_level)
        local t = type(value)
        local current_indent = string.rep(indent_char, indent_level)

        if t == "number" then
            return tostring(value)
        elseif t == "boolean" then
            return value and "true" or "false"
        elseif t == "string" then
            return "\"" .. escape_string(value) .. "\""
        elseif t == "table" then
            local is_array = is_array_table(value)
            local items = {}

            if is_array then
                -- Array: Serialize as [item1, item2, ...]
                for _, v in ipairs(value) do
                    table.insert(items, serialize(v, indent_level + 1))
                end
                return "[\n" .. current_indent .. indent_char .. table.concat(items, ",\n" .. current_indent .. indent_char) .. "\n" .. current_indent .. "]"
            else
                -- Object: Serialize as {"key": value, ...}
                for k, v in pairs(value) do
                    if type(k) == "string" then
                        local key = "\"" .. escape_string(k) .. "\""
                        local val = serialize(v, indent_level + 1)
                        table.insert(items, current_indent .. indent_char .. key .. ": " .. val)
                    end
                end
                return "{\n" .. table.concat(items, ",\n") .. "\n" .. current_indent .. "}"
            end
        else
            -- Handle unsupported types (like functions, userdata) as 'null'
            return "null"
        end
    end

    return serialize(tbl, 0)
end

-- Function to write JSON to a file using the node name as the filename
local function write_node_to_file(name, json_data, base_folder)
    local file_name = base_folder .. name .. ".json"  -- Construct the file name (e.g., base_folder/Node.json)
    local file = io.open(file_name, "w")  -- Open the file in write mode
    if file then
        file:write(json_data)
        file:close()
        print("Successfully wrote " .. file_name)
    else
        error("Could not open file for writing: " .. file_name)
    end
end

-- Function to load a Lua file and execute it
local function load_node(file)
    local chunk = loadfile(file)
    if chunk then
        chunk()  -- Execute the file (which calls the register function inside)
    else
        error("Could not load file: " .. file)
    end
end

local listFiles = nil -- this forward allows this local to be called recursively in below function
listFiles = function(directory, extension)
  local subDirectories = app.enumerateDirectories(directory, "")
  local result = { }
  local index = 1

  for i=1, table.getn(subDirectories) do
    local files = listFiles(subDirectories[i], extension)
    for j=1, table.getn(files) do
      result[index] = files[j]
      index = index + 1
    end
  end

  local files = app.enumerateFiles(directory, extension)
  for i=1, table.getn(files) do
    result[index] = files[i]
    index = index + 1
  end
  return result
end

registerNodesInFolder = function(manifest_dir)
    local nodes = listFiles(manifest_dir, "*.lua")
    for i=1, table.getn(nodes) do
        require(nodes[i])
        load_node(nodes[i])
    end
end

initializeAndExportManifest = function(manifest_dir, output_dir, registered_table)
    -- Clear the registered table. We use a shared table for nodes and operator, this is necessary to avoid creating duplicate entries.
    for k in pairs(registered_table) do
        registered_table[k] = nil
    end
    
    -- Ensure the base folder exists. If not, create it.
    if not app.directoryExists(output_dir) then
        app.createDirectory(output_dir)
    end
    
    -- Register nodes from the specified manifest directory.
    registerNodesInFolder(manifest_dir)

    -- Write each registered node to a JSON file.
    for name, node in pairs(registered_table) do
        local json_string = table_to_json(node)

        write_node_to_file(name, json_string, output_dir)
    end
end

-- Convert Lua table to INI format string
convertManifestToJson = function()
    print("Converting manifest to JSON format...")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\nodes\\animation\\", mcn.getApplicationRoot() .. "\\jsonManifest\\nodes\\animation\\", registered_nodes)
    print("Registered " .. table.getn(registered_nodes) .. " animation nodes.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\nodes\\animation\\", mcn.getApplicationRoot() .. "\\jsonManifest\\nodes\\animation\\", registered_state_machines)
    print("Registered " .. table.getn(registered_state_machines) .. " animation state machines.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\nodes\\animation\\", mcn.getApplicationRoot() .. "\\jsonManifest\\nodes\\animation\\", registered_state_machine_nodes)
    print("Registered " .. table.getn(registered_state_machine_nodes) .. " animation state machine nodes.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\nodes\\operator\\", mcn.getApplicationRoot() .. "\\jsonManifest\\nodes\\operator\\", registered_nodes)
    print("Registered " .. table.getn(registered_nodes) .. " operator nodes.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\nodes\\physics\\", mcn.getApplicationRoot() .. "\\jsonManifest\\nodes\\physics\\", registered_physics_nodes)
    print("Registered " .. table.getn(registered_physics_nodes) .. " physics nodes.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\nodes\\physics\\", mcn.getApplicationRoot() .. "\\jsonManifest\\nodes\\physics\\", registered_state_machines)
    print("Registered " .. table.getn(registered_state_machines) .. " physics state machines.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\conditions\\cparam\\", mcn.getApplicationRoot() .. "\\jsonManifest\\conditions\\cparam\\", registered_conditions)
    print("Registered " .. table.getn(registered_conditions) .. " cparam conditions.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\conditions\\event\\", mcn.getApplicationRoot() .. "\\jsonManifest\\conditions\\event\\", registered_conditions)
    print("Registered " .. table.getn(registered_conditions) .. " event conditions.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\conditions\\physics\\", mcn.getApplicationRoot() .. "\\jsonManifest\\conditions\\physics\\", registered_conditions)
    print("Registered " .. table.getn(registered_conditions) .. " physics conditions.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\conditions\\request\\", mcn.getApplicationRoot() .. "\\jsonManifest\\conditions\\request\\", registered_conditions)
    print("Registered " .. table.getn(registered_conditions) .. " request conditions.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\transitions\\", mcn.getApplicationRoot() .. "\\jsonManifest\\transitions\\", registered_transitions)
    print("Registered " .. table.getn(registered_transitions) .. " transitions.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\messages\\", mcn.getApplicationRoot() .. "\\jsonManifest\\messages\\", registered_messages)
    print("Registered " .. table.getn(registered_messages) .. " messages.")

    initializeAndExportManifest(mcn.getScriptsPath() .. "\\manifest\\notes\\", mcn.getApplicationRoot() .. "\\jsonManifest\\notes\\", registered_notes)
    print("Registered " .. table.getn(registered_notes) .. " notes.")

    print("Manifest conversion to JSON completed successfully.")
end