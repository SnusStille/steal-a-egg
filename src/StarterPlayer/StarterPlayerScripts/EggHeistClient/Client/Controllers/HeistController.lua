-- EggHeist | Client/Controllers/HeistController.lua
-- Forwards heist state to HeistUI. Plot finder for scouting.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings"))

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
	ctx.Net.On("ScoutResult", function(intel)
		local ui = ctx.UI and ctx.UI.HeistUI
		if ui and ui.OnScout and type(intel) == "table" then
			ui.OnScout(intel)
		end
	end)
end

function HeistController.Grab(target)
	ctx.Net.Fire("GrabLoot", target)
end

function HeistController.Abandon()
	ctx.Net.Fire("AbandonLoot")
end

-- Fires ScoutBase for the nearest plot foundation in scout range.
-- The server validates ownership + range; invalid targets are ignored.
function HeistController.Scout()
	local character = Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local root = Workspace:FindFirstChild("EggHeist")
	local bases = root and root:FindFirstChild("Bases")
	if not bases then
		return
	end
	local range = (Settings.Heist or {}).ScoutRange or 60
	local best, bestDist = nil, range
	for i = 1, Settings.MaxBasePlots or 8 do
		local plot = bases:FindFirstChild(string.format("Plot%02d", i))
		local foundation = plot and plot:FindFirstChild("Foundation")
		if foundation and foundation:IsA("BasePart") then
			local dist = (hrp.Position - foundation.Position).Magnitude
			if dist < bestDist then
				best, bestDist = i, dist
			end
		end
	end
	if best then
		ctx.Net.Fire("ScoutBase", best)
	end
end

function HeistController.IsCarrying()
	return HeistController.State.carrying == true
end

function HeistController.Start()
end

return HeistController
