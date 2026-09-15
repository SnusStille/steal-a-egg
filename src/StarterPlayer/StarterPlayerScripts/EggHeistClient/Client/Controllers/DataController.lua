-- EggHeist | Client/Controllers/DataController.lua
-- Local profile cache, kept fresh by server DataSync pushes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Signal = require(Shared:WaitForChild("Utilities"):WaitForChild("Signal"))

local DataController = {}
DataController.Data = nil
DataController.Ready = false
DataController.Changed = Signal.new()

local ctx = nil

function DataController.Init(context)
	ctx = context
	ctx.Net.On("DataSync", function(snapshot)
		DataController.Data = snapshot
		DataController.Ready = true
		DataController.Changed:Fire(snapshot)
	end)
	-- initial fetch (retry until profiles load server-side)
	task.spawn(function()
		for _ = 1, 60 do
			if DataController.Ready then
				break
			end
			local snapshot = ctx.Net.Invoke("GetData")
			if snapshot then
				DataController.Data = snapshot
				DataController.Ready = true
				DataController.Changed:Fire(snapshot)
				break
			end
			task.wait(1)
		end
	end)
end

function DataController.Get()
	return DataController.Data
end

function DataController.GetSetting(key)
	local data = DataController.Data
	if data and data.settings and data.settings[key] ~= nil then
		return data.settings[key]
	end
	return nil
end

function DataController.Start()
end

return DataController
