ScriptName mzinBathePlayerAlias Extends ReferenceAlias

mzinUtility Property mzinUtil Auto
mzinBatheQuest Property BatheQuest Auto
Faction Property TrackedBatherFaction Auto
GlobalVariable Property AutomateFollowerBathing Auto
GlobalVariable Property BatheKeyCode Auto
GlobalVariable Property ModifierKeyCode Auto
GlobalVariable Property CheckStatusKeyCode Auto
GlobalVariable Property DirtinessPercentage Auto
GlobalVariable Property ShynessDistance Auto
Message Property DirtinessStatusMessage Auto

Actor Property PlayerRef Auto

; ---------- CHIM ----------

Event OnInit()
	RegisterChimBridge()
EndEvent

Event OnPlayerLoadGame()
	RegisterChimBridge()
EndEvent

Event OnUpdateGameTime()
	mzinCHIM.ScanHygiene(BatheQuest, PlayerRef)
	RegisterForSingleUpdateGameTime(0.5)
EndEvent

Event OnCHIMCommand(String npcName, String command, String parameter)
	mzinCHIM.HandleCommand(BatheQuest, npcName, command, parameter)
EndEvent

Event OnBiS_WashActorFinish(Form akBathingActor, Form akWashProp, Bool abUsingSoap)
	Actor washed = akBathingActor as Actor
	If washed
		mzinCHIM.NotifyWashed(washed)
	EndIf
EndEvent

Function RegisterChimBridge()
	UnregisterForUpdateGameTime()
	UnregisterForModEvent("CHIM_CommandReceived")
	UnregisterForModEvent("SPG_CommandReceived")
	UnregisterForModEvent("BiS_WashActorFinish")
	If Game.GetModByName("AIAgent.esp") != 255
		RegisterForModEvent("CHIM_CommandReceived", "OnCHIMCommand")
		RegisterForModEvent("SPG_CommandReceived", "OnCHIMCommand")
	EndIf
	RegisterForModEvent("BiS_WashActorFinish", "OnBiS_WashActorFinish")
	RegisterForSingleUpdateGameTime(0.5)
	mzinCHIM.ScanHygiene(BatheQuest, PlayerRef)
EndFunction

; ---------- Bathing Event ----------

Event OnBiS_BatheEvent_Player(Bool abArg)
	Actor[] PlayerFollowers = PO3_SKSEfunctions.GetPlayerFollowers()
	if abArg && (PlayerFollowers.Length > 0)
		Utility.Wait(1.0)
		CycleTeammate(PlayerFollowers, BatheQuest.GetGawker(PlayerRef, ShynessDistance.GetValue()))
	endIf
EndEvent

Function CycleTeammate(Actor[] PlayerFollowers, Actor LastGawker)
	int i = 0
	if AutomateFollowerBathing.GetValue() == 1.0 ; Tracked Only
		while i < PlayerFollowers.Length
			if PlayerFollowers[i].IsInFaction(TrackedBatherFaction)
				TryWashTeammate(PlayerFollowers[i], LastGawker)
			endIf
			i += 1
		endWhile
	elseIf AutomateFollowerBathing.GetValue() == 2.0 ; All Teammates
		while i < PlayerFollowers.Length
			TryWashTeammate(PlayerFollowers[i], LastGawker)
			i += 1
		endWhile
	endIf
EndFunction

Function TryWashTeammate(Actor akTarget, Actor akGawker)
	MiscObject WashProp = BatheQuest.TryFindWashProp(akTarget)
	if WashProp && !(BatheQuest.IsRestricted(akTarget, akGawker))
		if BatheQuest.IsInWater(akTarget)
			BatheQuest.WashActor(akTarget, WashProp, false, false, true, false)
		ElseIf BatheQuest.IsUnderWaterfall(akTarget)
			BatheQuest.WashActor(akTarget, WashProp, true, false, true, false)
		EndIf
	EndIf
EndFunction

; ---------- Hotkey Event ----------

Event OnBiS_GDOTStateChange_Player(string NewState, string DefaultState)
	mzinUtil.LogTrace("Received default state GDOTStateChange event for player.")
	if NewState && (NewState != DefaultState)
		GoToState("PauseKeyCheck")
	ElseIf !NewState && !DefaultState
		RegisterHotKeys()
		RegisterChimBridge()
	endIf
EndEvent

State PauseKeyCheck
	Event OnBeginState()
		UnregisterForAllKeys()
	EndEvent
	Event OnCHIMCommand(String npcName, String command, String parameter)
		mzinCHIM.HandleCommand(BatheQuest, npcName, command, parameter)
	EndEvent
	Event OnKeyDown(Int KeyCode)
		If Utility.IsInMenuMode() || SPE_Actor.GetPlayerSpeechTarget() || UI.IsTextInputEnabled()
			return
		EndIf
		mzinUtil.LogTrace("Received OnKeyDown event, but hotkey process state was toggled off.")
	EndEvent
	Event OnBiS_GDOTStateChange_Player(string NewState, string DefaultState)
		mzinUtil.LogTrace("Received in-state GDOTStateChange event for player.")
		if !NewState || (NewState == DefaultState)
			RegisterHotKeys()
			RegisterChimBridge()
			GoToState("")
		endIf
	EndEvent
EndState

Event OnKeyDown(Int KeyCode)
	If Utility.IsInMenuMode() || SPE_Actor.GetPlayerSpeechTarget() || UI.IsTextInputEnabled()
		return
	EndIf

	UnregisterForAllKeys()
	If KeyCode == CheckStatusKeyCode.GetValue() as int
		if Input.IsKeyPressed(ModifierKeyCode.GetValue() as int)
			ObjectReference crosshairRef = Game.GetCurrentCrosshairRef()
			If crosshairRef as Actor
				mzinUtil.LogNotification(crosshairRef.GetBaseObject().GetName() + " feels " + Math.Floor(StorageUtil.GetFloatValue(crosshairRef, "BiS_Dirtiness") * 100.0) + "% dirty.")
			EndIf
		Else
			mzinUtil.GameMessage(DirtinessStatusMessage, DirtinessPercentage.GetValue() * 100)
		EndIf
	ElseIf KeyCode == BatheKeyCode.GetValue() as int
		if Input.IsKeyPressed(ModifierKeyCode.GetValue() as int)
			if BatheQuest.TryWashActor(PlayerRef, None, true, true)
				return
			endIf
		else
			if BatheQuest.TryWashActor(PlayerRef, None, false, true)
				return
			endIf
		endIf
	EndIf
	RegisterHotKeys()
EndEvent

Function RegisterHotKeys()
	UnregisterForAllKeys()
	If BatheKeyCode.GetValue() as int > 0
		RegisterForKey(BatheKeyCode.GetValue() as int)
	EndIf
	If CheckStatusKeyCode.GetValue() as int > 0
		RegisterForKey(CheckStatusKeyCode.GetValue() as int)
	EndIf
EndFunction
