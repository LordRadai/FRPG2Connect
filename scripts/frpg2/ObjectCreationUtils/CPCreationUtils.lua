------------------------------------------------------------------------------------------------------------------------
--| LUAHELP: FUNCTION
--| signature: string createControlParameter(string dataType, string name, number min, number max, number defaultValue)
--| brief: Creates a control parameter node with the specified attributes and returns its path.
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