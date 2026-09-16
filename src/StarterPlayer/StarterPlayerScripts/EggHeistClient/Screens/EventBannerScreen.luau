-- EggHeist | Client/Screens/EventBannerScreen.luau
-- Full-width event announcement banner.

local Players = game:GetService("Players")

local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))

local EventBannerScreen = {}
local ctx = nil
local banner = nil
local titleLabel = nil
local descLabel = nil

function EventBannerScreen.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistEvent", 40)
	gui.Parent = playerGui

	banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -120)
	banner.Size = UDim2.new(0, 520, 0, 92)
	banner.BackgroundColor3 = UIFactory.Theme.Panel
	banner.BorderSizePixel = 0
	UIFactory.Corner(banner, 12)
	UIFactory.Stroke(banner, UIFactory.Theme.Accent, 2)
	banner.Parent = gui

	titleLabel = UIFactory.Label("", UDim2.new(1, -20, 0, 34), UIFactory.Theme.Accent, 22)
	titleLabel.Position = UDim2.new(0, 10, 0, 8)
	titleLabel.Parent = banner
	descLabel = UIFactory.Label("", UDim2.new(1, -20, 0, 44), UIFactory.Theme.TextDim, 13)
	descLabel.Position = UDim2.new(0, 10, 0, 44)
	descLabel.TextWrapped = true
	descLabel.Font = UIFactory.Theme.FontRegular
	descLabel.Parent = banner
end

function EventBannerScreen.OnEvent(state)
	if state.active then
		titleLabel.Text = tostring(state.displayName or "Event") .. "!"
		descLabel.Text = tostring(state.description or "")
		Effects.Tween(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 70),
		})
		task.delay(8, function()
			Effects.Tween(banner, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -120),
			})
		end)
	end
end

return EventBannerScreen
