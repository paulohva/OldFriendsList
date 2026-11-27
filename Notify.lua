--------------------------------------------------------------------------------
-- Notifications: the classic yellow "X has come online." line, plus a sound
--------------------------------------------------------------------------------

local _, ns = ...
local Data = ns.Data

local Notify = {}
ns.Notify = Notify

-- quiet until the first full check after login is done (that one prints a summary)
Notify.ready = false

local function SystemColor()
	local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
	if info then return info.r, info.g, info.b end
	return 1, 1, 0
end

-- clickable [Name] like the game's own player links
local function PlayerLink(key)
	local display = Data.Display(key)
	local f = Data.Get(key)
	local c = f and Data.ClassColor(f.class)
	local text = display
	if c and c.WrapTextInColorCode then text = c:WrapTextInColorCode(display) end
	return ("|Hplayer:%s|h[%s]|h"):format(key, text)
end
Notify.PlayerLink = PlayerLink

local function SystemLine(text)
	DEFAULT_CHAT_FRAME:AddMessage(text, SystemColor())
end

local function PlayOnlineSound()
	if not ns.db.settings.sound then return end
	local id = SOUNDKIT and (SOUNDKIT.UI_BNET_TOAST or SOUNDKIT.FRIEND_JOIN_GAME)
	if id then pcall(PlaySound, id, "Master") end
end

-- Blizzard's own string when it exists and takes exactly `count` %s, else nil
local function Blizzard(name, count)
	local s = _G[name]
	if type(s) ~= "string" then return nil end
	local _, n = s:gsub("%%s", "")
	local _, other = s:gsub("%%[^s%%]", "")
	if n == count and other == 0 then return s end
	return nil
end

-- the game's own "|Hplayer:%s|h[%s]|h has come online." (already in the client's language).
-- A friend in your guild, with the game's guild member alert on, already gets that line
-- and the game's sound: nothing from us then (there's no separate option for that sound).
function Notify.Online(key)
	if not ns.db.settings.notifyOnline then return end
	if ns.Guild.Announces(key) then
		ns.Debug("%s: login left to the guild alert", key)
		return
	end
	local blizzard = Blizzard("ERR_FRIEND_ONLINE_SS", 2)
	if blizzard then
		local f = Data.Get(key)
		local c = f and Data.ClassColor(f.class)
		local display = Data.Display(key)
		if c and c.WrapTextInColorCode then display = c:WrapTextInColorCode(display) end
		SystemLine(blizzard:format(key, display))
	else
		SystemLine(ns.L["%s has come online."]:format(PlayerLink(key)))
	end
	PlayOnlineSound()
end

-- the game's own "%s has gone offline."
function Notify.Offline(key)
	if not ns.db.settings.notifyOffline then return end
	if ns.Guild.Announces(key) then
		ns.Debug("%s: offline line left to the guild alert", key)
		return
	end
	local blizzard = Blizzard("ERR_FRIEND_OFFLINE_S", 1)
	SystemLine((blizzard or ns.L["%s has gone offline."]):format(PlayerLink(key)))
end

--------------------------------------------------------------------------------
-- Battle.net friends not on the list: the same lines, with the BattleTag (no number) in
-- Battle.net blue after [Character]; only when BattleNet.ShouldNotify() says so
--------------------------------------------------------------------------------

local BNET_COLOR = "|cff82c5ff"

-- [Character] clickable, in class colour when that option is on
local function BNetLink(entry)
	local c = Data.ClassColor(entry.class)
	local text = entry.key
	if c and c.WrapTextInColorCode then text = c:WrapTextInColorCode(text) end
	return ("|Hplayer:%s|h[%s]|h"):format(entry.key, text)
end

local function BNetTag(entry)
	local tag = ns.BattleNet.ShortTag(entry)
	return tag and (BNET_COLOR .. tag .. "|r") or nil
end

local function BNetAllowed(entry, setting)
	if not (entry and ns.BattleNet.ShouldNotify() and ns.db.settings[setting]) then return false end
	if ns.Guild.Announces(entry.key) then
		ns.Debug("%s: left to the guild alert", entry.key)
		return false
	end
	return true
end

function Notify.BNetOnline(entry)
	if not BNetAllowed(entry, "notifyOnline") then return end
	local tag = BNetTag(entry)
	local line
	local blizzard = Blizzard("ERR_FRIEND_ONLINE_SS", 2)
	if blizzard then
		local c = Data.ClassColor(entry.class)
		local display = (c and c.WrapTextInColorCode) and c:WrapTextInColorCode(entry.key) or entry.key
		line = blizzard:format(entry.key, display)
		-- the tag goes right after the game's [Character] link, whatever the language
		if tag then line = line:gsub("(|h%[.-%]|h)", function(link) return link .. " " .. tag end, 1) end
	else
		line = ns.L["%s has come online."]:format(BNetLink(entry) .. (tag and (" " .. tag) or ""))
	end
	SystemLine(line)
	PlayOnlineSound()
end

function Notify.BNetOffline(entry)
	if not BNetAllowed(entry, "notifyOffline") then return end
	local tag = BNetTag(entry)
	local blizzard = Blizzard("ERR_FRIEND_OFFLINE_S", 1)
	SystemLine((blizzard or ns.L["%s has gone offline."]):format(BNetLink(entry) .. (tag and (" " .. tag) or "")))
end

-- after the first full check: from now on, logins and logouts are announced one by one
function Notify.FirstCheckDone()
	Notify.ready = true
end

-- one line with everyone online (not shown on login anymore; kept for the demo screenshots)
function Notify.Summary()
	Notify.ready = true
	local names = {}
	for _, key in ipairs(Data.Sorted()) do
		if Data.status[key] == "online" then names[#names + 1] = PlayerLink(key) end
	end
	if #names > 0 and ns.db.settings.notifyOnline then
		ns.Print(#names == 1 and ns.L["%d friend online: %s"] or ns.L["%d friends online: %s"], #names, table.concat(names, ", "))
	end
end

ns.Listen("STATUS_CHANGED", function(key, new, old)
	if not Notify.ready then return end
	if new == "online" and old == "offline" then
		Notify.Online(key)
	elseif new == "offline" and old == "online" then
		Notify.Offline(key)
	end
end)
