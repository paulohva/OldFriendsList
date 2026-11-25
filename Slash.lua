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
	Line("setup", L["show the first-time setup again"])
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
	Line("setup", L["show the first-time setup again"])
	Line("showoffline on|off", L["offline friends in the lists"])
	Line("ping " .. NAME, L["check one character now and print the result"])
	Line("diag", L["information for bug reports"])
	Line("diag mail", L["check the names suggested in the mail"])
	Line("debug", L["toggle debug messages"])
end

local function Config()
	local s = ns.db.settings
	ns.Print(L["Settings:"])
	print(("  %s: %s   %s: %s   %s: %s"):format(L["online messages"], OnOff(s.notifyOnline),
		L["offline messages"], OnOff(s.notifyOffline), L["sound"], OnOff(s.sound)))
	print(("  %s: %s   %s: %ds   debug: %s"):format(L["share zone with friends"], OnOff(s.shareZone),
		L["check interval"], s.pingInterval, OnOff(s.debug)))
	print(("  %s: %s"):format(L["offline friends in the lists"], OnOff(s.showOffline ~= false)))
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

-- /ofl diag: for bug reports, in sections: how the addon is set up, what it can see, the game APIs
-- (only the missing ones named), and last the problems (what people usually need to send).
local GREEN, RED, YELLOW = "|cff20ff20", "|cffff4040", "|cffffd100"
local function Good(text) return GREEN .. text .. "|r" end
local function Bad(text) return RED .. text .. "|r" end
local function Section(title) print(YELLOW .. title .. "|r") end
local function Item(label, value) print(("  %s: %s"):format(label, value)) end

local function AddonVersion()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if not get then return "?" end
	local ok, v = pcall(get, "OldFriendsList", "Version")
	return ok and v or "?"
end

-- the problems section: last, so it's what shows at the bottom of the chat (easy to screenshot)
local function Problems()
	Section("Problems")
	-- only while /ofl enablesuperdebug is on (it isn't listed anywhere else)
	if ns.db.settings.superDebug then
		Item("super debug", ("%s%s - taint log level %s, Lua errors on screen %s, debug messages %s"):format(OnOff(true),
			ns.db.settings.superDebugAll and " (all)" or "", tostring(ns.TaintLogLevel()),
			ns.ScriptErrorsShown() and "yes" or "no", OnOff(ns.db.settings.debug)))
	end
	-- actions the game blocked and blamed on this addon, this session
	local blocked = {}
	for func, b in pairs(ns.blocked) do
		blocked[#blocked + 1] = ("%s (%s, %dx, last %s)"):format(func, b.event, b.count, b.last)
	end
	table.sort(blocked)
	Item("blocked actions this session", #blocked > 0 and Bad(table.concat(blocked, "; ")) or Good("none"))
	-- "Interface action failed because of an AddOn" shown by Blizzard's own code (any addon)
	local m = ns.actionMessages
	if ns.ActionMessagesWatched() then
		Item("\"action failed\" messages (any addon)", m.count > 0
			and Bad(("%dx, last %s"):format(m.count, tostring(m.last))) or Good("none"))
		if m.count > 0 then
			-- the last one: where Blizzard showed it, and the first addon in the calls that led there
			Item("  blocked in", tostring(m.blocked))
			Item("  call started by", tostring(m.started))
		end
	else
		Item("\"action failed\" messages (any addon)", GREY .. "can't be counted on this client|r")
	end
	-- script errors in this addon's own code, this session
	local e = ns.scriptErrors
	Item("script errors (this addon)", e.count > 0
		and Bad(("%dx, last %s: %s"):format(e.count, tostring(e.last), tostring(e.message))) or Good("none"))
	-- the chat's globals: tainted ones make Blizzard's Social window fail (SearchFriends blocked)
	local tainted = {}
	for _, name in ipairs({ "ACTIVE_CHAT_EDIT_BOX", "LAST_ACTIVE_CHAT_EDIT_BOX", "CHAT_FOCUS_OVERRIDE" }) do
		local secure, by = issecurevariable(name)
		if not secure then tainted[#tainted + 1] = ("%s (%s)"):format(name, tostring(by)) end
	end
	Item("chat", #tainted > 0 and Bad("tainted: " .. table.concat(tainted, ", ")) or Good("clean"))
end

local function Diag()
	ns.Print("diag: version %s, interface %s, locale %s, %s", tostring(AddonVersion()),
		tostring(select(4, GetBuildInfo())), tostring(GetLocale()), date("%Y-%m-%d %H:%M"))

	Section("Setup")
	local s = ns.db.settings
	local mode = s.socialMode == "integrated" and "in the Social window"
		or s.socialMode == "separate" and "separate window" or tostring(s.socialMode)
	Item("list shown", mode .. (s.setupDone == false and " (setup not done yet)" or ""))
	Item("Social window", ns.SocialList.Info())
	local hidden, toHide = ns.ControllerHiddenCount()
	Item("controller interface", ns.GamepadUI()
		and ("on, %d of %d lists kept out of the controller's cursor"):format(hidden, toHide) or "off")
	Item("keys", "O: " .. tostring(GetBindingAction(ns.SOCIAL_KEY)) .. ", Shift-O: " .. tostring(GetBindingAction(ns.DEFAULT_KEY)))
	Item("name links", ns.UI.LinkInfo())
	Item("offline friends", s.showOffline == false and "hidden" or "shown")
	Item("debug", OnOff(s.debug))
	for _, line in ipairs(UI.SocialIconInfo()) do Item("tab", line) end

	Section("Status sources")
	local can, why = ns.Comm.CanSend()
	Item("addon messages now", can and Good("yes") or Bad("no") .. " (" .. tostring(why) .. ")")
	Item("checks", Presence.PausedReason() and ("paused: " .. tostring(Presence.PausedReason())) or "running")
	print("  " .. ns.Guild.Info())
	print("  " .. ns.BattleNet.Info())
	-- how this client spells names (Forever: "First Last", maybe with a realm)
	for _, unit in ipairs({ "player", "target" }) do
		if UnitExists(unit) and UnitIsPlayer(unit) then
			local n1 = ns.Safe.Call(UnitName, unit)
			local n2, r2 = ns.Safe.CallAll(UnitFullName, unit)
			Item(unit, ("UnitName=%q UnitFullName=%q,%q -> key %q"):format(tostring(n1), tostring(n2), tostring(r2),
				tostring(Data.KeyFromUnit(unit))))
		end
	end
	-- where a group member is, by each source
	if UnitExists("party1") then
		local key = Data.KeyFromUnit("party1")
		Item("party1", ("%s: roster zone %q, map zone %q"):format(tostring(key),
			tostring(key and Presence.RosterZone(key)), tostring(Presence.MapZone("party1"))))
	end

	Section("Game APIs")
	local apis = {
		{ "C_ChatInfo.SendAddonMessage", C_ChatInfo and C_ChatInfo.SendAddonMessage },
		{ "chat message filter", (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter },
		{ "ERR_CHAT_PLAYER_NOT_FOUND_S", ERR_CHAT_PLAYER_NOT_FOUND_S },
		{ "send tell", (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell },
		{ "C_PartyInfo.InviteUnit", C_PartyInfo and C_PartyInfo.InviteUnit },
		{ "Menu.ModifyMenu", Menu and Menu.ModifyMenu },
		{ "MenuUtil.CreateContextMenu", MenuUtil and MenuUtil.CreateContextMenu },
		{ "C_FriendList.SendWho", C_FriendList and C_FriendList.SendWho },
		{ "C_FriendList.AddFriend (character friends)", C_FriendList and C_FriendList.AddFriend },
		{ "SOUNDKIT.UI_BNET_TOAST", SOUNDKIT and SOUNDKIT.UI_BNET_TOAST },
		{ "secret values (issecretvalue)", issecretvalue },
		{ "controller navigation (SmartNavigation_MarkFrameIgnored)", SmartNavigation_MarkFrameIgnored },
	}
	local missing = {}
	for _, api in ipairs(apis) do
		if not api[2] then missing[#missing + 1] = api[1] end
	end
	Item("checked", #apis)
	Item("missing", #missing > 0 and Bad(table.concat(missing, ", ")) or Good("none"))

	Problems()
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
	elseif cmd == "showoffline" then
		local arg = rest:lower()
		local show
		if arg == "on" then show = true
		elseif arg == "off" then show = false
		else show = ns.db.settings.showOffline == false end
		ns.Options.SetShowOffline(show)
		ns.Print("%s: %s", L["offline friends in the lists"], OnOff(show))
	elseif cmd == "minimap" then
		ns.MinimapButton.SetShown(ns.db.settings.minimapHidden and true or false)
		if not ns.db.settings.minimapHidden then ns.Print(L["Minimap button shown."]) end
	elseif cmd == "debug" then
		SetToggle("debug", "debug", rest)
	elseif cmd == "enablesuperdebug" then
		-- (not in the help or /ofl advanced: for us, when hunting a bug; see Core.lua)
		-- "all": also the debug messages in chat (turns it on, or adds them if it's already on)
		local arg = rest:lower()
		local on, all = nil, arg == "all"
		if arg == "on" or all then on = true
		elseif arg == "off" then on = false
		else on = not ns.db.settings.superDebug end
		local took = ns.SetSuperDebug(on, all)
		if on then
			ns.SuperDebugMessage()
			if not took then
				ns.Print(L["The game didn't accept the taint log setting (now %s). Use /console taintLog 2 instead."],
					tostring(ns.TaintLogLevel()))
			end
		else
			ns.Print(L["Super debug is off: everything is back as it was."])
		end
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
		if rest:lower() == "mail" then ns.Mail.Diag() else Diag() end
	elseif cmd == "setup" then
		ns.Setup.Show()
	else
		Help()
	end
end
