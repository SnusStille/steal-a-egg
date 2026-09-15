-- EggHeist | Shared/Util/Maid.lua
-- Cleanup helper: connections, instances, functions, signals.

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
	if task == nil then
		return nil
	end
	self._tasks[#self._tasks + 1] = task
	return task
end

function Maid:DoCleaning()
	for _, task in ipairs(self._tasks) do
		local t = typeof(task)
		if t == "RBXScriptConnection" then
			task:Disconnect()
		elseif t == "Instance" then
			task:Destroy()
		elseif t == "function" then
			local ok, err = pcall(task)
			if not ok then
				warn("[EggHeist] Maid task error: " .. tostring(err))
			end
		elseif t == "table" then
			if type(task.Disconnect) == "function" then
				pcall(function() task:Disconnect() end)
			elseif type(task.Destroy) == "function" then
				pcall(function() task:Destroy() end)
			elseif type(task.destroy) == "function" then
				pcall(function() task:destroy() end)
			end
		end
	end
	self._tasks = {}
end

Maid.Destroy = Maid.DoCleaning

return Maid
