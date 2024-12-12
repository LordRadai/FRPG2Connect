------------------------------------------------------------------------------------------------------------------------
-- Initialise all the FRPG2 scripts required
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- make sure the main startup script was run first
------------------------------------------------------------------------------------------------------------------------
local appScriptsDir = app.getAppScriptsDir()

-- as startup.lua defines the LUA_PATH we must use the full path to it when calling require
--
local filename = string.format("%sstartup.lua", appScriptsDir)
require(filename)

require [[FRPG2/frpg2Menu.lua]]