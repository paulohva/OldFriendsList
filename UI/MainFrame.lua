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
-- "Statuses may be out of date" (1.0.3): a small clock next to the online count, here and on
-- the group header in the Social window, while the game doesn't let the addon check anyone
-- (in a dungeon, raid, battleground...). Not in combat: that pause lasts seconds.
--------------------------------------------------------------------------------

local STALE_ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"

-- why statuses may be out of date right now (a reason Presence gives), or nil
function UI.StaleReason()
	local reason = Presence.PausedReason()
	if reason == "in combat" then
		-- (a fight in a dungeon is still a dungeon: keep the clock)
		return Safe.InInstance() and "in an instance" or nil
	end
	return reason
end

-- the clock, with its tooltip; shown and hidden by UI.UpdateStale
function UI.CreateStaleIcon(parent, size)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(size or 14, size or 14)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(STALE_ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- (without the icon's border)
	b:SetAlpha(0.8)
	b:EnableMouse(true)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Statuses may be out of date"])
		local reason = UI.StaleReason()
		GameTooltip:AddLine(L["The game doesn't let the addon check your friends right now (%s). They're checked again as soon as it does."]
			:format(reason and L[reason] or "?"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	return b
end

function UI.UpdateStale(icon)
	if icon then icon:SetShown(UI.StaleReason() ~= nil) end
end

--------------------------------------------------------------------------------
-- Actions (also used by the slash commands)
--------------------------------------------------------------------------------

local Actions = {}
ns.Actions = Actions

--------------------------------------------------------------------------------
-- Whispers (1.1.1). The game's own "open a whisper" (ChatFrameUtil.SendTell / SendBNetTell),
-- called by an addon, leaves the chat's globals (ACTIVE_CHAT_EDIT_BOX, LAST_ACTIVE_CHAT_EDIT_BOX,
-- CHAT_FOCUS_OVERRIDE) tainted until /reload. Blizzard's Social window then reads them when you
-- whisper from its own cards, its protected SearchFriends() gets blocked and its list empties.
-- Tested in game (taintLog, /ofl diag): opening the chat's input box ourselves taints them too,
-- and a name link on our cards was unreliable. What stays clean: a line in chat with the name as
-- a link. Clicking it is the game's own whisper, exactly like clicking a name in chat.
--------------------------------------------------------------------------------

local function ChatLine(text)
	local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
	DEFAULT_CHAT_FRAME:AddMessage(text, info and info.r or 1, info and info.g or 1, info and info.b or 0)
end

function Actions.Whisper(key)
	local name = Data.Display(key)
	ChatLine(L["Click the name to whisper: %s"]:format(("|Hplayer:%s|h[%s]|h"):format(name, name)))
end

--------------------------------------------------------------------------------
-- Link layers (1.1.1): a frame made from Blizzard's own InlineHyperlinkFrameTemplate, over a
-- name or a button. Its click script comes from the template (SetItemRef(link, text, button),
-- no chat window needed), so a click on its link runs only the game's code: the whisper opens
-- straight away and the chat stays clean. We never set its click script: a script set by an
-- addon runs as the addon's code. Only the hover is ours.
--------------------------------------------------------------------------------

local LINK_PAD = (" "):rep(60)

-- the link around `text`, padded with spaces inside it so the whole line (or button) takes clicks;
-- centred: spaces on both sides
local function LinkText(target, text, centred)
	return ("|H%s|h%s%s%s|h"):format(target, centred and LINK_PAD or "", text, LINK_PAD)
end

function UI.PlayerLinkText(name, text, centred)
	return LinkText("player:" .. name, text or name, centred)
end

-- the game's Battle.net name link (name:id:line:type:target, as the chat writes it), or nil
function UI.BNetLinkText(entry, text, centred)
	local name, id = entry and entry.accountName, entry and tonumber(entry.bnetAccountID)
	if type(name) ~= "string" or not id then return nil end
	return LinkText(("BNplayer:%s:%d:0:BN_WHISPER:%s"):format(name, id, name), text or name, centred)
end

local linkTemplateOK
-- a link layer over `region` of `owner`, or nil when the template isn't there. `hover`: the
-- layer keeps the owner highlighted while the mouse is on it (for a lone button; list rows
-- get theirs from UI.HoverTracker)
function UI.CreateLinkLayer(owner, region, fontObject, centred, hover)
	local ok, layer = pcall(CreateFrame, "Frame", nil, owner, "InlineHyperlinkFrameTemplate")
	linkTemplateOK = ok and layer ~= nil
	if not linkTemplateOK then return nil end
	layer:SetAllPoints(region)
	layer:SetFrameLevel(owner:GetFrameLevel() + 2)
	layer:EnableMouse(true)
	-- (a click on the link is the link's only: the owner under it doesn't get it too)
	if layer.SetPropagateMouseClicks then pcall(layer.SetPropagateMouseClicks, layer, false) end
	-- (the template's hover shows the link in a tooltip: not for player links)
	layer:SetScript("OnHyperlinkEnter", nil)
	layer:SetScript("OnHyperlinkLeave", nil)
	if hover and owner.LockHighlight then
		layer:SetScript("OnEnter", function() owner:LockHighlight() end)
		layer:SetScript("OnLeave", function() owner:UnlockHighlight() end)
	end
	local text = layer:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormalLarge")
	text:SetPoint(centred and "CENTER" or "LEFT")
	text:SetJustifyH(centred and "CENTER" or "LEFT")
	text:SetWordWrap(false)
	layer.Text = text
	return layer
end

-- Double-click to whisper, clean: the first click (ours) lays an invisible link over the whole
-- owner for a moment; the second click lands on it, and the game opens the whisper itself.
-- `linkText`: UI.PlayerLinkText / UI.BNetLinkText with "" as the text. False when it can't (no
-- template, or no link): the caller then does the whisper its own way.
local ARM_TIME = 0.5   -- seconds: about a double-click
function UI.ArmWhisper(owner, linkText)
	if not linkText then return false end
	if owner.ArmLayer == nil then owner.ArmLayer = UI.CreateLinkLayer(owner, owner, nil, true) or false end
	local layer = owner.ArmLayer
	if not layer then return false end
	-- (big letters: the link's spaces then fill the owner's height too, and all of it takes the click)
	local font = layer.Text:GetFont()
	if font then layer.Text:SetFont(font, math.max(12, math.min(64, math.floor(owner:GetHeight())))) end
	layer.Text:SetText(linkText)
	layer:Show()
	local armedAt = GetTime()
	layer.armedAt = armedAt
	C_Timer.After(ARM_TIME, function()
		if layer.armedAt == armedAt then layer:Hide() end
	end)
	return true
end

-- the invisible link for a friend (or a Battle.net friend who's only reachable through Battle.net)
function UI.WhisperLinkText(key, bnet)
	if bnet and not ns.BattleNet.Reachable(bnet) then return UI.BNetLinkText(bnet, "", true) end
	return key and UI.PlayerLinkText(Data.Display(key), "", true) or nil
end

-- One hovered row at a time, with its highlight and tooltip, read from the mouse's position
-- every frame (a link armed over a row takes the mouse from it: going by enter/leave events,
-- rows stayed lit). `area`: the list's visible part; `eachRow(fn)`: calls fn for each row;
-- `tooltip(row)`: shows the row's tooltip. Returns the OnUpdate function.
function UI.HoverTracker(area, eachRow, tooltip)
	local current
	return function()
		local found
		if area:IsVisible() and area:IsMouseOver() then
			eachRow(function(row)
				if not found and row:IsShown() and row:IsMouseOver() then found = row end
			end)
		end
		if found == current then return end
		if current then
			current:UnlockHighlight()
			if GameTooltip:IsOwned(current) then GameTooltip:Hide() end
		end
		current = found
		if found then
			found:LockHighlight()
			tooltip(found)
		end
	end
end

-- for /ofl diag
function UI.LinkInfo()
	if linkTemplateOK == nil then return "not used yet" end
	return linkTemplateOK and "InlineHyperlinkFrameTemplate" or "template missing"
end

function Actions.Invite(key)
	local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	if invite then invite(Data.Display(key)) end
end

-- a Battle.net whisper to a Battle.net friend (works across factions, realm types and regions):
-- the game's own Battle.net name link in chat, as it writes them ("BNplayer:name:id:...")
function Actions.WhisperBNet(entry)
	local name, id = entry and entry.accountName, entry and tonumber(entry.bnetAccountID)
	if type(name) ~= "string" or not id then return end
	local link = ("|HBNplayer:%s:%d:0:BN_WHISPER:%s|h[%s]|h"):format(name, id, name, name)
	ChatLine(L["Click the name for a Battle.net whisper: %s"]:format(link))
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

-- whisper by name, invite, Who, add: not on the other faction, another realm type nor in another region
local function Reachable(entry)
	return ns.BattleNet.Reachable(entry)
end

-- why only a Battle.net whisper reaches them: "Other region" / the other faction's name /
-- the realm type ("PvE"), or nil
local function FarReason(entry)
	if entry.otherRegion then return L["Other region"] end
	if not ns.BattleNet.SameFaction(entry) then return FactionName(entry.faction) end
	if not Data.SameRealmType(entry.realmType) then return Data.RealmTypeName(entry.realmType) end
	return nil
end

-- the character, then the BattleTag without its number in Battle.net blue ("Moletom#1851" -> "Moletom")
local function BNetNameText(entry)
	local c = Data.ClassColor(entry.class)
	local name = (c and c.WrapTextInColorCode) and c:WrapTextInColorCode(entry.key) or entry.key
	local tag = ns.BattleNet.ShortTag(entry)
	return tag and (name .. "  " .. BNET_COLOR .. tag .. "|r") or name
end

local function BNetInfoLine(entry)
	local who = Data.LevelClass(entry)
	local line = (who and entry.zone) and (who .. " - " .. entry.zone) or who or entry.zone or L["Online"]
	local far = FarReason(entry)
	if far then line = line .. " (" .. far .. ")" end
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
	local far = FarReason(entry)
	if far then GameTooltip:AddLine(far, 1, 0.3, 0.3) end
	if entry.battleTag then GameTooltip:AddLine(L["Battle.net friend: %s"]:format(entry.battleTag), 0.51, 0.77, 1) end
	GameTooltip:AddLine(" ")
	local hint = L["Double-click to whisper, right-click for options."]
	if entry.otherRegion then
		hint = L["Other region: double-click for a Battle.net whisper."]
	elseif not ns.BattleNet.SameFaction(entry) then
		hint = L["Other faction: double-click for a Battle.net whisper."]
	elseif far then
		hint = L["%s realm: double-click for a Battle.net whisper."]:format(far)
	end
	GameTooltip:AddLine(hint, 0.5, 0.5, 0.5, true)
	GameTooltip:Show()
end

local function OpenBNetMenu(row)
	local entry = row.bnet
	if not (entry and MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(entry.key)
		if Reachable(entry) then
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

-- whisper the selected row: by name, or through Battle.net for the other faction / region
local function WhisperSelected()
	-- (a click on the button's link already opened the whisper)
	local layer = whisperButton and whisperButton.LinkLayer
	if layer and layer:IsShown() and layer:IsMouseOver() then return end
	if selectedBNet and not Reachable(selectedBNet) then
		Actions.WhisperBNet(selectedBNet)
	elseif selectedKey then
		Actions.Whisper(selectedKey)
	end
end

-- the link over the Whisper button (UI.CreateLinkLayer) points at the selected friend: a click
-- opens the whisper with the game's own code. Hidden while the button is disabled.
local function UpdateWhisperLink()
	local layer = whisperButton and whisperButton.LinkLayer
	if not layer then return end
	local text
	if whisperButton:IsEnabled() then
		local label = G("WHISPER", "Whisper")
		if selectedBNet and not Reachable(selectedBNet) then
			text = UI.BNetLinkText(selectedBNet, label, true)
		elseif selectedKey then
			text = UI.PlayerLinkText(Data.Display(selectedKey), label, true)
		end
	end
	layer.Text:SetText(text or "")
	layer:SetShown(text ~= nil)
	-- (the button's own label hides under the link's, which says the same)
	local label = whisperButton:GetFontString()
	if label then label:SetAlpha(text and 0 or 1) end
end

local function UpdateButtons()
	if not frame then return end
	if selectedBNet then
		whisperButton:SetEnabled(true)
		inviteButton:SetEnabled(Reachable(selectedBNet) and Actions.CanInvite(selectedKey, true) and true or false)
		removeButton:SetEnabled(false)
		UpdateWhisperLink()
		return
	end
	local has = selectedKey and Data.Has(selectedKey)
	whisperButton:SetEnabled(has and true or false)
	UpdateWhisperLink()
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
		-- double-click to whisper (1.1.1): the first click selects and arms an invisible link over
		-- the row, the second lands on it and the game opens the whisper (UI.ArmWhisper)
		row:SetScript("OnClick", function(self, button)
			SelectKey(self.key, self.bnet)
			if button == "RightButton" then
				if self.bnet then OpenBNetMenu(self) else OpenRowMenu(self) end
			else
				self.armed = UI.ArmWhisper(self, UI.WhisperLinkText(self.key, self.bnet))
			end
		end)
		row:SetScript("OnDoubleClick", function(self)
			-- (only when the link couldn't be armed: the "click the name" line in chat)
			if self.armed then return end
			if self.bnet and not Reachable(self.bnet) then Actions.WhisperBNet(self.bnet) else Actions.Whisper(self.key) end
		end)
		-- (highlight and tooltip: UI.HoverTracker, set up with the list)
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
		local entry = ns.db.settings.showBNet and ns.BattleNet.Shown(selectedKey)
		if entry and not Data.Has(selectedKey) then selectedBNet = entry else selectedKey, selectedBNet = nil, nil end
	elseif selectedKey and not Data.Has(selectedKey) then
		selectedKey = nil
	end

	local online, total = Data.CountOnline()
	onlineText:SetText(L["Online: |cffffffff%d|r / %d"]:format(online, total))
	frame.Stale:ClearAllPoints()
	frame.Stale:SetPoint("LEFT", onlineText, "LEFT", onlineText:GetStringWidth() + 6, 0)
	UI.UpdateStale(frame.Stale)
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
	onlineText:SetWordWrap(false)
	-- the clock goes right after the count ("Online: 3 / 7 ⏱")
	frame.Stale = UI.CreateStaleIcon(frame, 14)
	frame.Stale:SetPoint("LEFT", onlineText, "LEFT", 0, 0)

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
	-- one lit row at a time (UI.HoverTracker), checked every frame while the window is open
	local hoverPoll = CreateFrame("Frame", nil, frame)
	hoverPoll:SetScript("OnUpdate", UI.HoverTracker(scrollBox, function(fn) scrollBox:ForEachFrame(fn) end,
		function(row) if row.bnet then ShowBNetTooltip(row) else ShowTooltip(row) end end))

	emptyText = inset:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("CENTER", inset, "CENTER", 0, 20)
	emptyText:SetWidth(260)
	emptyText:SetText(L["No friends yet.\n\nClick |cffffd100%s|r, or right-click a player's portrait or name and choose |cffffd100%s|r."]:format(
		L["Add Friend"], L["Add to Old Friends List"]))

	local add = MakeButton(frame, L["Add Friend"], 82, Actions.AddPrompt)
	add:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
	whisperButton = MakeButton(frame, G("WHISPER", "Whisper"), 78, WhisperSelected)
	whisperButton:SetPoint("LEFT", add, "RIGHT", 2, 0)
	-- (without the template, the button itself writes the "click the name" line in chat)
	whisperButton.LinkLayer = UI.CreateLinkLayer(whisperButton, whisperButton, "GameFontNormal", true, true)
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
	-- closing the window clears the selection (1.1.4)
	frame:HookScript("OnHide", function() SelectKey(nil, nil) end)
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

