-- TravelUI: fast-travel window (server validates + rate-limits).
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Players = game:GetService("Players")

local TravelUI = {}

local DESTINATIONS = {
	{ Id = "base", Label = "My Base" },
	{ Id = "spawn", Label = "Spawn Plaza" },
	{ Id = "market", Label = "Egg Market" },
	{ Id = "event", Label = "Event Grounds" },
	{ Id = "heist", Label = "Heist Zone" },
	{ Id = "extraction", Label = "Extraction" },
}

local window = nil
local ctxRef = nil

function TravelUI.Init(ctx)
	ctxRef = ctx
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistTravel", 12)
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "FAST TRAVEL", UDim2.new(0, 360, 0, 380))
	local note = UIFactory.Label("10s cooldown. No travel with stolen loot!",
		UDim2.new(1, 0, 0, 22), UIFactory.Theme.TextDim, 12)
	note.Parent = window.Content

	local grid = UIFactory.Grid(window.Content, UDim2.new(0, 150, 0, 52), 8)
	grid.Position = UDim2.new(0, 0, 0, 28)
	grid.Size = UDim2.new(1, 0, 1, -28)
	for _, dest in ipairs(DESTINATIONS) do
		local button = UIFactory.PrimaryButton(dest.Label, function()
			if ctxRef and ctxRef.Net then
				ctxRef.Net.Fire("Travel", dest.Id)
			end
		end)
		button.Parent = grid
	end
end

function TravelUI.Toggle()
	if window then
		window.Toggle()
	end
end

function TravelUI.SetVisible(visible)
	if window then
		window.SetVisible(visible)
	end
end

return TravelUI
