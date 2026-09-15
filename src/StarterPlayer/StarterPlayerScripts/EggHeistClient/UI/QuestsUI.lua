-- EggHeist | Client/UI/QuestsUI.lua
-- Daily + weekly quests with progress and claim buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local QuestsUI = {}
local ctx = nil
local window = nil
local list = nil

local Theme = UIFactory.Theme

function QuestsUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistQuests", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Quests", UDim2.new(0, 480, 0, 440))
	list = UIFactory.ScrollingList(window.Content)

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				QuestsUI.Refresh()
			end
		end)
	end
end

local function questCard(quest)
	local reward = Economy.QuestReward(quest.difficulty or 1)
	local complete = quest.progress >= quest.target
	local card = UIFactory.Card(86)
	local name = UIFactory.Label(quest.text or quest.id, UDim2.new(1, -110, 0, 24), Theme.Text, 14)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = card
	local progress = UIFactory.Label(Format.Compact(quest.progress or 0) .. " / "
		.. Format.Compact(quest.target or 1), UDim2.new(1, -110, 0, 20), Theme.TextDim, 12)
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Position = UDim2.new(0, 0, 0, 26)
	progress.Font = Theme.FontRegular
	progress.Parent = card
	local rewardLabel = UIFactory.Label(Format.Money(reward.Cash) .. "  +"
		.. tostring(reward.Xp) .. " XP" .. (reward.Gems > 0 and ("  +" .. tostring(reward.Gems) .. " G") or ""),
		UDim2.new(1, -110, 0, 20), Theme.Accent, 11)
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
	rewardLabel.Position = UDim2.new(0, 0, 0, 48)
	rewardLabel.Font = Theme.FontRegular
	rewardLabel.Parent = card
	if quest.claimed then
		local done = UIFactory.Label("DONE", UDim2.new(0, 90, 0, 40), Theme.Success, 14)
		done.Position = UDim2.new(1, -98, 0, 14)
		done.Parent = card
	elseif complete then
		local claim = UIFactory.PrimaryButton("CLAIM", function()
			ctx.Controllers.QuestController.Claim(quest.id)
		end)
		claim.Size = UDim2.new(0, 90, 0, 40)
		claim.Position = UDim2.new(1, -98, 0, 14)
		claim.Parent = card
	else
		local _, fill = UIFactory.ProgressBar(card, 8, Theme.Accent)
		fill.Parent.Position = UDim2.new(1, -98, 0, 32)
		fill.Parent.Size = UDim2.new(0, 90, 0, 8)
		UIFactory.SetProgress(fill, (quest.progress or 0) / math.max(1, quest.target or 1))
	end
	return card
end

function QuestsUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	UIFactory.ClearChildren(list, true)
	local quests = snapshot.quests or {}
	local dailies = quests.dailies or {}
	local weeklies = quests.weeklies or {}

	local dailyHeader = UIFactory.Label("DAILY QUESTS", UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	dailyHeader.TextXAlignment = Enum.TextXAlignment.Left
	dailyHeader.Parent = list
	if #dailies == 0 then
		local empty = UIFactory.Label("Check back soon!", UDim2.new(1, 0, 0, 24), Theme.TextDim, 13)
		empty.Parent = list
	end
	for _, quest in ipairs(dailies) do
		questCard(quest).Parent = list
	end
	local weeklyHeader = UIFactory.Label("WEEKLY QUESTS", UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	weeklyHeader.TextXAlignment = Enum.TextXAlignment.Left
	weeklyHeader.Parent = list
	if #weeklies == 0 then
		local empty = UIFactory.Label("Check back soon!", UDim2.new(1, 0, 0, 24), Theme.TextDim, 13)
		empty.Parent = list
	end
	for _, quest in ipairs(weeklies) do
		questCard(quest).Parent = list
	end
end

function QuestsUI.SetVisible(visible)
	if visible then
		QuestsUI.Refresh()
	end
	window.SetVisible(visible)
end

function QuestsUI.Toggle()
	QuestsUI.SetVisible(not window.IsVisible())
end

return QuestsUI
