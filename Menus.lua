--------------------------------------------------------------------------------
-- Right-click menus: "Add to Old Friends List" / "Remove from Old Friends List" on player
-- portraits (target, focus, party, raid), names in chat, the guild roster and (1.0.3) Battle.net
-- friends in the game's Social window
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data, L = ns.Safe, ns.Data, ns.L

local Menus = {}
ns.Menus = Menus

local TAGS = {
	"MENU_UNIT_TARGET",
	"MENU_UNIT_FOCUS",
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_FRIEND",            -- names clicked in chat
	"MENU_UNIT_CHAT_ROSTER",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
	"MENU_UNIT_COMMUNITIES_MEMBER",
	"MENU_UNIT_GUILD",
}

-- key and unit info for the menu's player, or nil when it isn't a player
local function Resolve(contextData)
	if type(contextData) ~= "table" then return end
	local unit = Safe.Value(contextData.unit)
	if unit and Safe.Call(UnitExists, unit) then
		if not Safe.Call(UnitIsPlayer, unit) then return end
		return Data.KeyFromUnit(unit), Data.InfoFromUnit(unit)
	end
	local name = Safe.Value(contextData.name)
	if type(name) ~= "string" or name == "" then return end
	return Data.Normalize(name)
end

local function Modify(_, root, contextData)
	local key, info = Resolve(contextData)
	if not key or key == Data.MyKey() then return end
	local myFaction = Data.MyFaction()
	if info and info.faction and myFaction and info.faction ~= myFaction then return end
	if info and not Data.SameRealmType(info.realmType) then return end
	-- a name in chat (no unit): a Battle.net friend on the other faction, another realm type or
	-- in another region is for Battle.net only, so no "Add" for them
	local BattleNet = ns.BattleNet
	if not info and not Data.Has(key) and BattleNet then
		local entry = BattleNet.Shown(key)
		if entry and not BattleNet.Reachable(entry) then return end
	end

	root:CreateDivider()
	if Data.Has(key) then
		root:CreateButton(L["Remove from Old Friends List"], function()
			Data.Remove(key)
			ns.Print(L["Removed %s."], Data.Display(key))
		end)
	else
		root:CreateButton(L["Add to Old Friends List"], function()
			local added, err = Data.Add(key, info)
			if added then
				ns.Print(L["Added %s."], Data.Display(added))
			else
				ns.Print(err)
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- 1.0.3: a Battle.net friend in the game's Social window (Favorites or the list): add the
-- character they're playing right now, when you could group with it (same faction and realm
-- type, this region). Only the menu changes: Blizzard's cards aren't touched.
--------------------------------------------------------------------------------

local BNET_TAGS = { "MENU_UNIT_BN_FRIEND", "MENU_UNIT_BN_FRIEND_OFFLINE" }

-- the character a Battle.net friend's menu is about, from what the game hands the menu
local function BNetCharacter(contextData)
	local BattleNet = ns.BattleNet
	if not (BattleNet and type(contextData) == "table") then return nil end
	local account = Safe.Value(contextData.accountInfo)
	local id = Safe.Value(contextData.bnetIDAccount)
	if id == nil and type(account) == "table" then id = Safe.Value(account.bnetAccountID) end
	local entry = BattleNet.ByAccount(id)
	if entry then return entry end
	-- (no id: the character named in the account's game info, when it's online here)
	local game = type(account) == "table" and Safe.Value(account.gameAccountInfo)
	local key = type(game) == "table" and Data.Normalize(Safe.Value(game.characterName))
	return key and BattleNet.Get(key) or nil
end

local function ModifyBNet(_, root, contextData)
	local entry = BNetCharacter(contextData)
	if not entry or entry.key == Data.MyKey() then return end
	if Data.Has(entry.key) then
		root:CreateDivider()
		root:CreateButton(L["Remove %s from Old Friends List"]:format(entry.key), function()
			Data.Remove(entry.key)
			ns.Print(L["Removed %s."], Data.Display(entry.key))
		end)
		return
	end
	if not ns.BattleNet.Reachable(entry) then return end
	root:CreateDivider()
	root:CreateButton(L["Add %s to Old Friends List"]:format(entry.key), function()
		local added, err = Data.Add(entry.key, { class = entry.class, level = entry.level,
			faction = entry.faction, realmType = entry.realmType })
		if added then
			ns.Print(L["Added %s."], Data.Display(added))
		else
			ns.Print(err)
		end
	end)
end

ns.Listen("DB_READY", function()
	if not (Menu and Menu.ModifyMenu) then
		ns.Debug("no Menu.ModifyMenu: right-click options unavailable")
		return
	end
	for _, tag in ipairs(TAGS) do
		pcall(Menu.ModifyMenu, tag, Modify)
	end
	for _, tag in ipairs(BNET_TAGS) do
		pcall(Menu.ModifyMenu, tag, ModifyBNet)
	end
end)

Menus.ModifyBNet = ModifyBNet   -- (for tests)
