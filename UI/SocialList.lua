--------------------------------------------------------------------------------
-- Old Friends inside the game's Social window (O): a section "Old Friends List x/y" above
-- Blizzard's Favorites, collapsible, with rows drawn like Blizzard's friend cards. Only when
-- the "integrated" mode is chosen.
--
-- Blizzard's friends list is never touched: we don't add to its data, call its functions or
-- wrap its code (doing that makes its card creation run as addon code, and the game then
-- blocks the protected calls those cards make). We only read plain fields and use frame calls.
--
-- One scroll for everything (SINGLE_SCROLL, 1.0.0): our own scroll box takes the place of
-- Blizzard's list. Inside it go our group (every friend, no scroll bar of its own) and, below
-- it, Blizzard's list itself, moved in (SetParent) and made as tall as its content (its view's
-- total extent, a plain field), so it never scrolls on its own: our one scroll bar, in
-- Blizzard's scroll bar column, scrolls both. Blizzard's own scroll bar waits in a hidden frame.
-- Turning the mode off puts everything back exactly.
--
-- With SINGLE_SCROLL off, the 0.3.x layout: our group with its own scroll list (up to
-- MAX_ROWS cards) at the top, and Blizzard's list moved down by the group's height.
--------------------------------------------------------------------------------

local _, ns = ...
local Data, L, UI, Safe = ns.Data, ns.L, ns.UI, ns.Safe

local SocialList = {}
ns.SocialList = SocialList

local SINGLE_SCROLL = true

local ROW_TEMPLATE = "OldFriendsListSocialRowTemplate"
local ROW_HEIGHT, ROW_SPACING = 58, 3
local HEADER_HEIGHT = 24
-- two scrolls: more friends than this and the group scrolls on its own; one scroll: all of them
local MAX_ROWS = SINGLE_SCROLL and math.huge or 4
local PAN_EXTENT = 36              -- one mouse wheel step in the single scroll (about Blizzard's)
local PAD_LEFT, PAD_RIGHT, PAD_TOP = 10, 7, 10
-- below our last card: nothing more. Blizzard's list starts with its own padding, which already
-- makes about the same gap Blizzard leaves between a group's last card and the next header
-- (measured in game: ~12)
local END_GAP = 0
-- collapsed: header to header, like Blizzard's collapsed groups (measured in game: 2 less)
local COLLAPSED_END_GAP = -2
local DOT_MARGIN = 6               -- room for the status dots, centred on the cards' top-left corner
local HEADER_GAP = 8               -- header to first card, same as Blizzard's Favorites
-- our scroll bar goes where Blizzard puts its own, next to its list: right of the list, from
-- just below its top to just above its bottom (its template: x 5, top -7, bottom 4). Read from
-- Blizzard's scroll bar anchors when they're the usual kind, so we follow if they change.
local BAR_X, BAR_TOP, BAR_BOTTOM = 5, -7, 4

local list            -- SocialUIFrame.FriendsList
local section, header
local scrollBox, scrollBar, view                 -- two scrolls: our group's own scroll list
local viewport, viewportBar, content, holder     -- one scroll: our scroll box, its bar, what it scrolls
local rows = {}                                  -- one scroll: our cards (plain frames)
local engaged         -- one scroll: Blizzard's list is inside our scroll box right now
local pending         -- one scroll: a change waits for the end of combat
local sectionHeight = 0
local original = {}   -- one scroll: Blizzard's list and scroll bar as they were (parent, level, wheel)
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

--------------------------------------------------------------------------------
-- The invite button on a card, like Blizzard's (its shared action button and icons)
--------------------------------------------------------------------------------

local INVITE_ATLAS = { [true] = "friends-icon-friendsAvailable", [false] = "friends-icon-friendsAvailable-dis" }
local IN_GROUP_ATLAS = { [true] = "friends-icon-friendsInGroup", [false] = "friends-icon-friendsInGroup-dis" }

local function ShowPartyTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["Invite to group"], 1, 1, 1)
	if button.why then GameTooltip:AddLine(button.why, 1, 0.25, 0.25, true) end
	GameTooltip:Show()
end

local function MakePartyButton(row)
	-- Blizzard's own action button (the square with the icon); a plain look-alike if it's not there
	local ok, button = pcall(CreateFrame, "Button", nil, row, "SocialCardActionButtonTemplate")
	if ok and button then
		button.ShowTooltip = ShowPartyTooltip   -- its OnEnter calls this; its OnLeave hides the tooltip
	else
		button = CreateFrame("Button", nil, row)
		button:SetSize(34, 34)
		pcall(button.SetNormalAtlas, button, "common-button-tertiary-square-normal")
		pcall(button.SetPushedAtlas, button, "common-button-tertiary-square-pressed")
		pcall(button.SetHighlightAtlas, button, "common-button-tertiary-square-normal", "ADD")
		button.ActionIcon = button:CreateTexture(nil, "OVERLAY")
		button.ActionIcon:SetPoint("CENTER")
		button:SetScript("OnEnter", ShowPartyTooltip)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	button:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	button:SetMotionScriptsWhileDisabled(true)   -- the tooltip says why it's disabled
	button:SetScript("OnClick", function(self)
		if self.key then ns.Actions.Invite(self.key) end
	end)
	return button
end

-- enabled only when the friend can be invited right now; the tooltip says why not
local function UpdatePartyButton(button, key)
	local ok, why, reason = ns.Actions.CanInvite(key)
	button.key, button.why = key, why
	button:SetEnabled(ok and true or false)
	local atlas = (reason == "ingroup" and IN_GROUP_ATLAS or INVITE_ATLAS)[ok and true or false]
	if button.ActionIcon then pcall(button.ActionIcon.SetAtlas, button.ActionIcon, atlas, true) end
	if GameTooltip:IsOwned(button) then ShowPartyTooltip(button) end
end

-- The status dot exactly as on Blizzard's cards (SocialCardPresenceHolderTemplate and
-- FriendsListSocialCardMixin:LayoutScaledPresenceHolderAnchors): 19x19, centred on the card's
-- top-left corner at (3, -4), all of it grown with the game's text size, weighted 0.6.
local DOT_SIZE, DOT_X, DOT_Y, DOT_WEIGHT = 19, 3, -4, 0.6

local function TextScaleWeighted()
	local manager = _G.TextSizeManager
	local ok, scale = pcall(function() return manager and manager:GetScale() end)
	scale = ok and tonumber(scale) or 1
	return 1 + (scale - 1) * DOT_WEIGHT
end

local function LayoutPresence(row)
	-- (its own frame stays just above the card, whatever level the card gets)
	if row.PresenceHolder then row.PresenceHolder:SetFrameLevel(row:GetFrameLevel() + 1) end
	local w = TextScaleWeighted()
	if row.dotScale == w then return end
	row.dotScale = w
	row.Presence:SetSize(DOT_SIZE * w, DOT_SIZE * w)
	row.Presence:ClearAllPoints()
	row.Presence:SetPoint("CENTER", row, "TOPLEFT", DOT_X * w, DOT_Y * w)
end

local selectedKey   -- the card clicked last (like Blizzard's cards: one selected; click again to clear)

local function ShowSelection(row)
	row.SelectedTexture:SetShown(row.key ~= nil and row.key == selectedKey)
end

local function InitRow(row, elementData)
	local key = elementData and elementData.key
	row.key = key
	local f = key and Data.Get(key)
	if not f then return end
	if not row.oflSetUp then
		row.oflSetUp = true
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		-- Blizzard's selected card look
		-- the status dot in a frame of its own over the card, like Blizzard's PresenceHolder: the
		-- card's highlight (drawn over its own textures, additive) doesn't wash it out on hover
		row.PresenceHolder = CreateFrame("Frame", nil, row)
		row.PresenceHolder:SetAllPoints()
		row.PresenceHolder:SetFrameLevel(row:GetFrameLevel() + 1)
		row.Presence:SetParent(row.PresenceHolder)
		row.SelectedTexture = row:CreateTexture(nil, "ARTWORK", nil, -1)
		row.SelectedTexture:SetAllPoints()
		row.SelectedTexture:SetAtlas("friends-card-selected")
		row.SelectedTexture:SetBlendMode("ADD")
		-- a click selects; double-click to whisper (1.1.1): the first click also arms an invisible
		-- link over the card, the second lands on it and the game opens the whisper itself
		-- (UI.ArmWhisper: the chat stays clean)
		row:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				UI.OpenFriendMenu(self)
				return
			end
			selectedKey = (selectedKey ~= self.key) and self.key or nil
			for _, other in ipairs(rows) do if other.SelectedTexture then ShowSelection(other) end end
			self.armed = UI.ArmWhisper(self, UI.WhisperLinkText(self.key))
		end)
		row:SetScript("OnDoubleClick", function(self)
			-- (only when the link couldn't be armed: the "click the name" line in chat)
			if not self.armed then ns.Actions.Whisper(self.key) end
		end)
		-- (highlight and tooltip: UI.HoverTracker, set up with the section)
		row.PartyButton = MakePartyButton(row)
	end
	ShowSelection(row)
	UpdatePartyButton(row.PartyButton, key)
	local online = Data.status[key] == "online"
	row.Background:SetAtlas(online and "friends-card-default" or "friends-card-disabled", false)
	row.Presence:SetAtlas(online and "friends-status-online" or "friends-status-offline", false)
	LayoutPresence(row)
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

-- Old Friends to show: online first, filtered by the search box; with "hide friends already
-- shown by Battle.net" on, not those a Battle.net friend is playing right now (Blizzard's own
-- card shows them, just below)
function SocialList.Keys(search)
	local keys, online = {}, 0
	local hideBNet = ns.db.settings.hideBNetDuplicates and ns.BattleNet
	for _, key in ipairs(Data.Sorted()) do
		if (search == "" or key:lower():find(search, 1, true)) and not (hideBNet and ns.BattleNet.Get(key)) then
			keys[#keys + 1] = key
			if Data.status[key] == "online" then online = online + 1 end
		end
	end
	return keys, online
end

-- the section's height for n friends (header only when collapsed). With no friends to show it's
-- hidden, unless keepHeader: an empty list still shows its header, with the "+" to add the first one
function SocialList.SectionHeight(n, collapsed, keepHeader)
	if n == 0 and not keepHeader then return 0 end
	local rows = collapsed and 0 or math.min(n, MAX_ROWS)
	-- header gap + the cards with the spacing between them (none after the last one)
	local body = rows > 0 and (HEADER_GAP + rows * (ROW_HEIGHT + ROW_SPACING) - ROW_SPACING) or 0
	return PAD_TOP + HEADER_HEIGHT + body + (rows > 0 and END_GAP or COLLAPSED_END_GAP)
end

local function SetCollapseIcon(collapsed)
	local button = header.CollapseButton
	local icon = button and button.Icon
	local atlas = collapsed and "common-button-list-plus" or "common-button-list-minus"
	if icon then pcall(icon.SetAtlas, icon, atlas, true) end
	if button and button.SetHighlightAtlas then pcall(button.SetHighlightAtlas, button, atlas) end
	if header.Fallback then header.Fallback:SetText(collapsed and "+" or "-") end
end

-- two scrolls: redraws our section and moves Blizzard's list to fit
local function LayoutTwoScrolls()
	if not SocialList.Enabled() then
		section:Hide()
		MoveBlizzardList(0)
		return
	end
	local search = SearchText()
	local keys, online = SocialList.Keys(search)
	local collapsed = ns.db.settings.socialCollapsed and true or false
	-- (an empty list keeps its header, for the "+"; a search with no match hides it)
	local height = SocialList.SectionHeight(#keys, collapsed, search == "")
	if height == 0 then
		section:Hide()
		MoveBlizzardList(0)
		return
	end

	local text = L["Old Friends List %d/%d"]:format(online, #keys)
	if header.SetText then header:SetText(text) end
	if header.ButtonText then header.ButtonText:SetText(text) end
	SetCollapseIcon(collapsed)
	UI.UpdateStale(header.Stale)

	local rows = collapsed and 0 or math.min(#keys, MAX_ROWS)
	local scrolls = rows > 0 and #keys > MAX_ROWS
	scrollBox:SetShown(rows > 0)
	scrollBar:SetShown(scrolls)
	-- full width like Blizzard's cards (our scroll bar sits to their right, like Blizzard's)
	scrollBox:ClearAllPoints()
	-- (the list has an inner margin so the status dots, which sit on the cards' corner, aren't clipped)
	scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -DOT_MARGIN, DOT_MARGIN - HEADER_GAP)
	scrollBox:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, DOT_MARGIN - HEADER_GAP)
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

--------------------------------------------------------------------------------
-- One scroll: Blizzard's list inside our scroll box, as tall as its content
--------------------------------------------------------------------------------

-- the height of everything in Blizzard's list (its view's total extent, padding included),
-- read as a plain field: calling its methods would run its code as ours
local function BlizzardExtent()
	local v = list.ScrollBox.view
	local extent = type(v) == "table" and Safe.Value(v.extent)
	if type(extent) ~= "number" or extent <= 1 then return nil end
	return math.ceil(extent)
end

-- Can't move or resize Blizzard's list right now? Only in combat, and only if the game protects
-- it: frames it protects can't be moved by addons mid-fight. Its friends list isn't protected,
-- so it normally follows straight away, even in combat. (Waiting for every fight to end left
-- the list at the height of an empty list when the window was opened in combat after a
-- /reload: Favorites and Friends vanished until the fight was over.)
local function Locked()
	if not Safe.InCombat() then return false end
	for _, frame in ipairs({ list.ScrollBox, list.ScrollBar }) do
		if frame then
			local ok, protected = pcall(frame.IsProtected, frame)
			if not ok or protected then return true end
		end
	end
	return false
end

local lastTop, lastExtent
-- Blizzard's list right under our group, as tall as its content; our scroll box follows
local function SyncHeights()
	if not engaged then return end
	if Locked() then pending = true return end
	local extent = BlizzardExtent() or math.ceil(viewport:GetHeight())
	local box = list.ScrollBox
	if lastTop ~= sectionHeight then
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -sectionHeight)
		box:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -sectionHeight)
		lastTop = sectionHeight
	end
	if lastExtent ~= extent then
		box:SetHeight(extent)
		lastExtent = extent
	end
	content:SetHeight(sectionHeight + extent)
	viewport:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately)
end

-- Blizzard's list changed (friends, a group collapsed, search): its height follows, a moment later
local syncQueued
local function SyncSoon()
	if not engaged or syncQueued then return end
	syncQueued = true
	C_Timer.After(0, function()
		syncQueued = nil
		local ok, err = pcall(SyncHeights)
		if not ok then ns.Debug("social section: %s", tostring(err)) end
	end)
end

-- moves Blizzard's list into our scroll box (and its scroll bar out of sight)
local function Engage()
	if engaged then return true end
	if Locked() then pending = true return false end
	local box, bar = list.ScrollBox, list.ScrollBar
	original.boxParent, original.boxLevel = box:GetParent(), box:GetFrameLevel()
	original.boxWheel = box:IsMouseWheelEnabled()
	if bar then original.barParent, original.barLevel = bar:GetParent(), bar:GetFrameLevel() end
	box:SetParent(content)
	box:EnableMouseWheel(false)   -- the wheel goes to our scroll box, which scrolls both
	if bar then bar:SetParent(holder) end
	lastTop, lastExtent = nil, nil
	viewport:Show()
	viewportBar:Show()
	engaged = true
	return true
end

-- puts Blizzard's list and scroll bar back exactly as they were
local function Disengage()
	if not engaged then
		if viewport then viewport:Hide() viewportBar:Hide() end
		return
	end
	if Locked() then pending = true return end
	local box, bar = list.ScrollBox, list.ScrollBar
	box:SetParent(original.boxParent or list)
	if original.boxLevel then box:SetFrameLevel(original.boxLevel) end
	box:EnableMouseWheel(original.boxWheel ~= false)
	Shift(box, 0)
	if bar then
		bar:SetParent(original.barParent or list)
		if original.barLevel then bar:SetFrameLevel(original.barLevel) end
		Shift(bar, 0, box)
	end
	viewport:Hide()
	viewportBar:Hide()
	engaged = false
end

-- our cards, one under the other below the header (the same places the scroll list gave them)
local function LayoutRows(keys, collapsed)
	local shown = collapsed and 0 or #keys
	for i = 1, shown do
		local row = rows[i]
		if not row then
			row = CreateFrame("Button", nil, section, ROW_TEMPLATE)
			rows[i] = row
		end
		local y = -(HEADER_GAP + (i - 1) * (ROW_HEIGHT + ROW_SPACING))
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, y)
		row:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, y)
		row:SetHeight(ROW_HEIGHT)
		InitRow(row, { key = keys[i] })
		row:Show()
	end
	for i = shown + 1, #rows do rows[i]:Hide() end
end

local function LayoutSingleScroll()
	if not SocialList.Enabled() then
		Disengage()
		return
	end
	local search = SearchText()
	local keys, online = SocialList.Keys(search)
	local collapsed = ns.db.settings.socialCollapsed and true or false
	-- (an empty list keeps its header, for the "+"; a search with no match hides it)
	sectionHeight = SocialList.SectionHeight(#keys, collapsed, search == "")
	if not Engage() then return end
	if sectionHeight > 0 then
		local text = L["Old Friends List %d/%d"]:format(online, #keys)
		if header.SetText then header:SetText(text) end
		if header.ButtonText then header.ButtonText:SetText(text) end
		SetCollapseIcon(collapsed)
		UI.UpdateStale(header.Stale)
		LayoutRows(keys, collapsed)
		section:SetHeight(sectionHeight)
		section:Show()
	else
		section:Hide()
	end
	SyncHeights()
end

-- redraws our group and fits Blizzard's list around it
function SocialList.Layout()
	if not (installed and section) then return end
	if SINGLE_SCROLL then LayoutSingleScroll() else LayoutTwoScrolls() end
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

	-- "+": add a character, next to the collapse sign. Quiet until the mouse is on it (like the
	-- gear in the separate window). Its own button: clicking it doesn't collapse the group.
	local add = CreateFrame("Button", nil, h)
	add:SetSize(18, 18)
	if h.CollapseButton then
		add:SetPoint("RIGHT", h.CollapseButton, "LEFT", -6, 0)
	elseif h.Fallback then
		add:SetPoint("RIGHT", h.Fallback, "LEFT", -6, 0)
	else
		add:SetPoint("RIGHT", h, "RIGHT", -30, 0)
	end
	local icon = add:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ns.ICON)   -- our own round icon (the minimap's): same art as the window's portrait, cut for small sizes
	icon:SetDesaturated(true)
	add:SetAlpha(0.5)
	add:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		icon:SetDesaturated(false)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Add a character"])
		GameTooltip:AddLine(L["Add a character to Old Friends List"], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	add:SetScript("OnLeave", function(self)
		self:SetAlpha(0.5)
		icon:SetDesaturated(true)
		GameTooltip:Hide()
	end)
	add:SetScript("OnClick", function() ns.Actions.AddPrompt() end)
	h.AddButton = add
	-- statuses may be out of date (in a dungeon...): the separate window's clock, left of the "+"
	h.Stale = UI.CreateStaleIcon(h, 16)
	h.Stale:SetPoint("RIGHT", add, "LEFT", -6, 0)
	h:SetScript("OnClick", function()
		ns.db.settings.socialCollapsed = not ns.db.settings.socialCollapsed
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		SocialList.Layout()
	end)
	return h
end

-- where Blizzard puts its scroll bar next to its list (BAR_X, BAR_TOP, BAR_BOTTOM), from its anchors
local function ReadBlizzardBar()
	for _, p in ipairs(saved[list.ScrollBar] or {}) do
		local point, relativeTo, relativePoint, x, y = p[1], p[2], p[3], p[4], p[5]
		if relativeTo == list.ScrollBox and point == "TOPLEFT" and relativePoint == "TOPRIGHT" then
			BAR_X, BAR_TOP = x or 0, y or 0
		elseif relativeTo == list.ScrollBox and point == "BOTTOMLEFT" and relativePoint == "BOTTOMRIGHT" then
			BAR_BOTTOM = y or 0
		end
	end
end

-- one scroll: our scroll box where Blizzard's list was, with our group at the top of what it scrolls
local function BuildSingleScroll()
	viewport = CreateFrame("Frame", nil, list, "WowScrollBox")
	for _, p in ipairs(saved[list.ScrollBox]) do viewport:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
	viewport:SetFrameLevel(list.ScrollBox:GetFrameLevel())
	viewport:EnableMouseWheel(true)

	-- the one thing it scrolls: our group, then Blizzard's list (moved in by Engage)
	content = CreateFrame("Frame", nil, viewport)
	content.scrollable = true
	content:SetHeight(1)

	section = CreateFrame("Frame", nil, content)
	section:SetPoint("TOPLEFT")
	section:SetPoint("TOPRIGHT")
	header = BuildHeader()
	-- one lit card at a time (UI.HoverTracker), checked every frame while the section shows
	local hoverPoll = CreateFrame("Frame", nil, section)
	hoverPoll:SetScript("OnUpdate", UI.HoverTracker(viewport, function(fn) for _, row in ipairs(rows) do fn(row) end end,
		UI.ShowFriendTooltip))

	-- the one scroll bar, exactly where Blizzard's own is (same offsets from the same place)
	viewportBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
	viewportBar:SetPoint("TOPLEFT", viewport, "TOPRIGHT", BAR_X, BAR_TOP)
	viewportBar:SetPoint("BOTTOMLEFT", viewport, "BOTTOMRIGHT", BAR_X, BAR_BOTTOM)

	local linear = CreateScrollBoxLinearView()
	if linear.SetPanExtent then linear:SetPanExtent(PAN_EXTENT) end
	ScrollUtil.InitScrollBoxWithScrollBar(viewport, viewportBar, linear)

	-- Blizzard's own scroll bar waits here, out of sight, while its list is in ours
	holder = CreateFrame("Frame", nil, list)
	holder:Hide()

	viewport:Hide()
	viewportBar:Hide()
	section:Hide()

	-- Blizzard's list changed (friends, a group collapsed, search): its height follows.
	-- (secure post-hooks: they run after Blizzard's code and don't change it)
	if type(list.ScrollBox.FullUpdateInternal) == "function" then
		hooksecurefunc(list.ScrollBox, "FullUpdateInternal", SyncSoon)
	end
	if type(list.Refresh) == "function" then hooksecurefunc(list, "Refresh", SyncSoon) end
end

-- two scrolls: our group (with its own scroll list) at the top, Blizzard's list moved down
local function BuildTwoScrolls()
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
	local hoverPoll = CreateFrame("Frame", nil, section)

	scrollBox = CreateFrame("Frame", nil, section, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	scrollBox:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)

	-- the scroll bar in Blizzard's scroll bar column: the section has the width and the top of
	-- Blizzard's list, so the same offsets from the section put it exactly where Blizzard's own
	-- would be. Its bottom follows our cards (the list's right edge is PAD_RIGHT in from the section's).
	scrollBar = CreateFrame("EventFrame", nil, section, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", section, "TOPRIGHT", BAR_X, BAR_TOP)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", BAR_X + PAD_RIGHT, BAR_BOTTOM)

	view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	if view.SetPadding then view:SetPadding(DOT_MARGIN, 0, DOT_MARGIN, 0, ROW_SPACING) end
	view:SetElementInitializer(ROW_TEMPLATE, InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	hoverPoll:SetScript("OnUpdate", UI.HoverTracker(scrollBox, function(fn) scrollBox:ForEachFrame(fn) end,
		UI.ShowFriendTooltip))

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
		ReadBlizzardBar()
		if SINGLE_SCROLL then BuildSingleScroll() else BuildTwoScrolls() end
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
		if list then
			if engaged then pcall(Disengage) end
			pcall(MoveBlizzardList, 0)
		end
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
-- Battle.net friends came, went or changed character (the "hide duplicates" option)
ns.Listen("BNET_CHANGED", OnDataChanged)
-- checks paused or back (a dungeon...): the clock on the header
ns.Listen("PAUSE_CHANGED", OnDataChanged)
-- the invite buttons depend on your group (who's in it, who leads it)
ns.On("GROUP_ROSTER_UPDATE", OnDataChanged)
ns.On("PARTY_LEADER_CHANGED", OnDataChanged)
-- the game's text size changed (Options, Accessibility): the status dots follow, like Blizzard's
if EventRegistry and EventRegistry.RegisterCallback then
	pcall(EventRegistry.RegisterCallback, EventRegistry, "TextSizeManager.OnTextScaleUpdated", OnDataChanged, SocialList)
end

-- one scroll: what had to wait for the end of combat (moving or resizing Blizzard's list)
ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		pending = nil
		SocialList.Refresh()
	end
end)

ns.Listen("LOGIN", function()
	Install()
	-- the Social window may only be created the first time it opens
	if ToggleFriendsFrame then hooksecurefunc("ToggleFriendsFrame", Install) end
end)
ns.On("ADDON_LOADED", function() Install() end)

-- for /ofl diag
function SocialList.Info()
	local state = installed and "installed" or failed and "failed" or "waiting for the Social window"
	local layout = SINGLE_SCROLL and ("one scroll, Blizzard's list inside: %s, its height %s"):format(
		tostring(engaged and true or false), tostring(list and list.ScrollBox and BlizzardExtent())) or "two scrolls"
	return ("Social window section: %s, mode %s, shown %s, %s"):format(state, tostring(ns.db and ns.db.settings.socialMode),
		tostring(section and section:IsShown()), layout)
end
