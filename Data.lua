--------------------------------------------------------------------------------
-- Friends data: names, the saved list, and who's online right now
--------------------------------------------------------------------------------

local _, ns = ...
local Safe = ns.Safe

local Data = {}
ns.Data = Data

-- runtime only (not saved): key -> "online" | "offline"; nil = not known yet
Data.status = {}

--------------------------------------------------------------------------------
-- Names. On Forever every character has a first and a last name ("Asha Brightvale"),
-- unique across the whole region: there are no realm suffixes. Each part is 2-12
-- letters (accents allowed), first letter upper case, the rest lower case.
-- A friend is keyed by the full name exactly as the game writes it.
--------------------------------------------------------------------------------

local function Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- letters in a UTF-8 string (counts lead bytes only)
local function Letters(s)
	return select(2, s:gsub("[^\128-\191]", ""))
end

-- "aSHA" -> "Asha", "ñoño" -> "Ñoño" (ASCII and Latin-1 accented letters)
local function Capitalize(part)
	local first, rest
	if part:byte(1) and part:byte(1) >= 192 then
		first, rest = part:match("^([\192-\255][\128-\191]*)(.*)$")
	else
		first, rest = part:sub(1, 1), part:sub(2)
	end
	first = first:upper():gsub("^\195([\160-\190])", function(b)
		if b == "\183" then return "\195" .. b end            -- (the division sign)
		return "\195" .. string.char(b:byte() - 32)
	end)
	rest = rest:lower():gsub("\195([\128-\158])", function(b)
		if b == "\151" then return "\195" .. b end            -- (the multiplication sign)
		return "\195" .. string.char(b:byte() + 32)
	end)
	return first .. rest
end

local function ValidPart(part)
	local n = Letters(part)
	return n >= 2 and n <= 12 and not part:find("[%d%p%c]")
end

function Data.MyFaction()
	return Safe.Call(UnitFactionGroup, "player")
end

function Data.MyKey()
	return Data.Normalize(Safe.Call(UnitName, "player"))
end

-- "asha brightvale", "Asha  Brightvale-SomeRealm" -> "Asha Brightvale"; nil if not a name.
-- (a "-Realm" the game may add is dropped: names are unique across the region)
function Data.Normalize(input)
	if type(input) ~= "string" then return nil end
	input = Trim(input:gsub("%-.*$", ""))
	if input == "" then return nil end
	local parts = {}
	for part in input:gmatch("%S+") do
		if not ValidPart(part) then return nil end
		parts[#parts + 1] = Capitalize(part)
	end
	if #parts < 1 or #parts > 2 then return nil end
	return table.concat(parts, " ")
end

-- what to show / whisper: the full name
function Data.Display(key)
	return key
end

function Data.ShortName(key)
	return key
end

--------------------------------------------------------------------------------
-- The list
--------------------------------------------------------------------------------

function Data.Get(key)
	return key and ns.db.friends[key]
end

function Data.Has(key)
	return key ~= nil and ns.db.friends[key] ~= nil
end

-- add a friend; info may carry class, level, faction from a unit. Returns key or nil, error
function Data.Add(input, info)
	local key = Data.Normalize(input)
	if not key or not key:find(" ") then
		return nil, "That's not a valid character name. Use the first and last name, e.g. Asha Brightvale."
	end
	if key == Data.MyKey() then return nil, "You can't add yourself." end
	if Data.Has(key) then return nil, ("%s is already on your list."):format(Data.Display(key)) end
	local myFaction = Data.MyFaction()
	if info and info.faction and myFaction and info.faction ~= myFaction then
		return nil, ("%s is on the other faction: you can't whisper or invite them."):format(Data.Display(key))
	end
	ns.db.friends[key] = {
		class = info and info.class,
		level = info and info.level,
		faction = (info and info.faction) or myFaction,
		note = nil,
		addedAt = time(),
		lastSeen = nil,
		lastZone = nil,
	}
	ns.Fire("FRIENDS_CHANGED", key, "added")
	return key
end

function Data.Remove(key)
	if not Data.Has(key) then return false end
	ns.db.friends[key] = nil
	Data.status[key] = nil
	ns.Fire("FRIENDS_CHANGED", key, "removed")
	return true
end

function Data.SetNote(key, note)
	local f = Data.Get(key)
	if not f then return end
	if note then note = Trim(note) end
	f.note = (note and note ~= "") and note or nil
	ns.Fire("FRIENDS_CHANGED", key, "note")
end

-- updates class/level/zone from whatever source (unit, handshake, /who)
function Data.UpdateInfo(key, class, level, zone)
	local f = Data.Get(key)
	if not f then return end
	if type(class) == "string" and class ~= "" then f.class = class end
	level = tonumber(level)
	if level and level > 0 then f.level = level end
	if type(zone) == "string" and zone ~= "" then f.lastZone = zone end
	ns.Fire("FRIENDS_CHANGED", key, "info")
end

-- friends that belong to this character's realm group and faction
function Data.Visible()
	local out = {}
	local myFaction = Data.MyFaction()
	for key, f in pairs(ns.db.friends) do
		if not f.faction or not myFaction or f.faction == myFaction then
			out[#out + 1] = key
		end
	end
	return out
end

-- Visible() sorted: online first, then by name
function Data.Sorted()
	local list = Data.Visible()
	table.sort(list, function(a, b)
		local oa, ob = Data.status[a] == "online", Data.status[b] == "online"
		if oa ~= ob then return oa end
		return a < b
	end)
	return list
end

function Data.CountOnline()
	local online, total = 0, 0
	for _, key in ipairs(Data.Visible()) do
		total = total + 1
		if Data.status[key] == "online" then online = online + 1 end
	end
	return online, total
end

--------------------------------------------------------------------------------
-- Status (set by Presence/Comm); fires STATUS_CHANGED(key, new, old)
--------------------------------------------------------------------------------

function Data.SetStatus(key, status)
	local f = Data.Get(key)
	if not f then return end
	if status == "online" then f.lastSeen = time() end
	local old = Data.status[key]
	if old == status then return end
	Data.status[key] = status
	ns.Fire("STATUS_CHANGED", key, status, old)
end

-- marks a friend as seen online right now (from a passive signal)
function Data.Seen(key)
	if Data.Has(key) then Data.SetStatus(key, "online") end
end

--------------------------------------------------------------------------------
-- Display helpers
--------------------------------------------------------------------------------

function Data.ClassColor(class)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
		or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	return c
end

function Data.ClassName(class)
	if not class then return nil end
	return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class:sub(1, 1) .. class:sub(2):lower()
end

function Data.Ago(t)
	if not t then return "never seen" end
	local d = time() - t
	if d < 60 then return "just now" end
	if d < 3600 then
		local m = math.floor(d / 60)
		return m == 1 and "1 minute ago" or m .. " minutes ago"
	end
	if d < 86400 then
		local h = math.floor(d / 3600)
		return h == 1 and "1 hour ago" or h .. " hours ago"
	end
	local days = math.floor(d / 86400)
	return days == 1 and "1 day ago" or days .. " days ago"
end

-- info table (class, level, faction) for a unit, or nil when not a player
function Data.InfoFromUnit(unit)
	if not Safe.Call(UnitIsPlayer, unit) then return nil end
	local _, class = Safe.CallAll(UnitClass, unit)
	return {
		class = class,
		level = Safe.Call(UnitLevel, unit),
		faction = Safe.Call(UnitFactionGroup, unit),
	}
end

-- key (full name) for a unit, or nil
function Data.KeyFromUnit(unit)
	if not Safe.Call(UnitIsPlayer, unit) then return nil end
	return Data.Normalize(Safe.Call(UnitName, unit))
end

-- friends saved by an older version as "Name-Realm": drop the realm
ns.Listen("DB_READY", function()
	local moved = {}
	for key, f in pairs(ns.db.friends) do
		local new = Data.Normalize(key)
		if new ~= key then moved[key] = new or false end
		if new and new ~= key and not ns.db.friends[new] then ns.db.friends[new] = f end
	end
	for old in pairs(moved) do ns.db.friends[old] = nil end
end)
