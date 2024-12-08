-- Global table to store registered nodes
local registered_nodes = {}

-- Function to register a node with a given name and table
function registerNode(name, node_table)
    registered_nodes[name] = node_table
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
            local is_array = (table.getn(value) > 0)
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
local function write_node_to_file(name, json_data)
    local file_name = mcn.getApplicationRoot() .. "\\json\\" .. name .. ".json"  -- Construct the file name (e.g., Node1.json)
    local file = io.open(file_name, "w")  -- Open the file in write mode
    if file then
        file:write(json_data)  -- Write the JSON data to the file
        file:close()  -- Close the file
        print("Successfully wrote " .. file_name)
    else
        error("Could not open file for writing: " .. file_name)
    end
end

-- Function to load a Lua file and execute it
local function load_node(file)
    local chunk = loadfile(file)
    if chunk then
        chunk()  -- Execute the file (which calls registerNode() inside)
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

fileExists = function(filename)
  local handle = io.open(filename)
  if io.type(handle) == "file" then
    handle:close()
    return true
  end
  return false
end

-- Convert Lua table to INI format string
convertManifestToJson = function()
    -- Serialize the table to JSON
    local animNodePath = mcn.getScriptsPath() .. "\\manifest\\nodes\\animation\\"
    local operatorNodePath = mcn.getScriptsPath() .. "\\manifest\\nodes\\operator\\"

    local animNodes = listFiles(animNodePath, "*.lua")
    for i=1, table.getn(animNodes) do
      require(animNodes[i])
      load_node(animNodes[i])
    end

    local operatorNodes = listFiles(operatorNodePath, "*.lua")
    for i=1, table.getn(operatorNodes) do
      require(operatorNodes[i])
      load_node(operatorNodes[i])
    end

    -- Now, `registered_nodes` holds all the nodes with their names as keys.
    for name, node in pairs(registered_nodes) do
        local json_string = table_to_json(node)

        write_node_to_file(name, json_string)
    end
end