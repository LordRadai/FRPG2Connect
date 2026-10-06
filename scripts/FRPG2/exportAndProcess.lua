------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Export and Process
--
-- Exports the currently open network to <OutputDir>\<Name>.xml (Name = the .mcn's name) and processes it with the asset compiler into
-- <OutputDir>\<Name>_runtimeBinary, the same way File > Export > Export and Process does, but without asking for a
-- file every time, then runs morphemeBinderPacker.exe on <OutputDir>\<Name>_runtimeBinary. The output folder and the
-- packer path are remembered between sessions.
------------------------------------------------------------------------------------------------------------------------
require [[ui/NetworkValidationDialog.lua]]

local kOutputDirPreference = "FRPG2ExportAndProcessDir"
local kPackerPreference = "FRPG2MorphemeBinderPackerPath"
local kPackerExe = "morphemeBinderPacker.exe"
local kDialogName = "FRPG2ExportAndProcessDialog"

------------------------------------------------------------------------------------------------------------------------
-- string getRememberedString(string preference)
------------------------------------------------------------------------------------------------------------------------
local getRememberedString = function(preference)
  if preferences.exists(preference) then
    local value = preferences.get(preference)
    if type(value) == "string" then
      return value
    end
  end
  return ""
end

------------------------------------------------------------------------------------------------------------------------
-- nil rememberString(string preference, string value)
------------------------------------------------------------------------------------------------------------------------
local rememberString = function(preference, value)
  preferences.set{
    name = preference,
    location = "RoamingUser",
    type = "string",
    value = value,
  }
end

------------------------------------------------------------------------------------------------------------------------
-- string getDefaultPackerPath()
-- The remembered packer path, else morphemeBinderPacker.exe next to morphemeConnect.exe if it is there.
------------------------------------------------------------------------------------------------------------------------
local getDefaultPackerPath = function()
  local path = getRememberedString(kPackerPreference)
  if string.len(path) > 0 then
    return path
  end
  local besideConnect = app.getAppExecutableDir() .. kPackerExe
  if app.fileExists(besideConnect) then
    return besideConnect
  end
  return ""
end

------------------------------------------------------------------------------------------------------------------------
-- boolean runPacker(string packerPath, string runtimeDir)
------------------------------------------------------------------------------------------------------------------------
local runPacker = function(packerPath, runtimeDir)
  if string.len(packerPath) == 0 or not app.fileExists(packerPath) then
    ui.showMessageBox(string.format("%s not found:\n%s", kPackerExe, packerPath), "ok")
    return false
  end

  -- cmd.exe strips the outer quotes, so the whole command line is quoted once more (as AnimUtils.lua does)
  local command = string.format("%q %q", packerPath, runtimeDir)
  local exitCode = app.execute(string.format("\"%s\"", command), false, true)
  if exitCode ~= 0 then
    app.error(string.format("FRPG2: %s failed on %s (exit code %s)", kPackerExe, runtimeDir, tostring(exitCode)))
    ui.showMessageBox(string.format("%s failed on\n%s\n(exit code %s)", kPackerExe, runtimeDir, tostring(exitCode)), "ok")
    return false
  end

  app.info(string.format("FRPG2: packed %s", runtimeDir))
  return true
end

------------------------------------------------------------------------------------------------------------------------
-- string getCurrentNetworkName()
-- Name of the open file without folder and extension, or nil for an unsaved network.
------------------------------------------------------------------------------------------------------------------------
local getCurrentNetworkName = function()
  local filename = project.getFilename()
  if type(filename) ~= "string" or string.len(filename) == 0 then
    return nil
  end
  local _, file = splitFilePath(filename)
  return stripFilenameExtension(file)
end

------------------------------------------------------------------------------------------------------------------------
-- string stripTrailingSeparator(string dir)
------------------------------------------------------------------------------------------------------------------------
local stripTrailingSeparator = function(dir)
  return (string.gsub(dir, "[\\/]+$", ""))
end

------------------------------------------------------------------------------------------------------------------------
-- boolean exportAndProcess(string outputDir, string packerPath)
------------------------------------------------------------------------------------------------------------------------
local exportAndProcess = function(outputDir, packerPath)
  if not mcn.isOpen() then
    ui.showMessageBox("No network is open.", "ok")
    return false
  end

  outputDir = stripTrailingSeparator(outputDir)
  if string.len(outputDir) == 0 then
    ui.showMessageBox("Set an output folder first.", "ok")
    return false
  end

  local name = getCurrentNetworkName()
  if not name then
    ui.showMessageBox("The network has no file name yet. Save it first.", "ok")
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

  if not result then
    app.error(string.format("FRPG2: export and process of %s failed", xmlPath))
    return false
  end

  app.info(string.format("FRPG2: exported %s and processed it into %s", xmlPath, runtimeDir))
  return runPacker(packerPath, runtimeDir)
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
    dlg:beginFlexGridSizer{ rows = 3, cols = 3, flags = "expand", proportion = 0 }
      dlg:setFlexGridColumnExpandable(2)

      dlg:addStaticText{ text = "Output folder" }
      local dirTextBox = dlg:addTextBox{
        name = "OutputDir",
        flags = "expand",
        proportion = 1,
        value = getRememberedString(kOutputDirPreference),
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
            rememberString(kOutputDirPreference, dirDlg:getPath())
          end
        end,
      }

      dlg:addStaticText{ text = "Binder packer" }
      local packerTextBox = dlg:addTextBox{
        name = "PackerPath",
        flags = "expand",
        proportion = 1,
        value = getDefaultPackerPath(),
      }
      dlg:addButton{
        label = "...",
        size = { width = 24 },
        onClick = function(self)
          local fileDlg = ui.createFileDialog{
            style = "open;mustExist",
            caption = "Locate " .. kPackerExe,
            wildcard = "Executable|exe" }
          if fileDlg:show() then
            packerTextBox:setValue(fileDlg:getFullPath())
            rememberString(kPackerPreference, fileDlg:getFullPath())
          end
        end,
      }

      dlg:addStaticText{ text = "Network" }
      local nameText = dlg:addStaticText{
        name = "NetworkName",
        text = getCurrentNetworkName() or "(unsaved network)",
        flags = "expand",
      }
      dlg:addHSpacer(0)
    dlg:endSizer()

    dlg:addVSpacer(6)

    dlg:beginHSizer{ flags = "right", proportion = 0 }
      dlg:addButton{
        name = "ExportProcessButton",
        label = "Export and Process",
        onClick = function(self)
          local dir = dirTextBox:getValue()
          local packer = packerTextBox:getValue()
          rememberString(kOutputDirPreference, dir)
          rememberString(kPackerPreference, packer)
          nameText:setLabel(getCurrentNetworkName() or "(unsaved network)")
          exportAndProcess(dir, packer)
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
