-- EggHeist | Server/Net/NotifyService.lua
-- Thin wrapper for server -> client toast notifications.

local NotifyService = {}
NotifyService.Name = "NotifyService"

local registry = nil

function NotifyService.Init(_, reg)
	registry = reg
end

-- kind: "info" | "success" | "warning" | "error" | "rare" | "secret"
function NotifyService.Send(player, kind, title, message, duration)
	if not registry.Net then
		return
	end
	registry.Net.Fire(player, "Notify", kind or "info", title or "", message or "", duration or 4)
end

function NotifyService.Broadcast(kind, title, message, duration)
	if not registry.Net then
		return
	end
	registry.Net.FireAll("Notify", kind or "info", title or "", message or "", duration or 5)
end

function NotifyService.Start()
end

return NotifyService
