-- EggHeist | Client/UI/DailyUI.lua
-- 7-day login reward calendar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Eggs = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local DailyUI = {}
local ctx = nil
local window = nil
local grid = nil
local statusLabel = nil
local claimButton = nil

local Theme = UIFactory.Theme

local function rewardText(reward)
	local parts = {}
	if reward.Cash and reward.Cash > 0 then
		parts[#parts + 1] = Format.Money(reward.Cash)
	end
	if reward.Gems and reward.Gems > 0 then
		parts[#parts + 1] = tostring(reward.Gems) .. " Gems"
	end
	if reward.Egg then
		local def = Eggs.ById[reward.Egg]
		parts[#parts + 1] = def and def.DisplayName or reward.Egg
	end
	return table.concat(parts, "\n")
end

function DailyUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistDaily", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Daily Rewards", UDim2.new(0, 520, 0, 400))
	statusLabel = UIFactory.Label("", UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	statusLabel.Parent = window.Content

	local holder = Instance.new("Frame")
	holder.Position = UDim2.new(0, 0, 0, 30)
	holder.Size = UDim2.new(1, 0, 1, -80)
	holder.BackgroundTransparency = 1
	holder.Parent = window.Content
	grid = UIFactory.Grid(holder, UDim2.new(0, 150, 0, 110), 8)

	claimButton = UIFactory.PrimaryButton("CLAIM", function()
		ctx.Controllers.QuestController.ClaimDaily()
	end)
	claimButton.Size = UDim2.new(0, 220, 0, 42)
	claimButton.Position = UDim2.new(0.5, -110, 1, -48)
	claimButton.Parent = window.Content

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				DailyUI.Refresh()
			end
		end)
	end
end

function DailyUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	UIFactory.ClearChildren(grid, true)
	local daily = snapshot.daily or {}
	local today = math.floor(os.time() / 86400)
	local canClaim = (daily.lastClaimDay or -1) ~= today
	local streak = daily.streak or 0
	local nextDay = (streak % 7) + 1

	statusLabel.Text = canClaim
		and ("Day " .. tostring(streak + 1) .. " reward ready! (Streak: " .. tostring(streak) .. ")")
		or ("Claimed! Come back tomorrow. (Streak: " .. tostring(streak) .. ")")
	claimButton.Visible = canClaim

	for day = 1, 7 do
		local reward = Economy.DailyRewards[day]
		local isToday = canClaim and day == nextDay
		local isPast = (not canClaim and day <= ((streak - 1) % 7 + 1))
			or (canClaim and day < nextDay and streak > 0 and false) -- claim-day cells stay bright
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 150, 0, 110)
		card.BackgroundColor3 = Theme.Card
		card.BorderSizePixel = 0
		UIFactory.Corner(card, 8)
		UIFactory.Padding(card, 6)
		if isToday then
			UIFactory.Stroke(card, Theme.Accent, 3)
		elseif isPast then
			UIFactory.Stroke(card, Theme.Success, 1)
		end
		local title = UIFactory.Label("Day " .. tostring(day), UDim2.new(1, 0, 0, 22),
			isToday and Theme.Accent or Theme.Text, 14)
		title.Parent = card
		local body = UIFactory.Label(rewardText(reward), UDim2.new(1, 0, 0, 66),
			Theme.TextDim, 12)
		body.Position = UDim2.new(0, 0, 0, 26)
		body.Font = Theme.FontRegular
		body.Parent = card
		card.Parent = grid
	end
end

function DailyUI.SetVisible(visible)
	if visible then
		DailyUI.Refresh()
	end
	window.SetVisible(visible)
end

function DailyUI.Toggle()
	DailyUI.SetVisible(not window.IsVisible())
end

return DailyUI
