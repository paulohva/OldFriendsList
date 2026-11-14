--------------------------------------------------------------------------------
-- The window: a Blizzard-style friends list of characters
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data, Presence, L, G = ns.Safe, ns.Data, ns.Presence, ns.L, ns.G

local UI = {}
ns.UI = UI

local ICON = ns.ICON
local ONLINE_ICON = "Interface\\FriendsFrame\\StatusIcon-Online"
local OFFLINE_ICON = "Interface\\FriendsFrame\\StatusIcon-Offline"
local ROW_HEIGHT = 34          -- name + level/zone line
local ROW_HEIGHT_COMPACT = 22  -- name only ("Show level and zone" off)
local GREY = "|cff808080"

local frame, scrollBox, listView, dataProvider, onlineText, emptyText
local whisperButton, inviteButton, removeButton
local selectedKey

--------------------------------------------------------------------------------
-- Actions (also used by the slash commands)
--------------------------------------------------------------------------------

local Actions = {}
ns.Actions = Actions

function Actions.Whisper(key)
	local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
	if tell then tell(Data.Display(key)) end
end

function Actions.Invite(key)
	local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	if invite then invite(Data.Display(key)) end
end

function Actions.Who(key)
	Presence.Who(key)
end

function Actions.SetNote(key)
	StaticPopup_Show("OLDFRIENDSLIST_SET_NOTE", Data.Display(key), nil, key)
end

function Actions.Remove(key)
	StaticPopup_Show("OLDFRIENDSLIST_REMOVE", Data.Display(key), nil, key)
end

function Actions.AddPrompt()
	StaticPopup_Show("OLDFRIENDSLIST_ADD")
end

function Actions.AddByName(text)
	local key, err = Data.Add(text)
	if key then
		ns.Print(L["Added %s."], Data.Display(key))
		selectedKey = key
	else
		ns.Print(err)
	end
	return key
end

--------------------------------------------------------------------------------
-- Popups
--------------------------------------------------------------------------------

local function EditBoxOf(dialog)
	return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end

StaticPopupDialogs.OLDFRIENDSLIST_ADD = {
	text = L["Enter the first and last name of the character you want to add:"],
	button1 = G("ADD", "Add"),
	button2 = G("CANCEL", "Cancel"),
	hasEditBox = true,
	maxLetters = 60,
	OnShow = function(self)
		local box = EditBoxOf(self)
		if box then box:SetText("") box:SetFocus() end
	end,
	OnAccept = function(self)
		local box = EditBoxOf(self)
		if box then Actions.AddByName(box:GetText()) end
	end,
	EditBoxOnEnterPressed = function(box)
		Actions.AddByName(box:GetText())
		box:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.OLDFRIENDSLIST_SET_NOTE = {
	text = L["Set a note for %s:"],
	button1 = G("ACCEPT", "Accept"),
	button2 = G("CANCEL", "Cancel"),
	hasEditBox = true,
	maxLetters = 120,
	editBoxWidth = 260,
	OnShow = function(self, key)
		local box = EditBoxOf(self)
		local f = Data.Get(key)
		if box then box:SetText(f and f.note or "") box:SetFocus() box:HighlightText() end
	end,
	OnAccept = function(self, key)
		local box = EditBoxOf(self)
		if box then Data.SetNote(key, box:GetText()) end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		Data.SetNote(dialog.data, box:GetText())
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.OLDFRIENDSLIST_REMOVE = {
	text = L["Remove %s from your Old Friends List?"],
	button1 = G("YES", "Yes"),
	button2 = G("NO", "No"),
	OnAccept = function(_, key)
		Data.Remove(key)
		if selectedKey == key then selectedKey = nil end
	end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function InfoLine(key, f)
	local online = Data.status[key] == "online"
	local who = Data.LevelClass(f)
	local prefix = who and (who .. " - ") or ""
	if online then
		local zone = f.lastZone
		if who and zone then return who .. " - " .. zone end
		return who or zone or L["Online"]
	end
	-- offline: the last known level and class, like the classic list
	if Data.status[key] == nil then
		return GREY .. prefix .. L["Checking..."] .. "|r"
	end
	local ago = Data.Ago(f.lastSeen)
	return GREY .. prefix .. (ago and L["Offline, last seen %s"]:format(ago) or L["Offline"]) .. "|r"
end

local function ShowTooltip(row)
	local key = row.key
	local f = key and Data.Get(key)
	if not f then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local c = Data.ClassColor(f.class)
	GameTooltip:AddLine(Data.Display(key), c and c.r or 1, c and c.g or 0.82, c and c.b or 0)
	local online = Data.status[key] == "online"
	local who = Data.LevelClass(f)
	if who then GameTooltip:AddLine(who, 1, 1, 1) end
	if online then
		GameTooltip:AddLine(L["Online"], 0.1, 1, 0.1)
		if f.lastZone then GameTooltip:AddLine(f.lastZone, 1, 1, 1) end
	else
		GameTooltip:AddLine(Data.status[key] == nil and L["Checking..."] or L["Offline"], 0.6, 0.6, 0.6)
		local ago = Data.Ago(f.lastSeen)
		if ago then GameTooltip:AddLine(L["Last seen %s"]:format(ago), 0.6, 0.6, 0.6) end
		if f.lastZone then GameTooltip:AddLine(L["Last zone: %s"]:format(f.lastZone), 0.6, 0.6, 0.6) end
	end
	if f.note then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(f.note, 1, 0.82, 0, true)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Double-click to whisper, right-click for options."], 0.5, 0.5, 0.5, true)
	GameTooltip:Show()
end

local function OpenRowMenu(row)
	local key = row.key
	if not (key and MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(Data.Display(key))
		root:CreateButton(G("WHISPER", "Whisper"), function() Actions.Whisper(key) end)
		root:CreateButton(G("INVITE", "Invite"), function() Actions.Invite(key) end)
		root:CreateButton(G("WHO", "Who"), function() Actions.Who(key) end)
		root:CreateButton(G("SET_NOTE", "Set Note"), function() Actions.SetNote(key) end)
		root:CreateDivider()
		root:CreateButton(G("REMOVE_FRIEND", "Remove Friend"), function() Actions.Remove(key) end)
	end)
end

-- the name as shown in a list: class color (option) when online, grey when offline
local function NameText(key, f)
	local name = Data.Display(key)
	local online = Data.status[key] == "online"
	local c = online and Data.ClassColor(f.class)
	if c and c.WrapTextInColorCode then return c:WrapTextInColorCode(name) end
	if online then return name end
	return GREY .. name .. "|r"
end

-- shared with the group in the game's Social window (UI/SocialList.lua): any frame with a .key
UI.InfoLine, UI.NameText, UI.ShowFriendTooltip, UI.OpenFriendMenu = InfoLine, NameText, ShowTooltip, OpenRowMenu

local function UpdateButtons()
	if not frame then return end
	local has = selectedKey and Data.Has(selectedKey)
	local online = has and Data.status[selectedKey] == "online"
	whisperButton:SetEnabled(has and true or false)
	inviteButton:SetEnabled(online and true or false)
	removeButton:SetEnabled(has and true or false)
end

local function SelectKey(key)
	selectedKey = key
	if scrollBox then
		scrollBox:ForEachFrame(function(row) row.Selected:SetShown(row.key == selectedKey) end)
	end
	UpdateButtons()
end

local function InitRow(row, elementData)
	local key = elementData.key
	row.key = key
	local f = Data.Get(key)
	if not f then return end
	if not row.oflSetUp then
		row.oflSetUp = true
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(self, button)
			SelectKey(self.key)
			if button == "RightButton" then OpenRowMenu(self) end
		end)
		row:SetScript("OnDoubleClick", function(self) Actions.Whisper(self.key) end)
		row:SetScript("OnEnter", ShowTooltip)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	local online = Data.status[key] == "online"
	row.Status:SetTexture(online and ONLINE_ICON or OFFLINE_ICON)
	row.Name:SetText(NameText(key, f))
	local details = ns.db.settings.showDetails
	row.Info:SetShown(details)
	if details then row.Info:SetText(InfoLine(key, f)) end
	row.NoteIcon:SetShown(f.note ~= nil)
	row.Selected:SetShown(key == selectedKey)
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

function UI.Refresh()
	if not (frame and frame:IsShown()) then return end
	local items = {}
	for _, key in ipairs(Data.Sorted()) do items[#items + 1] = { key = key } end
	listView:SetElementExtent(ns.db.settings.showDetails and ROW_HEIGHT or ROW_HEIGHT_COMPACT)
	dataProvider = CreateDataProvider(items)
	scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
	if selectedKey and not Data.Has(selectedKey) then selectedKey = nil end

	local online, total = Data.CountOnline()
	local text = L["Online: |cffffffff%d|r / %d"]:format(online, total)
	local paused = Presence.PausedReason()
	if paused then text = text .. GREY .. "  (" .. L["checks paused: %s"]:format(L[paused]) .. ")|r" end
	onlineText:SetText(text)
	emptyText:SetShown(total == 0)
	UpdateButtons()
end

ns.Listen("FRIENDS_CHANGED", UI.Refresh)
ns.Listen("STATUS_CHANGED", UI.Refresh)
ns.Listen("PAUSE_CHANGED", UI.Refresh)

--------------------------------------------------------------------------------
-- Building the frame
--------------------------------------------------------------------------------

local function MakeButton(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function SavePosition()
	local point, _, relPoint, x, y = frame:GetPoint(1)
	ns.db.settings.position = { point, relPoint, x, y }
end

local function Build()
	frame = CreateFrame("Frame", "OldFriendsListFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(338, 460)
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePosition() end)

	local pos = ns.db.settings.position
	if pos then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 380, -116)
	end

	if frame.SetTitle then frame:SetTitle(ns.NAME)
	elseif frame.TitleText then frame.TitleText:SetText(ns.NAME) end
	if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, ICON) end

	-- a small, quiet gear: opens Options > AddOns > Old Friends List
	local gear = CreateFrame("Button", nil, frame)
	gear:SetSize(16, 16)
	gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -35)
	local gearIcon = gear:CreateTexture(nil, "ARTWORK")
	gearIcon:SetAllPoints()
	if not (gearIcon.SetAtlas and pcall(gearIcon.SetAtlas, gearIcon, "QuestLog-icon-setting")) then
		gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	end
	gearIcon:SetDesaturated(true)
	gear:SetAlpha(0.45)
	gear:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		gearIcon:SetDesaturated(false)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(G("SETTINGS", "Settings"))
		local key = ns.Options and ns.Options.KeyText()
		GameTooltip:AddLine(key and L["Notifications, key binding (%s) and more."]:format(key) or L["Notifications, key binding and more."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", function(self)
		self:SetAlpha(0.45)
		gearIcon:SetDesaturated(true)
		GameTooltip:Hide()
	end)
	gear:SetScript("OnClick", function()
		if not (ns.Options and ns.Options.Open()) then ns.Print(L["The options panel isn't available; type /ofl help."]) end
	end)

	onlineText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	onlineText:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -36)
	onlineText:SetPoint("TOPRIGHT", gear, "TOPLEFT", -6, -1)
	onlineText:SetJustifyH("LEFT")

	local inset = frame.Inset or frame
	scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -20, 4)
	local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, -2)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 2)

	listView = CreateScrollBoxListLinearView()
	listView:SetElementExtent(ns.db.settings.showDetails and ROW_HEIGHT or ROW_HEIGHT_COMPACT)
	listView:SetElementInitializer("OldFriendsListRowTemplate", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, listView)

	emptyText = inset:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("CENTER", inset, "CENTER", 0, 20)
	emptyText:SetWidth(260)
	emptyText:SetText(L["No friends yet.\n\nClick |cffffd100%s|r, or right-click a player's portrait or name and choose |cffffd100%s|r."]:format(
		L["Add Friend"], L["Add to Old Friends"]))

	local add = MakeButton(frame, L["Add Friend"], 82, Actions.AddPrompt)
	add:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
	whisperButton = MakeButton(frame, G("WHISPER", "Whisper"), 78, function()
		if selectedKey then Actions.Whisper(selectedKey) end
	end)
	whisperButton:SetPoint("LEFT", add, "RIGHT", 2, 0)
	inviteButton = MakeButton(frame, G("INVITE", "Invite"), 78, function()
		if selectedKey then Actions.Invite(selectedKey) end
	end)
	inviteButton:SetPoint("LEFT", whisperButton, "RIGHT", 2, 0)
	removeButton = MakeButton(frame, G("REMOVE", "Remove"), 78, function()
		if selectedKey then Actions.Remove(selectedKey) end
	end)
	removeButton:SetPoint("LEFT", inviteButton, "RIGHT", 2, 0)

	-- keep the "last seen" times fresh while open
	local ticker
	frame:SetScript("OnShow", function()
		UI.Refresh()
		ticker = C_Timer.NewTicker(30, UI.Refresh)
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
	end)
	frame:SetScript("OnHide", function()
		if ticker then ticker:Cancel() ticker = nil end
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end
	end)

	-- The template's close button goes through HideUIPanel, which is protected in combat
	-- (the window then can't be closed). Hide it directly instead.
	local close = frame.CloseButton or _G["OldFriendsListFrameCloseButton"]
	if close then close:SetScript("OnClick", function() frame:Hide() end) end

	tinsert(UISpecialFrames, "OldFriendsListFrame")
	frame:Hide()
end

function UI.Toggle()
	if not ns.db then return end
	if not frame then Build() end
	frame:SetShown(not frame:IsShown())
end

function UI.Show()
	if not frame then Build() end
	frame:Show()
end

--------------------------------------------------------------------------------
-- Entry points: keybinding, addon compartment, a button on Blizzard's Friends window
--------------------------------------------------------------------------------

BINDING_HEADER_OLDFRIENDSLIST = ns.NAME
BINDING_NAME_OLDFRIENDSLIST_TOGGLE = L["Toggle Old Friends List"]

function OldFriendsList_Toggle() UI.Toggle() end

function OldFriendsList_OnAddonCompartmentClick() UI.Toggle() end

function OldFriendsList_OnAddonCompartmentEnter(_, owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:AddLine(ns.NAME)
	local online, total = Data.CountOnline()
	GameTooltip:AddLine(L["%d of %d online"]:format(online, total), 1, 1, 1)
	GameTooltip:AddLine(L["Click to open."], 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

function OldFriendsList_OnAddonCompartmentLeave() GameTooltip:Hide() end

