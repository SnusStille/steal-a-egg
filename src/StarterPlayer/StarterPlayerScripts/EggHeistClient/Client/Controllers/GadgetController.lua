-- EggHeist | Client/Controllers/GadgetController.lua
-- Gadget shop intent: buy + use. All effects resolve server-side.

local GadgetController = {}
local ctx = nil

function GadgetController.Init(context)
	ctx = context
end

function GadgetController.Buy(gadgetId)
	ctx.Net.Fire("BuyGadget", gadgetId)
end

function GadgetController.Use(gadgetId)
	ctx.Net.Fire("UseGadget", gadgetId)
end

function GadgetController.Start()
end

return GadgetController
