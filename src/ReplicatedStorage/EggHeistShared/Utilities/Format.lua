-- EggHeist | Shared/Utilities/Format.lua
-- Number / time / string formatting helpers (client + server safe).

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.Money(value)
	value = math.floor(tonumber(value) or 0)
	local negative = value < 0
	value = math.abs(value)
	local tier = 1
	while value >= 1000 and tier < #SUFFIXES do
		value = value / 1000
		tier = tier + 1
	end
	local text
	if tier == 1 then
		text = tostring(math.floor(value))
	elseif value >= 100 then
		text = tostring(math.floor(value))
	elseif value >= 10 then
		text = string.format("%.1f", math.floor(value * 10) / 10)
	else
		text = string.format("%.2f", math.floor(value * 100) / 100)
	end
	if negative then
		text = "-" .. text
	end
	return "$" .. text .. SUFFIXES[tier]
end

function Format.Compact(value)
	local s = Format.Money(value)
	if string.sub(s, 1, 1) == "$" then
		return string.sub(s, 2)
	end
	return s
end

function Format.Int(value)
	value = math.floor(tonumber(value) or 0)
	local s = tostring(math.abs(value))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	out = s .. out
	if value < 0 then
		out = "-" .. out
	end
	return out
end

function Format.Duration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.Percent(fraction, decimals)
	decimals = decimals or 0
	return string.format("%." .. tostring(decimals) .. "f%%", (tonumber(fraction) or 0) * 100)
end

function Format.Capitalize(str)
	str = tostring(str or "")
	if #str == 0 then
		return str
	end
	return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

return Format
