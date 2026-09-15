-- EggHeist | Client/Controllers/TradeController.lua
-- Trade intents + last TradeUpdate state. The server owns all validation;
-- this only forwards taps and caches the latest trade snapshot for TradeUI.

local TradeController = {}
TradeController.State = { phase = "Closed" }

local ctx = nil

function TradeController.Init(context)
	ctx = context
	ctx.Net.On("TradeUpdate", function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.phase == "Closed" then
			TradeController.State = { phase = "Closed", reason = payload.reason }
		else
			TradeController.State = payload
		end
		local ui = ctx.UI and ctx.UI.TradeUI
		if ui and ui.OnUpdate then
			ui.OnUpdate(TradeController.State)
		end
	end)
end

function TradeController.Request(userId)
	ctx.Net.Fire("TradeRequest", userId)
end

function TradeController.Accept()
	ctx.Net.Fire("TradeAccept")
end

function TradeController.Decline()
	ctx.Net.Fire("TradeDecline")
end

function TradeController.OfferAdd(kind, ref, amount)
	ctx.Net.Fire("TradeOfferAdd", kind, ref, amount)
end

function TradeController.OfferRemove(kind, ref)
	ctx.Net.Fire("TradeOfferRemove", kind, ref)
end

function TradeController.Lock()
	ctx.Net.Fire("TradeLock")
end

function TradeController.Confirm()
	ctx.Net.Fire("TradeConfirm")
end

function TradeController.Cancel()
	ctx.Net.Fire("TradeCancel")
end

function TradeController.Start()
end

return TradeController
