--------------------------------------------------------------------------------
-- A way into the list from the game's Social window (O). Opt-in: the "socialIcon" option.
--  * Forever's SocialUIFrame: a tab under Blizzard's own side tabs, built like them
--    (their background, highlight and mask are copied; the icon is ours).
--  * Otherwise (the older FriendsFrame, or the tabs can't be found): a small icon left of the
--    window's close button.
-- Blizzard's tabs have no names, so they're found by their parts (an Icon and a Background).
--------------------------------------------------------------------------------

local _, ns = ...
local L, UI = ns.L, ns.UI

local Social = {}
ns.SocialTab = Social

local hooked = {}    -- [window] = true once we watch it
local buttons = {}   -- [window] = our button
local kinds = {}     -- [window] = "tab" | "icon"

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- the tab is opt-in, and not needed when the friends are already in the window (integrated mode)
local function Enabled()
	local s = ns.db and ns.db.settings
	return s and s.socialIcon and s.socialMode ~= "integrated" and true or false
end

local function SetupButton(b)
	b:SetScript("OnClick", function() UI.Toggle() end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(ns.NAME)
		GameTooltip:AddLine(L["Your list of characters, the classic way."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- a round mask over a texture (our icon is square art)
local function RoundMask(b, texture)
	local mask = b:CreateMaskTexture()
	mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
end

--------------------------------------------------------------------------------
-- The side tab (Forever's SocialUIFrame)
--------------------------------------------------------------------------------

-- Blizzard's side tabs, top to bottom
local function FindTabs(social)
	local tabs = {}
	for _, child in ipairs({ social:GetChildren() }) do
		if child ~= buttons[social] and child.Icon and child.Background and child:IsShown() then
			tabs[#tabs + 1] = child
		end
	end
	table.sort(tabs, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
	return tabs
end

-- a tab to copy the look from: one that isn't selected (no glow), else any
local function PickModel(tabs)
	for _, tab in ipairs(tabs) do
		if not (tab.TabGlow and tab.TabGlow:IsShown()) then return tab end
	end
	return tabs[1]
end

-- copies a texture's look and anchors; `map` turns the model's regions into ours
local function CopyTexture(src, dst, map)
	local atlas = src.GetAtlas and src:GetAtlas()
	if atlas then
		dst:SetAtlas(atlas, false)
	elseif src.GetTexture then
		dst:SetTexture(src:GetTexture())
		if src.GetTexCoord and dst.SetTexCoord then dst:SetTexCoord(src:GetTexCoord()) end
	end
	if src.GetVertexColor and dst.SetVertexColor then dst:SetVertexColor(src:GetVertexColor()) end
	if src.GetBlendMode and dst.SetBlendMode then dst:SetBlendMode(src:GetBlendMode()) end
	if src.GetAlpha then dst:SetAlpha(src:GetAlpha()) end
	dst:ClearAllPoints()
	local n = src:GetNumPoints()
	if n == 0 then
		dst:SetAllPoints()
	else
		for i = 1, n do
			local point, relativeTo, relativePoint, x, y = src:GetPoint(i)
			local target = relativeTo and (map[relativeTo] or relativeTo) or nil
			dst:SetPoint(point, target, relativePoint, x, y)
		end
	end
	local w, h = src:GetSize()
	if w and h and w > 0 and h > 0 then dst:SetSize(w, h) end
end

local function BuildTab(social, model)
	local b = CreateFrame("Button", nil, social)
	b:SetSize(model:GetSize())
	b:SetFrameStrata(model:GetFrameStrata())
	b:SetFrameLevel(model:GetFrameLevel())

	-- create our copies first (anchors may point at each other), then copy the look
	local map = { [model] = b }
	local pairsToCopy = {}
	for _, key in ipairs({ "Background", "Icon", "Mask" }) do
		local src = model[key]
		if src then
			local isMask = src.GetObjectType and src:GetObjectType() == "MaskTexture"
			local layer, sublevel
			if not isMask and src.GetDrawLayer then layer, sublevel = src:GetDrawLayer() end
			local dst = isMask and b:CreateMaskTexture() or b:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
			map[src] = dst
			pairsToCopy[#pairsToCopy + 1] = { src, dst, key }
		end
	end
	local highlight = model.GetHighlightTexture and model:GetHighlightTexture()
	local ourHighlight
	if highlight then
		ourHighlight = b:CreateTexture(nil, "HIGHLIGHT")
		map[highlight] = ourHighlight
		pairsToCopy[#pairsToCopy + 1] = { highlight, ourHighlight, "Highlight" }
	end

	local ourIcon, iconMasked
	for _, p in ipairs(pairsToCopy) do
		local src, dst, key = p[1], p[2], p[3]
		CopyTexture(src, dst, map)
		-- the same masks as the model's
		if src.GetNumMaskTextures and dst.AddMaskTexture then
			for i = 1, src:GetNumMaskTextures() do
				local m = map[src:GetMaskTexture(i)]
				if m then
					dst:AddMaskTexture(m)
					if key == "Icon" then iconMasked = true end
				end
			end
		end
		if key == "Icon" then ourIcon = dst end
	end
	if ourHighlight then b:SetHighlightTexture(ourHighlight) end

	-- our icon instead of theirs
	if ourIcon then
		ourIcon:SetTexture(ns.ICON)
		ourIcon:SetTexCoord(0, 1, 0, 1)
		ourIcon:SetVertexColor(1, 1, 1)
		if not iconMasked then RoundMask(b, ourIcon) end
	end

	SetupButton(b)
	return b
end

-- under the last tab, with the same spacing the tabs have between them
local function PlaceTab(social)
	local b = buttons[social]
	local tabs = FindTabs(social)
	local last = tabs[#tabs]
	if not last then return end
	local gap = 0
	if #tabs >= 2 then
		local above = tabs[#tabs - 1]
		if above:GetBottom() and last:GetTop() then gap = above:GetBottom() - last:GetTop() end
	end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
end

--------------------------------------------------------------------------------
-- The fallback icon (left of the close button)
--------------------------------------------------------------------------------

local function CloseButtonOf(social)
	return social.CloseButton or _G[(social:GetName() or "") .. "CloseButton"]
end

-- above the title bar and the close button, whatever their levels
local function RaiseIcon(b, social)
	local level = social:GetFrameLevel()
	for _, part in ipairs({ social.TitleContainer, CloseButtonOf(social) }) do
		if part and part.GetFrameLevel then level = math.max(level, part:GetFrameLevel()) end
	end
	b:SetFrameLevel(level + 2)
end

local function BuildIcon(social)
	local b = CreateFrame("Button", nil, social)
	b:SetSize(22, 22)
	local close = CloseButtonOf(social)
	if close then
		b:SetPoint("RIGHT", close, "LEFT", -2, 0)
	else
		b:SetPoint("TOPRIGHT", social, "TOPRIGHT", -28, -4)
	end
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ns.ICON)
	RoundMask(b, icon)
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	SetupButton(b)
	return b
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

-- build (once) and place our button on a shown window
local function Refresh(social)
	if not Enabled() then
		if buttons[social] then buttons[social]:Hide() end
		return
	end
	if not buttons[social] then
		local model = PickModel(FindTabs(social))
		local ok, b = pcall(function() return model and BuildTab(social, model) end)
		if ok and b then
			buttons[social], kinds[social] = b, "tab"
		else
			if not ok then ns.Debug("social tab: %s", tostring(b)) end
			buttons[social], kinds[social] = BuildIcon(social), "icon"
		end
	end
	if kinds[social] == "tab" then PlaceTab(social) else RaiseIcon(buttons[social], social) end
	buttons[social]:Show()
end

local function Watch(social)
	if not social or hooked[social] then return end
	hooked[social] = true
	-- wait a frame after it opens, so Blizzard's tabs are laid out
	social:HookScript("OnShow", function() C_Timer.After(0, function() Refresh(social) end) end)
	if social:IsShown() then C_Timer.After(0, function() Refresh(social) end) end
end

local function WatchAll()
	Watch(_G["SocialUIFrame"])
	Watch(_G["FriendsFrame"])
end

-- the option was flipped
function Social.Update()
	for social in pairs(hooked) do
		if social:IsShown() then
			Refresh(social)
		elseif buttons[social] then
			buttons[social]:SetShown(Enabled())
		end
	end
end
UI.UpdateSocialIcon = Social.Update

-- for /ofl diag
function UI.SocialIconInfo()
	local lines = {}
	for _, name in ipairs({ "SocialUIFrame", "FriendsFrame" }) do
		local social = _G[name]
		if social then
			local b = buttons[social]
			lines[#lines + 1] = ("%s: shown %s, side tabs found %d, ours %s"):format(name, tostring(social:IsShown()),
				#FindTabs(social), b and (kinds[social] .. ", shown " .. tostring(b:IsShown())) or "not built")
		else
			lines[#lines + 1] = name .. ": doesn't exist"
		end
	end
	return lines
end

ns.Listen("LOGIN", function()
	WatchAll()
	-- the Social window may only be created the first time it opens
	if ToggleFriendsFrame then hooksecurefunc("ToggleFriendsFrame", WatchAll) end
end)
ns.On("ADDON_LOADED", function() WatchAll() end)
ns.On("FRIENDLIST_UPDATE", function() WatchAll() end)
ns.On("BN_FRIEND_INFO_CHANGED", function() WatchAll() end)
