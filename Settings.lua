--------------------------------------------------------------------------------
-- Settings: a panel in Options > AddOns > Old Friends List, the key binding
-- (Shift-O by default, set once if that key is free), and helpers to show it.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe = ns.Safe

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
		ns.Print("%s is already used for \"%s\", so no key opens the list yet. Pick one in Options > AddOns > Old Friends List.",
			keyText, actionName)
		return
	end
	local ok = pcall(SetBinding, ns.DEFAULT_KEY, ns.BINDING)
	if ok and GetCurrentBindingSet and SaveBindings then pcall(SaveBindings, GetCurrentBindingSet()) end
	if ok then
		ns.Print("Press %s to open your list. You can change it in Options > AddOns > Old Friends List.", keyText)
	end
end

ns.On("PLAYER_ENTERING_WORLD", function()
	if ns.db then OfferDefaultKey() end
end)

--------------------------------------------------------------------------------
-- The options panel
--------------------------------------------------------------------------------

local function VarType(kind)
	local t = Settings.VarType
	if t then return kind == "boolean" and t.Boolean or t.Number end
	return kind
end

local function AddCheckbox(key, name, tooltip)
	local setting = Settings.RegisterAddOnSetting(category, "OldFriendsList_" .. key, key, ns.db.settings,
		VarType("boolean"), name, ns.DEFAULTS[key])
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddMinimapCheckbox()
	local setting = Settings.RegisterProxySetting(category, "OldFriendsList_minimap", VarType("boolean"),
		"Show minimap button", true,
		function() return not ns.db.settings.minimapHidden end,
		function(value) ns.MinimapButton.SetShown(value, true) end)
	Settings.CreateCheckbox(category, setting, "Show the Old Friends List button around the minimap.")
end

local function AddIntervalSlider()
	local setting = Settings.RegisterAddOnSetting(category, "OldFriendsList_pingInterval", "pingInterval",
		ns.db.settings, VarType("number"), "Check interval", ns.DEFAULTS.pingInterval)
	local options = Settings.CreateSliderOptions(15, 300, 5)
	if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return ("%d s"):format(v) end)
	end
	Settings.CreateSlider(category, setting, options,
		"How often each friend is checked. Lower is faster to notice logins; friends who use the addon are always instant.")
end

local function AddHeader(layout, text)
	if CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

local function AddKeybinding(layout)
	local index = C_KeyBindings and C_KeyBindings.GetBindingIndex and C_KeyBindings.GetBindingIndex(ns.BINDING)
	if index and CreateKeybindingEntryInitializer then
		local initializer = CreateKeybindingEntryInitializer(index, true)
		if initializer.AddSearchTags then initializer:AddSearchTags("key", "keybind", "shortcut", "hotkey") end
		layout:AddInitializer(initializer)
		return
	end
	-- older settings UI: send people to the game's Key Bindings instead
	if CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer("Toggle Old Friends List", "Key Bindings",
			function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end,
			"Set the key under Key Bindings > AddOns > Old Friends List.", true))
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

	Try(AddHeader, layout, "Key Binding")
	Try(AddKeybinding, layout)

	Try(AddHeader, layout, "Notifications")
	Try(AddCheckbox, "notifyOnline", "Online messages", "Print \"[Name] has come online.\" in chat when a friend logs in.")
	Try(AddCheckbox, "notifyOffline", "Offline messages", "Print \"[Name] has gone offline.\" in chat when a friend logs out.")
	Try(AddCheckbox, "sound", "Login sound", "Play a sound when a friend comes online.")

	Try(AddHeader, layout, "General")
	Try(AddMinimapCheckbox)
	Try(AddCheckbox, "shareZone", "Share my zone with friends",
		"Tell friends who also use Old Friends List which zone you're in. Only people on your own list get it.")
	Try(AddIntervalSlider)

	Settings.RegisterAddOnCategory(category)
end

ns.Listen("DB_READY", Build)

-- opens the panel; false when this client has no options panel for addons
function Options.Open()
	if not (category and Settings and Settings.OpenToCategory) then return false end
	local id = category.GetID and category:GetID() or category.ID
	return pcall(Settings.OpenToCategory, id) and true or false
end
