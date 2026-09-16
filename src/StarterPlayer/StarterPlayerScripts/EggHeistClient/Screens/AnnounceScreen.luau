-- EggHeist | Client/Screens/AnnounceScreen.luau
-- Big queued announcement banners: event starts, secret hatches, big
-- heists, prestiges. Fed by the Fx "Announce" channel via MainScreen.
-- One banner at a time, auto-sized for phone screens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Juice = require(Shared:WaitForChild("Config"):WaitForChild("Juice"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))
local SoundManager = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundManager"))

local AnnounceScreen = {}
local gui = nil
local queue = {}
local showing = false

local Theme = UIFactory.Theme

function AnnounceScreen.Init(_ctx)
	local player = Players.LocalPlayer
	local playerGui = player and player:WaitForChild("PlayerGui")
	if not playerGui then
		return
	end
	gui = UIFactory.ScreenGui("EggHeistAnnounce", 60)
	gui.Parent = playerGui
end

local function pump()
	if showing or gui == nil or #queue == 0 then
		return
	end
	showing = true
	local item = table.remove(queue, 1)
	local style = Juice.Announce[item.style] or Juice.Announce.info
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0.1, 0)
	banner.Size = UDim2.new(0.85, 0, 0, 92)
	banner.BackgroundColor3 = Theme.Panel
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.Parent = gui
	UIFactory.Corner(banner, 12)
	UIFactory.Stroke(banner, style.Color, 2)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.BackgroundColor3 = style.Color
	bar.BorderSizePixel = 0
	bar.Parent = banner
	UIFactory.Corner(bar, 6)
	local title = UIFactory.Label(item.title, UDim2.new(1, -24, 0, 44), style.Color, 30)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 10)
	title.TextScaled = true
	title.Parent = banner
	local sub = UIFactory.Label(item.sub, UDim2.new(1, -24, 0, 26), Theme.Text, 15)
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0, 56)
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	sub.Parent = banner
	SoundManager.Play(style.Sound, 0.7)
	Effects.Pop(banner, 1.04)
	task.delay(item.duration or style.Duration or 5, function()
		if banner and banner.Parent then
			Effects.Tween(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 }, function()
				if banner then
					banner:Destroy()
				end
			end)
		end
		showing = false
		pump()
	end)
end

--- Queue a banner. style: key of Juice.Announce (info/event/rare/...).
function AnnounceScreen.Announce(style, title, sub, duration)
	if gui == nil then
		return
	end
	queue[#queue + 1] = {
		style = style or "info",
		title = tostring(title or ""),
		sub = tostring(sub or ""),
		duration = tonumber(duration),
	}
	while #queue > 3 do
		table.remove(queue, 1)
	end
	pump()
end

return AnnounceScreen
