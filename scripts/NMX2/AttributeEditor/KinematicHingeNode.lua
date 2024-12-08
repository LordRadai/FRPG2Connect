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

local attributeGroups, errorString = scriptManager:createCallback(
  -- The scripting language the callback is written in
  --
  "lua",

  -- The arguments that the callback will take.
  --
  nmx.CallbackManager.AttributeGroupsCallbackSignature(),

  -- The callback function body.
  --
  [[
    -- These attributes will always be shown.
    --
    validAttributes:push_back({
        nmx.String.new('Limit Attributes'),
        nmx.String.new('RotationOffset'),
        nmx.String.new('Active'),
        nmx.String.new('Angle'),
        nmx.String.new('Offset')
        })
  ]]
)

-- Unregister any previous callbacks
callbackManager:unRegisterAttributeGroupsCallback(nmx.KinematicHingeNode.ClassTypeId())
-- Register the new callback
callbackManager:registerAttributeGroupsCallback(nmx.KinematicHingeNode.ClassTypeId(), attributeGroups)

