--------------------------------------------------------------------------------
-- Guild: who's in your guild, and whether the game already announces their
-- logins. With the game's "Guild member alert" on, the game itself announces
-- guild members ("X has come online." / "X has gone offline.", with its sound),
-- so our own line and sound for a friend in the guild would be duplicates.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data = ns.Safe, ns.Data

local Guild = {}
ns.Guild = Guild

local members = {}   -- [key] = true, from the guild roster
Guild.count = 0

function Guild.InGuild()
	return Safe.Call(IsInGuild) == true
end

-- the game's "Guild member alert" (Options > Social); nil when this client doesn't say
function Guild.AlertsOn()
	if C_CVar and C_CVar.GetCVarBool then
		local on = Safe.Call(C_CVar.GetCVarBool, "guildMemberNotify")
		if on ~= nil then return on end
	end
	return Safe.Call(GetCVarBool, "guildMemberNotify")
end

-- in a guild, with a rank that can invite (the game's check for its guild window's Add Member)
function Guild.CanInvite()
	return Guild.InGuild() and Safe.Call(CanGuildInvite) == true
end

function Guild.IsMember(key)
	return members[key] == true
end

-- true when the game itself prints this friend's logins and logouts
function Guild.Announces(key)
	return Guild.IsMember(key) and Guild.InGuild() and Guild.AlertsOn() == true
end

-- the roster holds every member (online first), whatever the guild window shows
local function Rebuild()
	if not Guild.InGuild() then
		wipe(members)
		Guild.count = 0
		return
	end
	local found, n = {}, 0
	for i = 1, Safe.Call(GetNumGuildMembers) or 0 do
		local key = Data.Normalize(Safe.Call(GetGuildRosterInfo, i))
		if key and not found[key] then
			found[key] = true
			n = n + 1
		end
	end
	if n == 0 then return end   -- roster not loaded yet: keep what we had
	members = found
	Guild.count = n
end

local function Request()
	Safe.Call((C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster)
end

ns.On("GUILD_ROSTER_UPDATE", Rebuild)
ns.On("PLAYER_GUILD_UPDATE", function()
	Request()
	Rebuild()
end)
ns.Listen("LOGIN", function()
	Request()
	Rebuild()
end)

-- for /ofl diag
function Guild.Info()
	local alerts = Guild.AlertsOn()
	return ("guild: %s, guild member alert %s, %d members known"):format(
		Guild.InGuild() and "yes" or "no",
		alerts == nil and "unknown" or (alerts and "on" or "off"),
		Guild.count)
end
