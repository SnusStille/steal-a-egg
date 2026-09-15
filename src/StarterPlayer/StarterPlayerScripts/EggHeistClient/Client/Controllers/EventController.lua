-- EggHeist | Client/Controllers/EventController.lua
-- Tracks active event + countdown for banners/timers.

local EventController = {}
EventController.Active = nil
EventController.ServerOffset = 0

local ctx = nil

function EventController.Init(context)
	ctx = context
	ctx.Net.On("EventUpdate", function(state)
		if type(state) ~= "table" then
			return
		end
		if state.serverNow then
			EventController.ServerOffset = state.serverNow - os.time()
		end
		if state.active then
			EventController.Active = state
		else
			EventController.Active = nil
		end
		local ui = ctx.UI and ctx.UI.EventBannerUI
		if ui then
			ui.OnEvent(state)
		end
	end)
end

function EventController.TimeLeft()
	if not EventController.Active or not EventController.Active.endsAt then
		return 0
	end
	return math.max(0, EventController.Active.endsAt - (os.time() + EventController.ServerOffset))
end

function EventController.Start()
end

return EventController
