--------------------------------------------------------------------------------
-- Mail: Old Friends List names in the suggestions under the mail's "To:" field, added after the
-- game's own (AutoComplete_Update post-hook). The box stays the game's; only the mail's "To:" field
-- is touched (the same box serves chat whispers).
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Data = ns.Safe, ns.Data

local Mail = {}
ns.Mail = Mail

local MAX_FALLBACK = 5   -- (AUTOCOMPLETE_MAX_BUTTONS, when the game doesn't say)

local function Enabled()
	return ns.db and ns.db.settings.mailNames
end

-- friends you can mail whose name starts with text (any case), online first, then by name
function Mail.Matches(text)
	local out = {}
	if type(text) ~= "string" or text == "" then return out end
	local prefix, me = text:lower(), Data.MyKey()
	for _, key in ipairs(Data.Sorted()) do
		if key ~= me and key:lower():sub(1, #prefix) == prefix then out[#out + 1] = key end
	end
	return out
end

-- a result's name, whatever shape the game uses ({ name = ... } or a plain string)
local function ResultName(r)
	if type(r) == "table" then return Safe.Value(r.name) end
	return Safe.Value(r)
end

-- the game's results plus ours (not already there), in the game's shape. nil when we add nothing.
function Mail.Merge(results, text, max)
	results = type(results) == "table" and results or {}
	local tables = type(results[1]) ~= "string"   -- (the modern client uses tables; also when empty)
	local seen, out = {}, {}
	for i, r in ipairs(results) do
		out[i] = r
		local name = ResultName(r)
		local key = type(name) == "string" and Data.Normalize(name)
		if key then seen[key] = true end
	end
	local added = 0
	for _, key in ipairs(Mail.Matches(text)) do
		if #out >= max then break end
		if not seen[key] then
			out[#out + 1] = tables and { name = key, priority = 0 } or key
			added = added + 1
		end
	end
	if added == 0 then return nil end
	return out
end

-- what the game would suggest for this field, in either of the call shapes clients have used
local function GameResults(parent, text, cursorPosition, max)
	local params = parent.autoCompleteParams
	if not (GetAutoCompleteResults and type(params) == "table") then return {} end
	-- modern: (text, cursor, include, exclude, max) -> list of { name, priority }
	local ok, results = pcall(GetAutoCompleteResults, text, cursorPosition, params.include, params.exclude, max)
	if ok and type(results) == "table" then return results end
	-- older: (text, include, exclude, max, cursor) -> names
	local packed = { pcall(GetAutoCompleteResults, text, params.include, params.exclude, max, cursorPosition) }
	if packed[1] then
		table.remove(packed, 1)
		local names = {}
		for _, v in ipairs(packed) do if type(v) == "string" then names[#names + 1] = v end end
		return names
	end
	return {}
end

-- after the game filled the box for the mail's "To:" field: add our friends
function Mail.OnAutoComplete(parent, text, cursorPosition)
	if not Enabled() or parent == nil or parent ~= _G.SendMailNameEditBox then return end
	if type(text) ~= "string" or text == "" then return end
	if type(cursorPosition) == "number" and cursorPosition > #text then return end
	if not (AutoCompleteBox and AutoComplete_UpdateResults) then return end
	-- (one more than the box shows, as the game asks, so it can show "...")
	local max = (tonumber(AUTOCOMPLETE_MAX_BUTTONS) or MAX_FALLBACK) + 1
	local merged = Mail.Merge(GameResults(parent, text, cursorPosition or #text, max), text, max)
	if not merged then return end
	local ok, err = pcall(AutoComplete_UpdateResults, AutoCompleteBox, merged)
	if not ok then ns.QuietError("mail names", err) end
end

ns.Listen("LOGIN", function()
	if type(AutoComplete_Update) == "function" then
		hooksecurefunc("AutoComplete_Update", Mail.OnAutoComplete)
	else
		ns.Debug("no AutoComplete_Update: no Old Friends List names in the mail")
	end
end)

--------------------------------------------------------------------------------
-- /ofl diag mail: how this client's mail suggestions work (open the mail's Send tab first)
--------------------------------------------------------------------------------

function Mail.Diag()
	local function has(name, value) print(("  %s: %s"):format(name, value ~= nil and "yes" or "no")) end
	print("Old Friends List: mail")
	has("SendMailNameEditBox", _G.SendMailNameEditBox)
	has("AutoCompleteBox", _G.AutoCompleteBox)
	has("AutoComplete_Update", _G.AutoComplete_Update)
	has("AutoComplete_UpdateResults", _G.AutoComplete_UpdateResults)
	has("GetAutoCompleteResults", _G.GetAutoCompleteResults)
	print(("  AUTOCOMPLETE_MAX_BUTTONS: %s"):format(tostring(_G.AUTOCOMPLETE_MAX_BUTTONS)))
	local box = _G.SendMailNameEditBox
	local params = box and box.autoCompleteParams
	if type(params) == "table" then
		print(("  To: field include %s, exclude %s"):format(tostring(params.include), tostring(params.exclude)))
		local results = GameResults(box, "a", 1, 3)
		local first = results[1]
		print(("  results for \"a\": %d, shape %s, first %s"):format(#results, type(first),
			tostring(ResultName(first))))
	else
		print("  To: field: no autoCompleteParams (open the mail first)")
	end
	print(("  setting: %s, matches for \"a\": %d"):format(tostring(Enabled() and true or false), #Mail.Matches("a")))
end
