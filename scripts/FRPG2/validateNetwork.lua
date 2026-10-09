------------------------------------------------------------------------------------------------------------------------
-- FRPG2 Validate Network
--
-- Checks that the open network has the nodes Dark Souls II looks up by name. c0001.mcn (the player) is checked against
-- the player list, every other network against the enemy list. Paths are node paths as Connect writes them, without a
-- root prefix: "SM_Main|SubAct|Ladder". If any are missing, a modal dialog lists them.
--
-- Frpg2 > Validate Network runs it. validateFrpg2Network() returns true when nothing is missing, so it can also gate an
-- export.
------------------------------------------------------------------------------------------------------------------------

local kDialogName = "FRPG2ValidateNetworkDialog"
local kPlayerNetworkName = "c0001"

local kPlayerNodePaths = {
  "StateMachine_Main|BT_StartUp",
  "StateMachine_Main|BlendTree_BasicMove",
  "StateMachine_Main|BlendTree_BasicMove|StateMachine_MainNetwork|SM_Idle",
  "StateMachine_Main|BlendTree_BasicMove|StateMachine_MainNetwork|SM_MenuIdle",
  "StateMachine_Main|BlendTree_BasicMove|StateMachine_MainNetwork|BlendTree_MoveTurn",
  "SM_MoveGuard|SM_Guard",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Move",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|Selector_In_L",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|Selector_In_R",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|Selector_Out_L",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|Selector_Out_R",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_ItemUse",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Move|SM_ChangeWeapon_L|SM_WeaponChange_L",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Move|SM_ChangeWeapon_R|SM_WeaponChange_R",
  "StateMachine_Main|SM_CatchDamagePC",
  "StateMachine_Main|BT_CatchDamageENE",
  "StateMachine_Main|SM_Step|BT_Step",
  "StateMachine_Main|SM_Step|BT_StepStaminaEmpty",
  "StateMachine_Main|SM_Step|BT_StepFailed",
  "StateMachine_Main|SM_Dodge",
  "StateMachine_Main|SM_Dodge|BT_DodgeTakeoff",
  "StateMachine_Main|SM_Dodge|BT_DodgeTakeoffStaminaEmpty",
  "StateMachine_Main|SM_Dodge|BT_DodgeTakeoffFailed",
  "StateMachine_Main|SM_Jump",
  "StateMachine_Main|SM_Jump|BT_JumpTakeoff",
  "StateMachine_Main|SM_Jump|BT_StandJumpTakeoff",
  "StateMachine_Main|SM_Jump|BT_JumpLoop",
  "StateMachine_Main|SM_Ladder",
  "StateMachine_Main|SM_Ladder|SM_LadderDash",
  "StateMachine_Main|SM_Ladder|SM_LadderFall|BT_FallLoop",
  "StateMachine_Main|SM_Ladder|SM_LadderIdle",
  "StateMachine_Main|SM_Ladder|SM_LadderIdle|BT_LadderIdle_Left",
  "StateMachine_Main|SM_Ladder|SM_LadderIdle|BT_LadderIdle_Right",
  "StateMachine_Main|SM_Ladder|SM_LadderMoveEnd",
  "StateMachine_Main|SM_Fall",
  "StateMachine_Main|SM_Fall|BT_RollLanding",
  "StateMachine_Main|SM_Guard",
  "StateMachine_Main|BT_Damage",
  "StateMachine_Main|BT_Damage|SM_Damage|SM_HitBack",
  "StateMachine_Main|SM_Die",
  "StateMachine_Main|BT_EventAction|SM_EventAction",
  "StateMachine_Main|BT_Bonfire",
  "StateMachine_Main|BT_Gesture",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|SM_Attack_ShortRange|BT_Attack1HandJump_R_Hit",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|SM_Attack_ShortRange|BT_Attack1HandJump_L_Hit",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|SM_Attack_ShortRange|BT_Attack2HandJump_R_Hit",
  "StateMachine_Main|BlendTree_BasicMove|SM_MoveOrAttackGuard|BT_Attack_MoveGuard|MoveAttack_Ref|BT_MoveAttack|SM_Attack_ShortRange|BT_Attack2HandJump_L_Hit",
  "StateMachine_Main|BT_Rope|SM_Rope|SM_RopeMove",
  "StateMachine_Main|BT_Damage|SM_Damage|SM_Down_Tumble_Air",
}

local kEnemyNodePaths = {
  "SM_Main|SM_StartUp",
  "SM_Main|BT_BaseAct|SM_BasicMove|BT_Idle",
  "SM_Main|BT_BaseAct|SM_BasicMove",
  "SM_Main|SM_Attack",
  "SM_Main|BT_Damage|DamageFullBody",
  "SM_Main|SubAct|Event",
  "SM_Main|SubAct|BT_MoveJump|SM_MoveJump",
  "SM_Main|SubAct|BT_StandJump|SM_StandJump",
  "SM_Main|SubAct|BT_MoveJump|SM_MoveJump|BT_JumpTakeoff",
  "SM_Main|SubAct|BT_StandJump|SM_StandJump|BT_StandJumpTakeoff",
  "SM_Main|SubAct|BT_MoveJump|SM_MoveJump|SM_JumpLoop",
  "SM_Main|SubAct|BT_StandJump|SM_StandJump|SM_StandJumpLoop",
  "SM_Main|BT_BaseAct|SM_BasicMove|BT_WalkStayTurn",
  "SM_Main|BT_BaseAct|SM_BasicMove|BT_MoveTurn",
  "SM_Main|SubAct|Ladder",
  "SM_Main|SubAct|Ladder|BT_Ladder|SM_Ladder|SM_LadderIdle",
  "SM_Main|SubAct|Ladder|BT_Ladder|SM_Ladder|SM_LadderFall",
  "SM_Main|SubAct|Ladder|BT_Ladder|SM_Ladder|SM_LadderMoveEnd",
  "SM_Main|SM_Avoid|Dodge_act",
  "SM_Main|SM_Avoid|Step_act",
}

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
-- boolean nodeExists(string path)
------------------------------------------------------------------------------------------------------------------------
local nodeExists = function(path)
  local ok, exists = pcall(objectExists, path)
  return ok and exists == true
end

------------------------------------------------------------------------------------------------------------------------
-- table findMissingNodes(table paths)
------------------------------------------------------------------------------------------------------------------------
local findMissingNodes = function(paths)
  local missing = { }
  for _, path in ipairs(paths) do
    if not nodeExists(path) then
      table.insert(missing, path)
    end
  end
  return missing
end

------------------------------------------------------------------------------------------------------------------------
-- nil showMissingNodesDialog(string networkName, number numChecked, table missing)
-- Modal: blocks until the user closes it.
------------------------------------------------------------------------------------------------------------------------
local showMissingNodesDialog = function(networkName, numChecked, missing)
  local dlg = ui.getWindow(kDialogName)
  if not dlg then
    dlg = ui.createModalDialog{
      name = kDialogName,
      caption = "Validate Network",
      centre = true,
      resize = true,
    }
  end

  dlg:freeze()
  dlg:clear()
  dlg:suspendLayout()
  dlg:setBorder(3)

  dlg:beginVSizer{ flags = "expand", proportion = 1 }
    dlg:addStaticText{
      text = string.format("%s: missing %d states. This does not mean a network is invalid, but a character without some key states cannot perform certain actions.",
        networkName, table.getn(missing)),
      font = "bold",
    }

    local listText = dlg:addTextControl{
      name = "MissingNodes",
      flags = "expand",
      proportion = 1,
      size = { width = 720, height = 320 },
    }
    listText:setValue(table.concat(missing, "\n"))
    listText:setReadOnly(true)

    dlg:addVSpacer(6)

    dlg:beginHSizer{ flags = "right", proportion = 0 }
      dlg:addButton{
        label = "OK",
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
  dlg:show()
end

------------------------------------------------------------------------------------------------------------------------
-- boolean validateFrpg2Network(boolean quietIfValid)
-- true when every required node exists. Missing nodes are logged and shown in a modal dialog; a valid network shows a
-- message box unless quietIfValid is set.
------------------------------------------------------------------------------------------------------------------------
validateFrpg2Network = function(quietIfValid)
  if not mcn.isOpen() then
    ui.showMessageBox("No network is open.", "ok")
    return false
  end

  local name = getCurrentNetworkName()
  if not name then
    ui.showMessageBox("The network has no file name yet. Save it first.", "ok")
    return false
  end

  local paths = kEnemyNodePaths
  local listName = "enemy"
  if string.lower(name) == kPlayerNetworkName then
    paths = kPlayerNodePaths
    listName = "player"
  end

  local missing = findMissingNodes(paths)
  local numChecked = table.getn(paths)

  if table.getn(missing) == 0 then
    app.info(string.format("FRPG2: %s has all %d %s nodes", name, numChecked, listName))
    if not quietIfValid and not mcn.inCommandLineMode() then
      ui.showMessageBox(string.format("%s has all %d required %s nodes.", name, numChecked, listName), "ok")
    end
    return true
  end

  for _, path in ipairs(missing) do
    app.warning(string.format("FRPG2: %s is missing %s", name, path))
  end

  if not mcn.inCommandLineMode() then
    showMissingNodesDialog(name, numChecked, missing)
  end
  return false
end
