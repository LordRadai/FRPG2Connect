------------------------------------------------------------------------------------------------------------------------
-- Copyright (c) 2011 NaturalMotion.  All Rights Reserved.
-- Not to be copied, adapted, modified, used, distributed, sold, licensed or commercially exploited in any manner
-- without the written consent of NaturalMotion.
--
-- All non public elements of this software are the confidential information of NaturalMotion and may not be disclosed
-- to any person nor used for any purpose not expressly approved by NaturalMotion in writing.
------------------------------------------------------------------------------------------------------------------------
require "ui/tools/ToolSettingsPages.lua"
require "ui/tools/ToolSettingsPanel.lua"

removeToolSettingsPage("SelectTool")
addToolSettingsPage(
  "SelectTool",
  {
    title = "Select Tool Settings",
    attributes = {
      {
        name = "ClickThroughSelection",
        displayName = "Click through selection",
      },
      {
        name = "PixelSize",
        displayName = "Pixel size",
      },
    },
    settingsNode = "|SelectToolSettingsNode",
    create = defaultToolSettingsPageCreateFunction,
    update = defaultToolSettingsPageUpdateFunction,
  }
)