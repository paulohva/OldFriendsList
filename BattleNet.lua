--------------------------------------------------------------------------------
-- Battle.net friends playing this game right now, and the character each one is on.
--  * Always: an Old Friend who is a Battle.net friend's current character is online, with
--    level, class and zone, straight away and even on the other faction (no pings for them).
--    When the Battle.net friend logs off or switches character, that Old Friend is checked
--    again at once (a ping tells whether they're still on).
--  * Options: hide those friends from the group in the Social window (hideBNetDuplicates), and
--    list the other Battle.net friends in the separate window (showBNet).
--  * 1.0.2: the other Battle.net friends (not on the list) logging in and out of this game get
--    a chat line too (notifyBNet, see BattleNet.ShouldNotify); Old Friends keep their own line.
--    Friends playing in another region are shown too, with a chat line, but only a Battle.net
--    whisper reaches them (no invite, Who or adding them: names repeat across regions).
-- Everything is read with ns.Safe (values the game keeps secret count as unknown).
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data = ns.Safe, ns.Data

local BattleNet = {}
ns.BattleNet = BattleNet

local online = {}     -- key -> entry: characters of Battle.net friends online in this game now
local elsewhere = {}  -- the same, in another region (never Old Friends: names repeat across regions)
local UPDATE_DELAY = 0.5

-- class file ("WARRIOR") from the class name the friend's game reports (in the game's language)
local classByName
local function ClassFile(className, guid)
	if not classByName then
		classByName = {}
		for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
			if type(names) == "table" then
				for file, name in pairs(names) do classByName[name] = file end
			end
		end
	end
	local file = className and classByName[className]
	if not file and guid then
		local _, englishClass = Safe.CallAll(GetPlayerInfoByGUID, guid)
		if type(englishClass) == "string" and englishClass ~= "" then file = englishClass end
	end
	return file
end

-- a game account that is online in this game (WoW Forever): "here" in this region, "elsewhere"
-- in another one (a different set of realms: only a Battle.net whisper reaches them), or nil
local function InThisGame(game)
	if Safe.Value(game.isOnline) ~= true then return nil end
	local client = Safe.Value(game.clientProgram)
	if client ~= (BNET_CLIENT_WOW or "WoW") then return nil end
	local project = Safe.Value(game.wowProjectID)
	if WOW_PROJECT_ID and project and project ~= WOW_PROJECT_ID then return nil end
	if Safe.Value(game.isInCurrentRegion) == false then return "elsewhere" end
	return "here"
end

local function Entry(account, game)
	local key = Data.Normalize(Safe.Value(game.characterName))
	if not key then return nil end
	local level = tonumber(Safe.Value(game.characterLevel))
	local zone = Safe.Value(game.areaName)
	return {
		key = key,
		level = level and level > 0 and level or nil,
		class = ClassFile(Safe.Value(game.className), Safe.Value(game.playerGuid)),
		zone = type(zone) == "string" and zone ~= "" and zone or nil,
		faction = Safe.Value(game.factionName),
		accountName = Safe.Value(account.accountName),   -- for a Battle.net whisper
		battleTag = Safe.Value(account.battleTag),
		bnetAccountID = Safe.Value(account.bnetAccountID),
	}
end

-- every Battle.net friend's character online in this game, by key: in this region, and in
-- another region (shown in the separate window only to chat with them)
local function Read()
	local found, far = {}, {}
	if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return found, far end
	local n = Safe.Call(BNGetNumFriends) or 0
	for i = 1, n do
		local account = Safe.Call(C_BattleNet.GetFriendAccountInfo, i)
		if type(account) == "table" then
			local function Consider(game)
				if type(game) ~= "table" then return end
				local where = InThisGame(game)
				if not where then return end
				local entry = Entry(account, game)
				if not entry then return end
				if where == "here" then
					found[entry.key] = entry
				else
					entry.otherRegion = true
					far[entry.key] = entry
				end
			end
			-- a friend can be on several games at once: look at each of them
			local games = Safe.Call(C_BattleNet.GetFriendNumGameAccounts, i) or 0
			if games > 0 and C_BattleNet.GetFriendGameAccountInfo then
				for j = 1, games do Consider(Safe.Call(C_BattleNet.GetFriendGameAccountInfo, i, j)) end
			else
				Consider(Safe.Value(account.gameAccountInfo))
			end
		end
	end
	return found, far
end

-- the first read after logging in (or after Battle.net comes back) only learns who's on: no
-- "has come online" for everyone at once
local primed

local function Update()
	-- Battle.net not connected: the list reads empty, which isn't everyone logging off
	if Safe.Call(BNConnected) == false then
		primed = false
		return
	end
	local ok, found, far = pcall(Read)
	if not ok then
		ns.Debug("battle.net: %s", tostring(found))
		return
	end
	far = far or {}
	-- Battle.net friends not on the list, logging in or out of this game (or switching
	-- character: the old one goes, the new one comes), in this region or another one.
	-- Old Friends get their own lines.
	local Notify = ns.Notify
	if primed and Notify then
		-- (who left first: a character switch reads "old one offline, new one online")
		for key, e in pairs(online) do
			if not found[key] and not Data.Has(key) then Notify.BNetOffline(e) end
		end
		for key, e in pairs(elsewhere) do
			if not far[key] then Notify.BNetOffline(e) end
		end
		for key, e in pairs(found) do
			if not online[key] and not Data.Has(key) then Notify.BNetOnline(e) end
		end
		for key, e in pairs(far) do
			if not elsewhere[key] then Notify.BNetOnline(e) end
		end
	end
	primed = true
	elsewhere = far
	local Presence = ns.Presence
	-- Old Friends seen through Battle.net: online now, with what their game says
	for key, e in pairs(found) do
		if Data.Has(key) then
			Data.UpdateInfo(key, e.class, e.level, e.zone)
			if Presence then Presence.Resolve(key) end
			Data.Seen(key)
		end
	end
	-- gone from Battle.net (logged off, or another character): ask about them at once
	for key in pairs(online) do
		if not found[key] and Data.Has(key) and Presence then Presence.CheckSoon(key) end
	end
	online = found
	ns.Fire("BNET_CHANGED")
end

local queued
local function UpdateSoon()
	if queued then return end
	queued = true
	C_Timer.After(UPDATE_DELAY, function()
		queued = nil
		Update()
	end)
end

for _, event in ipairs({
	"BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
	"BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED", "PLAYER_ENTERING_WORLD",
}) do
	ns.On(event, UpdateSoon)
end
ns.Listen("LOGIN", UpdateSoon)
-- a friend added to the list may already be on Battle.net
ns.Listen("FRIENDS_CHANGED", function(_, what) if what == "added" then UpdateSoon() end end)

--------------------------------------------------------------------------------
-- Reading it
--------------------------------------------------------------------------------

-- the Battle.net friend on this character right now, or nil
function BattleNet.Get(key)
	return key and online[key]
end

-- a Battle.net friend's character shown in the separate window (this region or another), or nil
function BattleNet.Shown(key)
	return key and (online[key] or elsewhere[key])
end

-- Battle.net friends' characters online in this game, not on the Old Friends List, by name;
-- also the ones in another region
function BattleNet.Others()
	local out = {}
	for key, e in pairs(online) do
		if not Data.Has(key) then out[#out + 1] = e end
	end
	for key, e in pairs(elsewhere) do
		-- (the same name here wins: one row per name)
		if not online[key] and not Data.Has(key) then out[#out + 1] = e end
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

-- the BattleTag without its number ("Moletom#1851" -> "Moletom"), or nil
function BattleNet.ShortTag(entry)
	local tag = entry and entry.battleTag
	return type(tag) == "string" and tag:match("^[^#]+") or nil
end

-- announce Battle.net friends (not on the list) logging in and out? Only where they're part of
-- what you see: Old Friends List in the Social window, or Battle.net friends in the separate window
function BattleNet.ShouldNotify()
	local s = ns.db and ns.db.settings
	return s and s.notifyBNet and (s.socialMode == "integrated" or s.showBNet) and true or false
end

-- on your faction (they can be whispered by name, invited and looked up with Who)?
function BattleNet.SameFaction(e)
	local mine = Data.MyFaction()
	return not (e and e.faction and mine) or e.faction == mine
end

-- can you whisper them by name, invite them, look them up with Who, add them to the list?
-- Not on the other faction nor in another region: there, only a Battle.net whisper
function BattleNet.Reachable(e)
	return not (e and e.otherRegion) and BattleNet.SameFaction(e)
end

-- for /ofl diag
function BattleNet.Info()
	local count, onList = 0, 0
	for key in pairs(online) do
		count = count + 1
		if Data.Has(key) then onList = onList + 1 end
	end
	local far = 0
	for _ in pairs(elsewhere) do far = far + 1 end
	return ("Battle.net: %d friends online in this game (%d on your list, %d more in another region), project %s")
		:format(count, onList, far, tostring(WOW_PROJECT_ID))
end

BattleNet.Update, BattleNet.Read = Update, Read   -- (for tests)
