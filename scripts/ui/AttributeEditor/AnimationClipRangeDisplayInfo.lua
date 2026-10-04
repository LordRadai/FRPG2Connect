------------------------------------------------------------------------------------------------------------------------
-- Copyright (c) 2010 NaturalMotion.  All Rights Reserved.
-- Not to be copied, adapted, modified, used, distributed, sold, licensed or commercially exploited in any manner
-- without the written consent of NaturalMotion.
--
-- All non public elements of this software are the confidential information of NaturalMotion and may not be disclosed
-- to any person nor used for any purpose not expressly approved by NaturalMotion in writing.
------------------------------------------------------------------------------------------------------------------------

require "ui/AttributeEditor/AttributeEditor.lua"

local timelineButtonHelpText = [[
Sets the values of the Start and End clip range to that of the clipped range of the animation take selected in the animation take attribute for the same animation set.
]]

local resetButtonHelpText = [[
Resets the values of the Start and End clip range to the full length of the animation take selected in the animation take attribute for the same animation set.
]]

------------------------------------------------------------------------------------------------------------------------
-- create a per animation set clip range section
------------------------------------------------------------------------------------------------------------------------
local addPerAnimSetClipRangeSection = function(panel, selection, attributes, set)
  attributeEditor.logEnterFunc("addPerAnimSetClipRangeSection")
  local clipStartWidget, clipEndWidget

  -- ClipRangeMode values, as the asset compiler reads them
  local kMarkerRange, kEntireRange, kCustomRange = 1, 2, 3
  local rangeModeItems = { "Marker range", "Entire range", "Custom range" }
  local syncing = false   -- syncInterface sets the combo; that must not write attributes back

  -- Start / End only matter for a custom range; show what the other modes will play
  local rangeModeChanged = function(self)
    if syncing then return end
    local mode = self:getSelectedIndex()
    if mode < kMarkerRange or mode > kCustomRange then return end
    setCommonAttributeValue(selection, "ClipRangeMode", mode, set)
    if mode == kEntireRange then
      setCommonAttributeValue(selection, "ClipStartFraction", 0, set)
      setCommonAttributeValue(selection, "ClipEndFraction", 1, set)
    elseif mode == kMarkerRange then
      for i, object in ipairs(selection) do
        local animationTake = getAttribute(object, "AnimationTake", set)
        if animationTake and anim.takeExists(animationTake) then
          local animPath = string.format("%s|%s", animationTake.filename, animationTake.takename)
          local clipStartFraction = anim.getAttribute(string.format("%s.%s", animPath, "ClipStartFraction")) -- marked up clip start
          local clipEndFraction = anim.getAttribute(string.format("%s.%s", animPath, "ClipEndFraction")) -- marked up clip end
          setAttribute(string.format("%s.ClipStartFraction", object), clipStartFraction, set)
          setAttribute(string.format("%s.ClipEndFraction", object), clipEndFraction, set)
        end
      end
    end
  end

  attributeEditor.log("panel:beginVSizer")
  panel:beginVSizer{ flags = "expand" }

    -- Clip range mode
    panel:beginHSizer{ flags = "expand" }
      panel:addHSpacer(6)
      local rangeModeLabel = attributeEditor.addAttributeLabel(panel, "Clip range", selection, "ClipRangeMode")
      local rangeModeCombo = panel:addComboBox{ flags = "expand", proportion = 1, items = rangeModeItems, onChanged = rangeModeChanged }
      attributeEditor.bindAttributeHelpToWidget(rangeModeCombo, selection, "ClipRangeMode")
    panel:endSizer()

    panel:addVSpacer(3)
    attributeEditor.log("panel:beginFlexGridSizer")
    panel:beginFlexGridSizer{ cols = 3, flags = "expand", proportion = 1 }
      panel:setFlexGridColumnExpandable(3)

      panel:addHSpacer(6)
      local clipStartLabel = attributeEditor.addAttributeLabel(panel, "Start", selection, "ClipStartFraction")
      clipStartWidget = attributeEditor.addAttributeWidget(panel, "ClipStartFraction", selection, set)
      clipStartWidget:setDisabledLabel(" ")

      panel:addHSpacer(6)
      local clipEndLabel = attributeEditor.addAttributeLabel(panel, "End", selection, "ClipEndFraction")
      clipEndWidget = attributeEditor.addAttributeWidget(panel, "ClipEndFraction", selection, set)
      clipEndWidget:setDisabledLabel(" ")

    attributeEditor.log("panel:endSizer")
    panel:endSizer()

    panel:addVSpacer(3)

    panel:beginHSizer{ flags = "right", }

      local resetButton = panel:addButton{
        label = "Reset",
        onClick = function()
          setCommonAttributeValue(selection, "ClipStartFraction", 0, set)
          setCommonAttributeValue(selection, "ClipEndFraction", 1, set)
        end,
        size = { width = 74 }
      }
      attributeEditor.bindHelpToWidget(resetButton, resetButtonHelpText)

    panel:endSizer()

  attributeEditor.log("panel:endSizer")
  panel:endSizer()

  -- syncInterface
  syncInterface = function()
    local rangeMode = getCommonAttributeValue(selection, "ClipRangeMode", set)
    if rangeMode == nil then
      rangeModeCombo:setIsIndeterminate(true)
    else
      rangeModeCombo:setIsIndeterminate(false)
      syncing = true
      rangeModeCombo:setSelectedIndex(rangeMode)
      syncing = false
    end

    -- Clip Widgets
    local duration = 0;
    if clipStartWidget and clipEndWidget then
      local validAndCommonTake = getCommonSubAttributeValue(selection, "AnimationTake", "filename", set)
      if validAndCommonTake then
        local animationTake = getAttribute(selection[1], "AnimationTake", set)
        if anim.takeExists(animationTake) then
          duration = anim.getTakeDuration(animationTake)
          local fps = anim.getTakeFramerate(animationTake)

          clipStartWidget:setDisplayDuration(duration)
          clipStartWidget:setDisplayFramerate(fps)

          clipEndWidget:setDisplayDuration(duration)
          clipEndWidget:setDisplayFramerate(fps)
        else
          validAndCommonTake = false
        end
      end

      local disableWidgets = duration == 0 or (not validAndCommonTake) or (rangeMode ~= kCustomRange)
      clipStartWidget:enable(not disableWidgets)
      clipEndWidget:enable(not disableWidgets)
      clipStartLabel:enable(not disableWidgets)
      clipEndLabel:enable(not disableWidgets)

      clipStartWidget:setDisplayUnits("preferences")
      clipStartWidget:showTrailingUnits()
      clipEndWidget:setDisplayUnits("preferences")
      clipEndWidget:showTrailingUnits()
    end

    -- Enable/Disable the reset button
    local disableResetButton = duration == 0 or containsReference(selection) or (rangeMode ~= kCustomRange)
    resetButton:enable(not disableResetButton)

    local disableRangeMode = duration == 0 or containsReference(selection)
    rangeModeCombo:enable(not disableRangeMode)
    rangeModeLabel:enable(not disableRangeMode)
  end

  local animationFilesChanged = function(resourceSet)
    local commonTake = getCommonSubAttributeValue(selection, "AnimationTake", "filename", set)
    if commonTake then
      local id = anim.getResourceId(commonTake)
      if resourceSet[id] ~= nil then
        syncInterface()
      end
    end
  end

  -- Create a change context to watch the ClipRangeMode
  local changeContext = attributeEditor.createChangeContext()
  changeContext:setObjects(selection)
  changeContext:addAttributeChangeEvent("ClipRangeMode")
  changeContext:setAttributeChangedHandler(syncInterface)
  syncInterface()

  attributeEditor.addAnimationFileChanged(animationFilesChanged)
  attributeEditor.logExitFunc("addPerAnimSetClipRangeSection")
end

------------------------------------------------------------------------------------------------------------------------
-- Add's a display info section for animation clip range attributes.
-- Used by AnimWithEvents.
------------------------------------------------------------------------------------------------------------------------
attributeEditor.animationClipRangeDisplayInfoSection = function(panel, displayInfo, selection)
  attributeEditor.logEnterFunc("attributeEditor.animationClipRangeDisplayInfoSection")

  attributeEditor.log("rollContainter:addRollup")
  local rollup = panel:addRollup{ label = displayInfo.title, flags = "mainSection", name = "animationClipRangeDisplayInfoSection" }
  local rollPanel = rollup:getPanel()

  attributeEditor.log("rollPanel:beginVSizer")
  rollPanel:beginVSizer{ flags = "expand" }

    attributeEditor.addAnimationSetWidget(rollPanel, displayInfo.usedAttributes, selection, addPerAnimSetClipRangeSection)

  attributeEditor.log("rollPanel:endSizer")
  rollPanel:endSizer()

  attributeEditor.logExitFunc("attributeEditor.animationClipRangeDisplayInfoSection")
end