--------------------------------------------------------------------------------
-- Addon messages (prefix "OFL"), all as whispers to one character:
--   "PING"                     are you there? (also how a friend's addon learns you're online)
--   "PONG\tclass\tlevel\tzone" yes, and here's what I'm up to (zone only to people on my list)
-- A PING works with anyone: if they're offline the server answers with a
-- "No player named ..." system message (see Presence.lua). If they also run
-- Old Friends List they answer PONG, which is instant and carries details.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data = ns.Safe, ns.Data

local Comm = {}
ns.Comm = Comm

local PREFIX = ns.PREFIX
local SEP = "\t"

-- can addon messages go out right now? (Forever blocks them in combat and instances,
-- and trial accounts can't send them at all)
function Comm.CanSend()
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "no API" end
	if Safe.Call(IsTrialAccount) then return false, "trial account" end
	if Safe.InCombat() then return false, "in combat" end
	if Safe.InInstance() then return false, "in an instance" end
	return true
end

-- whispers an addon message; true when the client accepted it
function Comm.Whisper(target, text)
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "WHISPER", target)
	if not ok then
		ns.Debug("send to %s failed: %s", target, tostring(result))
		return false
	end
	-- older clients return a boolean, newer ones an Enum.SendAddonMessageResult (0 = Success)
	if result == nil or result == true or result == 0 then return true end
	local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
	if success ~= nil and result == success then return true end
	ns.Debug("send to %s refused (result %s)", target, tostring(result))
	return false
end

function Comm.Ping(key)
	return Comm.Whisper(key, "PING")
end

local function MyDetails(includeZone)
	local _, class = Safe.CallAll(UnitClass, "player")
	local level = Safe.Call(UnitLevel, "player") or 0
	local zone = ""
	if includeZone and ns.db.settings.shareZone then
		zone = Safe.Call(GetRealZoneText) or Safe.Call(GetZoneText) or ""
	end
	return table.concat({ class or "", tostring(level), zone }, SEP)
end

local function OnMessage(prefix, text, channel, sender)
	prefix, text, channel, sender = Safe.Value(prefix), Safe.Value(text), Safe.Value(channel), Safe.Value(sender)
	if prefix ~= PREFIX or channel ~= "WHISPER" or type(text) ~= "string" or type(sender) ~= "string" then return end
	local key = Data.Normalize(sender)
	if not key or key == Data.MyKey() then return end
	local cmd, a, b, c = strsplit(SEP, text)
	ns.Debug("%s from %s", tostring(cmd), key)

	if cmd == "PING" then
		-- they're online (and likely just logged in or are checking on us)
		local friend = Data.Has(key)
		if friend then
			ns.Presence.Resolve(key)
			Data.SetStatus(key, "online")
		end
		if Comm.CanSend() then
			Comm.Whisper(sender, "PONG" .. SEP .. MyDetails(friend))
		end
	elseif cmd == "PONG" then
		if Data.Has(key) then
			ns.Presence.Resolve(key)
			Data.UpdateInfo(key, a, b, c)
			Data.SetStatus(key, "online")
		end
	end
end

ns.Listen("DB_READY", function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	end
end)

ns.On("CHAT_MSG_ADDON", OnMessage)
