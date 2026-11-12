--------------------------------------------------------------------------------
-- Old Friends List: core (namespace, secret-safe helpers, events, saved data)
--------------------------------------------------------------------------------

local ADDON, ns = ...

ns.NAME = "Old Friends List"
ns.PREFIX = "OFL"            -- addon message prefix
ns.ACCENT = "ffd100"         -- Blizzard gold
ns.ICON = "Interface\\AddOns\\OldFriendsList\\Media\\Icon"

local DB_VERSION = 1
ns.BINDING = "OLDFRIENDSLIST_TOGGLE"   -- the key binding's name (Bindings.xml)
ns.DEFAULT_KEY = "SHIFT-O"
local DEFAULTS = {
	notifyOnline = true,
	notifyOffline = false,
	sound = true,
	pingInterval = 30,       -- seconds between checks of the same friend
	shareZone = true,        -- tell friends who also use the addon where you are
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

eventFrame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		local ok, err = pcall(fn, ...)
		if not ok then geterrorhandler()(err) end
	end
end)

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
		if not ok then geterrorhandler()(err) end
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
	db.friends = db.friends or {}
	db.settings = db.settings or {}
	for k, v in pairs(DEFAULTS) do
		if db.settings[k] == nil then db.settings[k] = v end
	end
	ns.db = db
	ns.Fire("DB_READY")
end)

ns.On("PLAYER_LOGIN", function()
	ns.Fire("LOGIN")
end)
