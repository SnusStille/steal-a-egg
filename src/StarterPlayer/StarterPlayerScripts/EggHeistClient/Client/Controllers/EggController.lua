-- EggHeist | Client/Controllers/EggController.lua

local EggController = {}
local ctx = nil

function EggController.Init(context)
	ctx = context
	ctx.Net.On("HatchResult", function(result)
		local hatchUI = ctx.UI and ctx.UI.HatchUI
		if hatchUI and result then
			hatchUI.ShowResults(result)
		end
	end)
end

function EggController.BuyEgg(eggId)
	ctx.Net.Fire("BuyEgg", eggId)
end

function EggController.HatchEgg(eggUid)
	ctx.Net.Fire("HatchEgg", eggUid)
end

function EggController.HatchAll()
	ctx.Net.Fire("HatchAll")
end

function EggController.Start()
end

return EggController
