-- EggHeist | Client/Controllers/EggController.luau

local EggController = {}
local ctx = nil

function EggController.Init(context)
	ctx = context
	ctx.Net.On("HatchResult", function(result)
		local hatchScreen = ctx.Screens and ctx.Screens.HatchScreen
		if hatchScreen and result then
			hatchScreen.ShowResults(result)
		end
	end)
end

function EggController.BuyEgg(eggId, count)
	ctx.Net.Fire("BuyEgg", eggId, count or 1)
end

function EggController.HatchEgg(eggUid)
	ctx.Net.Fire("HatchEgg", eggUid)
end

function EggController.PlaceEgg(eggUid)
	ctx.Net.Fire("PlaceEgg", eggUid)
end

function EggController.PickupEgg(eggUid)
	ctx.Net.Fire("PickupEgg", eggUid)
end

function EggController.HatchAll()
	ctx.Net.Fire("HatchAll")
end

function EggController.Start()
end

return EggController
