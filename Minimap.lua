--------------------------------------------------------------------------------
-- Minimap button: left-click opens the list, right-click for quick settings,
-- drag to move it around the minimap. /ofl minimap shows or hides it.
--------------------------------------------------------------------------------

local _, ns = ...
local Data = ns.Data

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button

local function SetAngle(angle)
	ns.db.settings.minimapAngle = angle
	local rad = math.rad(angle)
	local radius = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	SetAngle(math.deg(math.atan2(cy - my, cx - mx)))
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine(ns.NAME)
	local online, total = Data.CountOnline()
	GameTooltip:AddLine(("%d of %d online"):format(online, total), 1, 1, 1)
	local shown = 0
	for _, key in ipairs(Data.Sorted()) do
		if Data.status[key] ~= "online" then break end
		shown = shown + 1
		if shown > 10 then GameTooltip:AddLine("...", 0.6, 0.6, 0.6) break end
		local f = Data.Get(key)
		local c = Data.ClassColor(f.class)
		GameTooltip:AddDoubleLine(Data.Display(key), f.lastZone or "", c and c.r or 1, c and c.g or 1, c and c.b or 1, 0.7, 0.7, 0.7)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: open the list", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Right-click: options", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Drag: move this button", 0.5, 0.5, 0.5)
	local key = ns.Options.KeyText()
	if key then GameTooltip:AddLine(key .. ": open the list", 0.5, 0.5, 0.5) end
	GameTooltip:Show()
end

local function OpenOptions(self)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local s = ns.db.settings
	local function Toggle(field) return function() s[field] = not s[field] end end
	local function Is(field) return function() return s[field] end end
	MenuUtil.CreateContextMenu(self, function(_, root)
		root:CreateTitle(ns.NAME)
		root:CreateButton("Open the list", function() ns.UI.Toggle() end)
		root:CreateButton("Add a friend...", function() ns.Actions.AddPrompt() end)
		root:CreateDivider()
		root:CreateCheckbox("Online messages", Is("notifyOnline"), Toggle("notifyOnline"))
		root:CreateCheckbox("Offline messages", Is("notifyOffline"), Toggle("notifyOffline"))
		root:CreateCheckbox("Login sound", Is("sound"), Toggle("sound"))
		root:CreateCheckbox("Share my zone with friends", Is("shareZone"), Toggle("shareZone"))
		root:CreateDivider()
		root:CreateButton("Settings and key binding...", function() ns.Options.Open() end)
		root:CreateButton("Hide minimap button", function() MinimapButton.SetShown(false) end)
	end)
end

local function Build()
	button = CreateFrame("Button", "OldFriendsListMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ns.ICON)
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then OpenOptions(self) else ns.UI.Toggle() end
	end)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnMouseDown", function() icon:SetSize(16, 16) end)
	button:SetScript("OnMouseUp", function() icon:SetSize(18, 18) end)

	SetAngle(ns.db.settings.minimapAngle or 210)
end

-- quiet: no chat message (when toggled from the options panel)
function MinimapButton.SetShown(show, quiet)
	ns.db.settings.minimapHidden = not show
	if show and not button then Build() end
	if button then button:SetShown(show) end
	if not show and not quiet then ns.Print("minimap button hidden. /ofl minimap brings it back.") end
end

ns.Listen("LOGIN", function()
	if not Minimap then return end
	if not ns.db.settings.minimapHidden then Build() end
end)
