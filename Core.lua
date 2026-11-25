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
	showOffline = true,      -- lists (Social window and separate window): offline friends shown (1.3.0)
	superDebug = false,      -- /ofl enablesuperdebug (1.3.1): taint log + Lua errors + debug, set again at each login
	-- (superDebugBefore: the player's own scriptErrors / taintLog / debug, put back when it's turned off)
	debug = false,
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
-- No taint log or Lua error setting needed: the call stack is read right then.
ns.actionMessages = { count = 0 }
local messageHooked

-- From a call stack (debugstack's text): the Blizzard function that showed the message, and the
-- first addon (not Blizzard's) in the calls that led to it. That addon *called*; it isn't
-- necessarily the one that tainted (Blizzard code reading something tainted shows no addon).
-- Pure, for tests: (blocked, started)
local SKIP_FUNCTIONS = { DisplayInterfaceActionBlockedMessage = true, EnsureIsSecure = true }

-- one stack line -> file (under Interface/AddOns/), line number, function name (or nil each).
-- Lines look like: [Interface/AddOns/Blizzard_X/File.lua]:271: in function 'Name'
-- (or <Interface/AddOns/...:451>, '?', `Mixin:Method', main chunk)
local function StackLine(line)
	local path, lineNo = line:match('Interface/AddOns/([^%]"]-)"?%]:(%d+)')
	if not path then path, lineNo = line:match('Interface/AddOns/([^%]":]+):(%d+)') end
	local fn = line:match("in function [`']([^'`]+)'")
	fn = fn and fn:match("([%w_]+)$")
	return path, lineNo, fn
end

function ns.ParseActionStack(stack)
	local blocked, started
	for line in tostring(stack or ""):gmatch("[^\n]+") do
		local path, lineNo, fn = StackLine(line)
		local addon = path and path:match("^([^/]+)")
		if path and not blocked and addon ~= "OldFriendsList" and not (fn and SKIP_FUNCTIONS[fn]) then
			blocked = (fn and (fn .. " (") or "(") .. path .. ":" .. lineNo .. ")"
		end
		if not started then
			if addon and not addon:find("^Blizzard_") and addon ~= "OldFriendsList" then
				started = addon .. " (" .. path .. ":" .. lineNo .. ")"
			elseif not path then
				-- a /run or macro: [string "the code"], not Blizzard's XML scripts ([string "@..."], [string "*:..."])
				local code = line:match('%[string "([^"]*)"%]')
				if code and not code:find("^[@*]") then started = "a script (/run or macro)" end
			end
		end
	end
	return blocked, started
end

local function OnActionMessage()
	local m = ns.actionMessages
	m.count, m.last = m.count + 1, date("%H:%M:%S")
	-- the top of the stack (where it was shown) and its bottom (where the calls started)
	local stack = debugstack and debugstack(2, 12, 8) or ""
	local blocked, started = ns.ParseActionStack(stack)
	m.blocked = blocked or "?"
	m.started = started or "Blizzard code only (no addon in the call chain)"
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
-- /ofl enablesuperdebug (1.3.1; not in the help or /ofl advanced: it's for us, when hunting a
-- bug). Everything that can log, in one switch:
--  - the game's taint log (_forever_/Logs/taint.log) at level 2: who tainted what, and where;
--  - Lua errors on screen ("scriptErrors");
--  - this addon's debug messages in chat (/ofl debug).
-- Typed again (or "off"): all three back to what the player had before turning it on. While it's
-- on, every login and /reload turns it off and on again (the game forgets the taint log when it
-- closes) and says so once in chat, so it's never left on by mistake. Off, the default: the
-- addon doesn't touch any of these.
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

-- off, then on: the taint log restarts at the level, Lua errors on screen, debug messages on.
-- True if the game took the taint log (some clients may refuse it).
local function SuperDebugOn()
	SetCVarValue("taintLog", "0")
	SetCVarValue("scriptErrors", "1")
	ns.db.settings.debug = true
	return SetCVarValue("taintLog", TAINT_LEVEL)
end

function ns.SetSuperDebug(on)
	local s = ns.db.settings
	if on then
		-- the player's own values, kept once (not again while it's on)
		if not s.superDebug then
			s.superDebugBefore = { scriptErrors = GetCVarValue("scriptErrors"), taintLog = GetCVarValue("taintLog"),
				debug = s.debug and true or false }
		end
		s.superDebug = true
		return SuperDebugOn()
	end
	local before = s.superDebugBefore or {}
	s.superDebug, s.superDebugBefore = false, nil
	s.debug = before.debug or false
	SetCVarValue("scriptErrors", before.scriptErrors or "0")
	return SetCVarValue("taintLog", before.taintLog or "0")
end

-- at login and /reload: only when it's on
local function ApplySuperDebug()
	if not (ns.db and ns.db.settings.superDebug) then return end
	SuperDebugOn()
	if ns.L then ns.Print(ns.L["Super debug is on: taint log level %s, Lua errors on screen, debug messages. Type /ofl enablesuperdebug again to turn it all off."],
		tostring(ns.TaintLogLevel())) end
end

-- /ofl errors (1.2.6) was taken out in 1.3.0: for whoever upgrades with it still on, once, the
-- player's own "scriptErrors" goes back to what it was, the taint log off, and the two saved fields go
local function ForgetErrorMode()
	local s = ns.db and ns.db.settings
	if not s then return end
	if s.errorMode then
		local set = (C_CVar and C_CVar.SetCVar) or SetCVar
		if set then
			pcall(set, "scriptErrors", s.scriptErrorsBefore or "0")
			pcall(set, "taintLog", "0")
		end
	end
	s.errorMode, s.scriptErrorsBefore = nil, nil
end

ns.On("PLAYER_LOGIN", function()
	ForgetErrorMode()
	ApplySuperDebug()
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
