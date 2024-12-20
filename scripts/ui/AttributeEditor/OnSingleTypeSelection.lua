------------------------------------------------------------------------------------------------------------------------
-- Copyright (c) 2010 NaturalMotion.  All Rights Reserved.
-- Not to be copied, adapted, modified, used, distributed, sold, licensed or commercially exploited in any manner
-- without the written consent of NaturalMotion.
--
-- All non public elements of this software are the confidential information of NaturalMotion and may not be disclosed
-- to any person nor used for any purpose not expressly approved by NaturalMotion in writing.
------------------------------------------------------------------------------------------------------------------------

require "ui/AttributeEditor/AttributeEditor.lua"

local kBakeReferenceMessage = [[
Are you sure you want to bake this reference?
]]

------------------------------------------------------------------------------------------------------------------------
-- copies node attribute values into a flat list which is attrib path indexed.
------------------------------------------------------------------------------------------------------------------------
local getNodeAttributes = function(nodePath)
  local allAttribValues = { }
  local attribValues = { }
  local attribList = listAttributes(nodePath)
  for f, attrib in attribList do
    local attribPath = nodePath .. "." .. attrib
    attribValues[attribPath] = getAttribute(attribPath)
  end
  return attribValues
end

------------------------------------------------------------------------------------------------------------------------
-- expects a flat list of node attribute values which is attrib path indexed (generated by getNodeAttributes)
-- and reapplied those values to any natching attribute path.
------------------------------------------------------------------------------------------------------------------------
local resetNodeAttributes = function(attribValues)
  for attribPath, attribValue in attribValues do
    if attributeExists(attribPath) then
      local type = getType(attribPath)
      if type == "controlParameter" and attribValue == "" then
        continue
      end
      setAttribute(attribPath, attribValue)
    end
  end
end

------------------------------------------------------------------------------------------------------------------------
-- adds the objects type text and the rename control
-- only used when one object is selected.
------------------------------------------------------------------------------------------------------------------------
local addObjectTypeAndRenameControl = function(panel, baseType, objectType, objectName)
  attributeEditor.logEnterFunc("addObjectTypeAndRenameControl()")

  local objectIsReferenced = isReferenced(objectName)

  -- add the actual controls
  attributeEditor.log("panel:beginVSizer()")
  panel:beginVSizer{ flags = "expand" }

  if baseType == "Transition" then
    local from = listConnections{
      Object = objectName,
      Upstream = true,
      Downstream = false,
      ResolveReferences = true
    }
    local to = listConnections{
      Object = objectName,
      Upstream = false,
      Downstream = true,
      ResolveReferences = true
    }
    
    
    attributeEditor.log("adding transition type ComboBox")
    local baseTypes = listTypes(baseType, getTransitionCategory(objectName))
    
    local transitToSelf = table.getn(from) == 1 and table.getn(to) == 1 and from[1] == to[1]
    if transitToSelf then
      for i=table.getn(baseTypes),1,-1 do
        if not manifest.supportsTransitToSelf(baseTypes[i]) and baseType ~= baseTypes[i] then
          table.remove(baseTypes, i)
        end
      end
    end
    
    if table.getn(baseTypes) > 1 then
      local transitCombo = panel:addComboBox{
        flags = "expand",
        proportion = 1,
        items = baseTypes, 
        onMouseEnter = function()
          attributeEditor.setHelpText(getHelpText(objectType))
        end,
        onMouseLeave = function()
          attributeEditor.clearHelpText()
        end,
        onChanged = function(self)
          local theSelection = ls("Selection")
          undoBlock(function()
             -- cache existing attribute values
            local allAttributeValues = getNodeAttributes(objectName)

            -- check if it belongs to a layer
            local belongingLayer = getLayer(objectName)
            if (belongingLayer ~= "") then
              removeFromLayer(objectName)
            end

            -- change transition type
            utils.changeTransitionType(objectName, self:getSelectedItem())

            -- make sure we keep the old transition name
            local _, nodeName = splitNodePath(objectName)
            rename(theSelection[1], nodeName)

            -- reapply shared attribute values
            resetNodeAttributes(allAttributeValues)

            if belongingLayer ~= "" then
              addToLayer(belongingLayer, objectName)
            end
          end)
          select(theSelection)
      end
      }

      transitCombo:setSelectedItem(objectType)

      if objectIsReferenced then
        transitCombo:enable(false)
      end
    end
  else
    attributeEditor.log("adding object type StaticText")
    panel:addStaticText{text = objectType, flags = "expand"}
    attributeEditor.bindHelpToWidget(panel,getHelpText(objectType))
  end

  if baseType ~= nil and objectName ~= "" then
    attributeEditor.log("adding object rename TextBox")
    local fullpath, nodename = splitNodePath(objectName)
    local nodeNameWidget = panel:addTextBox{value = nodename, flags = "expand", proportion = 1}
    attributeEditor.bindHelpToWidget(nodeNameWidget, "The name of the node.")

    -- if it is a reference we add an additional field with the file name and a button
    if baseType ~= "Transition" and baseType ~= "Condition" then
      local parentEditable = not isReferenced(fullpath)
      local nodeFile = getReferenceFile(objectName)
      if string.len(nodeFile) > 0 then
        local referenceFile = panel:addTextBox{value = nodeFile, flags = "expand", proportion = 1}
        referenceFile:setReadOnly(true)        
        attributeEditor.bindHelpToWidget(referenceFile, "The path of the file that is referenced.")

        local bakeButton = panel:addButton{
          label = "Bake Reference",
          flags = "right",
          onClick = function(self)
            if ui.showMessageBox(kBakeReferenceMessage, "yesno") == "yes" then
              bakeReference(objectName)
            end
          end
        }
        bakeButton:enable(parentEditable)
      end
    end

    if objectIsReferenced then
      nodeNameWidget:enable(false)
    end

    -- set the on enter function for the name text box
    nodeNameWidget:setOnEnter(
      function()
        attributeEditor.logEnterFunc("rename control nodeNameWidget:setOnEnter()")

        local newName = nodeNameWidget:getValue()
        attributeEditor.log(string.format("renaming object from \"%s\" to \"%s\"", objectName, newName))
        rename(objectName, newName)

        attributeEditor.logExitFunc("rename control nodeNameWidget:setOnEnter()")
        attributeEditor.log()
      end
    )
  end

  attributeEditor.log("panel:endSizer()")
  panel:endSizer()

  attributeEditor.logExitFunc("addObjectTypeAndRenameControl()")
end

------------------------------------------------------------------------------------------------------------------------
-- handle selection of a single type with one or more nodes
------------------------------------------------------------------------------------------------------------------------
attributeEditor.doSingleTypeSelection = function(panel, selection)
  attributeEditor.logEnterFunc("attributeEditor.doSingleTypeSelection()")

  local selectionCount = table.getn(selection)
  if selectionCount < 1 then
    attributeEditor.log("error selection must contain 1 or more objects, contains %d", selectionCount)
    attributeEditor.logExitFunc("attributeEditor.doSingleTypeSelection()")
    return
  end

  panel:beginVSizer{ flags = "expand" }

    local firstObjectName = selection[1]
    local objectType, baseType = getType(firstObjectName)

    if selectionCount > 1 then
      attributeEditor.log("adding type and selection count")
      panel:addStaticText{ text = objectType .. " (" .. selectionCount .. ")" }
    else
      -- set the active object name
      attributeEditor.log("setting attributeEditor.activeObjectName to \"%s\"", firstObjectName)
      attributeEditor.activeObjectName = firstObjectName

      -- next add the type and rename text box
      addObjectTypeAndRenameControl(panel, baseType, objectType, firstObjectName)
    end

    -- Add a rollup into a container for each display info section.
    attributeEditor.log("adding main rollup container")
    local rollContainerName = string.format("MainRollupContainer_%s", objectType)
    local rollContainer = panel:addRollupContainer{ flags = "expand", name = rollContainerName }

    -- add conditions editor
    if baseType == "Transition" then
      attributeEditor.addConditionEditor(rollContainer, selection)
    end

    local displayInfo = attributeEditor.displayInfo[objectType]
    if type(displayInfo) == "table" then
      attributeEditor.log("adding display info sections")
      for i, section in ipairs(displayInfo) do

        -- add the current sections used attributes to the global attributes table
        if type(section.usedAttributes) == "table" then
          for j, attr in ipairs(section.usedAttributes) do
            attributeEditor.log("marking attribute \"%s\" as used", attr)
            attributeEditor.usedAttributes[attr] = true
          end
        end

        if type(section.title) == "string" and string.len(section.title) > 0 then
          -- call the display function for the current section
          attributeEditor.log("attempting to call displayInfo.displayFunc", attr)
          safefunc(section.displayFunc, rollContainer, section, selection)
        end
      end
    end

    -- build the list of unused attributes and non manifest attributes that not been used so far
    attributeEditor.log("building list of unused attributes")
    local objectAttributes = listAttributes(firstObjectName)
    local unusedAttributes = { }
    local nonManifestAttributes = { }
    for i, attr in pairs(objectAttributes) do
      if not attributeEditor.usedAttributes[attr] then
        if isManifestAttribute(string.format("%s.%s", firstObjectName, attr)) then
          table.insert(unusedAttributes, attr)
        else
          table.insert(nonManifestAttributes, attr)
        end
      end
    end

    -- If there are any unused manifest attributes render them
    if table.getn(unusedAttributes) > 0 then
      table.sort(unusedAttributes)
      attributeEditor.addSimpleAttributeSection(rollContainer, "Properties", selection, unusedAttributes)
    end

    -- gather all common non manifest properties and render them if any
    local commonNonManifestAttributes = getCommonAttributes(selection, nonManifestAttributes)
    table.sort(commonNonManifestAttributes)
    attributeEditor.addCustomAttributeSection(rollContainer, "Custom Properties", selection, commonNonManifestAttributes)

  panel:endSizer()

  attributeEditor.logExitFunc("attributeEditor.doSingleTypeSelection()")
end

