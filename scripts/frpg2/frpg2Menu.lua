------------------------------------------------------------------------------------------------------------------------
-- Copyright (c) 2012 NaturalMotion.  All Rights Reserved.
-- Not to be copied, adapted, modified, used, distributed, sold, licensed or commercially exploited in any manner
-- without the written consent of NaturalMotion.
--
-- All non public elements of this software are the confidential information of NaturalMotion and may not be disclosed
-- to any person nor used for any purpose not expressly approved by NaturalMotion in writing.
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- include other required scripts
------------------------------------------------------------------------------------------------------------------------
require [[ui/StaticUI.lua]]
require [[FRPG2/mergeXmlNetwork.lua]]
require [[FRPG2/convertManifestsToJson.lua]]

local olderUserInitStaticUI = userInitStaticUI

------------------------------------------------------------------------------------------------------------------------
-- nil addRiggingToolsMenu(MenuBar mainMenuBar)
------------------------------------------------------------------------------------------------------------------------
local addFrpg2Menu = function(mainMenuBar)

  local riggingToolsMenu = mainMenuBar:addSubMenu{ name = "FRPG2", label = "&FRPG2" }
  riggingToolsMenu:addItem{
    name = "MergeXMLNetwork",
    label = "&Merge XML Network",
    onClick = function(self)
      createMergeNetworkXMLWindowFunc();
    end,
  }

  riggingToolsMenu:addItem{
    name = "ManifestToINI",
    label = "&Export Manifest to JSON",
    onClick = function(self)
      convertManifestToJson();
    end,
  }   
end


------------------------------------------------------------------------------------------------------------------------
-- nil userInitStaticUI()
------------------------------------------------------------------------------------------------------------------------
userInitStaticUI = function()

  local mainFrame = ui.getWindow("MainFrame")
  local mainMenuBar = mainFrame:getChild("MainMenu")

  addFrpg2Menu(mainMenuBar)

  safefunc(olderUserInitStaticUI)
end