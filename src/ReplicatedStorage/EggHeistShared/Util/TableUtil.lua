-- EggHeist | Shared/Util/TableUtil.lua
-- Small, allocation-conscious table helpers.

local TableUtil = {}

function TableUtil.DeepCopy(original, seen)
	if type(original) ~= "table" then
		return original
	end
	seen = seen or {}
	if seen[original] then
		return seen[original]
	end
	local copy = {}
	seen[original] = copy
	for k, v in pairs(original) do
		copy[TableUtil.DeepCopy(k, seen)] = TableUtil.DeepCopy(v, seen)
	end
	return copy
end

-- Copies only plain data (string/number/boolean/table). Drops instances, functions.
function TableUtil.CopyData(value, depth)
	depth = depth or 0
	if depth > 12 then
		return nil
	end
	local t = type(value)
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then
		return value
	end
	if t ~= "table" then
		return nil
	end
	local out = {}
	for k, v in pairs(value) do
		local kt = type(k)
		if kt == "string" or kt == "number" or kt == "boolean" then
			out[k] = TableUtil.CopyData(v, depth + 1)
		end
	end
	return out
end

function TableUtil.Keys(tbl)
	local out = {}
	for k, _ in pairs(tbl) do
		out[#out + 1] = k
	end
	return out
end

function TableUtil.Count(tbl)
	local n = 0
	for _, _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

function TableUtil.ShallowMerge(base, overlay)
	local out = {}
	for k, v in pairs(base) do
		out[k] = v
	end
	if overlay then
		for k, v in pairs(overlay) do
			out[k] = v
		end
	end
	return out
end

function TableUtil.Find(list, predicate)
	for i, v in ipairs(list) do
		if predicate(v, i) then
			return v, i
		end
	end
	return nil, nil
end

function TableUtil.RemoveByIndex(list, index)
	if index and list[index] ~= nil then
		table.remove(list, index)
		return true
	end
	return false
end

function TableUtil.Shuffle(list, rng)
	for i = #list, 2, -1 do
		local j
		if rng then
			j = rng:NextInteger(1, i)
		else
			j = math.random(1, i)
		end
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return TableUtil
