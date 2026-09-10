ScriptName BiSR Hidden
{Native CHIM static dispatch looks up this class name from integration metadata.}

Bool Function DispatchExternalCommand(String asNpcName, String asCommand, String asParameter) Global
	Return mzinCHIM.DispatchExternalCommand(asNpcName, asCommand, asParameter)
EndFunction
