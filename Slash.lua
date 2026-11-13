--------------------------------------------------------------------------------
-- Slash commands: /ofl, /oldfriends
-- (the commands themselves stay in English; their descriptions follow the client's language.
-- ping, diag and debug output stays in English: it's for bug reports)
--------------------------------------------------------------------------------

local _, ns = ...
local Data, Presence, UI, L = ns.Data, ns.Presence, ns.UI, ns.L

local GREY = "|cff808080"

local function OnOff(v) return v and ("|cff20ff20" .. L["on"] .. "|r") or ("|cffff4040" .. L["off"] .. "|r") end

local function Line(command, description)
	print(("  /ofl %s - %s"):format(command, description))
end

local NAME = L["<first last>"]

-- the everyday commands
local function Help()
	ns.Print(L["Commands:"])
	print("  /ofl - " .. L["open or close the list"])
	Line("add " .. NAME, L["add a character, e.g. /ofl add Asha Brightvale"])
	Line("remove " .. NAME, L["remove a character"])
	Line("note " .. NAME .. " " .. L["<text>"], L["set a note (no text clears it)"])
	Line("list", L["print the list with who's online"])
	Line("config", L["open the options (settings and key binding)"])
	Line("minimap", L["show or hide the minimap button"])
	print(GREY .. "  /ofl advanced - " .. L["all commands"] .. "|r")
end

-- everything
local function Advanced()
	ns.Print(L["All commands:"])
	print("  /ofl - " .. L["open or close the list"])
	Line("add " .. NAME, L["add a character, e.g. /ofl add Asha Brightvale"])
	Line("remove " .. NAME, L["remove a character"])
	Line("note " .. NAME .. " " .. L["<text>"], L["set a note (no text clears it)"])
	Line("list", L["print the list with who's online"])
	Line("config", L["open the options (settings and key binding)"])
	Line("status", L["print your settings in chat"])
	Line("online on|off", L["\"has come online\" messages"])
	Line("offline on|off", L["\"has gone offline\" messages"])
	Line("sound on|off", L["login sound"])
	Line("zone on|off", L["share your zone with friends who use the addon"])
	Line("interval " .. L["<seconds>"], L["how often each friend is checked (15-300)"])
	Line("minimap", L["show or hide the minimap button"])
	Line("ping " .. NAME, L["check one character now and print the result"])
	Line("diag", L["check which game APIs this client has"])
	Line("debug", L["toggle debug messages"])
end

local function Config()
	local s = ns.db.settings
	ns.Print(L["Settings:"])
	print(("  %s: %s   %s: %s   %s: %s"):format(L["online messages"], OnOff(s.notifyOnline),
		L["offline messages"], OnOff(s.notifyOffline), L["sound"], OnOff(s.sound)))
	print(("  %s: %s   %s: %ds   debug: %s"):format(L["share zone with friends"], OnOff(s.shareZone),
		L["check interval"], s.pingInterval, OnOff(s.debug)))
	print(("  %s: %s"):format(L["key to open the list"], ns.Options.KeyText() or L["none (set one with /ofl config)"]))
	local paused = Presence.PausedReason()
	if paused then print("  " .. L["checks paused: %s"]:format(L[paused])) end
end

local function List()
	local keys = Data.Sorted()
	if #keys == 0 then ns.Print(L["Your list is empty. /ofl add <first last>"]) return end
	local online, total = Data.CountOnline()
	ns.Print(L["%d of %d online:"], online, total)
	for _, key in ipairs(keys) do
		local f = Data.Get(key)
		local st = Data.status[key]
		local line
		if st == "online" then
			line = "|cff20ff20" .. L["online"] .. "|r" .. (f.lastZone and (" - " .. f.lastZone) or "")
		elseif st == "offline" then
			local ago = Data.Ago(f.lastSeen)
			line = GREY .. (ago and L["offline, last seen %s"]:format(ago) or L["offline"]) .. "|r"
		else
			line = GREY .. L["checking..."] .. "|r"
		end
		print(("  %s%s: %s%s"):format(ns.Notify.PlayerLink(key), f.level and (" (" .. f.level .. ")") or "", line,
			f.note and (" |cffffd100- " .. f.note .. "|r") or ""))
	end
end

local function Diag()
	local function has(label, v) print(("  %s: %s"):format(label, v and "|cff20ff20yes|r" or "|cffff4040no|r")) end
	ns.Print("API check (%s, interface %s, locale %s):", ns.NAME, tostring(select(4, GetBuildInfo())), tostring(GetLocale()))
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
	elseif cmd == "advanced" then
		Advanced()
	elseif cmd == "add" then
		if rest == "" then ns.Actions.AddPrompt() else ns.Actions.AddByName(rest) end
	elseif cmd == "remove" or cmd == "del" then
		local key = Data.Normalize(rest)
		if key and Data.Remove(key) then ns.Print(L["Removed %s."], Data.Display(key))
		else ns.Print(L["%s isn't on your list."], rest) end
	elseif cmd == "note" then
		local name, text = rest:match("^(%S+%s+%S+)%s*(.-)$")
		local key = name and Data.Normalize(name)
		if not (key and Data.Has(key)) then ns.Print(L["%s isn't on your list."], tostring(name or rest)) return end
		Data.SetNote(key, text)
		ns.Print(text ~= "" and L["Note set for %s."] or L["Note cleared for %s."], Data.Display(key))
	elseif cmd == "list" then
		List()
	elseif cmd == "config" or cmd == "settings" or cmd == "options" then
		if not ns.Options.Open() then Config() end
	elseif cmd == "status" then
		Config()
	elseif cmd == "online" then
		SetToggle("notifyOnline", L["online messages"], rest)
	elseif cmd == "offline" then
		SetToggle("notifyOffline", L["offline messages"], rest)
	elseif cmd == "sound" then
		SetToggle("sound", L["sound"], rest)
	elseif cmd == "zone" then
		SetToggle("shareZone", L["share zone with friends"], rest)
	elseif cmd == "minimap" then
		ns.MinimapButton.SetShown(ns.db.settings.minimapHidden and true or false)
		if not ns.db.settings.minimapHidden then ns.Print(L["Minimap button shown."]) end
	elseif cmd == "debug" then
		SetToggle("debug", "debug", rest)
	elseif cmd == "interval" then
		local n = tonumber(rest)
		if not n or n < 15 or n > 300 then ns.Print(L["The interval must be 15 to 300 seconds."]) return end
		ns.db.settings.pingInterval = math.floor(n)
		ns.Print(L["Each friend is checked every %d seconds."], ns.db.settings.pingInterval)
	elseif cmd == "ping" then
		local key = Data.Normalize(rest)
		if not key then ns.Print("Usage: /ofl ping <first last>") return end
		Presence.PingNow(key)
	elseif cmd == "diag" then
		Diag()
	else
		Help()
	end
end
