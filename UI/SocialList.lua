--------------------------------------------------------------------------------
-- Old Friends inside the game's Social window (O): a section "Old Friends List x/y" above
-- Blizzard's Favorites, collapsible, with rows drawn like Blizzard's friend cards. Only when
-- the "integrated" mode is chosen.
--
-- Blizzard's friends list is never touched: we don't add to its data, call its functions or
-- wrap its code (doing that makes its card creation run as addon code, and the game then
-- blocks the protected calls those cards make). Instead:
--  * our own section (header + our own scroll list) sits at the top of the friends tab;
--  * Blizzard's list (and its scroll bar) is moved down by the section's height, by shifting
--    the y offset of its top anchors. Turning the mode off puts them back exactly.
--------------------------------------------------------------------------------

local _, ns = ...
local Data, L, UI, Safe = ns.Data, ns.L, ns.UI, ns.Safe

local SocialList = {}
ns.SocialList = SocialList

local ROW_TEMPLATE = "OldFriendsListSocialRowTemplate"
local ROW_HEIGHT, ROW_SPACING = 58, 3
local HEADER_HEIGHT = 24
local MAX_ROWS = 4                 -- more friends than this: the section scrolls
local PAD_LEFT, PAD_RIGHT, PAD_TOP, GAP = 10, 7, 10, 6
local DOT_MARGIN = 6               -- room for the status dots, centred on the cards' top-left corner

local list            -- SocialUIFrame.FriendsList
local section, header, scrollBox, scrollBar, view
local saved = {}      -- [frame] = its original anchors, to shift and restore
local installed, failed

function SocialList.Enabled()
	return ns.db and ns.db.settings.socialMode == "integrated" or false
end

function SocialList.Installed()
	return installed and true or false
end

--------------------------------------------------------------------------------
-- Moving Blizzard's list down (and back)
--------------------------------------------------------------------------------

local function SaveAnchors(frame)
	if not frame or saved[frame] then return end
	local points = {}
	for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
	saved[frame] = points
end

-- re-applies the original anchors, with top anchors moved down by `offset`
-- (top anchors relative to `except` move with it on their own and are left alone)
local function Shift(frame, offset, except)
	local points = saved[frame]
	if not points or #points == 0 then return end
	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		local point, relativeTo, relativePoint, x, y = p[1], p[2], p[3], p[4], p[5]
		if point:find("TOP") and (not except or relativeTo ~= except) then y = (y or 0) - offset end
		frame:SetPoint(point, relativeTo, relativePoint, x, y)
	end
end

local function MoveBlizzardList(offset)
	if not list then return end
	Shift(list.ScrollBox, offset)
	Shift(list.ScrollBar, offset, list.ScrollBox)
end

--------------------------------------------------------------------------------
-- Our section
--------------------------------------------------------------------------------

local function InitRow(row, elementData)
	local key = elementData and elementData.key
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

-- the section's height for n friends (header only when collapsed)
function SocialList.SectionHeight(n, collapsed)
	if n == 0 then return 0 end
	local rows = collapsed and 0 or math.min(n, MAX_ROWS)
	local body = rows > 0 and (rows * (ROW_HEIGHT + ROW_SPACING) + 2) or 0
	return PAD_TOP + HEADER_HEIGHT + body + GAP
end

local function SetCollapseIcon(collapsed)
	local button = header.CollapseButton
	local icon = button and button.Icon
	local atlas = collapsed and "common-button-list-plus" or "common-button-list-minus"
	if icon then pcall(icon.SetAtlas, icon, atlas, true) end
	if button and button.SetHighlightAtlas then pcall(button.SetHighlightAtlas, button, atlas) end
	if header.Fallback then header.Fallback:SetText(collapsed and "+" or "-") end
end

-- redraws our section and moves Blizzard's list to fit
function SocialList.Layout()
	if not (installed and section) then return end
	if not SocialList.Enabled() then
		section:Hide()
		MoveBlizzardList(0)
		return
	end
	local keys, online = SocialList.Keys(SearchText())
	local collapsed = ns.db.settings.socialCollapsed and true or false
	local height = SocialList.SectionHeight(#keys, collapsed)
	if height == 0 then
		section:Hide()
		MoveBlizzardList(0)
		return
	end

	local text = L["Old Friends List %d/%d"]:format(online, #keys)
	if header.SetText then header:SetText(text) end
	if header.ButtonText then header.ButtonText:SetText(text) end
	SetCollapseIcon(collapsed)

	local rows = collapsed and 0 or math.min(#keys, MAX_ROWS)
	local scrolls = rows > 0 and #keys > MAX_ROWS
	scrollBox:SetShown(rows > 0)
	scrollBar:SetShown(scrolls)
	-- full width like Blizzard's cards, unless our own scroll bar needs the room
	scrollBox:ClearAllPoints()
	-- (the list has an inner margin so the status dots, which sit on the cards' corner, aren't clipped)
	scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -2 - DOT_MARGIN, DOT_MARGIN - 2)
	scrollBox:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", scrolls and -12 or 0, DOT_MARGIN - 2)
	if rows > 0 then
		scrollBox:SetHeight(DOT_MARGIN + rows * (ROW_HEIGHT + ROW_SPACING))
		local items = {}
		for _, key in ipairs(keys) do items[#items + 1] = { key = key } end
		scrollBox:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
	end

	if section.copyWidth then
		local width = list.ScrollBox:GetWidth()
		if width and width > 0 then section:SetWidth(width) end
	end
	section:SetHeight(height)
	section:Show()
	MoveBlizzardList(height)
end

-- our data changed, or the mode was flipped
local layoutQueued
function SocialList.Refresh()
	if not installed or layoutQueued then return end
	layoutQueued = true
	C_Timer.After(0.1, function()
		layoutQueued = nil
		local ok, err = pcall(SocialList.Layout)
		if not ok then ns.Debug("social section: %s", tostring(err)) end
	end)
end

local function BuildHeader()
	-- Blizzard's list header look (visual template only), or a plain one if it's not there
	local ok, h = pcall(CreateFrame, "Button", nil, section, "ListHeaderVisualTemplate")
	if not ok or not h then
		h = CreateFrame("Button", nil, section)
		local bg = h:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.25, 0.18, 0.08, 0.9)
		local label = h:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("LEFT", 8, 0)
		h.ButtonText = label
		local sign = h:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		sign:SetPoint("RIGHT", -10, 0)
		h.Fallback = sign
	end
	h:SetHeight(HEADER_HEIGHT)
	h:SetPoint("TOPLEFT", section, "TOPLEFT", PAD_LEFT, -PAD_TOP)
	h:SetPoint("TOPRIGHT", section, "TOPRIGHT", -PAD_RIGHT, -PAD_TOP)
	h:SetScript("OnClick", function()
		ns.db.settings.socialCollapsed = not ns.db.settings.socialCollapsed
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		SocialList.Layout()
	end)
	return h
end

local function Build()
	section = CreateFrame("Frame", nil, list)
	section:SetFrameLevel(list.ScrollBox:GetFrameLevel() + 1)

	-- the section takes the place where Blizzard's list starts (its top anchors); with a
	-- single top anchor, its width is copied from Blizzard's list on each layout
	local topAnchors = 0
	for _, p in ipairs(saved[list.ScrollBox]) do
		if p[1]:find("TOP") then
			section:SetPoint(p[1], p[2], p[3], p[4], p[5])
			topAnchors = topAnchors + 1
		end
	end
	section.copyWidth = topAnchors < 2

	header = BuildHeader()

	scrollBox = CreateFrame("Frame", nil, section, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	scrollBox:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -12, -2)
	scrollBar = CreateFrame("EventFrame", nil, section, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

	view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	if view.SetPadding then view:SetPadding(DOT_MARGIN, 0, DOT_MARGIN, 0, ROW_SPACING) end
	view:SetElementInitializer(ROW_TEMPLATE, InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	section:Hide()
end

local function Install()
	if installed or failed then return end
	local social = _G["SocialUIFrame"]
	local friendsList = social and social.FriendsList
	if not (friendsList and friendsList.ScrollBox) then return end

	local ok, err = pcall(function()
		list = friendsList
		SaveAnchors(list.ScrollBox)
		SaveAnchors(list.ScrollBar)
		assert(#saved[list.ScrollBox] > 0, "the friends list has no anchors")
		Build()
		-- redraw when the friends tab shows, and when the search text changes
		list:HookScript("OnShow", function() SocialList.Refresh() end)
		local bar = list.FilterBar and list.FilterBar.SearchBar
		if bar and bar.HookScript then bar:HookScript("OnTextChanged", function() SocialList.Refresh() end) end
	end)

	if ok then
		installed = true
		ns.Debug("social section: installed")
		SocialList.Refresh()
	else
		failed = true
		ns.Debug("social section: not installed (%s)", tostring(err))
		if section then section:Hide() end
		if list then pcall(MoveBlizzardList, 0) end
		if SocialList.Enabled() then
			ns.Print(L["Couldn't add your friends to the Social window; using the separate window."])
		end
	end
end
SocialList.Install = Install

-- our data changed: keep the open Social window in step
local function OnDataChanged()
	if SocialList.Enabled() and section and list and list:IsVisible() then SocialList.Refresh() end
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
	return ("Social window section: %s, mode %s, shown %s"):format(state, tostring(ns.db and ns.db.settings.socialMode),
		tostring(section and section:IsShown()))
end
