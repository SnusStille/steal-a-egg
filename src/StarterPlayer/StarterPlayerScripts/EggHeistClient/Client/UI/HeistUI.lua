-- EggHeist | Client/UI/HeistUI.lua
-- Heist HUD: carrying indicator, breach/extraction channels, intruder alerts.

local Players = game:GetService("Players")

local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))

local HeistUI = {}
local ctx = nil
local carryFrame = nil
local carryLabel = nil
local channelFrame = nil
local channelFill = nil
local channelLabel = nil
local alertFrame = nil
local alertLabel = nil
local channelEndsAt = 0
local channelTotal = 1

local Theme = UIFactory.Theme

function HeistUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistHeist", 30)
	gui.Parent = playerGui

	-- carrying indicator (bottom center, above claim button area)
	carryFrame = Instance.new("Frame")
	carryFrame.AnchorPoint = Vector2.new(0.5, 1)
	carryFrame.Position = UDim2.new(0.5, 0, 1, -150)
	carryFrame.Size = UDim2.new(0, 320, 0, 60)
	carryFrame.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	carryFrame.BorderSizePixel = 0
	carryFrame.Visible = false
	UIFactory.Corner(carryFrame, 10)
	UIFactory.Stroke(carryFrame, Color3.fromRGB(255, 80, 80), 2)
	carryFrame.Parent = gui
	carryLabel = UIFactory.Label("CARRYING LOOT", UDim2.new(1, -16, 1, 0), Color3.fromRGB(255, 160, 160), 15)
	carryLabel.Position = UDim2.new(0, 8, 0, 0)
	carryLabel.TextWrapped = true
	carryLabel.Parent = carryFrame

	-- channel bar (center)
	channelFrame = Instance.new("Frame")
	channelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	channelFrame.Position = UDim2.new(0.5, 0, 0.62, 0)
	channelFrame.Size = UDim2.new(0, 300, 0, 46)
	channelFrame.BackgroundColor3 = Theme.Panel
	channelFrame.BorderSizePixel = 0
	channelFrame.Visible = false
	UIFactory.Corner(channelFrame, 10)
	channelFrame.Parent = gui
	channelLabel = UIFactory.Label("BREACHING...", UDim2.new(1, 0, 0, 20), Theme.Accent, 13)
	channelLabel.Parent = channelFrame
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0, 12, 0, 24)
	barBack.Size = UDim2.new(1, -24, 0, 12)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	barBack.BorderSizePixel = 0
	UIFactory.Corner(barBack, 6)
	barBack.Parent = channelFrame
	channelFill = Instance.new("Frame")
	channelFill.Size = UDim2.new(0, 0, 1, 0)
	channelFill.BackgroundColor3 = Theme.Accent
	channelFill.BorderSizePixel = 0
	UIFactory.Corner(channelFill, 6)
	channelFill.Parent = barBack

	-- intruder alert (top center flash)
	alertFrame = Instance.new("Frame")
	alertFrame.AnchorPoint = Vector2.new(0.5, 0)
	alertFrame.Position = UDim2.new(0.5, 0, 68)
	alertFrame.Size = UDim2.new(0, 340, 0, 40)
	alertFrame.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	alertFrame.BorderSizePixel = 0
	alertFrame.Visible = false
	UIFactory.Corner(alertFrame, 10)
	alertFrame.Parent = gui
	alertLabel = UIFactory.Label("", UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 255, 255), 14)
	alertLabel.Parent = alertFrame

	-- channel ticker
	task.spawn(function()
		while true do
			task.wait(0.05)
			if channelFrame.Visible then
				local left = channelEndsAt - os.clock()
				if left <= 0 then
					channelFrame.Visible = false
				else
					local done = 1 - (left / channelTotal)
					channelFill.Size = UDim2.new(math.max(0, math.min(1, done)), 0, 1, 0)
				end
			end
		end
	end)
end

function HeistUI.OnState(state)
	if state.carrying == true then
		carryFrame.Visible = true
		carryLabel.Text = "CARRYING LOOT! Get to EXTRACTION (green pad in the vault grounds)!"
		Effects.Pop(carryFrame, 1.05)
	elseif state.carrying == false then
		carryFrame.Visible = false
	end
	if state.channeling == true then
		channelFrame.Visible = true
		channelLabel.Text = "BREACHING... STAY CLOSE!"
		channelTotal = tonumber(state.duration) or 3
		channelEndsAt = os.clock() + channelTotal
	elseif state.channeling == false then
		channelFrame.Visible = false
	end
	if state.extracted == true then
		carryFrame.Visible = false
		channelFrame.Visible = false
	end
	if state.alert == true then
		alertLabel.Text = "INTRUDER: " .. tostring(state.intruder or "unknown") .. " is in your base!"
		alertFrame.Visible = true
		Effects.Pop(alertFrame, 1.05)
		task.delay(5, function()
			alertFrame.Visible = false
		end)
	end
end

return HeistUI
