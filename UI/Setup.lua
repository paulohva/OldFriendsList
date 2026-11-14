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
local CARD_WIDTH, CARD_HEIGHT = 290, 330

local frame, cards, swapCheck

local function Done()
	ns.db.settings.setupDone = true
	ns.db.settings.setupFromUpdate = nil
end

local function Choose(mode)
	Done()
	local Options = ns.Options
	if mode == "integrated" then
		Options.SetMode("integrated")
		-- O is where the friends are now: give it back to the Social window if it was swapped
		if Options.IsSwapped() then Options.ApplySwap(false) end
		ns.Print(L["Your Old Friends now appear in the Social window (O). Shift-O still opens the separate window."])
	else
		local wasSeparate = ns.db.settings.socialMode ~= "integrated"
		Options.SetMode("separate")
		local wantSwap = swapCheck and swapCheck:GetChecked() and true or false
		local swapChanged = wantSwap ~= Options.IsSwapped()
		if swapChanged then Options.ApplySwap(wantSwap) end
		if wasSeparate and not swapChanged then
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

	local picture = card:CreateTexture(nil, "ARTWORK")
	picture:SetSize(CARD_WIDTH - 24, (CARD_WIDTH - 24) / 2)
	picture:SetPoint("TOP", card, "TOP", 0, -12)
	picture:SetTexture(image)

	local titleText = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleText:SetPoint("TOP", picture, "BOTTOM", 0, -12)
	titleText:SetText(title)

	local current = card:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
	current:SetPoint("TOP", titleText, "BOTTOM", 0, -2)
	current:SetText(L["(your current choice)"])
	card.Current = current

	local body = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	body:SetPoint("TOP", current, "BOTTOM", 0, -8)
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

local function Build()
	frame = CreateFrame("Frame", "OldFriendsListSetupFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(CARD_WIDTH * 2 + 48, CARD_HEIGHT + 178)
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
	if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, ns.ICON) end

	-- closing without choosing keeps things as they are (separate window) and counts as done
	local close = frame.CloseButton or _G["OldFriendsListSetupFrameCloseButton"]
	if close then close:SetScript("OnClick", function() Done() frame:Hide() end) end
	frame:SetScript("OnHide", Done)

	local question = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	question:SetPoint("TOP", frame, "TOP", 0, -60)
	question:SetText(L["How would you like to see your Old Friends?"])

	-- for players updating: nothing changes unless they pick the new way
	local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	intro:SetPoint("TOP", question, "BOTTOM", 0, -6)
	intro:SetWidth(CARD_WIDTH * 2)
	intro:SetText(L["New: your Old Friends can also appear in the game's Social window. Nothing changes unless you pick it."])
	frame.Intro = intro

	local integrated = MakeCard(frame, IMAGE_INTEGRATED, L["In the Social window (O)"],
		L["Your Old Friends appear together with the game's friends list, shown first. Shift-O still opens the separate window."],
		"integrated")
	integrated:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -110)

	local separate = MakeCard(frame, IMAGE_SEPARATE, L["Separate window"],
		L["A classic friends window of its own, opened with Shift-O."], "separate")
	separate:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -110)

	swapCheck = CreateFrame("CheckButton", nil, separate, "UICheckButtonTemplate")
	swapCheck:SetSize(24, 24)
	swapCheck:SetPoint("BOTTOMLEFT", separate, "BOTTOMLEFT", 16, 50)
	local label = swapCheck.Text or swapCheck.text
	if not label then
		label = swapCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", swapCheck, "RIGHT", 2, 0)
	end
	label:SetWidth(CARD_WIDTH - 60)
	label:SetJustifyH("LEFT")
	label:SetText(L["Use O instead (the Social window moves to Shift-O)"])

	cards = { integrated, separate }

	local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
	footer:SetWidth(CARD_WIDTH * 2 - 40)
	footer:SetJustifyH("CENTER")
	footer:SetSpacing(2)
	footer:SetText(L["Closing keeps everything as it is."] .. "\n" .. L["Change it anytime in Options > AddOns > Old Friends List."])

	tinsert(UISpecialFrames, "OldFriendsListSetupFrame")
	frame:Hide()
end

function Setup.Show()
	if not ns.db then return end
	if not frame then Build() end
	local s = ns.db.settings
	local mode = s.socialMode == "integrated" and "integrated" or "separate"
	-- someone updating from 0.2.x: their separate window is what they have, and stays unless they pick otherwise
	local updating = s.setupFromUpdate and not s.setupDone
	frame.Intro:SetShown(updating and true or false)
	for _, card in ipairs(cards) do
		local isCurrent = card.mode == mode and (s.setupDone or updating)
		card.Current:SetShown(isCurrent and true or false)
		card.Current:SetText(updating and L["(what you have now: nothing changes)"] or L["(your current choice)"])
		card.Choose:SetText(isCurrent and L["Keep as it is"] or L["Choose"])
	end
	swapCheck:SetChecked(ns.Options.IsSwapped())
	frame:Show()
end

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
