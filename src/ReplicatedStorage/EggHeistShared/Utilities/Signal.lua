-- EggHeist | Shared/Utilities/Signal.lua
-- Minimal event signal (no RBXScriptConnection leaks when used with Maid).

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {}, _nextId = 0 }, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")
	self._nextId = self._nextId + 1
	local id = self._nextId
	self._listeners[id] = callback
	local signal = self
	return {
		Connected = true,
		Disconnect = function(conn)
			if conn.Connected then
				conn.Connected = false
				signal._listeners[id] = nil
			end
		end,
	}
end

function Signal:Fire(...)
	for _, callback in pairs(self._listeners) do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[EggHeist] Signal handler error: " .. tostring(err))
		end
	end
end

function Signal:DisconnectAll()
	self._listeners = {}
end

function Signal:Destroy()
	self:DisconnectAll()
end

return Signal
