require [[FRPG2/XMLDecompiler/NodeCreationUtils.lua]]
require [[FRPG2/XMLDecompiler/CPCreationUtils.lua]]

local animSet = getSelectedAnimSet()
createAnimationNode("", animSet, "$(RootDir)\\c1020\\XMD\\motion_xmd\\a00_00_0000_Idle.xmd", "untitled", "Footsteps", true)
createControlParameter("float", "Speed", 0.0, 10.0, 5.0)
createControlParameter("int", "Int", -10, 10, 0)

create("Request", "Move")
createNote("", "Note", "Test!")