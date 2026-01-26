------------------------------------------------------------------------------------------------------------------------
--| LUAHELP: FUNCTION
--| signature: string getAnimationFileName(string animFilePath)
--| brief: Extracts the animation node name from the given animation file path by removing directories and file extensions.
--| page: FRPG2 XML Decompiler
------------------------------------------------------------------------------------------------------------------------
getAnimationFileName = function(animFilePath)
    if type(animFilePath) ~= "string" then
        error("Expected a string for animFilePath, got " .. tostring(animFilePath))
    end

    -- remove the path, keep only the filename
    local filename = animFilePath:gsub(".*[\\/]", "")

    -- remove the last file extension
    local nameWithoutExt = filename:gsub("%.[^%.]+$", "")

    return nameWithoutExt
end

------------------------------------------------------------------------------------------------------------------------
--| LUAHELP: FUNCTION 
--| signature: string createAnimationNode(string parentPath, string animSetName, string animFileName, string animTakeName, string syncTrack, boolean isLoop)
--| brief: Creates an animation node with the specified parameters and returns its path. 
--| page: FRPG2 XML Decompiler
------------------------------------------------------------------------------------------------------------------------
createAnimationNode = function(parentPath, animSetName, animFileName, animTakeName, syncTrack, isLoop)
  local animTake = {filename=animFileName, takename=animTakeName, synctrack=syncTrack}
  
  if not anim.takeExists(animTake) then
    print("Animation take does not exist: " .. animFileName .. " - " .. animTakeName)
    return nil
  end

  local animNode = create("AnimWithEvents", parentPath, getAnimationFileName(animFileName))
  setAttribute(animNode .. ".AnimationTake", animTake, animSetName)
  setAttribute(animNode .. ".Loop", isLoop)
  
  print("Created animation node: " .. animNode)
  
  return animNode
end

------------------------------------------------------------------------------------------------------------------------
--| LUAHELP: FUNCTION
--| signature: string createNote(string parentPath, string name, string message)
--| brief: Creates a note node with the specified attributes and returns its path.
------------------------------------------------------------------------------------------------------------------------
createNote = function(parentPath, name, message)
  local noteNode = create("Note", parentPath, name)
  setAttribute(noteNode .. ".Message", message)
  
  print("Created note node: " .. noteNode)
  
  return noteNode
end