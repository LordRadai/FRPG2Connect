------------------------------------------------------------------------------------------------------------------------
--| LUAHELP: FUNCTION
--| signature: string getAnimationFileName(string animFilePath)
--| brief: Extracts the animation node name from the given animation file path by removing directories and file extensions.
--| page: FRPG2 XML Decompiler
------------------------------------------------------------------------------------------------------------------------
createControlParameter = function(dataType, name, min, max, defaultValue)
  local paramNode = create{
    Type="ControlParameter", 
    DataType=dataType, 
    Name=name,
    Min=min,
    Max=max,
    Default=defaultValue
  }
  
  print("Created control parameter: " .. paramNode)
  
  return paramNode
end