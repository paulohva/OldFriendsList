--------------------------------------------------------------------------------
-- Old Friends List: core (namespace, secret-safe helpers, events, saved data)
--------------------------------------------------------------------------------

local ADDON, ns = ...

ns.NAME = "Old Friends List"
ns.PREFIX = "OFL"            -- addon message prefix
ns.ACCENT = "ffd100"         -- Blizzard gold
ns.ICON = "Interface\\AddOns\\OldFriendsList\\Media\\Icon"
ns.PORTRAIT = "Interface\\AddOns\\OldFriendsList\\Media\\Portrait"   -- the windows' portrait (inside Blizzard's ring)

local DB_VERSION = 5
ns.BINDING = "OLDFRIENDSLIST_TOGGLE"   -- the key binding's name (Bindings.xml)
ns.DEFAULT_KEY = "SHIFT-O"
ns.SOCIAL_BINDING = "TOGGLESOCIAL"     -- Blizzard's Social window binding
ns.SOCIAL_KEY = "O"
local DEFAULTS = {
	notifyOnline = true,
	notifyOffline = true,
	sound = true,
	pingInterval = 30,       -- seconds between checks of the same friend
	shareZone = true,        -- tell friends who also use the addon where you are
	showDetails = true,      -- list: level, class and zone under each name
	classColors = false,     -- names in class colors (list, tooltips, chat)
	socialIcon = false,      -- icon in the game's Social window that opens the list (opt-in)
	socialMode = "separate", -- "integrated": Old Friends as a group in the game's Social window (O)
	swapKeys = false,        -- O opens Old Friends List, Shift-O the game's Social window
	setupDone = false,       -- the first-time setup (integrated or separate) was shown
	socialCollapsed = false, -- the Old Friends group in the Social window is collapsed
	hideBNetDuplicates = false, -- Social window: hide Old Friends a Battle.net friend is playing right now
	showBNet = false,        -- separate window: also list Battle.net friends playing this game
	notifyBNet = false,      -- chat lines for Battle.net friends not on the list (opt-in, in the options; see BattleNet.ShouldNotify)
	mailNames = true,        -- Old Friends List names in the mail's "To:" suggestions (1.1.0)
	debug = false,
	errorMode = false,       -- /ofl errors: taint log + Lua errors on screen, set again at each login (1.2.6)
	scriptErrorsBefore = nil, -- the player's own "scriptErrors" value, put back when /ofl errors is turned off
}
ns.DEFAULTS = DEFAULTS

--------------------------------------------------------------------------------
-- Printing
--------------------------------------------------------------------------------

function ns.Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	msg = msg:gsub("^%l", string.upper)
	DEFAULT_CHAT_FRAME:AddMessage("|cff" .. ns.ACCENT .. ns.NAME .. "|r: " .. msg)
end

function ns.Debug(fmt, ...)
	if not (ns.db and ns.db.settings.debug) then return end
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	DEFAULT_CHAT_FRAME:AddMessage("|cff888888[OFL]|r " .. msg)
end

--------------------------------------------------------------------------------
-- Secret-safe reads (Forever runs Midnight's addon restrictions: some values
-- are "secret" and can't be compared or stored; treat those as unknown)
--------------------------------------------------------------------------------

local Safe = {}
ns.Safe = Safe

function Safe.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) or false
end

function Safe.Value(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- calls fn(...) and returns its first result when plain, else nil
function Safe.Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return Safe.Value(v)
end

-- calls fn(...) and returns all its results (each made safe), or nothing on error
function Safe.CallAll(fn, ...)
	if type(fn) ~= "function" then return end
	local res = { pcall(fn, ...) }
	if not res[1] then return end
	for i = 2, #res do res[i] = Safe.Value(res[i]) end
	return unpack(res, 2)
end

function Safe.InInstance()
	return Safe.Call(IsInInstance) and true or false
end

function Safe.InCombat()
	return Safe.Call(InCombatLockdown) and true or false
end

--------------------------------------------------------------------------------
-- Events: any number of handlers per event
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

-- (1.2.6) script errors in this addon's own code, kept for /ofl diag (the last one and a count),
-- then passed to the game's error handler as always. Costs nothing until an error happens.
ns.scriptErrors = { count = 0 }
local function KeepError(err)
	local e = ns.scriptErrors
	e.count, e.last, e.message = e.count + 1, date("%H:%M:%S"), tostring(err)
end
local function ReportError(err)
	KeepError(err)
	geterrorhandler()(err)
end
ns.ReportError = ReportError

-- an error this addon catches on purpose and keeps quiet (a part that can fail without bothering
-- the player): kept for /ofl diag all the same, and said in chat with /ofl debug on
function ns.QuietError(where, err)
	KeepError(where .. ": " .. tostring(err))
	ns.Debug("%s: %s", where, tostring(err))
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		local ok, err = pcall(fn, ...)
		if not ok then ReportError(err) end
	end
end)

-- the game blocked something and blamed this addon: said in chat once per kind, and kept for
-- /ofl diag (the function the game names, when, how many times)
ns.blocked = {}
local function OnBlocked(event, addon, func)
	if addon ~= ADDON then return end
	func = tostring(func or "?")
	local seen = ns.blocked[func]
	if seen then
		seen.count, seen.last = seen.count + 1, date("%H:%M:%S")
		return
	end
	ns.blocked[func] = { event = event, count = 1, last = date("%H:%M:%S") }
	if ns.L then ns.Print(ns.L["The game blocked an action (%s). Please report it with the output of /ofl diag."], func) end
end

-- "Interface action failed because of an AddOn" messages (1.2.6): Blizzard's own code shows these
-- directly when it finds itself tainted (the controller's navigation, for one), with no
-- ADDON_ACTION_BLOCKED event, so the watcher above never sees them, and they don't say which addon.
-- Counted for /ofl diag, with where they came from. A secure post-hook: it runs after Blizzard's
-- function, changes nothing, and only runs when the message is shown (never, in normal play).
ns.actionMessages = { count = 0 }
local messageHooked
local function OnActionMessage()
	local m = ns.actionMessages
	m.count, m.last = m.count + 1, date("%H:%M:%S")
	-- the first interface file below us on the stack that isn't the chat's: who showed it
	local stack = debugstack and debugstack(2, 12, 0) or ""
	for file in stack:gmatch("Interface/AddOns/([^/%]:]+)") do
		if file ~= "Blizzard_ChatFrameBase" then m.from = file break end
	end
end
function ns.WatchActionMessages()
	if messageHooked then return end
	if type(DisplayInterfaceActionBlockedMessage) ~= "function" then return end
	hooksecurefunc("DisplayInterfaceActionBlockedMessage", OnActionMessage)
	messageHooked = true
end
function ns.ActionMessagesWatched() return messageHooked and true or false end

--------------------------------------------------------------------------------
-- Controller mode (1.2.6)
--------------------------------------------------------------------------------

-- the game's controller interface is on (Options: Controller, "Interface style")
function ns.GamepadUI()
	if not (C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType) then
		return false
	end
	local ok, style = pcall(C_InputInterfaceStyle.GetCurrentStyle)
	return ok and style == Enum.InputDeviceInterfaceType.Gamepad or false
end

-- Frames kept out of the controller's navigation: its cursor reads the scroll boxes it moves
-- through, and ours (made and filled by this addon) taint it, so it shows "Interface action
-- failed because of an AddOn" and stops. Blizzard's own way (SmartNavigation_MarkFrameIgnored,
-- which covers the frame's children too), done out of combat, as it allows addons then, and only
-- while the controller interface is on.
local controllerHidden, hiddenDone = {}, {}
function ns.ApplyControllerHiding()
	if not ns.GamepadUI() or type(SmartNavigation_MarkFrameIgnored) ~= "function" then return end
	if InCombatLockdown and InCombatLockdown() then return end   -- (again after the fight)
	for _, frame in ipairs(controllerHidden) do
		if not hiddenDone[frame] then
			local ok, err = pcall(SmartNavigation_MarkFrameIgnored, frame)
			if ok then hiddenDone[frame] = true else ns.Debug("controller: %s", tostring(err)) end
		end
	end
end
function ns.HideFromController(frame)
	if not frame then return end
	controllerHidden[#controllerHidden + 1] = frame
	ns.ApplyControllerHiding()
end
function ns.ControllerHiddenCount()
	local n = 0
	for _ in pairs(hiddenDone) do n = n + 1 end
	return n, #controllerHidden
end

-- internal callbacks (ns.Fire("FRIENDS_CHANGED") etc.)
local callbacks = {}

function ns.Listen(name, fn)
	callbacks[name] = callbacks[name] or {}
	table.insert(callbacks[name], fn)
end

function ns.Fire(name, ...)
	if not callbacks[name] then return end
	for _, fn in ipairs(callbacks[name]) do
		local ok, err = pcall(fn, ...)
		if not ok then ReportError(err) end
	end
end

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	OldFriendsListDB = OldFriendsListDB or {}
	local db = OldFriendsListDB
	db.version = db.version or DB_VERSION
	db.settings = db.settings or {}
	-- 0.2.0: offline messages are on by default, also for people coming from 0.1.0
	if db.version < 2 then
		db.settings.notifyOffline = true
		db.version = 2
	end
	-- the Social window icon is opt-in (test builds had it on)
	if db.version < 3 then
		db.settings.socialIcon = false
		db.version = 3
	end
	-- 0.3.0: Social window integration; the defaults (separate window, setup not done yet)
	-- come from DEFAULTS below, so updating players also get the first-time setup
	if db.version < 4 then
		-- an existing install: the setup says clearly that nothing changes unless they choose it
		db.settings.setupFromUpdate = true
		db.version = 4
	end
	-- 1.0.2: Battle.net friends' login lines are off for everyone until turned on in the options
	-- (test builds had them on)
	if db.version < 5 then
		db.settings.notifyBNet = false
		db.version = 5
	end
	db.friends = db.friends or {}
	db.settings = db.settings or {}
	for k, v in pairs(DEFAULTS) do
		if db.settings[k] == nil then db.settings[k] = v end
	end
	ns.db = db
	ns.Fire("DB_READY")
end)

--------------------------------------------------------------------------------
-- /ofl errors (1.2.6): the game's own error tools, for bug hunting, in one switch:
--  - its taint log (_forever_/Logs/taint.log) at level 2: who tainted what, and where;
--  - Lua errors shown on screen ("scriptErrors"): errors that never reach /ofl diag.
-- The game forgets the taint log when it closes, so while this is on both are set again at each
-- login, and it's said once in chat so nobody leaves it on by mistake (the log grows fast, for
-- every addon). Off: the taint log off, and Lua errors back to what the player had before.
--------------------------------------------------------------------------------

local TAINT_LEVEL = "2"
local function GetCVarValue(name)
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, v = pcall(get, name)
	return ok and v or nil
end
local function SetCVarValue(name, value)
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if set then pcall(set, name, value) end
	return GetCVarValue(name) == value
end
function ns.TaintLogLevel() return GetCVarValue("taintLog") end
function ns.ScriptErrorsShown() return GetCVarValue("scriptErrors") == "1" end

-- turns both on or off; true if the game took the taint log (some clients may refuse it)
function ns.SetErrorMode(on)
	local s = ns.db.settings
	if on then
		if not s.errorMode then s.scriptErrorsBefore = GetCVarValue("scriptErrors") end
		s.errorMode = true
		SetCVarValue("scriptErrors", "1")
		return SetCVarValue("taintLog", TAINT_LEVEL)
	end
	s.errorMode = false
	SetCVarValue("scriptErrors", s.scriptErrorsBefore or "0")
	s.scriptErrorsBefore = nil
	return SetCVarValue("taintLog", "0")
end

local function ApplyErrorMode()
	if not (ns.db and ns.db.settings.errorMode) then return end
	SetCVarValue("taintLog", TAINT_LEVEL)
	SetCVarValue("scriptErrors", "1")
	if ns.L then ns.Print(ns.L["Error mode is on: taint log level %s, Lua errors on screen. Type /ofl errors again to turn it off."],
		tostring(ns.TaintLogLevel())) end
end

ns.On("PLAYER_LOGIN", function()
	ApplyErrorMode()
	ns.WatchActionMessages()
	ns.Fire("LOGIN")
end)

-- controller interface turned on or off (its setting is a CVar), and the end of a fight
ns.On("CVAR_UPDATE", function(name)
	if name ~= "InputDeviceInterfaceStyle" then return end
	ns.ApplyControllerHiding()
	ns.Fire("CONTROLLER_CHANGED")
end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.ApplyControllerHiding() end)

ns.On("ADDON_ACTION_BLOCKED", function(...) OnBlocked("blocked", ...) end)
ns.On("ADDON_ACTION_FORBIDDEN", function(...) OnBlocked("forbidden", ...) end)
