--------------------------------------------------------------------------------
-- The window: a Blizzard-style friends list of characters
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data, Presence = ns.Safe, ns.Data, ns.Presence

local UI = {}
ns.UI = UI

local ICON = ns.ICON
local ONLINE_ICON = "Interface\\FriendsFrame\\StatusIcon-Online"
local OFFLINE_ICON = "Interface\\FriendsFrame\\StatusIcon-Offline"
local ROW_HEIGHT = 34
local GREY = "|cff808080"

local frame, scrollBox, dataProvider, onlineText, emptyText
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
		ns.Print("Added %s.", Data.Display(key))
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
	text = "Enter the first and last name of the character you want to add:",
	button1 = ADD or "Add",
	button2 = CANCEL or "Cancel",
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
	text = "Set a note for %s:",
	button1 = ACCEPT or "Accept",
	button2 = CANCEL or "Cancel",
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
	text = "Remove %s from your Old Friends List?",
	button1 = YES or "Yes",
	button2 = NO or "No",
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
	local parts = {}
	if f.level then parts[#parts + 1] = "Level " .. f.level end
	local className = Data.ClassName(f.class)
	if className then parts[#parts + 1] = className end
	local who = table.concat(parts, " ")
	if online then
		local zone = f.lastZone
		if who ~= "" and zone then return who .. " - " .. zone end
		return (who ~= "" and who) or zone or "Online"
	end
	local status = Data.status[key] == nil and "Checking..." or "Offline"
	return GREY .. status .. " - last seen " .. Data.Ago(f.lastSeen) .. "|r"
end

local function ShowTooltip(row)
	local key = row.key
	local f = key and Data.Get(key)
	if not f then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local c = Data.ClassColor(f.class)
	GameTooltip:AddLine(Data.Display(key), c and c.r or 1, c and c.g or 0.82, c and c.b or 0)
	local online = Data.status[key] == "online"
	local desc = {}
	if f.level then desc[#desc + 1] = "Level " .. f.level end
	if f.class then desc[#desc + 1] = Data.ClassName(f.class) end
	if #desc > 0 then GameTooltip:AddLine(table.concat(desc, " "), 1, 1, 1) end
	if online then
		GameTooltip:AddLine("Online", 0.1, 1, 0.1)
		if f.lastZone then GameTooltip:AddLine(f.lastZone, 1, 1, 1) end
	else
		GameTooltip:AddLine(Data.status[key] == nil and "Checking..." or "Offline", 0.6, 0.6, 0.6)
		GameTooltip:AddLine("Last seen " .. Data.Ago(f.lastSeen), 0.6, 0.6, 0.6)
		if f.lastZone then GameTooltip:AddLine("Last zone: " .. f.lastZone, 0.6, 0.6, 0.6) end
	end
	if f.note then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(f.note, 1, 0.82, 0, true)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Double-click to whisper, right-click for options.", 0.5, 0.5, 0.5, true)
	GameTooltip:Show()
end

local function OpenRowMenu(row)
	local key = row.key
	if not (key and MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(Data.Display(key))
		root:CreateButton("Whisper", function() Actions.Whisper(key) end)
		root:CreateButton("Invite", function() Actions.Invite(key) end)
		root:CreateButton("Who", function() Actions.Who(key) end)
		root:CreateButton("Set Note", function() Actions.SetNote(key) end)
		root:CreateDivider()
		root:CreateButton("Remove Friend", function() Actions.Remove(key) end)
	end)
end

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
	local name = Data.Display(key)
	local c = online and Data.ClassColor(f.class)
	if c and c.WrapTextInColorCode then
		row.Name:SetText(c:WrapTextInColorCode(name))
	elseif online then
		row.Name:SetText(name)
	else
		row.Name:SetText(GREY .. name .. "|r")
	end
	row.Info:SetText(InfoLine(key, f))
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
	dataProvider = CreateDataProvider(items)
	scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
	if selectedKey and not Data.Has(selectedKey) then selectedKey = nil end

	local online, total = Data.CountOnline()
	local text = ("Online: |cffffffff%d|r / %d"):format(online, total)
	local paused = Presence.PausedReason()
	if paused then text = text .. GREY .. "  (checks paused: " .. paused .. ")|r" end
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
		GameTooltip:AddLine("Settings")
		local key = ns.Options and ns.Options.KeyText()
		GameTooltip:AddLine(key and ("Notifications, key binding (" .. key .. ") and more.") or "Notifications, key binding and more.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", function(self)
		self:SetAlpha(0.45)
		gearIcon:SetDesaturated(true)
		GameTooltip:Hide()
	end)
	gear:SetScript("OnClick", function()
		if not (ns.Options and ns.Options.Open()) then ns.Print("The options panel isn't available; type /ofl help.") end
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

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("OldFriendsListRowTemplate", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	emptyText = inset:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("CENTER", inset, "CENTER", 0, 20)
	emptyText:SetWidth(260)
	emptyText:SetText("No friends yet.\n\nClick |cffffd100Add Friend|r, or right-click a player's portrait or name and choose |cffffd100Add to Old Friends|r.")

	local add = MakeButton(frame, "Add Friend", 82, Actions.AddPrompt)
	add:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
	whisperButton = MakeButton(frame, WHISPER or "Whisper", 78, function()
		if selectedKey then Actions.Whisper(selectedKey) end
	end)
	whisperButton:SetPoint("LEFT", add, "RIGHT", 2, 0)
	inviteButton = MakeButton(frame, "Invite", 78, function()
		if selectedKey then Actions.Invite(selectedKey) end
	end)
	inviteButton:SetPoint("LEFT", whisperButton, "RIGHT", 2, 0)
	removeButton = MakeButton(frame, REMOVE or "Remove", 78, function()
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
BINDING_NAME_OLDFRIENDSLIST_TOGGLE = "Toggle Old Friends List"

function OldFriendsList_Toggle() UI.Toggle() end

function OldFriendsList_OnAddonCompartmentClick() UI.Toggle() end

function OldFriendsList_OnAddonCompartmentEnter(_, owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:AddLine(ns.NAME)
	local online, total = Data.CountOnline()
	GameTooltip:AddLine(("%d of %d online"):format(online, total), 1, 1, 1)
	GameTooltip:AddLine("Click to open.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

function OldFriendsList_OnAddonCompartmentLeave() GameTooltip:Hide() end

ns.Listen("LOGIN", function()
	if not FriendsFrame then return end
	local b = CreateFrame("Button", nil, FriendsFrame, "UIPanelButtonTemplate")
	b:SetSize(104, 22)
	b:SetText("Old Friends")
	b:SetPoint("TOPRIGHT", FriendsFrame, "BOTTOMRIGHT", 0, 2)
	b:SetScript("OnClick", UI.Toggle)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(ns.NAME)
		GameTooltip:AddLine("Your list of characters, the classic way.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end)
