--------------------------------------------------------------------------------
-- First-time setup: how to see your Old Friends.
--  * "In the Social window (O)": a group above Favorites in the game's friends window
--    (Shift-O still opens the separate window);
--  * "Separate window": our own window with Shift-O, optionally swapping keys so O opens
--    Old Friends List and Shift-O the game's Social window.
-- Shown once, a few seconds after the first login with 0.3.0 (closing it keeps the separate
-- window). Again with /ofl setup or the button in the options.
--------------------------------------------------------------------------------

local _, ns = ...
local L, Safe = ns.L, ns.Safe

local Setup = {}
ns.Setup = Setup

local IMAGE_INTEGRATED = "Interface\\AddOns\\OldFriendsList\\Media\\SetupIntegrated"
local IMAGE_SEPARATE = "Interface\\AddOns\\OldFriendsList\\Media\\SetupSeparate"
-- the pictures are 4:3 screenshots, 384x288 (24-bit): the whole texture is the picture
-- (PICTURE_U, PICTURE_V: how much of the texture is the picture, if it ever sits in a bigger one)
local PICTURE_SHAPE = 3 / 4
local PICTURE_U, PICTURE_V = 1, 1
local FRAME_HEIGHT = 508
local CARDS_TOP, CARDS_MARGIN = 110, 16
local CARD_WIDTH = 290
local CARD_HEIGHT = FRAME_HEIGHT - CARDS_TOP - CARDS_MARGIN   -- the cards go down to the frame's bottom margin

local frame, cards, swapCheck, bnetCheck, duplicatesCheck

-- the options under each card's text, above its button (from the bottom: 46, then 72)
local CHECK_LOW, CHECK_HIGH = 46, 72

local function Done()
	ns.db.settings.setupDone = true
	ns.db.settings.setupFromUpdate = nil
end

local function Choose(mode)
	if Safe.InCombat() then return end   -- (the buttons are off in combat; just in case)
	Done()
	local Options = ns.Options
	if mode == "integrated" then
		ns.db.settings.hideBNetDuplicates = duplicatesCheck and duplicatesCheck:GetChecked() and true or false
		Options.SetMode("integrated")
		if ns.SocialList then ns.SocialList.Refresh() end
		-- O is where the friends are now: give it back to the Social window if it was swapped
		if Options.IsSwapped() then Options.ApplySwap(false) end
		ns.Print(L["Old Friends List now appears in the Social window (O). Shift-O still opens the separate window."])
	else
		local wasSeparate = ns.db.settings.socialMode ~= "integrated"
		local wantBNet = bnetCheck and bnetCheck:GetChecked() and true or false
		local bnetChanged = wantBNet ~= (ns.db.settings.showBNet and true or false)
		ns.db.settings.showBNet = wantBNet
		-- Battle.net friends in this window: their logins and logouts are announced too
		-- (the Social window choice leaves that option as it is: on by default)
		if wantBNet then ns.db.settings.notifyBNet = true end
		if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
		Options.SetMode("separate")
		local wantSwap = swapCheck and swapCheck:GetChecked() and true or false
		local swapChanged = wantSwap ~= Options.IsSwapped()
		if swapChanged then Options.ApplySwap(wantSwap) end
		if wasSeparate and not swapChanged and not bnetChanged then
			ns.Print(L["Nothing changed: Old Friends List keeps its own window (%s)."], Options.KeyText() or "/ofl")
		else
			ns.Print(L["Old Friends List opens in its own window (%s)."], Options.KeyText() or "/ofl")
		end
	end
	ns.db.settings.setupFromUpdate = nil
	frame:Hide()
end

local function MakeCard(parent, image, title, text, mode)
	local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	card:SetSize(CARD_WIDTH, CARD_HEIGHT)

	-- (spacing kept tight so two options fit between the text and the button)
	local picture = card:CreateTexture(nil, "ARTWORK")
	picture:SetSize(CARD_WIDTH - 24, (CARD_WIDTH - 24) * PICTURE_SHAPE)
	picture:SetPoint("TOP", card, "TOP", 0, -10)
	picture:SetTexture(image)
	picture:SetTexCoord(0, PICTURE_U, 0, PICTURE_V)

	local titleText = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleText:SetPoint("TOP", picture, "BOTTOM", 0, -8)
	titleText:SetText(title)

	local current = card:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
	current:SetPoint("TOP", titleText, "BOTTOM", 0, -1)
	current:SetText(L["(your current choice)"])
	card.Current = current

	local body = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	body:SetPoint("TOP", current, "BOTTOM", 0, -6)
	body:SetWidth(CARD_WIDTH - 32)
	body:SetJustifyH("CENTER")
	body:SetText(text)
	card.Body = body

	local choose = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
	choose:SetSize(160, 26)
	choose:SetPoint("BOTTOM", card, "BOTTOM", 0, 14)
	choose:SetText(L["Choose"])
	choose:SetScript("OnClick", function() Choose(mode) end)
	card.Choose = choose

	card.mode = mode
	return card
end

-- a checkbox with its label, `bottom` above the card's bottom edge
local function MakeCheck(card, bottom, text)
	local check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, bottom)
	local label = check.Text or check.text
	if not label then
		label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	end
	label:SetWidth(CARD_WIDTH - 60)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return check
end

local function Build()
	frame = CreateFrame("Frame", "OldFriendsListSetupFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(CARD_WIDTH * 2 + 48, FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, frame) end
	if frame.Inset then frame.Inset:Hide() end
	if frame.SetTitle then frame:SetTitle(ns.NAME) end
	if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, ns.PORTRAIT) end

	-- closing without choosing keeps things as they are (separate window) and counts as done
	local close = frame.CloseButton or _G["OldFriendsListSetupFrameCloseButton"]
	if close then close:SetScript("OnClick", function() Done() frame:Hide() end) end
	frame:SetScript("OnHide", Done)

	local question = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	question:SetPoint("TOP", frame, "TOP", 0, -60)
	question:SetText(L["How would you like to see your friends?"])

	-- for players updating: nothing changes unless they pick the new way
	local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	intro:SetPoint("TOP", question, "BOTTOM", 0, -6)
	intro:SetWidth(CARD_WIDTH * 2)
	intro:SetText(L["New: Old Friends List can also appear in the game's Social window. Nothing changes unless you pick it."])
	frame.Intro = intro

	-- in combat the keys can't change: choosing waits for the end of the fight (same place as the intro)
	local combatNote = frame:CreateFontString(nil, "ARTWORK", "GameFontRed")
	combatNote:SetPoint("TOP", question, "BOTTOM", 0, -6)
	combatNote:SetWidth(CARD_WIDTH * 2)
	combatNote:SetText(L["You can choose after the fight."])
	combatNote:Hide()
	frame.CombatNote = combatNote

	local integrated = MakeCard(frame, IMAGE_INTEGRATED, L["In the Social window (O)"],
		L["Old Friends List appears together with the game's friends list. Shift-O still opens the separate window."],
		"integrated")
	integrated:SetPoint("TOPLEFT", frame, "TOPLEFT", CARDS_MARGIN, -CARDS_TOP)

	local separate = MakeCard(frame, IMAGE_SEPARATE, L["Separate window"],
		L["A classic friends window of its own, opened with Shift-O."], "separate")
	separate:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CARDS_MARGIN, -CARDS_TOP)

	-- each card's options (off by default; they show what's set now)
	duplicatesCheck = MakeCheck(integrated, CHECK_LOW, L["Hide friends already shown by Battle.net"])
	bnetCheck = MakeCheck(separate, CHECK_HIGH, L["Show Battle.net friends playing WoW"])
	swapCheck = MakeCheck(separate, CHECK_LOW, L["Use O to open this window (the game's friends window moves to Shift-O)"])

	cards = { integrated, separate }

	tinsert(UISpecialFrames, "OldFriendsListSetupFrame")
	frame:Hide()
end

-- in combat: the Choose buttons are off (the keys can't change mid-fight) and a line says why
local function UpdateCombatState()
	if not frame then return end
	local inCombat = Safe.InCombat()
	for _, card in ipairs(cards) do card.Choose:SetEnabled(not inCombat) end
	local s = ns.db.settings
	local updating = s.setupFromUpdate and not s.setupDone
	frame.CombatNote:SetShown(inCombat)
	frame.Intro:SetShown((updating and not inCombat) and true or false)
end

function Setup.Show()
	if not ns.db then return end
	if not frame then Build() end
	local s = ns.db.settings
	local mode = s.socialMode == "integrated" and "integrated" or "separate"
	-- someone updating from 0.2.x: their separate window is what they have, and stays unless they pick otherwise
	local updating = s.setupFromUpdate and not s.setupDone
	for _, card in ipairs(cards) do
		local isCurrent = card.mode == mode and (s.setupDone or updating)
		card.Current:SetShown(isCurrent and true or false)
		card.Current:SetText(updating and L["(what you have now: nothing changes)"] or L["(your current choice)"])
		-- the button always says "Choose": the green line under the title already marks the current one
	end
	swapCheck:SetChecked(ns.Options.IsSwapped())
	bnetCheck:SetChecked(s.showBNet and true or false)
	duplicatesCheck:SetChecked(s.hideBNetDuplicates and true or false)
	UpdateCombatState()
	frame:Show()
end

-- the setup may be open when a fight starts or ends
ns.On("PLAYER_REGEN_DISABLED", function() if frame and frame:IsShown() then UpdateCombatState() end end)
ns.On("PLAYER_REGEN_ENABLED", function() if frame and frame:IsShown() then UpdateCombatState() end end)

-- the first login with 0.3.0: a few seconds after the loading screen, never in combat
local shownThisSession
local function MaybeShowFirstTime()
	if shownThisSession or not ns.db or ns.db.settings.setupDone then return end
	if Safe.InCombat() then return end
	shownThisSession = true
	Setup.Show()
end

ns.On("PLAYER_ENTERING_WORLD", function()
	C_Timer.After(5, MaybeShowFirstTime)
end)
ns.On("PLAYER_REGEN_ENABLED", function()
	C_Timer.After(2, MaybeShowFirstTime)
end)
