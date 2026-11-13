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

-- the game's own "|Hplayer:%s|h[%s]|h has come online." (already in the client's language)
function Notify.Online(key)
	if not ns.db.settings.notifyOnline then return end
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
	local blizzard = Blizzard("ERR_FRIEND_OFFLINE_S", 1)
	SystemLine((blizzard or ns.L["%s has gone offline."]):format(PlayerLink(key)))
end

-- after the first full sweep: one line with everyone already online
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
