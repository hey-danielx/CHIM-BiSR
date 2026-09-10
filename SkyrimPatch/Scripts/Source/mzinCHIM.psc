ScriptName mzinCHIM Hidden
{CHIM hygiene bridge for Bathing in Skyrim - Renewed. Player and followers.}

Float Function CommentCooldown() Global
	Return 90.0
EndFunction

Bool Function IsCHIMLoaded() Global
	Return Game.GetModByName("AIAgent.esp") != 255
EndFunction

Bool Function IsBiSRRunning() Global
	If Game.GetModByName("Bathing in Skyrim.esp") == 255
		Return False
	EndIf
	Return mzinAPI.GetModState() != 0.0
EndFunction

String Function GetActorName(Actor akActor) Global
	If !akActor
		Return ""
	EndIf
	Form baseObj = akActor.GetBaseObject()
	If baseObj
		String actorName = baseObj.GetName()
		If actorName != ""
			Return actorName
		EndIf
	EndIf
	Return akActor.GetDisplayName()
EndFunction

Float Function GetDirtPercent(Actor akActor) Global
	If !akActor
		Return 0.0
	EndIf
	Return StorageUtil.GetFloatValue(akActor, "BiS_Dirtiness")
EndFunction

Int Function GetDirtTier(Float afPercent) Global
	If afPercent >= 0.75
		Return 3
	ElseIf afPercent >= 0.50
		Return 2
	ElseIf afPercent >= 0.25
		Return 1
	EndIf
	Return 0
EndFunction

String Function DirtLabel(Int aiTier) Global
	If aiTier >= 3
		Return "filthy"
	ElseIf aiTier == 2
		Return "quite dirty"
	ElseIf aiTier == 1
		Return "a bit dirty"
	EndIf
	Return "clean"
EndFunction

String Function OwnCommentPrompt(Int aiTier) Global
	If aiTier >= 3
		Return "You are filthy and very uncomfortable. Make one short in-character comment about your own smell and needing a bath as soon as possible. Do not mention mods, meters, or game menus."
	ElseIf aiTier == 2
		Return "You feel dirty and uncomfortable. Make one short in-character comment about needing to wash. Do not mention mods, meters, or game menus."
	EndIf
	Return "You have some dirt on you. Make one short in-character comment about wanting to wash up soon. Do not mention mods, meters, or game menus."
EndFunction

String Function PlayerCommentPrompt(String asPlayerName, Int aiTier) Global
	If aiTier >= 3
		Return asPlayerName + " is completely filthy and smells very bad. Make one short in-character comment about the smell and that they should bathe as soon as possible. Do not mention mods, meters, or game menus."
	ElseIf aiTier == 2
		Return asPlayerName + " is quite dirty. Make one short in-character comment noticing that they could use a bath. Do not mention mods, meters, or game menus."
	EndIf
	Return asPlayerName + " has some dirt on them. Make one short in-character comment noticing it. Do not mention mods, meters, or game menus."
EndFunction

Bool Function CommentReady(Actor akActor, String asKey) Global
	If !akActor
		Return False
	EndIf
	Float now = Utility.GetCurrentRealTime()
	Float last = StorageUtil.GetFloatValue(akActor, asKey)
	If last > 0.0 && now - last < CommentCooldown()
		Return False
	EndIf
	Return True
EndFunction

Function MarkComment(Actor akActor, String asKey) Global
	If !akActor
		Return
	EndIf
	StorageUtil.SetFloatValue(akActor, asKey, Utility.GetCurrentRealTime())
EndFunction

Function ReportCommandResult(String asNpcName, String asCommand, String asParameter, String asResult) Global
	If asNpcName == "" || !IsCHIMLoaded()
		Return
	EndIf
	AIAgentFunctions.logMessageForActor("command@" + asCommand + "@" + asParameter + "@" + asResult, "funcret", asNpcName)
EndFunction

Function SetDirtMarker(Actor akActor, String asName, Int aiTier, Float afPercent, Bool abIsPlayer) Global
	If asName == "" || !IsCHIMLoaded()
		Return
	EndIf

	Int lastTier = StorageUtil.GetIntValue(akActor, "BiS_ChimDirtTier", -1)
	If lastTier == aiTier
		Return
	EndIf
	StorageUtil.SetIntValue(akActor, "BiS_ChimDirtTier", aiTier)

	String line
	String flag = afPercent as String
	If aiTier <= 0
		line = asName + " is clean again."
		flag = "clear"
	Else
		line = asName + " is " + DirtLabel(aiTier) + "."
	EndIf

	AIAgentFunctions.logMessageForActor(line, "infoaction", asName)
	AIAgentFunctions.logMessageForActor("bisr_dirt@" + asName + "@" + aiTier + "@" + flag, "infoaction", asName)
EndFunction

Bool Function SpeakOwnDirt(Actor akActor, String asName, Int aiTier) Global
	If aiTier <= 0 || asName == "" || !IsCHIMLoaded()
		Return False
	EndIf
	If !CommentReady(akActor, "BiS_ChimOwnCommentTime")
		Return False
	EndIf
	If AIAgentFunctions.isActorTalking(asName) != 0
		Return False
	EndIf
	MarkComment(akActor, "BiS_ChimOwnCommentTime")
	AIAgentFunctions.requestMessageForActor(OwnCommentPrompt(aiTier), "chat", asName)
	Return True
EndFunction

Bool Function SpeakPlayerDirt(Actor akFollower, String asFollowerName, String asPlayerName, Int aiTier) Global
	If aiTier <= 0 || asFollowerName == "" || asPlayerName == "" || !IsCHIMLoaded()
		Return False
	EndIf
	If !CommentReady(akFollower, "BiS_ChimPlayerCommentTime")
		Return False
	EndIf
	If AIAgentFunctions.isActorTalking(asFollowerName) != 0
		Return False
	EndIf
	MarkComment(akFollower, "BiS_ChimPlayerCommentTime")
	AIAgentFunctions.requestMessageForActor(PlayerCommentPrompt(asPlayerName, aiTier), "chat", asFollowerName)
	Return True
EndFunction

Bool Function BasinInRange(Actor akActor, String asEditorId, Float afRadius) Global
	If !akActor || asEditorId == ""
		Return False
	EndIf
	Form basin = PO3_SKSEFunctions.GetFormFromEditorID(asEditorId)
	If !basin
		Return False
	EndIf
	ObjectReference[] found = PO3_SKSEFunctions.FindAllReferencesOfType(akActor, basin, afRadius)
	If found
		If found.Length > 0
			Return True
		EndIf
	EndIf
	Return False
EndFunction

Bool Function NearWashBasin(Actor akActor) Global
	If BasinInRange(akActor, "NobleWashBasin01", 1024.0)
		Return True
	ElseIf BasinInRange(akActor, "NobleWashBasin02", 1024.0)
		Return True
	ElseIf BasinInRange(akActor, "CommonWashBasin01", 1024.0)
		Return True
	ElseIf BasinInRange(akActor, "UpperClassWashBasin01", 1024.0)
		Return True
	ElseIf BasinInRange(akActor, "RTWashBasin01", 1024.0)
		Return True
	ElseIf BasinInRange(akActor, "FarmhouseWashBasin01", 1024.0)
		Return True
	EndIf
	Return False
EndFunction

Bool Function TextLooksLikeBath(String asText) Global
	If asText == ""
		Return False
	EndIf
	If StringUtil.Find(asText, "AAAFriendlierBath") >= 0
		Return True
	ElseIf StringUtil.Find(asText, "Bath") >= 0
		Return True
	ElseIf StringUtil.Find(asText, "bath") >= 0
		Return True
	ElseIf StringUtil.Find(asText, "Tub") >= 0
		Return True
	ElseIf StringUtil.Find(asText, "tub") >= 0
		Return True
	EndIf
	Return False
EndFunction

Bool Function InBathCell(Actor akActor) Global
	If !akActor
		Return False
	EndIf
	Cell akCell = akActor.GetParentCell()
	If !akCell
		Return False
	EndIf
	If TextLooksLikeBath(PO3_SKSEFunctions.GetFormEditorID(akCell))
		Return True
	EndIf
	If TextLooksLikeBath(akCell.GetName())
		Return True
	EndIf
	String originMod = PO3_SKSEFunctions.GetFormModName(akCell, False)
	If originMod == "Friendlier Taverns.esp"
		Return True
	EndIf
	Return False
EndFunction

Bool Function AtBathSpot(Actor akActor) Global
	If !akActor
		Return False
	EndIf
	If NearWashBasin(akActor)
		Return True
	EndIf
	Return InBathCell(akActor)
EndFunction

Bool Function CanReachWater(mzinBatheQuest akQuest, Actor akActor) Global
	If !akQuest || !akActor
		Return False
	EndIf
	If akQuest.IsInWater(akActor) || akQuest.IsUnderWaterfall(akActor) || akQuest.IsSubmerged(akActor)
		Return True
	EndIf
	If mzinAPI.IsActorInWater(akActor)
		Return True
	EndIf
	Return AtBathSpot(akActor)
EndFunction

String Function NormalizeCommand(String asCommand) Global
	If asCommand == ""
		Return ""
	EndIf
	Int atPos = StringUtil.Find(asCommand, "@")
	If atPos > 0
		Return StringUtil.Substring(asCommand, 0, atPos)
	EndIf
	Return asCommand
EndFunction

Bool Function StartWash(mzinBatheQuest akQuest, Actor akActor, MiscObject washProp, Bool usedShower) Global
	If !akActor
		Return False
	EndIf
	Int eid = ModEvent.Create("BiS_WashActor")
	If eid
		ModEvent.PushForm(eid, akActor)
		ModEvent.PushForm(eid, washProp)
		ModEvent.PushBool(eid, usedShower)
		ModEvent.PushBool(eid, False)
		ModEvent.PushBool(eid, True)
		ModEvent.PushBool(eid, False)
		ModEvent.Send(eid)
		Return True
	EndIf
	If akQuest
		akQuest.WashActor(akActor, washProp, usedShower, False, True, False)
		Return True
	EndIf
	Return False
EndFunction

Actor Function FindFollowerByName(String asNpcName) Global
	If asNpcName == ""
		Return None
	EndIf
	If IsCHIMLoaded()
		Actor chimActor = AIAgentFunctions.getAgentByName(asNpcName)
		If chimActor
			Return chimActor
		EndIf
	EndIf
	Actor[] followers = PO3_SKSEFunctions.GetPlayerFollowers()
	If !followers
		Return None
	EndIf
	Int i = 0
	While i < followers.Length
		If GetActorName(followers[i]) == asNpcName || followers[i].GetDisplayName() == asNpcName
			Return followers[i]
		EndIf
		i += 1
	EndWhile
	Return None
EndFunction

Function NotifyActorDirt(mzinBatheQuest akQuest, Actor akActor, Bool abIsPlayer, Bool abSpeak) Global
	If !akActor
		Return
	EndIf
	String actorName = GetActorName(akActor)
	If actorName == ""
		Return
	EndIf
	Float percent = GetDirtPercent(akActor)
	Int tier = GetDirtTier(percent)
	Int lastTier = StorageUtil.GetIntValue(akActor, "BiS_ChimDirtTier", -1)
	SetDirtMarker(akActor, actorName, tier, percent, abIsPlayer)
	If abSpeak && !abIsPlayer && tier > 0 && tier > lastTier && lastTier != -1
		SpeakOwnDirt(akActor, actorName, tier)
	ElseIf abSpeak && !abIsPlayer && lastTier == -1 && tier > 0
		SpeakOwnDirt(akActor, actorName, tier)
	EndIf
EndFunction

Function ScanHygiene(mzinBatheQuest akQuest, Actor akPlayer) Global
	If !akQuest || !akPlayer || !IsBiSRRunning() || !IsCHIMLoaded()
		Return
	EndIf

	String playerName = GetActorName(akPlayer)
	Int lastPlayerTier = StorageUtil.GetIntValue(akPlayer, "BiS_ChimDirtTier", -1)
	NotifyActorDirt(akQuest, akPlayer, True, False)
	Int playerTier = GetDirtTier(GetDirtPercent(akPlayer))
	Bool playerGotDirtier = playerTier > 0 && (lastPlayerTier == -1 || playerTier > lastPlayerTier)

	Actor[] followers = PO3_SKSEFunctions.GetPlayerFollowers()
	If !followers
		Return
	EndIf

	Bool spokeAboutPlayer = False
	Int i = 0
	While i < followers.Length
		Actor follower = followers[i]
		If follower && !follower.IsDead()
			NotifyActorDirt(akQuest, follower, False, True)
			If playerGotDirtier && !spokeAboutPlayer
				String followerName = GetActorName(follower)
				If followerName != ""
					spokeAboutPlayer = SpeakPlayerDirt(follower, followerName, playerName, playerTier)
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile
EndFunction

Function NotifyWashed(Actor akActor) Global
	If !akActor || !IsCHIMLoaded()
		Return
	EndIf
	String actorName = GetActorName(akActor)
	If actorName == ""
		Return
	EndIf
	StorageUtil.SetIntValue(akActor, "BiS_ChimDirtTier", 0)
	AIAgentFunctions.logMessageForActor(actorName + " is clean again.", "infoaction", actorName)
	AIAgentFunctions.logMessageForActor("bisr_dirt@" + actorName + "@0@clear", "infoaction", actorName)
EndFunction

Function TryBatheActor(mzinBatheQuest akQuest, Actor akActor, String asNpcName) Global
	If asNpcName == ""
		Return
	EndIf
	If !akQuest || !akActor
		Debug.Trace("[CHIM-BiSR] Take_Bath missing actor for " + asNpcName)
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " cannot bathe right now.")
		Return
	EndIf
	If !IsBiSRRunning()
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", "Bathing in Skyrim is not enabled.")
		Return
	EndIf
	If akActor.IsDead()
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " cannot bathe.")
		Return
	EndIf

	MiscObject washProp = akQuest.TryFindWashProp(akActor)
	If !washProp
		Debug.Trace("[CHIM-BiSR] Take_Bath " + asNpcName + " has no soap or wash rag")
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " has no soap or wash rag.")
		Return
	EndIf

	Bool sitting = akActor.GetSitState() != 0
	Bool inWater = akQuest.IsInWater(akActor) || mzinAPI.IsActorInWater(akActor)
	Bool usedShower = akQuest.IsUnderWaterfall(akActor)
	Bool atBath = AtBathSpot(akActor)
	String cellId = ""
	Cell bathCell = akActor.GetParentCell()
	If bathCell
		cellId = PO3_SKSEFunctions.GetFormEditorID(bathCell)
		If cellId == ""
			cellId = bathCell.GetName()
		EndIf
	EndIf
	Debug.Trace("[CHIM-BiSR] Take_Bath " + asNpcName + " sit=" + (akActor.GetSitState() as String) + " water=" + (inWater as Int) + " shower=" + (usedShower as Int) + " bathspot=" + (atBath as Int) + " cell=" + cellId)

	If akQuest.IsRestricted(akActor) && !atBath
		Debug.Trace("[CHIM-BiSR] Take_Bath " + asNpcName + " blocked by BiSR restriction")
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " cannot bathe right now.")
		Return
	EndIf
	If !CanReachWater(akQuest, akActor)
		Debug.Trace("[CHIM-BiSR] Take_Bath " + asNpcName + " has no water, waterfall, basin, or bath")
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " needs a river, waterfall, or bath nearby.")
		Return
	EndIf

	Bool ok = False
	If sitting || atBath
		ok = StartWash(akQuest, akActor, washProp, usedShower)
	Else
		ok = akQuest.TryWashActor(akActor, washProp, usedShower, False)
		If !ok
			ok = StartWash(akQuest, akActor, washProp, usedShower)
		EndIf
	EndIf

	If ok
		NotifyWashed(akActor)
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " washes off the dirt.")
	Else
		ReportCommandResult(asNpcName, "ExtCmdBiSR_Bathe", "", asNpcName + " could not bathe here.")
	EndIf
EndFunction

Function HandleCommand(mzinBatheQuest akQuest, String asNpcName, String asCommand, String asParameter) Global
	asCommand = NormalizeCommand(asCommand)
	If asCommand != "ExtCmdBiSR_Bathe"
		Return
	EndIf
	Debug.Trace("[CHIM-BiSR] HandleCommand " + asNpcName + " " + asCommand)
	Actor target = FindFollowerByName(asNpcName)
	TryBatheActor(akQuest, target, asNpcName)
EndFunction

Bool Function DispatchExternalCommand(String asNpcName, String asCommand, String asParameter) Global
	asCommand = NormalizeCommand(asCommand)
	If asCommand != "ExtCmdBiSR_Bathe"
		Return False
	EndIf
	Debug.Trace("[CHIM-BiSR] DispatchExternalCommand " + asNpcName)
	HandleCommand(mzinAPI.GetBatheQuest(), asNpcName, asCommand, asParameter)
	Return True
EndFunction
