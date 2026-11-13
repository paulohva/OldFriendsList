--------------------------------------------------------------------------------
-- Presence: who's online
--  1. Silent ping: an addon whisper to each friend in turn. Offline -> the server
--     answers "No player named '%s' is currently playing." (hidden from chat);
--     no answer within a few seconds -> online.
--  2. Handshake (Comm.lua): friends running this addon answer at once.
--  3. Passive: anything they say, being in your group, targeting them.
--  4. Who: a /who for one friend, on a click (the game only allows it then).
-- Pings pause in combat and instances (the game blocks addon messages there).
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data, Comm, Notify = ns.Safe, ns.Data, ns.Comm, ns.Notify

local Presence = {}
ns.Presence = Presence
Presence.probe = {}         -- keys pinged by hand (/ofl ping): report the outcome

local TICK = 1.5            -- seconds between pings (keeps well under the addon message throttle)
local TIMEOUT = 4           -- no "No player named" by then -> online
local SUMMARY_MAX_WAIT = 90 -- print the login summary by then even if some checks are still pending

local pending = {}          -- key -> GetTime() of a ping awaiting an answer
local lastCheck = {}        -- key -> GetTime() of the last ping
local decided = {}          -- system message id -> hidden? (filters run once per chat frame)
local decidedCount = 0
local readyAt               -- GetTime() after which pinging may start (after loading screens)
local loginAt
local pausedReason

--------------------------------------------------------------------------------
-- "No player named '%s' is currently playing."
--------------------------------------------------------------------------------

local NOT_FOUND_PATTERN
do
	local s = ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
	s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	s = s:gsub("%%%%s", "(.+)")
	NOT_FOUND_PATTERN = "^" .. s .. "$"
end

-- true when this message answers one of our pings (and should be hidden)
local function HandleNotFound(msg, lineID)
	msg = Safe.Value(msg)
	if type(msg) ~= "string" then return false end
	local name = msg:match(NOT_FOUND_PATTERN)
	if not name then return false end
	local id = Safe.Value(lineID) or (msg .. math.floor(GetTime()))
	if decided[id] ~= nil then return decided[id] end

	local key = Data.Normalize(name)
	local ours = key ~= nil and pending[key] ~= nil
	decided[id] = ours
	decidedCount = decidedCount + 1
	if decidedCount > 200 then wipe(decided) decidedCount = 0 decided[id] = ours end

	if key and Presence.probe[key] then
		Presence.probe[key] = nil
		ns.Print("%s: offline (the server said 'No player named ...', hidden from chat: %s).", key, ours and "yes" or "no")
	end
	if key and Data.Has(key) then
		pending[key] = nil
		Data.SetStatus(key, "offline")
		ns.Debug("%s is offline%s", key, ours and "" or " (from your own whisper)")
	elseif key then
		pending[key] = nil
	end
	return ours
end

local function SystemFilter(_, _, msg, ...)
	local lineID = select(10, ...)
	if HandleNotFound(msg, lineID) then return true end
	return false
end

ns.On("CHAT_MSG_SYSTEM", function(msg, ...)
	HandleNotFound(msg, (select(10, ...)))
end)

do
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if add then
		add("CHAT_MSG_SYSTEM", SystemFilter)
	else
		ns.Debug("no chat filter API: ping errors will show in chat")
	end
end

--------------------------------------------------------------------------------
-- The scheduler
--------------------------------------------------------------------------------

-- an answer came some other way (handshake): stop waiting for this ping
function Presence.Resolve(key)
	pending[key] = nil
end

-- ask about this friend as soon as possible
function Presence.CheckSoon(key)
	lastCheck[key] = nil
end

function Presence.PausedReason()
	return pausedReason
end

local function Pause(reason)
	local changed = pausedReason ~= reason
	if changed then ns.Debug("pings paused: %s", reason) end
	pausedReason = reason
	if changed then ns.Fire("PAUSE_CHANGED") end
	-- an answer can't be trusted now: forget the open pings
	wipe(pending)
end

local function NextFriend(now)
	local interval = ns.db.settings.pingInterval
	local best, bestAt
	for _, key in ipairs(Data.Visible()) do
		if not pending[key] then
			local at = lastCheck[key]
			if not at then return key end
			if now - at >= interval and (not bestAt or at < bestAt) then best, bestAt = key, at end
		end
	end
	return best
end

local function MaybeSummary(now)
	if Notify.ready or not loginAt then return end
	local done = true
	for _, key in ipairs(Data.Visible()) do
		if Data.status[key] == nil then done = false break end
	end
	if done or now - loginAt >= SUMMARY_MAX_WAIT then Notify.Summary() end
end

local function Tick()
	if not ns.db then return end
	local now = GetTime()

	-- unanswered pings: they're online
	for key, at in pairs(pending) do
		if now - at >= TIMEOUT then
			pending[key] = nil
			if Presence.probe[key] then
				Presence.probe[key] = nil
				ns.Print("%s: online (no error within %ds).", key, TIMEOUT)
			end
			if Data.Has(key) then
				ns.Debug("%s is online (no error)", key)
				Data.SetStatus(key, "online")
			end
		end
	end

	MaybeSummary(now)

	if not readyAt or now < readyAt then return end
	local can, why = Comm.CanSend()
	if not can then Pause(why) return end
	if pausedReason then
		ns.Debug("pings resumed")
		pausedReason = nil
		ns.Fire("PAUSE_CHANGED")
	end

	local key = NextFriend(now)
	if not key then return end
	lastCheck[key] = now
	if Comm.Ping(key) then
		pending[key] = now
		ns.Debug("ping %s", key)
	end
end

ns.Listen("LOGIN", function()
	loginAt = GetTime()
	C_Timer.NewTicker(TICK, Tick)
end)

-- wait a moment after every loading screen
ns.On("PLAYER_ENTERING_WORLD", function()
	readyAt = GetTime() + 3
	wipe(pending)
end)

ns.Listen("FRIENDS_CHANGED", function(key, what)
	if what == "added" then lastCheck[key] = nil end
	if what == "removed" then pending[key] = nil lastCheck[key] = nil end
end)

--------------------------------------------------------------------------------
-- Passive signals
--------------------------------------------------------------------------------

local function SeenName(name)
	local key = Data.Normalize(Safe.Value(name))
	if key and Data.Has(key) then
		pending[key] = nil
		Data.Seen(key)
	end
end

for _, event in ipairs({
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
	"CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
}) do
	ns.On(event, function(_, sender) SeenName(sender) end)
end

local function SeenUnit(unit)
	local key = Data.KeyFromUnit(unit)
	if not (key and Data.Has(key)) then
		if unit ~= "mouseover" and Safe.Call(UnitIsPlayer, unit) then
			ns.Debug("%s is %s: not on the list (UnitName %q)", unit, tostring(key), tostring(Safe.Call(UnitName, unit)))
		end
		return
	end
	ns.Debug("%s is %s: level %s, class %s", unit, key, tostring(Safe.Call(UnitLevel, unit)),
		tostring(select(2, Safe.CallAll(UnitClass, unit))))
	if Safe.Call(UnitIsConnected, unit) == false then return end
	local info = Data.InfoFromUnit(unit)
	if info then Data.UpdateInfo(key, info.class, info.level, nil) end
	pending[key] = nil
	Data.Seen(key)
end

ns.On("PLAYER_TARGET_CHANGED", function() SeenUnit("target") end)
ns.On("UNIT_LEVEL", function(unit)
	unit = Safe.Value(unit)
	if type(unit) == "string" and (unit == "target" or unit == "focus" or unit:find("^party%d") or unit:find("^raid%d")) then
		SeenUnit(unit)
	end
end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() SeenUnit("mouseover") end)
ns.On("GROUP_ROSTER_UPDATE", function()
	if Safe.Call(IsInRaid) then
		for i = 1, 40 do SeenUnit("raid" .. i) end
	else
		for i = 1, 4 do SeenUnit("party" .. i) end
	end
end)

--------------------------------------------------------------------------------
-- Who (only from a click: the game requires a hardware event)
--------------------------------------------------------------------------------

local whoKey, whoAt

function Presence.Who(key)
	if not (C_FriendList and C_FriendList.SendWho) then
		ns.Print(ns.L["/who isn't available."])
		return
	end
	whoKey, whoAt = key, GetTime()
	local filter = ('n-"%s"'):format(Data.ShortName(key))
	local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social
	local ok, err = pcall(C_FriendList.SendWho, filter, origin)
	if not ok then
		whoKey = nil
		ns.Print(ns.L["Couldn't send /who: %s"], tostring(err))
	end
end

-- A few /who results come back as chat lines instead of WHO_LIST_UPDATE:
-- "[Valkur Maul]: Level 29 Tauren Warrior <Guild> - Zone", in the client's language.
-- The pattern is built from the game's own format (WHO_LIST_FORMAT / WHO_LIST_GUILD_FORMAT).

-- "|Hplayer:%s|h[%s]|h: Level %d %s %s - %s" -> Lua pattern + which argument each capture is
local function FormatToPattern(fmt)
	if type(fmt) ~= "string" or fmt == "" then return nil end
	local out, order, i, n = { "^" }, {}, 1, 0
	while i <= #fmt do
		local spec = fmt:match("^%%%d*%$?[sd]", i)
		if spec then
			n = n + 1
			local position = spec:match("^%%(%d+)%$")
			order[#order + 1] = position and tonumber(position) or n
			out[#out + 1] = spec:sub(-1) == "d" and "(%d+)" or "(.-)"
			i = i + #spec
		elseif fmt:sub(i, i + 1) == "%%" then
			out[#out + 1] = "%%"
			i = i + 2
		else
			local c = fmt:sub(i, i)
			out[#out + 1] = c:find("[%(%)%.%+%-%*%?%[%]%^%$%%]") and ("%" .. c) or c
			i = i + 1
		end
	end
	out[#out + 1] = "$"
	return table.concat(out), order
end

local whoPatterns
local function WhoPatterns()
	if whoPatterns then return whoPatterns end
	whoPatterns = {}
	for _, name in ipairs({ "WHO_LIST_GUILD_FORMAT", "WHO_LIST_FORMAT" }) do
		local pattern, order = FormatToPattern(_G[name])
		if pattern then
			whoPatterns[#whoPatterns + 1] = { pattern = pattern, order = order, guild = name == "WHO_LIST_GUILD_FORMAT" }
		end
	end
	return whoPatterns
end

-- "Tauren Guerreiro" -> "WARRIOR" (the longest localized class name at the end of the text)
local function ClassFromText(text)
	local best, bestLen
	for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
		for token, name in pairs(names) do
			if #name > 0 and (text == name or text:sub(-(#name + 1)) == " " .. name) and (not bestLen or #name > bestLen) then
				best, bestLen = token, #name
			end
		end
	end
	return best
end

-- name, level, class token, zone from a /who chat line, or nil
function Presence.ParseWhoLine(msg)
	for _, p in ipairs(WhoPatterns()) do
		local caps = { msg:match(p.pattern) }
		if #caps > 0 then
			local args = {}
			for j, index in ipairs(p.order) do args[index] = caps[j] end
			local raceClass = ((args[4] or "") .. " " .. (args[5] or "")):gsub("^%s+", "")
			return args[1] or args[2], tonumber(args[3]), ClassFromText(raceClass), p.guild and args[7] or args[6]
		end
	end
end

ns.On("CHAT_MSG_SYSTEM", function(msg)
	if not whoKey or GetTime() - whoAt > 15 then return end
	msg = Safe.Value(msg)
	if type(msg) ~= "string" then return end
	local name, level, class, zone = Presence.ParseWhoLine(msg)
	if not name or Data.Normalize(name) ~= whoKey then return end
	local key = whoKey
	whoKey = nil
	ns.Debug("who (chat): %s level %s class %s zone %s", key, tostring(level), tostring(class), tostring(zone))
	Data.UpdateInfo(key, class, level, zone)
	pending[key] = nil
	Data.SetStatus(key, "online")
end)

ns.On("WHO_LIST_UPDATE", function()
	if not whoKey or GetTime() - whoAt > 15 then whoKey = nil return end
	local key = whoKey
	local n = Safe.Call(C_FriendList.GetNumWhoResults) or 0
	ns.Debug("who (list): %d results for %s", n, key)
	for i = 1, n do
		local info = Safe.Call(C_FriendList.GetWhoInfo, i)
		if type(info) == "table" and Data.Normalize(Safe.Value(info.fullName)) == key then
			whoKey = nil
			Data.UpdateInfo(key, Safe.Value(info.filename), Safe.Value(info.level), Safe.Value(info.area))
			pending[key] = nil
			Data.SetStatus(key, "online")
			return
		end
	end
	-- not in the list: either nobody was found (offline), or the answer went to chat instead
	-- (handled above), so only conclude "offline" when the search found nobody at all
	if n == 0 then
		whoKey = nil
		Data.SetStatus(key, "offline")
	end
end)

--------------------------------------------------------------------------------
-- Debug: /ofl ping <name>
--------------------------------------------------------------------------------

function Presence.PingNow(key)
	local can, why = Comm.CanSend()
	if not can then ns.Print("Can't ping now (%s).", why) return end
	lastCheck[key] = GetTime()
	if Comm.Ping(key) then
		pending[key] = GetTime()
		Presence.probe[key] = true
		ns.Print("Pinged %s; result in a few seconds.", key)
	else
		ns.Print("The ping to %s didn't go out.", key)
	end
end
