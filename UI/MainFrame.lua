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
local NO_FRIENDS_TEXT   -- the empty list's text (1.3.0: or "No friends online." with offline hidden)
local selectedKey
local selectedBNet    -- the Battle.net friend's entry, when the selected row is one (not on the list)
local BNET_COLOR = "|cff82c5ff"   -- Battle.net names, as the game colours them

--------------------------------------------------------------------------------
-- "Statuses may be out of date": a small clock next to the online count (here and on the Social
-- window's header) while the game blocks our checks (dungeon, raid, battleground; not combat).
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
-- Whispers. The game's SendTell / SendBNetTell (or opening the chat box) called by an addon leaves
-- the chat's globals tainted until /reload, and the Social window's protected SearchFriends() then
-- gets blocked. Clean: a name link, clicked like any name in chat.
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
-- Link layers: a frame from Blizzard's InlineHyperlinkFrameTemplate over a name or a button. Its
-- click script is the template's, so clicking the link runs only the game's code. Never set its
-- click script: one set by an addon runs as addon code.
--------------------------------------------------------------------------------

-- a player link's target ("player:Name")
function UI.PlayerLinkTarget(name)
	return name and ("player:" .. name) or nil
end

-- the game's Battle.net name link target (name:id:line:type:target, as the chat writes it), or nil
function UI.BNetLinkTarget(entry)
	local name, id = entry and entry.accountName, entry and tonumber(entry.bnetAccountID)
	if type(name) ~= "string" or not id then return nil end
	return ("BNplayer:%s:%d:0:BN_WHISPER:%s"):format(name, id, name)
end

-- Fills `layer` with a link to `target` showing `label`, padded with just enough spaces to cover
-- the layer's width (centred: both sides), so the link takes clicks there and nowhere else.
-- (Any frame with links works, e.g. a link button's own text.)
function UI.FillLink(holder, fontString, target, label, centred)
	label = label or ""
	local width = math.floor((holder:GetWidth() or 0) - (holder.linkInset or 0))
	-- (only when something changed: rewriting the link under the mouse made the button blink)
	if holder.linkTarget == target and holder.linkLabel == label and holder.linkWidth == width then return end
	holder.linkTarget, holder.linkLabel, holder.linkWidth = target, label, width
	-- measured on a text of its own, invisible: the width of a space (between two dots) and of
	-- the label, in the link's font
	local measure = holder.Measure
	if not measure then
		measure = holder:CreateFontString(nil, "BACKGROUND")
		measure:SetAlpha(0)
		holder.Measure = measure
	end
	measure:SetFontObject(fontString:GetFontObject())
	local font, size, flags = fontString:GetFont()
	if font then measure:SetFont(font, size, flags) end
	measure:SetText("..")
	local dots = measure:GetStringWidth() or 0
	measure:SetText("." .. (" "):rep(20) .. ".")
	local space = ((measure:GetStringWidth() or 0) - dots) / 20
	measure:SetText(label ~= "" and label or ".")
	local used = label ~= "" and (measure:GetStringWidth() or 0) or 0
	local free = width - used - 2
	local n = 0
	if space > 0 and free > 0 then n = math.min(200, math.floor(free / space / (centred and 2 or 1))) end
	local pad = (" "):rep(n)
	fontString:SetText(("|H%s|h%s%s%s|h"):format(target, centred and pad or "", label, pad))
end

-- fills a link layer (UI.CreateLinkLayer) with a link to `target`
function UI.SetLayerLink(layer, target, label, centred)
	UI.FillLink(layer, layer.Text, target, label, centred)
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
	-- (no SetPropagateMouseClicks: it's forbidden in combat, and building a layer mid-fight got blocked)
	-- (the template's hover shows the link in a tooltip: not for player links)
	layer:SetScript("OnHyperlinkEnter", nil)
	layer:SetScript("OnHyperlinkLeave", nil)
	if hover and owner.LockHighlight then
		layer:SetScript("OnEnter", function() owner:LockHighlight() end)
		-- (left for real only: checked a frame later, when the game has the mouse's new position)
		layer:SetScript("OnLeave", function()
			C_Timer.After(0, function()
				if not (owner:IsVisible() and owner:IsMouseOver()) then owner:UnlockHighlight() end
			end)
		end)
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
-- `target`: UI.WhisperLinkTarget. False when it can't (no template, or no link): the caller then
-- does the whisper its own way.
local ARM_TIME = 0.5   -- seconds: about a double-click
function UI.ArmWhisper(owner, target)
	if not target then return false end
	if owner.ArmLayer == nil then owner.ArmLayer = UI.CreateLinkLayer(owner, owner, nil, true) or false end
	local layer = owner.ArmLayer
	if not layer then return false end
	-- (big letters: the link's spaces then fill the owner's height too, and all of it takes the click)
	local font = layer.Text:GetFont()
	if font then layer.Text:SetFont(font, math.max(12, math.min(64, math.floor(owner:GetHeight())))) end
	layer:Show()
	UI.SetLayerLink(layer, target, "", true)
	local armedAt = GetTime()
	layer.armedAt = armedAt
	C_Timer.After(ARM_TIME, function()
		if layer.armedAt == armedAt then layer:Hide() end
	end)
	return true
end

-- the whisper link's target for a friend (or a Battle.net friend only reachable through Battle.net)
function UI.WhisperLinkTarget(key, bnet)
	if bnet and not ns.BattleNet.Reachable(bnet) then return UI.BNetLinkTarget(bnet) end
	return key and UI.PlayerLinkTarget(Data.Display(key)) or nil
end

-- One hovered row at a time (highlight + tooltip), read from the mouse's position rather than
-- enter/leave events (an armed link takes the mouse from the row). `area`: the list's visible
-- part; `eachRow(fn)`; `tooltip(row)`. Called with "hide": nothing lit, tooltip gone.
-- is the tooltip owned by something on the row under the mouse (its Invite button)? Only the row's
-- own children count: units in the world own it through UIParent, which is always under the mouse.
local function TooltipTakenBy(row)
	local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
	if not owner or owner == row or not (owner.IsMouseOver and owner:IsMouseOver()) then return false end
	local parent = owner.GetParent and owner:GetParent()
	for _ = 1, 4 do
		if parent == row then return true end
		parent = parent and parent.GetParent and parent:GetParent()
	end
	return false
end

-- A row's right-click menu covers the rows below it: while it's open, that row stays lit.
local openMenu, openMenuRow
function UI.MenuOpenedFor(row, menu)
	openMenu, openMenuRow = menu, row
end
local function MenuRow()
	if openMenu and openMenu:IsShown() and openMenuRow and openMenuRow:IsVisible() then return openMenuRow end
	openMenu, openMenuRow = nil, nil
	return nil
end

function UI.HoverTracker(area, eachRow, tooltip)
	local current
	return function(hide)
		local menuRow = hide ~= "hide" and MenuRow()
		if menuRow then
			-- a row's menu is open: keep that row lit (if it's ours), nothing else, no tooltip
			local ours
			eachRow(function(row) if row == menuRow then ours = true end end)
			local keep = ours and menuRow or nil
			if current ~= keep then
				if current then
					current:UnlockHighlight()
					if GameTooltip:IsOwned(current) then GameTooltip:Hide() end
				end
				current = keep
				if keep then keep:LockHighlight() end
			end
			if keep and GameTooltip:IsOwned(keep) then GameTooltip:Hide() end
			return
		end
		local found
		if hide ~= "hide" and area:IsVisible() and area:IsMouseOver() then
			eachRow(function(row)
				if not found and row:IsShown() and row:IsMouseOver() then found = row end
			end)
		end
		if found and found == current then
			-- still on the same row, but a button on it (Invite) hid the row's tooltip: show it again
			if not GameTooltip:IsOwned(found) and not TooltipTakenBy(found) then tooltip(found) end
			return
		end
		if found == current then return end
		if current then
			current:UnlockHighlight()
			if GameTooltip:IsOwned(current) then GameTooltip:Hide() end
		end
		current = found
		if found then
			found:LockHighlight()
			-- straight onto its Invite button: that button's tooltip stays
			if not TooltipTakenBy(found) then tooltip(found) end
		end
	end
end

-- runs fn every `interval` seconds while `frame` is visible
function UI.PollWhileShown(frame, interval, fn)
	local ticker
	local function Start()
		if not ticker then ticker = C_Timer.NewTicker(interval, fn) end
	end
	local function Stop()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
		-- (closed with Esc or the key: the row's tooltip goes now, not at the next mouse move)
		fn("hide")
	end
	frame:HookScript("OnShow", Start)
	frame:HookScript("OnHide", Stop)
	if frame:IsVisible() then Start() end
end
UI.HOVER_EVERY = 0.05   -- seconds: the eye can't tell from every frame

-- A link button doesn't sink when clicked: the click goes to its link and the template's
-- OnMouseDown/Up don't run. While the mouse is on it (`watch`), it sinks and rises with the left
-- button, using the template's own functions (and the pushed state, which moves the text).
local function PressSunk(button, sunk)
	if sunk == button.sunk then return end
	button.sunk = sunk
	if sunk then button:SetButtonState("PUSHED", true) else button:SetButtonState("NORMAL") end
	local fn = sunk and UIPanelButton_OnMouseDown or UIPanelButton_OnMouseUp
	if fn then fn(button) end
end

function UI.WatchPress(button, watch)
	if not watch then
		button:SetScript("OnUpdate", nil)
		PressSunk(button, false)
		return
	end
	button.wasDown = IsMouseButtonDown("LeftButton")   -- (held from elsewhere: not a press here)
	button.pressedHere = false
	button:SetScript("OnUpdate", function(self)
		local down = IsMouseButtonDown("LeftButton")
		if down and not self.wasDown then self.pressedHere = true end
		if not down then self.pressedHere = false end
		self.wasDown = down
		PressSunk(self, down and self.pressedHere and self:IsEnabled() and self:IsMouseOver() or false)
	end)
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
	local f = Data.Get(key)
	UI.ShowDialog({
		text = L["Set a note for %s:"]:format(Data.Display(key)),
		accept = G("ACCEPT", "Accept"), cancel = G("CANCEL", "Cancel"),
		editText = f and f.note or "", maxLetters = 120, wide = true,
		onAccept = function(text) Data.SetNote(key, text) end,
	})
end

function Actions.Remove(key)
	UI.ShowDialog({
		text = L["Remove %s from your Old Friends List?"]:format(Data.Display(key)),
		accept = G("YES", "Yes"), cancel = G("NO", "No"),
		onAccept = function()
			Data.Remove(key)
			if selectedKey == key then selectedKey = nil end
		end,
	})
end

function Actions.AddPrompt()
	UI.ShowDialog({
		text = L["Enter the first and last name of the character you want to add:"],
		accept = G("ADD", "Add"), cancel = G("CANCEL", "Cancel"),
		editText = "", maxLetters = 60,
		onAccept = function(text) Actions.AddByName(text) end,
	})
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
-- Our own dialog for Add / Note / Remove, with the game's look. Blizzard's shared popups
-- (StaticPopup_Show) get tainted by an addon, and the game reuses them for protected things
-- (release spirit, invites...), which were then blocked and blamed on us.
--------------------------------------------------------------------------------

local dialog

local function DialogButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(128, 21)
	for _, part in ipairs({ { "SetNormalTexture", "Up" }, { "SetPushedTexture", "Down" },
			{ "SetDisabledTexture", "Disabled" }, { "SetHighlightTexture", "Highlight" } }) do
		b[part[1]](b, "Interface\\Buttons\\UI-DialogBox-Button-" .. part[2])
	end
	for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[get](b)
		if t then t:SetTexCoord(0, 1, 0, 0.71875) end
	end
	local highlight = b:GetHighlightTexture()
	if highlight then highlight:SetBlendMode("ADD") end
	b:SetNormalFontObject("GameFontNormal")
	b:SetHighlightFontObject("GameFontHighlight")
	b:SetDisabledFontObject("GameFontDisable")
	b:SetScript("OnClick", onClick)
	return b
end

local function BuildDialog()
	local d = CreateFrame("Frame", "OldFriendsListDialog", UIParent)
	d:SetSize(320, 100)
	d:SetPoint("TOP", UIParent, "TOP", 0, -135)
	d:SetFrameStrata("DIALOG")
	d:SetToplevel(true)
	d:EnableMouse(true)
	-- the game's dialog look; a plain dark panel if its border template isn't there
	local ok, border = pcall(CreateFrame, "Frame", nil, d, "DialogBorderDarkTemplate")
	if ok and border then
		border:SetAllPoints()
	else
		local bg = d:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.85)
	end

	d.Text = d:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	d.Text:SetPoint("TOP", d, "TOP", 0, -16)
	d.Text:SetWidth(290)

	d.EditBox = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
	d.EditBox:SetSize(240, 32)
	d.EditBox:SetPoint("TOP", d.Text, "BOTTOM", 0, -6)
	d.EditBox:SetAutoFocus(false)
	d.EditBox:SetScript("OnEnterPressed", function() d.Accept() end)
	d.EditBox:SetScript("OnEscapePressed", function() d:Hide() end)

	d.Button1 = DialogButton(d, function() d.Accept() end)
	d.Button1:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 16)
	d.Button2 = DialogButton(d, function() d:Hide() end)
	d.Button2:SetPoint("BOTTOMLEFT", d, "BOTTOM", 6, 16)

	-- Esc closes it, like the game's dialogs
	tinsert(UISpecialFrames, "OldFriendsListDialog")
	d:Hide()
	return d
end

-- o: text, accept, cancel (button texts; no cancel: one button, centred); editText (nil: no edit
-- box), maxLetters, wide; onAccept(text) (text: the edit box's, when there is one); copy: the box
-- only holds editText to copy (typing doesn't change it; Ctrl+C copies and closes)
function UI.ShowDialog(o)
	dialog = dialog or BuildDialog()
	local d = dialog
	d:Hide()
	d.Text:SetText(o.text)
	d.Button1:SetText(o.accept)
	d.Button2:SetText(o.cancel or "")
	d.Button2:SetShown(o.cancel ~= nil)
	d.Button1:ClearAllPoints()
	if o.cancel then
		d.Button1:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 16)
	else
		d.Button1:SetPoint("BOTTOM", d, "BOTTOM", 0, 16)
	end
	local box = d.EditBox
	if o.copy then
		box:SetScript("OnTextChanged", function(self, userInput)
			if userInput then
				self:SetText(o.editText)
				self:HighlightText()
			end
		end)
		box:SetScript("OnKeyDown", function(_, key)
			-- (closed a frame later: the copy happens first)
			if key == "C" and IsControlKeyDown() then C_Timer.After(0, function() d:Hide() end) end
		end)
	else
		box:SetScript("OnTextChanged", nil)
		box:SetScript("OnKeyDown", nil)
	end
	local hasBox = o.editText ~= nil
	d.EditBox:SetShown(hasBox)
	d.EditBox:SetWidth(o.wide and 270 or 240)
	d:SetHeight(16 + d.Text:GetStringHeight() + (hasBox and 44 or 12) + 16 + 21 + 8)
	d.Accept = function()
		local text = hasBox and d.EditBox:GetText() or nil
		d:Hide()
		o.onAccept(text)
	end
	d:Show()
	if hasBox then
		d.EditBox:SetMaxLetters(o.maxLetters or 0)
		d.EditBox:SetText(o.editText)
		d.EditBox:SetFocus()
		d.EditBox:HighlightText()
	end
end

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
	-- "Last online 3 hours ago", in Blizzard's words (Data.LastOnline)
	return GREY .. prefix .. Data.LastOnline(f.lastSeen) .. "|r"
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
	-- (short, like Blizzard's: online, the zone; offline, "Last online ..."; the note)
	if online then
		if f.lastZone then GameTooltip:AddLine(f.lastZone, 1, 1, 1) end
	else
		GameTooltip:AddLine(Data.status[key] == nil and L["Checking..."] or Data.LastOnline(f.lastSeen), 0.6, 0.6, 0.6)
	end
	if f.note then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(f.note, 1, 0.82, 0, true)
	end
	GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Invite to Guild. Only Blizzard's own interface may call C_GuildInfo.Invite: an addon is
-- blocked, and so are macros, secure buttons and text an addon writes into the chat box. The
-- game's /ginvite, pasted and sent by you, is the game's own code. The clipboard is closed to
-- addons too (CopyToClipboard): a window shows "/ginvite Name" selected, and Ctrl+C copies it.
--------------------------------------------------------------------------------

function Actions.GuildInvite(key)
	local name = Data.Display(key)
	UI.ShowDialog({
		text = L["To invite %s to your guild, press Ctrl+C to copy the command and paste it in the chat (Enter, Ctrl+V, Enter)."]:format(name),
		accept = G("CLOSE", "Close"),
		editText = "/ginvite " .. name, wide = true, copy = true,
		onAccept = function() end,
	})
end

-- Invite to Guild: only with a rank that can invite, and not for someone already in the guild;
-- greyed out while they're offline (the invite needs them online)
local function AddGuildInvite(root, key, online)
	if not ns.Guild.CanInvite() or ns.Guild.IsMember(key) then return end
	local item = root:CreateButton(L["Invite to Guild"], function() Actions.GuildInvite(key) end)
	if not online and item and item.SetEnabled then item:SetEnabled(false) end
end

--------------------------------------------------------------------------------
-- Whisper from a menu, clean like the double-click: while the menu is open, a link layer of ours
-- (UI.CreateLinkLayer) lies over its Whisper item, and the click lands on the link: the game
-- opens the whisper itself. Without the link template, the item's own click (Actions.Whisper).
--------------------------------------------------------------------------------

local menuLink        -- { holder, layer }; false when the template isn't there
local menuLinkItem    -- the menu item's frame it lies over
local menuLinkTarget

local function CloseMenus()
	local manager = Menu and Menu.GetManager and Menu.GetManager()
	if manager and manager.CloseMenus then manager:CloseMenus() end
end

local function MenuLink()
	if menuLink ~= nil then return menuLink end
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetFrameStrata("TOOLTIP")
	holder:SetSize(1, 1)
	holder:Hide()
	local layer = UI.CreateLinkLayer(holder, holder, "GameFontNormal")
	if not layer then menuLink = false return false end
	local pressed, propagating
	holder:SetScript("OnUpdate", function(self)
		local down = IsMouseButtonDown("LeftButton")
		if down and layer:IsMouseOver() then pressed = true end
		if pressed and not down then
			-- the click went to the link (the game opened the whisper): the menu closes
			pressed = nil
			C_Timer.After(0, CloseMenus)
		end
		local item = menuLinkItem
		local l, b, w, h
		if item and item:IsVisible() then l, b, w, h = item:GetRect() end
		if l and w and w > 0 then
			local s = item:GetEffectiveScale() / UIParent:GetEffectiveScale()
			self:ClearAllPoints()
			self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * s, b * s)
			self:SetSize(w * s, h * s)
			-- (the mouse's movement goes on to the item under it, for its highlight; out of combat only)
			if not propagating and layer.SetPropagateMouseMotion and not InCombatLockdown() then
				layer:SetPropagateMouseMotion(true)
				propagating = true
			end
			-- (big letters: the link's spaces then fill the item's height too, as UI.ArmWhisper does)
			local height = math.floor(h * s)
			if height ~= self.fontHeight then
				self.fontHeight = height
				local font = layer.Text:GetFont()
				if font then layer.Text:SetFont(font, math.max(10, math.min(64, height))) end
				layer.linkWidth = nil
			end
			UI.SetLayerLink(layer, menuLinkTarget, "")
		elseif not down then
			-- (the menu is gone; kept while the button is down, so a click under way still lands)
			menuLinkItem, pressed = nil, nil
			self:Hide()
		end
	end)
	menuLink = { holder = holder, layer = layer }
	return menuLink
end

-- a Whisper item in a menu: `target` (UI.WhisperLinkTarget / UI.BNetLinkTarget) for the link,
-- `fallback` for the item's own click
local function AddWhisper(root, label, target, fallback)
	local item = root:CreateButton(label, fallback)
	local link = target and MenuLink()
	if not (link and item and item.AddInitializer) then return end
	item:AddInitializer(function(frame)
		menuLinkItem, menuLinkTarget = frame, target
		link.holder:Show()
	end)
end

local function OpenRowMenu(row)
	local key = row.key
	if not (key and MenuUtil and MenuUtil.CreateContextMenu) then return end
	local menu = MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(Data.Display(key))
		AddWhisper(root, G("WHISPER", "Whisper"), UI.WhisperLinkTarget(key), function() Actions.Whisper(key) end)
		root:CreateButton(G("INVITE", "Invite"), function() Actions.Invite(key) end)
		AddGuildInvite(root, key, Data.status[key] == "online")
		root:CreateButton(G("WHO", "Who"), function() Actions.Who(key) end)
		root:CreateButton(G("SET_NOTE", "Set Note"), function() Actions.SetNote(key) end)
		root:CreateDivider()
		root:CreateButton(G("REMOVE_FRIEND", "Remove Friend"), function() Actions.Remove(key) end)
	end)
	UI.MenuOpenedFor(row, menu)
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
	-- (no "double-click to whisper" hint, like Blizzard's; only for Battle.net whispers)
	local hint
	if entry.otherRegion then
		hint = L["Other region: double-click for a Battle.net whisper."]
	elseif not ns.BattleNet.SameFaction(entry) then
		hint = L["Other faction: double-click for a Battle.net whisper."]
	elseif far then
		hint = L["%s realm: double-click for a Battle.net whisper."]:format(far)
	end
	if hint then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(hint, 0.5, 0.5, 0.5, true)
	end
	GameTooltip:Show()
end

local function OpenBNetMenu(row)
	local entry = row.bnet
	if not (entry and MenuUtil and MenuUtil.CreateContextMenu) then return end
	local menu = MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(entry.key)
		if Reachable(entry) then
			AddWhisper(root, G("WHISPER", "Whisper"), UI.WhisperLinkTarget(entry.key), function() Actions.Whisper(entry.key) end)
			root:CreateButton(G("INVITE", "Invite"), function() Actions.Invite(entry.key) end)
			AddGuildInvite(root, entry.key, true)
			root:CreateButton(G("WHO", "Who"), function() Actions.Who(entry.key) end)
			root:CreateDivider()
			root:CreateButton(L["Add to Old Friends List"], function()
				Actions.AddByName(entry.key, { class = entry.class, level = entry.level, faction = entry.faction })
			end)
		else
			AddWhisper(root, L["Battle.net whisper"], UI.BNetLinkTarget(entry), function() Actions.WhisperBNet(entry) end)
		end
	end)
	UI.MenuOpenedFor(row, menu)
end

-- whisper the selected row: by name, or through Battle.net for the other faction / region (the
-- Whisper button's way only when it isn't a link button: see UpdateWhisperLink)
local function WhisperSelected()
	if selectedBNet and not Reachable(selectedBNet) then
		Actions.WhisperBNet(selectedBNet)
	elseif selectedKey then
		Actions.Whisper(selectedKey)
	end
end

-- The Whisper button is itself a link button (UIPanelButtonTemplate + InlineHyperlinkFrameTemplate):
-- its text links to the selected friend, so a click opens the whisper with the game's own code.
local function UpdateWhisperLink()
	if not (whisperButton and whisperButton.isLinkButton) then return end
	local label = G("WHISPER", "Whisper")
	local target = whisperButton:IsEnabled() and UI.WhisperLinkTarget(selectedKey, selectedBNet) or nil
	if target then
		UI.FillLink(whisperButton, whisperButton:GetFontString(), target, label, true)
	else
		whisperButton.linkTarget = nil   -- (so the next friend's link is written again)
		whisperButton:SetText(label)
	end
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
		-- double-click to whisper: the first click selects and arms a link over the row (UI.ArmWhisper)
		row:SetScript("OnClick", function(self, button)
			SelectKey(self.key, self.bnet)
			if button == "RightButton" then
				if self.bnet then OpenBNetMenu(self) else OpenRowMenu(self) end
			else
				self.armed = UI.ArmWhisper(self, UI.WhisperLinkTarget(self.key, self.bnet))
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

-- what the list shows: online first (Battle.net friends not on the list too, with that option),
-- then offline friends (unless they're hidden)
function UI.Items()
	local online, offline = {}, {}
	local showOffline = ns.db.settings.showOffline ~= false
	for _, key in ipairs(Data.Sorted()) do
		if Data.status[key] == "online" then
			online[#online + 1] = { key = key }
		elseif showOffline then
			offline[#offline + 1] = { key = key }
		end
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
	elseif selectedKey and ns.db.settings.showOffline == false and Data.status[selectedKey] ~= "online" then
		-- (went offline with offline friends hidden: gone from the list, so not selected either)
		selectedKey = nil
	end

	local online, total = Data.CountOnline()
	onlineText:SetText(L["Online: |cffffffff%d|r / %d"]:format(online, total))
	frame.Stale:ClearAllPoints()
	frame.Stale:SetPoint("LEFT", onlineText, "LEFT", onlineText:GetStringWidth() + 6, 0)
	UI.UpdateStale(frame.Stale)
	-- empty: no friends at all, or (offline hidden) none online
	emptyText:SetText(total == 0 and NO_FRIENDS_TEXT or L["No friends online."])
	emptyText:SetShown(#items == 0)
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
	-- the controller's cursor reads scroll boxes, and ours taints it: it skips the list
	ns.HideFromController(scrollBox)
	ns.HideFromController(scrollBar)
	-- one lit row at a time (UI.HoverTracker), checked 20 times a second while the window is open
	UI.PollWhileShown(frame, UI.HOVER_EVERY, UI.HoverTracker(scrollBox, function(fn) scrollBox:ForEachFrame(fn) end,
		function(row) if row.bnet then ShowBNetTooltip(row) else ShowTooltip(row) end end))

	emptyText = inset:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("CENTER", inset, "CENTER", 0, 20)
	emptyText:SetWidth(260)
	NO_FRIENDS_TEXT = L["No friends yet.\n\nClick |cffffd100%s|r, or right-click a player's portrait or name and choose |cffffd100%s|r."]:format(
		L["Add Friend"], L["Add to Old Friends List"])
	emptyText:SetText(NO_FRIENDS_TEXT)

	local add = MakeButton(frame, L["Add Friend"], 82, Actions.AddPrompt)
	add:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
	-- (a link button: see UpdateWhisperLink; a plain one if the link template isn't there)
	local ok, linkButton = pcall(CreateFrame, "Button", nil, frame, "UIPanelButtonTemplate, InlineHyperlinkFrameTemplate")
	if ok and linkButton then
		whisperButton = linkButton
		whisperButton:SetSize(78, 22)
		whisperButton:SetText(G("WHISPER", "Whisper"))
		whisperButton.isLinkButton = true
		whisperButton.linkInset = 6   -- (the button's rounded ends)
		-- (no link tooltip; no OnClick: a click on the link is the game's, and anything of ours
		-- on the same click would run as addon code)
		whisperButton:SetScript("OnHyperlinkEnter", nil)
		whisperButton:SetScript("OnHyperlinkLeave", nil)
		-- its highlight by the mouse's position: over the link's letters the mouse passes between the
		-- button and the link, and the game's own highlight blinked
		UI.PollWhileShown(frame, UI.HOVER_EVERY, function(hide)
			local over = hide ~= "hide" and whisperButton:IsVisible() and whisperButton:IsEnabled()
				and whisperButton:IsMouseOver() or false
			if over == whisperButton.lit then return end
			whisperButton.lit = over
			if over then whisperButton:LockHighlight() else whisperButton:UnlockHighlight() end
			UI.WatchPress(whisperButton, over)
		end)
	else
		whisperButton = MakeButton(frame, G("WHISPER", "Whisper"), 78, WhisperSelected)
	end
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
		ns.ApplyControllerHiding()   -- (the controller interface may have been turned on since)
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
	-- closing the window clears the selection
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

