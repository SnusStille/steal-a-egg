-- EggHeist | Client/UI/QuestsUI.lua
-- Daily + weekly quests with progress and claim buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Achievements = require(ConfigFolder:WaitForChild("Achievements"))
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Gadgets = require(ConfigFolder:WaitForChild("Gadgets"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local QuestsUI = {}
local ctx = nil
local window = nil
local pages = {}
local tabButtons = {}
local currentTab = "Quests"

local Theme = UIFactory.Theme
local TABS = { "Quests", "Achievements" }

function QuestsUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistQuests", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Quests & Achievements", UDim2.new(0, 500, 0, 450))

	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window.Content
	for i, tab in ipairs(TABS) do
		local button = UIFactory.Button(tab, function()
			QuestsUI.ShowTab(tab)
		end)
		button.Size = UDim2.new(1 / #TABS, -6, 1, 0)
		button.Position = UDim2.new((i - 1) / #TABS, 3, 0, 0)
		button.Parent = tabBar
		tabButtons[tab] = button
	end

	local pageHolder = Instance.new("Frame")
	pageHolder.Position = UDim2.new(0, 0, 0, 42)
	pageHolder.Size = UDim2.new(1, 0, 1, -42)
	pageHolder.BackgroundTransparency = 1
	pageHolder.Parent = window.Content
	for _, tab in ipairs(TABS) do
		local page = Instance.new("Frame")
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = pageHolder
		pages[tab] = page
		UIFactory.ScrollingList(page)
	end
	QuestsUI.ShowTab("Quests")

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				QuestsUI.Refresh()
			end
		end)
	end
end

function QuestsUI.ShowTab(tab)
	currentTab = tab
	for name, page in pairs(pages) do
		page.Visible = name == tab
	end
	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = name == tab and Theme.Accent or Theme.Button
		button.TextColor3 = name == tab and Color3.fromRGB(30, 25, 10) or Theme.Text
	end
end

local function rewardText(reward)
	reward = reward or {}
	local parts = {}
	if reward.Cash and reward.Cash > 0 then
		parts[#parts + 1] = Format.Money(reward.Cash)
	end
	if reward.Gems and reward.Gems > 0 then
		parts[#parts + 1] = tostring(reward.Gems) .. " G"
	end
	if reward.Xp and reward.Xp > 0 then
		parts[#parts + 1] = "+" .. tostring(reward.Xp) .. " XP"
	end
	if reward.Egg then
		local def = Eggs.ById[reward.Egg]
		parts[#parts + 1] = def and def.DisplayName or reward.Egg
	end
	if reward.Gadget then
		local def = Gadgets.ById[reward.Gadget]
		local count = reward.GadgetCount or 1
		parts[#parts + 1] = (def and def.DisplayName or reward.Gadget)
			.. (count > 1 and (" x" .. tostring(count)) or "")
	end
	return table.concat(parts, "  +  ")
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
	local list = pages.Quests:FindFirstChildOfClass("ScrollingFrame")
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

	-- Achievements page
	local achPage = pages.Achievements:FindFirstChildOfClass("ScrollingFrame")
	UIFactory.ClearChildren(achPage, true)
	local states = snapshot.achievements or {}
	local doneCount = 0
	for _, def in ipairs(Achievements.List) do
		local state = states[def.Id]
		if state and state.done then
			doneCount = doneCount + 1
		end
	end
	local header = UIFactory.Label("ACHIEVEMENTS  " .. tostring(doneCount)
		.. "/" .. tostring(#Achievements.List), UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = achPage
	for _, def in ipairs(Achievements.List) do
		local state = states[def.Id]
		local done = state and state.done
		local claimed = state and state.claimed
		local card = UIFactory.Card(86)
		local name = UIFactory.Label(def.Name, UDim2.new(1, -110, 0, 24),
			done and Theme.Text or Theme.TextDim, 14)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = card
		local text = UIFactory.Label(def.Text or "", UDim2.new(1, -110, 0, 22),
			Theme.TextDim, 12)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Position = UDim2.new(0, 0, 0, 26)
		text.Font = Theme.FontRegular
		text.Parent = card
		local reward = UIFactory.Label(rewardText(def.Reward),
			UDim2.new(1, -110, 0, 20), Theme.Accent, 11)
		reward.TextXAlignment = Enum.TextXAlignment.Left
		reward.Position = UDim2.new(0, 0, 0, 50)
		reward.Font = Theme.FontRegular
		reward.Parent = card
		if claimed then
			local label = UIFactory.Label("DONE", UDim2.new(0, 90, 0, 40), Theme.Success, 14)
			label.Position = UDim2.new(1, -98, 0, 14)
			label.Parent = card
		elseif done then
			local claim = UIFactory.PrimaryButton("CLAIM", function()
				ctx.Controllers.QuestController.ClaimAchievement(def.Id)
			end)
			claim.Size = UDim2.new(0, 90, 0, 40)
			claim.Position = UDim2.new(1, -98, 0, 14)
			claim.Parent = card
		else
			local label = UIFactory.Label("LOCKED", UDim2.new(0, 90, 0, 40), Theme.TextDim, 12)
			label.Position = UDim2.new(1, -98, 0, 14)
			label.Font = Theme.FontRegular
			label.Parent = card
		end
		card.Parent = achPage
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
