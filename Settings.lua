--------------------------------------------------------------------------------
-- Settings: a panel in Options > AddOns > Old Friends List, the key binding
-- (Shift-O by default, set once if that key is free), and helpers to show it.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, L = ns.Safe, ns.L

local Options = {}
ns.Options = Options

local category

--------------------------------------------------------------------------------
-- Key binding
--------------------------------------------------------------------------------

-- "SHIFT-O" -> "Shift-O", "CTRL-ALT-F" -> "Ctrl-Alt-F"
local function PrettyKey(key)
	local text = (GetBindingText and GetBindingText(key)) or key
	return (text:gsub("%u%u+", function(word)
		if #word <= 1 then return word end
		return word:sub(1, 1) .. word:sub(2):lower()
	end))
end

-- the key that opens the list, as "Shift-O", or nil
function Options.KeyText()
	local key = Safe.Call(GetBindingKey, ns.BINDING)
	if not key then return nil end
	return PrettyKey(key)
end

-- once per account: bind Shift-O, unless the player already chose a key or Shift-O is taken
local function OfferDefaultKey()
	local s = ns.db.settings
	if s.defaultKeyOffered then return end
	if Safe.InCombat() then return end            -- bindings can't change in combat; try next time
	s.defaultKeyOffered = true

	if Safe.Call(GetBindingKey, ns.BINDING) then return end
	local action = Safe.Call(GetBindingAction, ns.DEFAULT_KEY)
	local keyText = PrettyKey(ns.DEFAULT_KEY)
	if action and action ~= "" then
		local actionName = (GetBindingName and GetBindingName(action)) or action
		ns.Print(L["%s is already used for \"%s\", so no key opens the list yet. Pick one in Options > AddOns > Old Friends List."],
			keyText, actionName)
		return
	end
	local ok = pcall(SetBinding, ns.DEFAULT_KEY, ns.BINDING)
	if ok and GetCurrentBindingSet and SaveBindings then pcall(SaveBindings, GetCurrentBindingSet()) end
	if ok then
		ns.Print(L["Press %s to open your list. You can change it in Options > AddOns > Old Friends List."], keyText)
	end
end

ns.On("PLAYER_ENTERING_WORLD", function()
	if ns.db then OfferDefaultKey() end
end)

--------------------------------------------------------------------------------
-- Swapping keys with the game's Social window, and the Social window mode
--------------------------------------------------------------------------------

local function SaveKeys()
	if GetCurrentBindingSet and SaveBindings then pcall(SaveBindings, GetCurrentBindingSet()) end
end

-- is O already opening Old Friends List?
function Options.IsSwapped()
	return Safe.Call(GetBindingAction, ns.SOCIAL_KEY) == ns.BINDING
end

-- on: O opens Old Friends List and Shift-O the game's Social window; off: the other way round.
-- Only touches O and Shift-O when they're free or already one of the two windows.
function Options.ApplySwap(on)
	if Safe.InCombat() then
		ns.Print(L["Key bindings can't change in combat. Try again after the fight."])
		return false
	end
	local ours, social = ns.BINDING, ns.SOCIAL_BINDING
	for _, key in ipairs({ ns.SOCIAL_KEY, ns.DEFAULT_KEY }) do
		local action = Safe.Call(GetBindingAction, key)
		if action and action ~= "" and action ~= ours and action ~= social then
			ns.Print(L["%s is used for \"%s\", so the keys weren't swapped. Change them in Options > AddOns > Old Friends List."],
				PrettyKey(key), (GetBindingName and GetBindingName(action)) or action)
			return false
		end
	end
	local okO = pcall(SetBinding, ns.SOCIAL_KEY, on and ours or social)
	local okShift = pcall(SetBinding, ns.DEFAULT_KEY, on and social or ours)
	SaveKeys()
	ns.db.settings.swapKeys = on and true or false
	if okO and okShift then
		ns.Print(on and L["O now opens Old Friends List, and Shift-O the Social window."]
			or L["O opens the Social window again, and Shift-O Old Friends List."])
	end
	return okO and okShift
end

-- "integrated" (Old Friends as a group in the Social window) or "separate" (own window)
function Options.SetMode(mode)
	ns.db.settings.socialMode = mode == "integrated" and "integrated" or "separate"
	local list = ns.SocialList
	if list then
		if mode == "integrated" and list.Install then list.Install() end
		if list.Refresh then list.Refresh() end
	end
	if ns.UI and ns.UI.UpdateSocialIcon then ns.UI.UpdateSocialIcon() end
end

--------------------------------------------------------------------------------
-- The options panel
--------------------------------------------------------------------------------

local function VarType(kind)
	local t = Settings.VarType
	if t then return kind == "boolean" and t.Boolean or t.Number end
	return kind
end

-- onChange: called after the player flips it (e.g. to redraw the list)
local function AddCheckbox(key, name, tooltip, onChange)
	local variable = "OldFriendsList_" .. key
	local setting = Settings.RegisterAddOnSetting(category, variable, key, ns.db.settings,
		VarType("boolean"), name, ns.DEFAULTS[key])
	Settings.CreateCheckbox(category, setting, tooltip)
	if onChange then
		if setting.SetValueChangedCallback then
			setting:SetValueChangedCallback(function() onChange() end)
		elseif Settings.SetOnValueChangedCallback then
			Settings.SetOnValueChangedCallback(variable, function() onChange() end)
		end
	end
end

local function RefreshList()
	if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

local function AddMinimapCheckbox()
	local setting = Settings.RegisterProxySetting(category, "OldFriendsList_minimap", VarType("boolean"),
		L["Show minimap button"], true,
		function() return not ns.db.settings.minimapHidden end,
		function(value) ns.MinimapButton.SetShown(value, true) end)
	Settings.CreateCheckbox(category, setting, L["Show the Old Friends List button around the minimap."])
end

local function AddIntervalSlider()
	local setting = Settings.RegisterAddOnSetting(category, "OldFriendsList_pingInterval", "pingInterval",
		ns.db.settings, VarType("number"), L["Check interval"], ns.DEFAULTS.pingInterval)
	local options = Settings.CreateSliderOptions(15, 300, 5)
	if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return ("%d s"):format(v) end)
	end
	Settings.CreateSlider(category, setting, options,
		L["How often each friend is checked. Lower is faster to notice logins; friends who use the addon are always instant."])
end

local function AddHeader(layout, text)
	if CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

-- a native key binding row for a binding command (ours, or the game's Social window)
local function AddKeybinding(layout, command, isOurs)
	local index = C_KeyBindings and C_KeyBindings.GetBindingIndex and C_KeyBindings.GetBindingIndex(command)
	if index and CreateKeybindingEntryInitializer then
		local initializer = CreateKeybindingEntryInitializer(index, true)
		if initializer.AddSearchTags then initializer:AddSearchTags("key", "keybind", "shortcut", "hotkey", "social") end
		layout:AddInitializer(initializer)
		return
	end
	-- older settings UI: send people to the game's Key Bindings instead
	if isOurs and CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer(L["Toggle Old Friends List"], ns.G("KEY_BINDINGS", "Key Bindings"),
			function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end,
			L["Set the key under Key Bindings > AddOns > Old Friends List."], true))
	end
end

-- checkbox backed by a getter/setter instead of a saved field
local function AddProxyCheckbox(variable, name, tooltip, default, getter, setter)
	local setting = Settings.RegisterProxySetting(category, "OldFriendsList_" .. variable, VarType("boolean"),
		name, default, getter, setter)
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddSocialSection(layout)
	AddHeader(layout, L["Social window"])
	AddProxyCheckbox("integrated", L["Show Old Friends in the Social window (O)"],
		L["Your Old Friends appear as a group above Favorites in the game's friends window. Shift-O still opens the separate window."],
		false,
		function() return ns.db.settings.socialMode == "integrated" end,
		function(value) Options.SetMode(value and "integrated" or "separate") end)
	AddProxyCheckbox("swapKeys", L["Use O for Old Friends List"],
		L["O opens Old Friends List and Shift-O the game's Social window. Turn it off to swap them back."],
		false,
		function() return Options.IsSwapped() end,
		function(value) if value ~= Options.IsSwapped() then Options.ApplySwap(value) end end)
	AddCheckbox("socialIcon", L["Show in the Social window"],
		L["Adds an Old Friends List tab under the tabs of the game's Social window (O). Not shown when your Old Friends are already in that window."],
		function() if ns.UI and ns.UI.UpdateSocialIcon then ns.UI.UpdateSocialIcon() end end)
	if CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer(L["First-time setup"], L["Run the setup again"],
			function() if ns.Setup then ns.Setup.Show() end end,
			L["Choose again between your Old Friends in the Social window or a separate window."], true))
	end
end

local function Build()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then
		ns.Debug("no Settings API: options panel unavailable")
		return
	end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory(ns.NAME)

	-- each piece on its own, so one API difference doesn't take the whole panel down
	local function Try(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then ns.Debug("settings: %s", tostring(err)) end
	end

	-- both keys, ours and the game's Social window, to compare and change
	Try(AddHeader, layout, L["Key Binding"])
	Try(AddKeybinding, layout, ns.BINDING, true)
	Try(AddKeybinding, layout, ns.SOCIAL_BINDING, false)

	Try(AddSocialSection, layout)

	Try(AddHeader, layout, L["List"])
	Try(AddCheckbox, "showDetails", L["Show level and zone"],
		L["Show each friend's level, class and zone under their name. Turn it off to show only names."], RefreshList)
	Try(AddCheckbox, "classColors", L["Class colors"],
		L["Show friends' names in their class color, in the list, tooltips and chat messages."], RefreshList)

	Try(AddHeader, layout, L["Notifications"])
	Try(AddCheckbox, "notifyOnline", L["Online messages"], L["Show a message in chat when a friend logs in."])
	Try(AddCheckbox, "notifyOffline", L["Offline messages"], L["Show a message in chat when a friend logs out."])
	Try(AddCheckbox, "sound", L["Login sound"], L["Play a sound when a friend comes online."])

	Try(AddHeader, layout, L["General"])
	Try(AddMinimapCheckbox)
	Try(AddCheckbox, "shareZone", L["Share my zone with friends"],
		L["Tell friends who also use Old Friends List which zone you're in. Only people on your own list get it."])
	Try(AddIntervalSlider)

	Settings.RegisterAddOnCategory(category)
end

ns.Listen("DB_READY", Build)

-- opens the panel; false when this client has no options panel for addons
function Options.Open()
	if not (category and Settings and Settings.OpenToCategory) then return false end
	if Safe.InCombat() then
		ns.Print(L["The options can't be opened in combat. Try again after the fight."])
		return true
	end
	local id = category.GetID and category:GetID() or category.ID
	return pcall(Settings.OpenToCategory, id) and true or false
end
