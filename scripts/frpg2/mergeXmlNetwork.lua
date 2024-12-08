require [[luaAPI/McnUtils.lua]]

local id = nil

------------------------------------------------------------------------------------------------
-- cancel button function - hide window
------------------------------------------------------------------------------------------------
local cancel = function()  
  mergeNetworkXMLWindow:hide()  
end

------------------------------------------------------------------------------------------------
-- get full source xml path for the network
------------------------------------------------------------------------------------------------
local getNetworkXMLPath = function()
  local animdl = ui.createFileDialog({name = "XMLPathControl",
                                      caption = "Network XML Path",
                                      wildcard = "xml files|xml"} )
  animdl:show()  
  local NewImportPath = animdl:getFullPath() 
  local tempName = ui.getWindow("CreateMergeNetworkXMLWindow|NetworkXMLBox")   
  tempName:setValue(NewImportPath)
end --function

------------------------------------------------------------------------------------------------
-- get full source path for the anim library
------------------------------------------------------------------------------------------------
local getAnimLibraryPath = function()
  local animdl = ui.createFileDialog({name = "AnimLibraryPathControl",
                                      caption = "Anim Library Path",
                                      wildcard = "xml files|xml"} )
  animdl:show()  
  local NewImportPath = animdl:getFullPath() 
  local tempName = ui.getWindow("CreateMergeNetworkXMLWindow|AnimLibraryBox")   
  tempName:setValue(NewImportPath)
end --function

------------------------------------------------------------------------------------------------
-- create error dialogue if something goes wrong
------------------------------------------------------------------------------------------------
local errorDialog = function(errorText)

  errorWindow = nil
  collectgarbage()
  
  errorWindow = ui.createModelessDialog
  { 
    caption = "Errors", 
    size = {width = 300, height = 150}, 
    name = "ErrorWindow"
  }
  errorWindow:beginVSizer()
    ----------------------------------------------------------
    errorWindow:beginHSizer{flags = "expand"}    
      local errorName = errorWindow:addStaticText
      {
         text = errorText,
         name = "Help"
      }              
    errorWindow:endSizer()      
  errorWindow:endSizer()
  
  errorWindow:show() 

end

------------------------------------------------------------------------------------------------
-- merge network xml to mcn main function
------------------------------------------------------------------------------------------------
--local mergeXMLNetwork (string mcnPath, string networkPath, string animLibraryPath)
local mergeXMLNetwork = function(mcnPath, networkPath, animLibraryPath)
    local command = mcn.getApplicationRoot() .. "tools\\x64\\NoPhysics\\mcnMerger.exe " .. "\"" .. mcnPath .. "\" \"" .. networkPath .. "\" \"" .. animLibraryPath .. "\""
    --errorDialog(command)
    os.execute(command)
end

-------------------------------------------------------------------------------------------------
-- set variables from createAnimRigWindow() and call createAnimRig()
------------------------------------------------------------------------------------------------
local setVariables = function()

  local checkList = true
  local errorMessage = "\n"  
 
  local networkXMLName = ui.getWindow("CreateMergeNetworkXMLWindow|NetworkXMLBox"):getValue()
  local animLibraryName = ui.getWindow("CreateMergeNetworkXMLWindow|AnimLibraryBox"):getValue()
  local mcnFileName = mcn.filename();

  if(networkXMLName == "")then
    errorMessage = errorMessage .. "Network XML path was not selected.\n"
    errorDialog(errorMessage)
    checkList = false
  end 
  
  if(animLibraryName == "")then
    errorMessage = errorMessage .. "Anim library path was not selected.\n"
    errorDialog(errorMessage)
    checkList = false
  end 

  if(mcnFileName == "")then
    errorMessage = errorMessage .. "No MCN is loaded.\n"
    errorDialog(errorMessage)
    checkList = false
  end 

  if(checkList) then
    mergeXMLNetwork(mcnFileName, networkXMLName, animLibraryName)
    mergeNetworkXMLWindow:hide()
  end
end --function

------------------------------------------------------------------------------------------------
-- window function.
------------------------------------------------------------------------------------------------
createMergeNetworkXMLWindowFunc = function()

    mergeNetworkXMLWindow = nil
    collectgarbage()
    
    mergeNetworkXMLWindow = ui.createModelessDialog
    { 
      caption = "Merge Network XML", 
      size = {width = 500, height = 150}, 
      name = "CreateMergeNetworkXMLWindow"
    }
  
    local btnWidth = 100
    local btnHeight = 50
  
  
    -- start main layout   
      mergeNetworkXMLWindow:beginVSizer()
        ----------------------------------------------------------
        mergeNetworkXMLWindow:beginHSizer{flags = "expand"}
            
              local NetworkXMLText = mergeNetworkXMLWindow:addStaticText
              {
                text = "Network XML\t",
                name = "NetworkXMLText",
                size = { width = 120 }
              }
            
              local NetworkXMLBox = mergeNetworkXMLWindow:addTextBox
              {
                flags = "expand",
                proportion = 1,
                setReadOnly = false,              
                name = "NetworkXMLBox"
              }
              local NetworkXMLButton = mergeNetworkXMLWindow:addButton
              {
                setReadOnly = false,
                label = "...",
                name = "NetworkXMLButton"
              }       
              NetworkXMLButton:setOnClick(getNetworkXMLPath)
              
        mergeNetworkXMLWindow:endSizer() 
        ----------------------------------------------------------
        mergeNetworkXMLWindow:beginHSizer{flags = "expand"}
        
            local AnimLibraryText = mergeNetworkXMLWindow:addStaticText
            {
              text = "Animation Library\t",
              name = "AnimLibraryText",
              size = { width = 120 }
            }
          
            local AnimLibraryBox = mergeNetworkXMLWindow:addTextBox
            {
              flags = "expand",
              proportion = 1,
              setReadOnly = false,              
              name = "AnimLibraryBox"
            }
            local AnimLibraryButton = mergeNetworkXMLWindow:addButton
            {
              setReadOnly = false,
              label = "...",
              name = "AnimLibraryButton"
            }       
            AnimLibraryButton:setOnClick(getAnimLibraryPath)
            
        mergeNetworkXMLWindow:endSizer() 
        ----------------------------------------------------------
        mergeNetworkXMLWindow:beginHSizer()
        
          -- Add buttons to OK or Cancel this operation.
          local OKBox = mergeNetworkXMLWindow:addButton
          {
            flags = "expand",
            proportion = 1,
            label = "OK",
            name = "OKBox"
          }
          OKBox:setOnClick(setVariables)
  
          local CancelBox = mergeNetworkXMLWindow:addButton
          {
            flags = "expand",
            proportion = 1,
            label = "Cancel",
            name = "CancelBox"
          }
           CancelBox:setOnClick(cancel)
         
        mergeNetworkXMLWindow:endSizer()
    mergeNetworkXMLWindow:endSizer()
    mergeNetworkXMLWindow:show()
  end
  
  --creatAnimRigWindowFunc()