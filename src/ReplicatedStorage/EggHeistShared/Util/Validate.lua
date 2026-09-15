-- EggHeist | Shared/Util/Validate.lua
-- Server-side input validation. EVERY RemoteEvent argument passes through here.
-- Client input is untrusted: wrong types, huge strings, NaN, etc.

local Validate = {}

function Validate.IsFiniteNumber(value)
	return type(value) == "number" and value == value
		and value ~= math.huge and value ~= -math.huge
end

function Validate.ClampNumber(value, minValue, maxValue, defaultValue)
	if not Validate.IsFiniteNumber(value) then
		return defaultValue
	end
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

function Validate.String(value, maxLength, defaultValue)
	if type(value) ~= "string" then
		return defaultValue
	end
	if #value > (maxLength or 64) then
		return defaultValue
	end
	return value
end

function Validate.Boolean(value, defaultValue)
	if type(value) ~= "boolean" then
		return defaultValue
	end
	return value
end

function Validate.InSet(value, setTable)
	return setTable[value] == true
end

function Validate.Uid(value)
	-- UIDs are server-generated hex-ish strings, short.
	if type(value) ~= "string" then
		return nil
	end
	if #value < 4 or #value > 48 then
		return nil
	end
	if string.find(value, "[^%w%-_]") then
		return nil
	end
	return value
end

return Validate
