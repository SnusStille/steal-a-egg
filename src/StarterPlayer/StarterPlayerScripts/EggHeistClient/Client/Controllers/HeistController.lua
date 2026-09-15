-- EggHeist | Client/Controllers/HeistController.lua
-- Forwards heist state to HeistUI.

local HeistController = {}
HeistController.State = { carrying = false }

local ctx = nil

function HeistController.Init(context)
	ctx = context
	ctx.Net.On("HeistUpdate", function(state)
		if type(state) == "table" then
			for k, v in pairs(state) do
				HeistController.State[k] = v
			end
			local ui = ctx.UI and ctx.UI.HeistUI
			if ui then
				ui.OnState(HeistController.State)
			end
		end
	end)
end

function HeistController.Grab()
	ctx.Net.Fire("GrabLoot")
end

function HeistController.IsCarrying()
	return HeistController.State.carrying == true
end

function HeistController.Start()
end

return HeistController
