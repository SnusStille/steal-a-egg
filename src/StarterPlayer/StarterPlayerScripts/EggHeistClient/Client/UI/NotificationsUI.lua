-- EggHeist | Client/UI/NotificationsUI.lua
-- Toast notifications (top-right stack).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))
local SoundManager = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundManager"))

local NotificationsUI = {}
local ctx = nil
local stack = nil

local KIND_COLORS = {
	info = Color3.fromRGB(90, 140, 255),
	success = Color3.fromRGB(80, 220, 120),
	warning = Color3.fromRGB(255, 170, 60),
	error = Color3.fromRGB(255, 90, 90),
	rare = Color3.fromRGB(178, 102, 255),
	secret = Color3.fromRGB(60, 255, 210),
}

local KIND_SOUND = {
	info = "Notify",
	success = "Success",
	warning = "Notify",
	error = "Error",
	rare = "Rare",
	secret = "Rare",
}

function NotificationsUI.Init(context)
	ctx = context
	SoundManager.Init(ctx)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistNotifications", 100)
	gui.Parent = playerGui

	stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.new(1, -12, 0, 70)
	stack.Size = UDim2.new(0, 300, 1, -140)
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = stack

	ctx.Net.On("Notify", function(kind, title, message, duration)
		NotificationsUI.Show(kind, title, message, duration)
	end)
end

function NotificationsUI.Show(kind, title, message, duration)
	if not stack then
		return
	end
	kind = KIND_COLORS[kind] and kind or "info"
	-- respect notification setting (errors always show)
	if ctx and ctx.Data then
		local enabled = ctx.Data.GetSetting("notifications")
		if enabled == false and kind ~= "error" then
			return
		end
	end
	duration = duration or 4
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 300, 0, 74)
	toast.BackgroundColor3 = UIFactory.Theme.Panel
	toast.BorderSizePixel = 0
	UIFactory.Corner(toast, 10)
	UIFactory.Stroke(toast, KIND_COLORS[kind], 2)
	toast.Parent = stack

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 5, 1, -16)
	accent.Position = UDim2.new(0, 6, 0, 8)
	accent.BackgroundColor3 = KIND_COLORS[kind]
	accent.BorderSizePixel = 0
	UIFactory.Corner(accent, 3)
	accent.Parent = toast

	local titleLabel = UIFactory.Label(title or "", UDim2.new(1, -24, 0, 24), KIND_COLORS[kind], 15)
	titleLabel.Position = UDim2.new(0, 18, 0, 6)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = toast

	local bodyLabel = UIFactory.Label(message or "", UDim2.new(1, -24, 0, 40), UIFactory.Theme.TextDim, 13)
	bodyLabel.Position = UDim2.new(0, 18, 0, 30)
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.Font = UIFactory.Theme.FontRegular
	bodyLabel.Parent = toast

	SoundManager.Play(KIND_SOUND[kind] or "Notify", 0.5)
	if kind == "secret" or kind == "rare" then
		local playerGui = Effects.LocalPlayerGui()
		if playerGui then
			Effects.Flash(playerGui, KIND_COLORS[kind], 0.5)
		end
	end

	-- slide in
	toast.Position = UDim2.new(0, 320, 0, 0)
	Effects.Tween(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	})
	task.delay(duration, function()
		if toast.Parent then
			Effects.Tween(toast, TweenInfo.new(0.3), {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 320, 0, 0),
			}, function()
				toast:Destroy()
			end)
		end
	end)
	-- cap stack size
	local count = 0
	for _, child in ipairs(stack:GetChildren()) do
		if child:IsA("Frame") then
			count = count + 1
		end
	end
	if count > 5 then
		for _, child in ipairs(stack:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
end

return NotificationsUI
