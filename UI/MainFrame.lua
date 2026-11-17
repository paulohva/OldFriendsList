--------------------------------------------------------------------------------
-- The window: a Blizzard-style friends list of characters
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data, Presence, L, G = ns.Safe, ns.Data, ns.Presence, ns.L, ns.G

local UI = {}
ns.UI = UI

local PORTRAIT = ns.PORTRAIT
local ONLINE_ICON = "Interface\\FriendsFrame\\StatusIcon-Online"
local OFFLINE_ICON = "Interface\\FriendsFrame\\StatusIcon-Offline"
local ROW_HEIGHT = 34          -- name + level/zone line
local ROW_HEIGHT_COMPACT = 22  -- name only ("Show level and zone" off)
local GREY = "|cff808080"

local frame, scrollBox, listView, dataProvider, onlineText, emptyText
local whisperButton, inviteButton, removeButton
local selectedKey
local selectedBNet    -- the Battle.net friend's entry, when the selected row is one (not on the list)
local BNET_COLOR = "|cff82c5ff"   -- Battle.net names, as the game colours them

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

-- a Battle.net whisper to a Battle.net friend (works across factions)
function Actions.WhisperBNet(entry)
	local name = entry and entry.accountName
	local tell = (ChatFrameUtil and ChatFrameUtil.SendBNetTell) or ChatFrame_SendBNetTell
	if name and tell then tell(name) end
end

-- can you invite this friend right now? true; or false, why (a tooltip line) and a short reason
-- ("offline", "ingroup", "notleader", "full"). `online`: given for Battle.net friends (not on
-- the list), else read from the list.
function Actions.CanInvite(key, online)
	if online == nil then online = Data.status[key] == "online" end
	if not online then return false, L["Offline"], "offline" end
	if Presence.InGroup(key) then return false, L["Already in your group."], "ingroup" end
	if Safe.Call(IsInGroup) then
		local raid = Safe.Call(IsInRaid)
		local leader = Safe.Call(UnitIsGroupLeader, "player")
		local assistant = raid and Safe.Call(UnitIsGroupAssistant, "player")
		if not (leader or assistant) then
			return false, G("ERR_NOT_LEADER", L["Only the group leader can invite."]), "notleader"
		end
		if (Safe.Call(GetNumGroupMembers) or 0) >= (raid and 40 or 5) then
			return false, G("ERR_GROUP_FULL", L["Your group is full."]), "full"
		end
	end
	return true
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

-- info: class, level, faction when known (e.g. from a Battle.net friend's game)
function Actions.AddByName(text, info)
	local key, err = Data.Add(text, info)
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

--------------------------------------------------------------------------------
-- Battle.net friends' rows (separate window, "Show Battle.net friends playing WoW"): always
-- online; on your faction they work like Old Friends, on the other one only a Battle.net whisper
--------------------------------------------------------------------------------

local function FactionName(faction)
	if faction == "Alliance" then return G("FACTION_ALLIANCE", "Alliance") end
	if faction == "Horde" then return G("FACTION_HORDE", "Horde") end
	return tostring(faction)
end

local function SameFaction(entry)
	return ns.BattleNet.SameFaction(entry)
end

-- the character, then the BattleTag without its number in Battle.net blue ("Moletom#1851" -> "Moletom")
local function BNetNameText(entry)
	local c = Data.ClassColor(entry.class)
	local name = (c and c.WrapTextInColorCode) and c:WrapTextInColorCode(entry.key) or entry.key
	local tag = type(entry.battleTag) == "string" and entry.battleTag:match("^[^#]+")
	return tag and (name .. "  " .. BNET_COLOR .. tag .. "|r") or name
end

local function BNetInfoLine(entry)
	local who = Data.LevelClass(entry)
	local line = (who and entry.zone) and (who .. " - " .. entry.zone) or who or entry.zone or L["Online"]
	if not SameFaction(entry) then line = line .. " (" .. FactionName(entry.faction) .. ")" end
	return line
end

local function ShowBNetTooltip(row)
	local entry = row.bnet
	if not entry then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local c = Data.ClassColor(entry.class)
	GameTooltip:AddLine(entry.key, c and c.r or 1, c and c.g or 0.82, c and c.b or 0)
	local who = Data.LevelClass(entry)
	if who then GameTooltip:AddLine(who, 1, 1, 1) end
	if entry.zone then GameTooltip:AddLine(entry.zone, 1, 1, 1) end
	if not SameFaction(entry) then GameTooltip:AddLine(FactionName(entry.faction), 1, 0.3, 0.3) end
	if entry.battleTag then GameTooltip:AddLine(L["Battle.net friend: %s"]:format(entry.battleTag), 0.51, 0.77, 1) end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(SameFaction(entry) and L["Double-click to whisper, right-click for options."]
		or L["Other faction: double-click for a Battle.net whisper."], 0.5, 0.5, 0.5, true)
	GameTooltip:Show()
end

local function OpenBNetMenu(row)
	local entry = row.bnet
	if not (entry and MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(entry.key)
		if SameFaction(entry) then
			root:CreateButton(G("WHISPER", "Whisper"), function() Actions.Whisper(entry.key) end)
			root:CreateButton(G("INVITE", "Invite"), function() Actions.Invite(entry.key) end)
			root:CreateButton(G("WHO", "Who"), function() Actions.Who(entry.key) end)
			root:CreateDivider()
			root:CreateButton(L["Add to Old Friends List"], function()
				Actions.AddByName(entry.key, { class = entry.class, level = entry.level, faction = entry.faction })
			end)
		else
			root:CreateButton(L["Battle.net whisper"], function() Actions.WhisperBNet(entry) end)
		end
	end)
end

-- whisper the selected row: by name, or through Battle.net for the other faction
local function WhisperSelected()
	if selectedBNet and not SameFaction(selectedBNet) then
		Actions.WhisperBNet(selectedBNet)
	elseif selectedKey then
		Actions.Whisper(selectedKey)
	end
end

local function UpdateButtons()
	if not frame then return end
	if selectedBNet then
		whisperButton:SetEnabled(true)
		inviteButton:SetEnabled(SameFaction(selectedBNet) and Actions.CanInvite(selectedKey, true) and true or false)
		removeButton:SetEnabled(false)
		return
	end
	local has = selectedKey and Data.Has(selectedKey)
	whisperButton:SetEnabled(has and true or false)
	inviteButton:SetEnabled(has and Actions.CanInvite(selectedKey) and true or false)
	removeButton:SetEnabled(has and true or false)
end

local function SelectKey(key, bnet)
	selectedKey, selectedBNet = key, bnet
	if scrollBox then
		scrollBox:ForEachFrame(function(row) row.Selected:SetShown(row.key == selectedKey) end)
	end
	UpdateButtons()
end

local function InitRow(row, elementData)
	local key, bnet = elementData.key, elementData.bnet
	row.key, row.bnet = key, bnet
	if not row.oflSetUp then
		row.oflSetUp = true
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(self, button)
			SelectKey(self.key, self.bnet)
			if button == "RightButton" then
				if self.bnet then OpenBNetMenu(self) else OpenRowMenu(self) end
			end
		end)
		row:SetScript("OnDoubleClick", function(self)
			if self.bnet and not SameFaction(self.bnet) then Actions.WhisperBNet(self.bnet) else Actions.Whisper(self.key) end
		end)
		row:SetScript("OnEnter", function(self)
			if self.bnet then ShowBNetTooltip(self) else ShowTooltip(self) end
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	local details = ns.db.settings.showDetails
	row.Info:SetShown(details)
	row.Selected:SetShown(key == selectedKey)
	if bnet then
		row.Status:SetTexture(ONLINE_ICON)
		row.Name:SetText(BNetNameText(bnet))
		if details then row.Info:SetText(BNetInfoLine(bnet)) end
		row.NoteIcon:Hide()
		return
	end
	local f = Data.Get(key)
	if not f then return end
	local online = Data.status[key] == "online"
	row.Status:SetTexture(online and ONLINE_ICON or OFFLINE_ICON)
	row.Name:SetText(NameText(key, f))
	local details = ns.db.settings.showDetails
	row.Info:SetShown(details)
	if details then row.Info:SetText(InfoLine(key, f)) end
	row.NoteIcon:SetShown(f.note ~= nil)
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

-- what the list shows: online first (Old Friends and, with the option on, Battle.net friends
-- not on the list, together by name), then offline Old Friends
function UI.Items()
	local online, offline = {}, {}
	for _, key in ipairs(Data.Sorted()) do
		local t = Data.status[key] == "online" and online or offline
		t[#t + 1] = { key = key }
	end
	local bnet = 0
	if ns.db.settings.showBNet and ns.BattleNet then
		for _, entry in ipairs(ns.BattleNet.Others()) do
			online[#online + 1] = { key = entry.key, bnet = entry }
			bnet = bnet + 1
		end
		table.sort(online, function(a, b) return a.key < b.key end)
	end
	for _, item in ipairs(offline) do online[#online + 1] = item end
	return online, bnet
end

function UI.Refresh()
	if not (frame and frame:IsShown()) then return end
	local items, bnetCount = UI.Items()
	listView:SetElementExtent(ns.db.settings.showDetails and ROW_HEIGHT or ROW_HEIGHT_COMPACT)
	dataProvider = CreateDataProvider(items)
	scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
	-- the selection is gone from the list (or the Battle.net friend left, or was added to it)
	if selectedBNet then
		local entry = ns.db.settings.showBNet and ns.BattleNet.Get(selectedKey)
		if entry and not Data.Has(selectedKey) then selectedBNet = entry else selectedKey, selectedBNet = nil, nil end
	elseif selectedKey and not Data.Has(selectedKey) then
		selectedKey = nil
	end

	local online, total = Data.CountOnline()
	local text = L["Online: |cffffffff%d|r / %d"]:format(online, total)
	local paused = Presence.PausedReason()
	if paused then text = text .. GREY .. "  (" .. L["checks paused: %s"]:format(L[paused]) .. ")|r" end
	onlineText:SetText(text)
	emptyText:SetShown(total == 0 and bnetCount == 0)
	UpdateButtons()
end

ns.Listen("FRIENDS_CHANGED", UI.Refresh)
ns.Listen("STATUS_CHANGED", UI.Refresh)
ns.Listen("PAUSE_CHANGED", UI.Refresh)
ns.Listen("BNET_CHANGED", UI.Refresh)
-- the Invite button depends on your group
ns.On("GROUP_ROSTER_UPDATE", UpdateButtons)
ns.On("PARTY_LEADER_CHANGED", UpdateButtons)

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
	if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, PORTRAIT) end

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
		L["Add Friend"], L["Add to Old Friends List"]))

	local add = MakeButton(frame, L["Add Friend"], 82, Actions.AddPrompt)
	add:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
	whisperButton = MakeButton(frame, G("WHISPER", "Whisper"), 78, WhisperSelected)
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

