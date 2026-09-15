-- EggHeist | Client/Controllers/BaseController.lua

local BaseController = {}
local ctx = nil

function BaseController.Init(context)
	ctx = context
end

function BaseController.ClaimBase()
	ctx.Net.Fire("ClaimBase")
end

function BaseController.BuyUpgrade(trackId)
	ctx.Net.Fire("BuyUpgrade", trackId)
end

function BaseController.BuySecurity(itemId)
	ctx.Net.Fire("BuySecurity", itemId)
end

function BaseController.ToggleLockdown()
	ctx.Net.Fire("ToggleLockdown")
end

function BaseController.CollectVault()
	ctx.Net.Fire("CollectVault")
end

function BaseController.BuyDecoration(decorId)
	ctx.Net.Fire("BuyDecoration", decorId)
end

function BaseController.Start()
end

return BaseController
