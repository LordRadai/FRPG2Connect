------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Export and Process
--
-- Exports the currently open network (Name = the .mcn's name) into <OutputDir>\<Name>: writes <Name>.xml, processes it with
-- the asset compiler into <Name>_runtimeBinary (as File > Export > Export and Process does), runs
-- morphemeBinderPacker.exe on that folder (it writes binders), runs witchyBnd.exe on binders\runtimeBinary and on
-- every folder in binders\c0001, then deletes the folders inside binders. The output folder and the tool paths are
-- remembered between sessions.
------------------------------------------------------------------------------------------------------------------------
require [[ui/NetworkValidationDialog.lua]]

local kOutputDirPreference = "FRPG2ExportAndProcessDir"
local kPackerPreference = "FRPG2MorphemeBinderPackerPath"
local kPackerExe = "morphemeBinderPacker.exe"
local kWitchyPreference = "FRPG2WitchyBndPath"
local kWitchyExe = "witchyBnd.exe"
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
-- string getDefaultToolPath(string preference, string exeName)
-- The remembered tool path, else exeName next to morphemeConnect.exe if it is there.
------------------------------------------------------------------------------------------------------------------------
local getDefaultToolPath = function(preference, exeName)
  local path = getRememberedString(preference)
  if string.len(path) > 0 then
    return path
  end
  local besideConnect = app.getAppExecutableDir() .. exeName
  if app.fileExists(besideConnect) then
    return besideConnect
  end
  return ""
end

------------------------------------------------------------------------------------------------------------------------
-- boolean checkTool(string exePath, string exeName)
------------------------------------------------------------------------------------------------------------------------
local checkTool = function(exePath, exeName)
  if string.len(exePath) == 0 or not app.fileExists(exePath) then
    ui.showMessageBox(string.format("%s not found:\n%s", exeName, exePath), "ok")
    return false
  end
  return true
end

------------------------------------------------------------------------------------------------------------------------
-- boolean runTool(string exePath, string exeName, string targetDir, string options)
-- options (may be nil) go between the exe and the folder.
------------------------------------------------------------------------------------------------------------------------
local runTool = function(exePath, exeName, targetDir, options)
  -- cmd.exe strips the outer quotes, so the whole command line is quoted once more (as AnimUtils.lua does)
  local command = string.format("%q %s%q", exePath, options and (options .. " ") or "", targetDir)
  local exitCode = app.execute(string.format("\"%s\"", command), false, true)
  if exitCode ~= 0 then
    app.error(string.format("FRPG2: %s failed on %s (exit code %s)", exeName, targetDir, tostring(exitCode)))
    ui.showMessageBox(string.format("%s failed on\n%s\n(exit code %s)", exeName, targetDir, tostring(exitCode)), "ok")
    return false
  end

  app.info(string.format("FRPG2: ran %s on %s", exeName, targetDir))
  return true
end

------------------------------------------------------------------------------------------------------------------------
-- boolean runWitchyOnBinders(string witchyPath, string exportDir)
-- Runs witchyBnd on binders\runtimeBinary (required) and on every folder in binders\ext (optional).
------------------------------------------------------------------------------------------------------------------------
local runWitchyOnBinders = function(witchyPath, exportDir)
  local bindersDir = exportDir .. "\\binders"
  local runtimeBinaryDir = bindersDir .. "\\runtimeBinary"
  if not app.directoryExists(runtimeBinaryDir) then
    ui.showMessageBox(string.format("%s didn't create\n%s", kPackerExe, runtimeBinaryDir), "ok")
    return false
  end

  local targets = { runtimeBinaryDir }
  local extDir = bindersDir .. "\\c0001"
  if app.directoryExists(extDir) then
    local subDirectories = app.enumerateDirectories(extDir .. "\\", "")
    table.sort(subDirectories)
    for _, subDirectory in ipairs(subDirectories) do
      table.insert(targets, (string.gsub(subDirectory, "[\\/]+$", "")))
    end
  end

  for _, target in ipairs(targets) do
    -- -p (passive): witchyBnd otherwise waits for a key press after an error, which blocks Connect
    if not runTool(witchyPath, kWitchyExe, target, "-p") then
      return false
    end
  end
  return true
end

------------------------------------------------------------------------------------------------------------------------
-- boolean deleteBinderFolders(string exportDir)
-- Deletes every folder inside binders once witchyBnd has packed them; binders itself and its archives stay.
------------------------------------------------------------------------------------------------------------------------
local deleteBinderFolders = function(exportDir)
  local bindersDir = exportDir .. "\\binders"
  local prefix = string.lower(bindersDir .. "\\")
  local ok = true

  for _, subDirectory in ipairs(app.enumerateDirectories(bindersDir .. "\\", "")) do
    local dir = string.gsub(subDirectory, "[\\/]+$", "")
    -- only ever delete direct children of binders
    if string.sub(string.lower(dir), 1, string.len(prefix)) == prefix and string.len(dir) > string.len(prefix) then
      app.execute(string.format("\"rmdir /s /q %q\"", dir), false, true)
      if app.directoryExists(dir) then
        app.error(string.format("FRPG2: couldn't delete %s", dir))
        ok = false
      else
        app.info(string.format("FRPG2: deleted %s", dir))
      end
    end
  end

  if not ok then
    ui.showMessageBox(string.format("Some folders in\n%s\ncouldn't be deleted. See the log.", bindersDir), "ok")
  end
  return ok
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
-- boolean exportAndProcess(string outputDir, string packerPath, string witchyPath)
------------------------------------------------------------------------------------------------------------------------
local exportAndProcess = function(outputDir, packerPath, witchyPath)
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

  -- check the tools before the export, so a wrong path doesn't cost a full export
  if not checkTool(packerPath, kPackerExe) or not checkTool(witchyPath, kWitchyExe) then
    return false
  end

  -- everything goes into <output folder>\<network name>; create both levels in case createDirectory isn't recursive
  if not app.directoryExists(outputDir) then
    app.createDirectory(outputDir)
  end
  outputDir = string.format("%s\\%s", outputDir, name)
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
  if not runTool(packerPath, kPackerExe, outputDir) then
    return false
  end
  if not runWitchyOnBinders(witchyPath, outputDir) then
    return false
  end
  return deleteBinderFolders(outputDir)
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
      caption = "Export, Process and pack binders",
      centre = true,
      resize = true,
    }
  end

  dlg:freeze()
  dlg:clear()
  dlg:suspendLayout()
  dlg:setBorder(3)

  dlg:beginVSizer{ flags = "expand", proportion = 1 }
    dlg:beginFlexGridSizer{ rows = 4, cols = 3, flags = "expand", proportion = 0 }
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
        value = getDefaultToolPath(kPackerPreference, kPackerExe),
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

      dlg:addStaticText{ text = "WitchyBND" }
      local witchyTextBox = dlg:addTextBox{
        name = "WitchyPath",
        flags = "expand",
        proportion = 1,
        value = getDefaultToolPath(kWitchyPreference, kWitchyExe),
      }
      dlg:addButton{
        label = "...",
        size = { width = 24 },
        onClick = function(self)
          local fileDlg = ui.createFileDialog{
            style = "open;mustExist",
            caption = "Locate " .. kWitchyExe,
            wildcard = "Executable|exe" }
          if fileDlg:show() then
            witchyTextBox:setValue(fileDlg:getFullPath())
            rememberString(kWitchyPreference, fileDlg:getFullPath())
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
          local witchy = witchyTextBox:getValue()
          rememberString(kOutputDirPreference, dir)
          rememberString(kPackerPreference, packer)
          rememberString(kWitchyPreference, witchy)
          nameText:setLabel(getCurrentNetworkName() or "(unsaved network)")
          exportAndProcess(dir, packer, witchy)
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
