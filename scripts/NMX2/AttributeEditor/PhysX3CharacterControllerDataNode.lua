-- Copyright (c) 2010 NaturalMotion.  All Rights Reserved.
-- Not to be copied, adapted, modified, used, distributed, sold,
-- licensed or commercially exploited in any manner without the
-- written consent of NaturalMotion.
--
-- All non public elements of this software are the confidential
-- information of NaturalMotion and may not be disclosed to any
-- person nor used for any purpose not expressly approved by
-- NaturalMotion in writing.
------------------------------------------------------------------------------------------------------------------------

-- Get hold of the application
--
local app = nmx.Application.new()
local scriptManager = app:getScriptManager()
local callbackManager = app:getCallbackManager()

local attributeGroups = scriptManager:createCallback(
  -- The scripting language the callback is written in
  --
  "lua",

  -- The arguments that the callback will take.
  --
  nmx.CallbackManager.AttributeGroupsCallbackSignature(),

  -- The callback function body
  --
  [[
    local attrs = {
      'PhysX3 Attributes',
      'StepHeight'
    }

    validAttributes:push_back(attrs)
  ]]
)

-- Unregister any previous callbacks
callbackManager:unRegisterAttributeGroupsCallback("PhysX3CharacterControllerDataNode")
-- Register the new callback
callbackManager:registerAttributeGroupsCallback("PhysX3CharacterControllerDataNode", attributeGroups)