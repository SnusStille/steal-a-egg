-- EggHeist | Client/Screens/TutorialScreen.luau
-- Bottom hint panel guiding new players through onboarding.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Tutorial = require(Shared:WaitForChild("Config"):WaitForChild("Tutorial"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local TutorialScreen = {}
local ctx = nil
local panel = nil
local titleLabel = nil
local bodyLabel = nil
local nextButton = nil
local stepLabel = nil

function TutorialScreen.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistTutorial", 40)
	gui.Parent = playerGui

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, -12)
	panel.Size = UDim2.new(0, 340, 0, 130)
	panel.BackgroundColor3 = UIFactory.Theme.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	UIFactory.Corner(panel, 12)
	UIFactory.Stroke(panel, UIFactory.Theme.Accent, 2)
	UIFactory.Padding(panel, 10)
	panel.Parent = gui

	stepLabel = UIFactory.Label("", UDim2.new(1, 0, 0, 18), UIFactory.Theme.Accent, 11)
	stepLabel.TextXAlignment = Enum.TextXAlignment.Left
	stepLabel.Parent = panel
	titleLabel = UIFactory.Label("", UDim2.new(1, 0, 0, 26), UIFactory.Theme.Text, 16)
	titleLabel.Position = UDim2.new(0, 0, 0, 18)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel
	bodyLabel = UIFactory.Label("", UDim2.new(1, -90, 0, 62), UIFactory.Theme.TextDim, 13)
	bodyLabel.Position = UDim2.new(0, 0, 0, 46)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Font = UIFactory.Theme.FontRegular
	bodyLabel.Parent = panel

	nextButton = UIFactory.PrimaryButton("NEXT", function()
		local snapshot = ctx.Data and ctx.Data.Get()
		if snapshot and snapshot.tutorial then
			local step = Tutorial.Steps[snapshot.tutorial.step or 1]
			if step then
				ctx.Controllers.TutorialController.CompleteStep(step.Id)
			end
		end
	end)
	nextButton.Size = UDim2.new(0, 76, 0, 40)
	nextButton.Position = UDim2.new(1, -84, 1, -48)
	nextButton.Parent = panel
end

function TutorialScreen.OnData(snapshot)
	if not snapshot or not snapshot.tutorial then
		panel.Visible = false
		return
	end
	if snapshot.tutorial.done then
		panel.Visible = false
		return
	end
	local stepIndex = snapshot.tutorial.step or 1
	local step = Tutorial.Steps[stepIndex]
	if not step then
		panel.Visible = false
		return
	end
	panel.Visible = true
	stepLabel.Text = "GUIDE  " .. tostring(stepIndex) .. "/" .. tostring(#Tutorial.Steps)
	titleLabel.Text = step.Title or ""
	bodyLabel.Text = step.Text or ""
	nextButton.Visible = step.Action == "none"
end

return TutorialScreen
