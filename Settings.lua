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
	if t then
		if kind == "boolean" then return t.Boolean end
		if kind == "string" then return t.String end
		return t.Number
	end
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

-- A button to the game's Key Bindings, where our binding and the Social window's live.
-- Not Blizzard's own key binding rows (CreateKeybindingEntryInitializer): built from
-- addon code they carry addon-made functions and search tags, and the Options search
-- runs those on every keystroke. That tainted the search, so the game blocked its next
-- protected action and blamed Old Friends List. For the same reason nothing in this
-- panel adds search tags (addSearchTags = false).
local function AddKeybindingButton(layout)
	if not CreateSettingsButtonInitializer then return end
	layout:AddInitializer(CreateSettingsButtonInitializer(L["Toggle Old Friends List"], ns.G("KEY_BINDINGS", "Key Bindings"),
		function()
			local id = Settings.KEYBINDINGS_CATEGORY_ID
			if id then pcall(Settings.OpenToCategory, id) end
		end,
		L["Set the key under Key Bindings > Old Friends List."], false))
end


-- Where to see Old Friends List: a dropdown with the two choices (like the setup's two cards).
-- Built through Blizzard's own dropdown path, like the checkboxes (nothing addon-made that the
-- Options search runs, see AddKeybindingButton).
local function AddModeSection(layout)
	AddHeader(layout, L["Where to see Old Friends List"])
	local create = Settings.CreateDropdown or Settings.CreateDropDown
	if not (create and Settings.CreateControlTextContainer) then return end
	local setting = Settings.RegisterProxySetting(category, "OldFriendsList_mode", VarType("string"),
		L["Window"], "separate",
		function() return ns.db.settings.socialMode == "integrated" and "integrated" or "separate" end,
		function(value)
			Options.SetMode(value == "integrated" and "integrated" or "separate")
			-- the shortcut tab's checkbox shows off with the Social window, its choice otherwise
			if Settings.NotifyUpdate then pcall(Settings.NotifyUpdate, "OldFriendsList_socialIcon") end
		end)
	local function Choices()
		local container = Settings.CreateControlTextContainer()
		container:Add("integrated", L["In the Social window (O)"])
		container:Add("separate", L["Separate window"])
		return container:GetData()
	end
	create(category, setting, Choices,
		L["Old Friends List inside the game's Social window (O), or in a window of its own (Shift-O)."])
end

-- options for Old Friends List inside the game's Social window
local function AddSocialSection(layout)
	AddHeader(layout, L["Blizzard Social window"])
	AddCheckbox("hideBNetDuplicates", L["Hide friends already shown by Battle.net"],
		L["In the Social window, a character from your Old Friends List that a Battle.net friend is playing right now shows only on Blizzard's card, not in the Old Friends List group. It comes back when they log off or switch character."],
		function() if ns.SocialList then ns.SocialList.Refresh() end end)
end

-- options for the separate window
local function AddSeparateSection(layout)
	AddHeader(layout, L["Old Friends List window"])
	AddCheckbox("showBNet", L["Show Battle.net friends playing WoW"],
		L["In the separate window, also list your Battle.net friends who are playing right now. Those on the other faction can only get a Battle.net whisper."],
		RefreshList)
	-- (which key opens what is changed in the game's Key Bindings, linked below; the setup also offers the swap)
	-- The shortcut tab only exists with the separate window: with Old Friends List inside the
	-- Social window it's off and can't be turned on (the saved choice comes back with the
	-- separate window). Re-evaluated by the panel when the "Window" choice changes.
	local s = ns.db.settings
	local function Separate() return s.socialMode ~= "integrated" end
	local setting = Settings.RegisterProxySetting(category, "OldFriendsList_socialIcon", VarType("boolean"),
		L["Shortcut tab in the Blizzard Social window"], ns.DEFAULTS.socialIcon,
		function() return (s.socialIcon and Separate()) and true or false end,
		function(value)
			s.socialIcon = value and true or false
			if ns.UI and ns.UI.UpdateSocialIcon then ns.UI.UpdateSocialIcon() end
		end)
	local initializer = Settings.CreateCheckbox(category, setting,
		L["Adds an Old Friends List tab under the tabs of the game's Social window (O). Only with the separate window: not shown when Old Friends List is already in that window."])
	if initializer and initializer.AddModifyPredicate then
		initializer:AddModifyPredicate(Separate)
		if initializer.AddEvaluateStateCVar then initializer:AddEvaluateStateCVar("OldFriendsList_mode") end
	end
end

-- the first-time setup, under its own title
local function AddSetupSection(layout)
	if not CreateSettingsButtonInitializer then return end
	AddHeader(layout, L["First-time setup"])
	layout:AddInitializer(CreateSettingsButtonInitializer(L["Social window or separate window"], L["Run the setup again"],
		function() if ns.Setup then ns.Setup.Show() end end,
		L["Choose again: Old Friends List in the Social window or in a separate window."], false))
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

	Try(AddHeader, layout, L["General"])
	Try(AddMinimapCheckbox)
	Try(AddCheckbox, "shareZone", L["Share my zone with friends"],
		L["Tell friends who also use Old Friends List which zone you're in. Only people on your own list get it."])

	Try(AddModeSection, layout)
	Try(AddSocialSection, layout)
	Try(AddSeparateSection, layout)

	Try(AddHeader, layout, L["List"])
	Try(AddCheckbox, "showDetails", L["Show level and zone"],
		L["Show each friend's level, class and zone under their name. Turn it off to show only names."], RefreshList)
	Try(AddCheckbox, "classColors", L["Class colors"],
		L["Show friends' names in their class color, in the list, tooltips and chat messages."], RefreshList)

	Try(AddHeader, layout, L["Notifications"])
	Try(AddCheckbox, "notifyOnline", L["Online messages"], L["Show a message in chat when a friend logs in."])
	Try(AddCheckbox, "notifyOffline", L["Offline messages"], L["Show a message in chat when a friend logs out."])
	Try(AddCheckbox, "sound", L["Login sound"], L["Play a sound when a friend comes online."])
	Try(AddCheckbox, "notifyBNet", L["Battle.net friends"],
		L["Also announce when Battle.net friends who aren't on your Old Friends List log in or out of WoW Forever. Only with Old Friends List in the Social window, or with Battle.net friends shown in the separate window."])

	Try(AddHeader, layout, L["Key Binding"])
	Try(AddKeybindingButton, layout)

	Try(AddSetupSection, layout)

	Try(AddHeader, layout, L["Advanced"])
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
