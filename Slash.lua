--------------------------------------------------------------------------------
-- Slash commands: /ofl, /oldfriends
--------------------------------------------------------------------------------

local _, ns = ...
local Data, Presence, UI = ns.Data, ns.Presence, ns.UI

local function OnOff(v) return v and "|cff20ff20on|r" or "|cffff4040off|r" end

local function Help()
	ns.Print("commands:")
	print("  /ofl - open or close the list")
	print("  /ofl add <first last> - add a character, e.g. /ofl add Asha Brightvale")
	print("  /ofl remove <first last> - remove a character")
	print("  /ofl note <first last> <text> - set a note (no text clears it)")
	print("  /ofl list - print the list with who's online")
	print("  /ofl config - show settings")
	print("  /ofl online|offline|sound|zone on|off - toggle notifications / sound / sharing your zone")
	print("  /ofl interval <seconds> - how often each friend is checked (15-600)")
	print("  /ofl minimap - show or hide the minimap button")
	print("  /ofl ping <name> - check one character now and print the result")
	print("  /ofl diag - check which game APIs this client has")
	print("  /ofl debug - toggle debug messages")
end

local function Config()
	local s = ns.db.settings
	ns.Print("settings:")
	print(("  online messages: %s   offline messages: %s   sound: %s"):format(OnOff(s.notifyOnline), OnOff(s.notifyOffline), OnOff(s.sound)))
	print(("  share zone with friends: %s   check interval: %ds   debug: %s"):format(OnOff(s.shareZone), s.pingInterval, OnOff(s.debug)))
	local paused = Presence.PausedReason()
	if paused then print("  checks paused: " .. paused) end
end

local function List()
	local keys = Data.Sorted()
	if #keys == 0 then ns.Print("your list is empty. /ofl add <name>") return end
	local online, total = Data.CountOnline()
	ns.Print("%d of %d online:", online, total)
	for _, key in ipairs(keys) do
		local f = Data.Get(key)
		local st = Data.status[key]
		local line = st == "online" and ("|cff20ff20online|r" .. (f.lastZone and (" - " .. f.lastZone) or ""))
			or st == "offline" and ("|cff808080offline, last seen " .. Data.Ago(f.lastSeen) .. "|r")
			or "|cff808080checking...|r"
		print(("  %s%s: %s%s"):format(ns.Notify.PlayerLink(key), f.level and (" (" .. f.level .. ")") or "", line,
			f.note and (" |cffffd100- " .. f.note .. "|r") or ""))
	end
end

local function Diag()
	local function has(label, v) print(("  %s: %s"):format(label, v and "|cff20ff20yes|r" or "|cffff4040no|r")) end
	ns.Print("API check (%s, interface %s):", ns.NAME, tostring(select(4, GetBuildInfo())))
	has("C_ChatInfo.SendAddonMessage", C_ChatInfo and C_ChatInfo.SendAddonMessage)
	has("chat message filter", (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter)
	has("ERR_CHAT_PLAYER_NOT_FOUND_S", ERR_CHAT_PLAYER_NOT_FOUND_S)
	has("send tell", (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell)
	has("C_PartyInfo.InviteUnit", C_PartyInfo and C_PartyInfo.InviteUnit)
	has("Menu.ModifyMenu", Menu and Menu.ModifyMenu)
	has("MenuUtil.CreateContextMenu", MenuUtil and MenuUtil.CreateContextMenu)
	has("C_FriendList.SendWho", C_FriendList and C_FriendList.SendWho)
	has("C_FriendList.AddFriend (character friends)", C_FriendList and C_FriendList.AddFriend)
	has("SOUNDKIT.UI_BNET_TOAST", SOUNDKIT and SOUNDKIT.UI_BNET_TOAST)
	has("secret values (issecretvalue)", issecretvalue)
	-- how this client spells names (Forever: "First Last", maybe with a realm)
	for _, unit in ipairs({ "player", "target" }) do
		if UnitExists(unit) and UnitIsPlayer(unit) then
			local n1 = ns.Safe.Call(UnitName, unit)
			local n2, r2 = ns.Safe.CallAll(UnitFullName, unit)
			print(("  %s: UnitName=%q UnitFullName=%q,%q -> key %q"):format(unit, tostring(n1), tostring(n2), tostring(r2),
				tostring(Data.KeyFromUnit(unit))))
		end
	end
	local can, why = ns.Comm.CanSend()
	print("  can send addon messages now: " .. (can and "|cff20ff20yes|r" or ("|cffff4040no|r (" .. tostring(why) .. ")")))
end

local function SetToggle(field, label, arg)
	local s = ns.db.settings
	if arg == "on" then s[field] = true
	elseif arg == "off" then s[field] = false
	else s[field] = not s[field] end
	ns.Print("%s: %s", label, OnOff(s[field]))
end

SLASH_OLDFRIENDSLIST1 = "/ofl"
SLASH_OLDFRIENDSLIST2 = "/oldfriends"
SlashCmdList.OLDFRIENDSLIST = function(input)
	if not ns.db then return end
	input = input or ""
	local cmd, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()

	if cmd == "" then
		UI.Toggle()
	elseif cmd == "help" or cmd == "?" then
		Help()
	elseif cmd == "add" then
		if rest == "" then ns.Actions.AddPrompt() else ns.Actions.AddByName(rest) end
	elseif cmd == "remove" or cmd == "del" then
		local key = Data.Normalize(rest)
		if key and Data.Remove(key) then ns.Print("Removed %s.", Data.Display(key))
		else ns.Print("%s isn't on your list.", rest) end
	elseif cmd == "note" then
		local name, text = rest:match("^(%S+%s+%S+)%s*(.-)$")
		local key = name and Data.Normalize(name)
		if not (key and Data.Has(key)) then ns.Print("%s isn't on your list.", tostring(name)) return end
		Data.SetNote(key, text)
		ns.Print(text ~= "" and "Note set for %s." or "Note cleared for %s.", Data.Display(key))
	elseif cmd == "list" then
		List()
	elseif cmd == "config" or cmd == "settings" then
		Config()
	elseif cmd == "online" then
		SetToggle("notifyOnline", "online messages", rest)
	elseif cmd == "offline" then
		SetToggle("notifyOffline", "offline messages", rest)
	elseif cmd == "sound" then
		SetToggle("sound", "sound", rest)
	elseif cmd == "zone" then
		SetToggle("shareZone", "share zone with friends", rest)
	elseif cmd == "minimap" then
		ns.MinimapButton.SetShown(ns.db.settings.minimapHidden and true or false)
		if not ns.db.settings.minimapHidden then ns.Print("minimap button shown.") end
	elseif cmd == "debug" then
		SetToggle("debug", "debug", rest)
	elseif cmd == "interval" then
		local n = tonumber(rest)
		if not n or n < 15 or n > 600 then ns.Print("interval must be 15 to 600 seconds.") return end
		ns.db.settings.pingInterval = math.floor(n)
		ns.Print("each friend is checked every %d seconds.", ns.db.settings.pingInterval)
	elseif cmd == "ping" then
		local key = Data.Normalize(rest)
		if not key then ns.Print("usage: /ofl ping <first last>") return end
		Presence.PingNow(key)
	elseif cmd == "diag" then
		Diag()
	else
		Help()
	end
end
