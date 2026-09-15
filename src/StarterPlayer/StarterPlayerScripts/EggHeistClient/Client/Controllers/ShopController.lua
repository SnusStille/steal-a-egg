-- EggHeist | Client/Controllers/ShopController.lua

local ShopController = {}
local ctx = nil

function ShopController.Init(context)
	ctx = context
end

function ShopController.Prompt(kind, id)
	ctx.Net.Fire("PromptShop", kind, id)
end

function ShopController.Start()
end

return ShopController
