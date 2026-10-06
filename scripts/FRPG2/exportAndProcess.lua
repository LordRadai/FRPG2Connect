------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Export and Process
--
-- Exports the currently open network to <OutputDir>\<Name>.xml and processes it with the asset compiler into
-- <OutputDir>\<Name>_runtimeBinary, the same way File > Export > Export and Process does, but without asking for a
-- file every time. The output folder is remembered between sessions.
------------------------------------------------------------------------------------------------------------------------
require [[ui/NetworkValidationDialog.lua]]

local kOutputDirPreference = "FRPG2ExportAndProcessDir"
local kDialogName = "FRPG2ExportAndProcessDialog"

------------------------------------------------------------------------------------------------------------------------
-- string getRememberedOutputDir()
------------------------------------------------------------------------------------------------------------------------
local getRememberedOutputDir = function()
  if preferences.exists(kOutputDirPreference) then
    local value = preferences.get(kOutputDirPreference)
    if type(value) == "string" then
      return value
    end
  end
  return ""
end

------------------------------------------------------------------------------------------------------------------------
-- nil rememberOutputDir(string dir)
------------------------------------------------------------------------------------------------------------------------
local rememberOutputDir = function(dir)
  preferences.set{
    name = kOutputDirPreference,
    location = "RoamingUser",
    type = "string",
    value = dir,
  }
end

------------------------------------------------------------------------------------------------------------------------
-- string getCurrentNetworkName()
-- Name of the open .mcn without folder and extension, or "" when Connect doesn't tell us.
------------------------------------------------------------------------------------------------------------------------
local getCurrentNetworkName = function()
  local getters = { "filename", "getFilename", "getNetworkFilename", "getCurrentFilename" }
  for _, getter in ipairs(getters) do
    local fn = mcn[getter]
    if type(fn) == "function" then
      local ok, filename = pcall(fn)
      if ok and type(filename) == "string" and string.len(filename) > 0 then
        local _, file = splitFilePath(filename)
        return stripFilenameExtension(file)
      end
    end
  end
  return ""
end

------------------------------------------------------------------------------------------------------------------------
-- string stripTrailingSeparator(string dir)
------------------------------------------------------------------------------------------------------------------------
local stripTrailingSeparator = function(dir)
  return (string.gsub(dir, "[\\/]+$", ""))
end

------------------------------------------------------------------------------------------------------------------------
-- boolean exportAndProcess(string outputDir, string name)
------------------------------------------------------------------------------------------------------------------------
local exportAndProcess = function(outputDir, name)
  if not mcn.isOpen() then
    ui.showMessageBox("No network is open.", "ok")
    return false
  end

  outputDir = stripTrailingSeparator(outputDir)
  if string.len(outputDir) == 0 then
    ui.showMessageBox("Set an output folder first.", "ok")
    return false
  end
  if string.len(name) == 0 or not isValidFilename(name) then
    ui.showMessageBox("Set a valid network name first.", "ok")
    return false
  end

  if not app.directoryExists(outputDir) then
    app.createDirectory(outputDir)
  end

  local xmlPath = string.format("%s\\%s.xml", outputDir, name)
  local runtimeDir = string.format("%s\\%s_runtimeBinary", outputDir, name)
  app.createDirectory(runtimeDir)

  local result, ids, errors, warnings = mcn.export(xmlPath, nil, nil, nil, runtimeDir)

  local show = false
  if table.getn(errors) > 0 then
    show = true
  elseif preferences.get("DisplayNetworkValidationWarnings") then
    if table.getn(warnings) > 0 then
      show = true
    end
  end

  if not result or show then
    safefunc(showNetworkValidationReport, ids, warnings, errors)
  end

  if result then
    app.info(string.format("FRPG2: exported %s and processed it into %s", xmlPath, runtimeDir))
  else
    app.error(string.format("FRPG2: export and process of %s failed", xmlPath))
  end
  return result
end

------------------------------------------------------------------------------------------------------------------------
-- nil showFrpg2ExportAndProcessDialog()
------------------------------------------------------------------------------------------------------------------------
showFrpg2ExportAndProcessDialog = function()
  if mcn.inCommandLineMode() then
    return
  end

  local dlg = ui.getWindow(kDialogName)
  if not dlg then
    dlg = ui.createModelessDialog{
      name = kDialogName,
      caption = "FRPG2 Export and Process",
      centre = true,
      resize = true,
    }
  end

  dlg:freeze()
  dlg:clear()
  dlg:suspendLayout()
  dlg:setBorder(3)

  dlg:beginVSizer{ flags = "expand", proportion = 1 }
    dlg:beginFlexGridSizer{ rows = 2, cols = 3, flags = "expand", proportion = 0 }
      dlg:setFlexGridColumnExpandable(2)

      dlg:addStaticText{ text = "Output folder" }
      local dirTextBox = dlg:addTextBox{
        name = "OutputDir",
        flags = "expand",
        proportion = 1,
        value = getRememberedOutputDir(),
      }
      dlg:addButton{
        label = "...",
        size = { width = 24 },
        onClick = function(self)
          local dirDlg = ui.createDirectoryDialog{ parent = dlg, caption = "Output folder" }
          local current = dirTextBox:getValue()
          if string.len(current) > 0 and app.directoryExists(current) then
            dirDlg:setPath(current)
          end
          if dirDlg:show() ~= false then
            dirTextBox:setValue(dirDlg:getPath())
            rememberOutputDir(dirDlg:getPath())
          end
        end,
      }

      dlg:addStaticText{ text = "Network name" }
      local nameTextBox = dlg:addTextBox{
        name = "NetworkName",
        flags = "expand",
        proportion = 1,
        value = getCurrentNetworkName(),
      }
      dlg:addButton{
        label = "Reset",
        size = { width = 48 },
        onClick = function(self)
          nameTextBox:setValue(getCurrentNetworkName())
        end,
      }
    dlg:endSizer()

    dlg:addVSpacer(6)

    dlg:beginHSizer{ flags = "right", proportion = 0 }
      dlg:addButton{
        name = "ExportProcessButton",
        label = "Export and Process",
        onClick = function(self)
          local dir = dirTextBox:getValue()
          rememberOutputDir(dir)
          exportAndProcess(dir, nameTextBox:getValue())
        end,
      }
      dlg:addButton{
        label = "Close",
        size = { width = 74 },
        onClick = function(self)
          dlg:hide()
        end,
      }
    dlg:endSizer()
  dlg:endSizer()

  dlg:resumeLayout()
  dlg:rebuild()
  dlg:thaw()
  dlg:setSize{ width = 480, height = -1 }
  dlg:show()
end
