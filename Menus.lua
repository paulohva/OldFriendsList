--------------------------------------------------------------------------------
-- Right-click menus: "Add to Old Friends" / "Remove from Old Friends" on player
-- portraits (target, focus, party, raid), names in chat and the guild roster
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data, L = ns.Safe, ns.Data, ns.L

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

	root:CreateDivider()
	if Data.Has(key) then
		root:CreateButton(L["Remove from Old Friends"], function()
			Data.Remove(key)
			ns.Print(L["Removed %s."], Data.Display(key))
		end)
	else
		root:CreateButton(L["Add to Old Friends"], function()
			local added, err = Data.Add(key, info)
			if added then
				ns.Print(L["Added %s."], Data.Display(added))
			else
				ns.Print(err)
			end
		end)
	end
end

ns.Listen("DB_READY", function()
	if not (Menu and Menu.ModifyMenu) then
		ns.Debug("no Menu.ModifyMenu: right-click options unavailable")
		return
	end
	for _, tag in ipairs(TAGS) do
		pcall(Menu.ModifyMenu, tag, Modify)
	end
end)
