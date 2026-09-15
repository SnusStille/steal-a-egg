-- EggHeist | Server/World/TravelService.luau
-- Fast travel between districts. Server-authoritative: fixed destinations,
-- 10s cooldown, and no teleporting while carrying stolen loot.

local Players = game:GetService("Players")

local TravelService = {}
TravelService.Name = "TravelService"

local registry = nil
local cooldownUntil = {}

local COOLDOWN = 10

function TravelService.Init(_, reg)
	registry = reg
end

local function resolveDestination(player, destId)
	if destId == "spawn" then
		return registry.World.GetSpawnCFrame()
	elseif destId == "extraction" then
		local pad = registry.World.GetExtractionPad()
		if pad and pad:IsA("BasePart") then
			return pad.CFrame + Vector3.new(0, 5, 0)
		end
		return nil
	elseif destId == "market" then
		return registry.World.GetMarketCFrame()
	elseif destId == "event" then
		return registry.World.GetEventCFrame()
	elseif destId == "heist" then
		return registry.World.GetHeistCFrame()
	elseif destId == "grotto" or destId == "beach" then
		if registry.Activities and registry.Activities.GetSpotCFrame then
			return registry.Activities.GetSpotCFrame(destId)
		end
		return nil
	elseif destId == "base" then
		local plotIndex = registry.Base.GetPlotOf(player)
		local plot = plotIndex and registry.World.GetPlotModel(plotIndex)
		local foundation = plot and plot:FindFirstChild("Foundation")
		if foundation and foundation:IsA("BasePart") then
			return foundation.CFrame + Vector3.new(0, foundation.Size.Y / 2 + 4, 0)
		end
		return nil
	end
	return nil
end

function TravelService.Start()
	registry.Net.OnRequest("Travel", function(player, destId)
		if type(destId) ~= "string" then
			return
		end
		if registry.Heist and registry.Heist.IsCarrying(player) then
			registry.Notify.Send(player, "warning", "Too heavy!",
				"Can't fast-travel while carrying stolen loot.", 4)
			return
		end
		local now = os.clock()
		if (cooldownUntil[player.UserId] or 0) > now then
			local left = math.ceil((cooldownUntil[player.UserId] or 0) - now)
			registry.Notify.Send(player, "info", "Warming up",
				"Travel ready in " .. tostring(left) .. "s.", 3)
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local dest = resolveDestination(player, destId)
		if not dest then
			if destId == "base" then
				registry.Notify.Send(player, "warning", "No base yet",
					"Claim a plot first!", 4)
			else
				registry.Notify.Send(player, "warning", "Unknown destination",
					"No teleport anchor for that district.", 4)
			end
			return
		end
		cooldownUntil[player.UserId] = now + COOLDOWN
		hrp.CFrame = dest
		registry.Net.Fire(player, "Fx", "Travel")
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldownUntil[player.UserId] = nil
	end)
end

return TravelService
