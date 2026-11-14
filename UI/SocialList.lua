--------------------------------------------------------------------------------
-- Old Friends inside the game's Social window (O): a group "Old Friends List x/y" above
-- Favorites, collapsible like Blizzard's. Only when the "integrated" mode is chosen.
--
-- Forever's friends list (Blizzard_FriendsFrame, FriendsListSocialViewMixin) rebuilds a
-- tree data provider in Refresh(). We:
--  * post-hook Refresh (hooksecurefunc: Blizzard's code runs untouched) and insert our
--    group at the top of the tree it just built;
--  * wrap the view's element factory so our rows (data.oflKey) get our template; every
--    other row goes to Blizzard's factory unchanged. Headers reuse Blizzard's header
--    template, so collapsing works exactly like Favorites;
--  * register our template's height with the list (it sizes rows from that registry).
-- If any of that isn't there (Blizzard changed it), nothing is installed and the addon
-- keeps working with its own window.
--------------------------------------------------------------------------------

local _, ns = ...
local Data, L, UI, Safe = ns.Data, ns.L, ns.UI, ns.Safe

local SocialList = {}
ns.SocialList = SocialList

local HEADER_TYPE = "OldFriendsList"
local ROW_TEMPLATE = "OldFriendsListSocialRowTemplate"
local ROW_HEIGHT = 58

local list            -- SocialUIFrame.FriendsList, once installed
local installed, failed, warned

function SocialList.Enabled()
	return ns.db and ns.db.settings.socialMode == "integrated" or false
end

function SocialList.Installed()
	return installed and true or false
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function InitRow(row, node)
	local data = node and node.GetData and node:GetData()
	local key = data and data.oflKey
	row.key = key
	local f = key and Data.Get(key)
	if not f then return end
	if not row.oflSetUp then
		row.oflSetUp = true
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(self, button)
			if button == "RightButton" then UI.OpenFriendMenu(self) end
		end)
		row:SetScript("OnDoubleClick", function(self) ns.Actions.Whisper(self.key) end)
		row:SetScript("OnEnter", UI.ShowFriendTooltip)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	local online = Data.status[key] == "online"
	row.Background:SetAtlas(online and "friends-card-default" or "friends-card-disabled", false)
	row.Presence:SetAtlas(online and "friends-status-online" or "friends-status-offline", false)
	row.FriendName:SetText(UI.NameText(key, f))
	local details = ns.db.settings.showDetails
	row.Info:SetShown(details)
	if details then row.Info:SetText(UI.InfoLine(key, f)) end
	row.NoteIcon:SetShown(f.note ~= nil)
end

--------------------------------------------------------------------------------
-- The group, added after each Blizzard refresh
--------------------------------------------------------------------------------

-- what's typed in the Social window's search box (lowercase), or ""
local function SearchText()
	local bar = list and list.FilterBar and list.FilterBar.SearchBar
	local text = bar and bar.GetText and Safe.Call(bar.GetText, bar)
	return type(text) == "string" and text:lower() or ""
end

-- Old Friends to show: online first, filtered by the search box
function SocialList.Keys(search)
	local keys, online = {}, 0
	for _, key in ipairs(Data.Sorted()) do
		if search == "" or key:lower():find(search, 1, true) then
			keys[#keys + 1] = key
			if Data.status[key] == "online" then online = online + 1 end
		end
	end
	return keys, online
end

-- collapsed? Blizzard's header click records it under our header type; we keep it across reloads
local function Collapsed()
	local headers = list.collapsedHeaders
	local value = headers and headers[HEADER_TYPE]
	if value == nil then
		value = ns.db.settings.socialCollapsed and true or false
		if headers then headers[HEADER_TYPE] = value end
	else
		ns.db.settings.socialCollapsed = value and true or false
	end
	return value and true or false
end

-- inserts our group at the top of a tree data provider
function SocialList.InsertGroup(provider, keys, online, collapsed)
	if #keys == 0 then return nil end
	local header = provider:InsertAtIndex({
		headerType = HEADER_TYPE,
		headerText = L["Old Friends List %d/%d"]:format(online, #keys),
	}, 1)
	header:SetCollapsed(collapsed, false, true)
	for _, key in ipairs(keys) do header:Insert({ oflKey = key }) end
	header:Insert({ isSpacer = true })
	provider:InsertAtIndex({ isSpacer = true }, 2)
	return header
end

local function AfterRefresh()
	if not SocialList.Enabled() or not list then return end
	local ok, err = pcall(function()
		local provider = list.ScrollBox:GetDataProvider()
		if not provider then return end
		local keys, online = SocialList.Keys(SearchText())
		SocialList.InsertGroup(provider, keys, online, Collapsed())
	end)
	if not ok then ns.Debug("social list: %s", tostring(err)) end
end

--------------------------------------------------------------------------------
-- Installing into the Social window
--------------------------------------------------------------------------------

local function Install()
	if installed or failed then return end
	local social = _G["SocialUIFrame"]
	local friendsList = social and social.FriendsList
	if not friendsList then return end

	local ok, err = pcall(function()
		assert(type(friendsList.Refresh) == "function", "no Refresh")
		local view = friendsList.ScrollBox and friendsList.ScrollBox:GetView()
		assert(view and view.SetElementFactory and type(view.elementFactory) == "function", "no element factory")
		assert(type(friendsList.RegisterTemplateForExtentPreview) == "function", "no extent registry")

		-- our rows' height, in the registry the list sizes its rows from
		friendsList:RegisterTemplateForExtentPreview(ROW_TEMPLATE, function() return ROW_HEIGHT end)

		-- our rows get our template; everything else goes to Blizzard's factory, unchanged
		local original = view.elementFactory
		view:SetElementFactory(function(factory, node)
			local data = node and node.GetData and node:GetData()
			if type(data) == "table" and data.oflKey then
				factory(ROW_TEMPLATE, InitRow)
				return
			end
			return original(factory, node)
		end)

		list = friendsList
		hooksecurefunc(friendsList, "Refresh", AfterRefresh)
	end)

	if ok then
		installed = true
		ns.Debug("social list: installed")
		if friendsList:IsVisible() and SocialList.Enabled() then SocialList.Refresh() end
	else
		failed = true
		list = nil
		ns.Debug("social list: not installed (%s)", tostring(err))
		if SocialList.Enabled() and not warned then
			warned = true
			ns.Print(L["Couldn't add your friends to the Social window; using the separate window."])
		end
	end
end
SocialList.Install = Install

-- rebuild the Social window's list (a moment later, so several changes become one refresh)
local refreshQueued
function SocialList.Refresh()
	if not (installed and list) or refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.2, function()
		refreshQueued = nil
		if list and list:IsVisible() then
			local ok, err = pcall(list.Refresh, list, true)
			if not ok then ns.Debug("social list refresh: %s", tostring(err)) end
		end
	end)
end

-- our data changed: keep the open Social window in step
local function OnDataChanged()
	if SocialList.Enabled() then SocialList.Refresh() end
end
ns.Listen("STATUS_CHANGED", OnDataChanged)
ns.Listen("FRIENDS_CHANGED", OnDataChanged)

ns.Listen("LOGIN", function()
	Install()
	-- the Social window may only be created the first time it opens
	if ToggleFriendsFrame then hooksecurefunc("ToggleFriendsFrame", Install) end
end)
ns.On("ADDON_LOADED", function() Install() end)

-- for /ofl diag
function SocialList.Info()
	local state = installed and "installed" or failed and "failed" or "waiting for the Social window"
	return ("Social window group: %s, mode %s"):format(state, tostring(ns.db and ns.db.settings.socialMode))
end
