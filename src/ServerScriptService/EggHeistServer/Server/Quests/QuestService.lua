-- EggHeist | Server/Quests/QuestService.lua
-- Daily/weekly quests: assignment, progress tracking, rewards.
-- Also hosts the tutorial hook (server-confirmed onboarding steps).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Quests = require(ConfigFolder:WaitForChild("Quests"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Tutorial = require(ConfigFolder:WaitForChild("Tutorial"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))
local TableUtil = require(Shared:WaitForChild("Utilities"):WaitForChild("TableUtil"))

local QuestService = {}
QuestService.Name = "QuestService"

local registry = nil
local rng = Random.new()
-- Server-side only: which completion toasts were already shown.
-- (Never stored on the quest itself: quest tables are persisted to DataStores.)
local toastShown = {} -- ["userId:questId"] = true

function QuestService.Init(_, reg)
	registry = reg
	-- Tutorial hook used by other services (Egg, Pet, Base)
	registry.TutorialHook = function(player, action)
		QuestService.TutorialAction(player, action)
	end
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

local function dayNumber()
	return math.floor(os.time() / 86400)
end

local function weekNumber()
	return math.floor(os.time() / (86400 * 7))
end

local function pickQuests(pool, count)
	local indices = {}
	for i = 1, #pool do
		indices[#indices + 1] = i
	end
	TableUtil.Shuffle(indices, rng)
	local out = {}
	for i = 1, math.min(count, #indices) do
		local def = pool[indices[i]]
		out[#out + 1] = {
			id = def.Id,
			type = def.Type,
			target = def.Target,
			difficulty = def.Difficulty,
			text = def.Text,
			progress = 0,
			claimed = false,
		}
	end
	return out
end

function QuestService.EnsureQuests(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local changed = false
	if profile.quests.dailyDate ~= tostring(dayNumber()) then
		profile.quests.dailyDate = tostring(dayNumber())
		profile.quests.dailies = pickQuests(Quests.DailyPool, Quests.DailiesPerDay)
		changed = true
	end
	if profile.quests.weeklyKey ~= tostring(weekNumber()) then
		profile.quests.weeklyKey = tostring(weekNumber())
		profile.quests.weeklies = pickQuests(Quests.WeeklyPool, Quests.WeekliesPerWeek)
		changed = true
	end
	-- hygiene: drop legacy toast flags persisted by older versions
	for _, quest in ipairs(profile.quests.dailies or {}) do
		quest._toast = nil
	end
	for _, quest in ipairs(profile.quests.weeklies or {}) do
		quest._toast = nil
	end
	if changed then
		registry.Data.MarkDirty(player)
	end
end

-- Special-case progress types that are "current value" rather than cumulative
local function applyProgress(quest, qtype, amount, player)
	if qtype ~= quest.type then
		return false
	end
	if quest.claimed and quest.progress >= quest.target then
		return false
	end
	if qtype == "EquipPets" then
		-- progress = current equipped count
		local profile = profileOf(player)
		local count = profile and #profile.equipped or 0
		if count > quest.progress then
			quest.progress = math.min(quest.target, count)
			return true
		end
		return false
	end
	if amount and amount > 0 then
		quest.progress = math.min(quest.target, quest.progress + amount)
		return true
	end
	return false
end

function QuestService.AddProgress(player, qtype, amount)
	local profile = profileOf(player)
	if not profile then
		return
	end
	QuestService.EnsureQuests(player)
	local changed = false
	for _, quest in ipairs(profile.quests.dailies or {}) do
		if applyProgress(quest, qtype, amount, player) then
			changed = true
		end
	end
	for _, quest in ipairs(profile.quests.weeklies or {}) do
		if applyProgress(quest, qtype, amount, player) then
			changed = true
		end
	end
	if changed then
		registry.Data.MarkDirty(player)
		-- completion toast (unclaimed, so they visit the quest UI)
		for _, quest in ipairs(profile.quests.dailies or {}) do
			if quest.type == qtype and quest.progress >= quest.target and not quest.claimed and not quest._toast then
				quest._toast = true
				registry.Notify.Send(player, "success", "Quest complete!",
					quest.text .. " - claim your reward!", 5)
			end
		end
		for _, quest in ipairs(profile.quests.weeklies or {}) do
			if quest.type == qtype and quest.progress >= quest.target and not quest.claimed and not quest._toast then
				quest._toast = true
				registry.Notify.Send(player, "success", "Weekly quest complete!",
					quest.text .. " - claim your reward!", 5)
			end
		end
	end
end

function QuestService.ClaimQuest(player, questId)
	questId = Validate.String(questId, 32, nil)
	if not questId then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	QuestService.EnsureQuests(player)
	local quest = nil
	for _, q in ipairs(profile.quests.dailies or {}) do
		if q.id == questId then
			quest = q
			break
		end
	end
	if not quest then
		for _, q in ipairs(profile.quests.weeklies or {}) do
			if q.id == questId then
				quest = q
				break
			end
		end
	end
	if not quest or quest.claimed or quest.progress < quest.target then
		return false
	end
	quest.claimed = true
	local reward = Economy.QuestReward(quest.difficulty or 1)
	if reward.Cash > 0 then
		registry.Economy.AddCash(player, reward.Cash, "quest")
	end
	if reward.Gems > 0 then
		registry.Economy.AddGems(player, reward.Gems, "quest")
	end
	if reward.Xp > 0 then
		registry.Economy.AddXp(player, reward.Xp)
	end
	profile.stats.questsDone = (profile.stats.questsDone or 0) + 1
	if registry.Achievement then
		registry.Achievement.Check(player, "QuestClaim")
	end
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success", "Reward claimed!",
		quest.text, 4)
	registry.Net.Fire(player, "Fx", "QuestClaim")
	return true
end

--------------------------------------------------------------------------------
-- Tutorial
--------------------------------------------------------------------------------

function QuestService.TutorialAction(player, action)
	local profile = profileOf(player)
	if not profile or profile.tutorial.done then
		return
	end
	local stepIndex = profile.tutorial.step or 1
	local step = Tutorial.Steps[stepIndex]
	if not step then
		profile.tutorial.done = true
		registry.Data.MarkDirty(player)
		return
	end
	-- "none" steps advance via CompleteTutorialStep remote (client button)
	if step.Action ~= action then
		return
	end
	QuestService.AdvanceTutorial(player)
end

function QuestService.AdvanceTutorial(player)
	local profile = profileOf(player)
	if not profile or profile.tutorial.done then
		return
	end
	profile.tutorial.step = (profile.tutorial.step or 1) + 1
	if profile.tutorial.step > #Tutorial.Steps then
		profile.tutorial.done = true
		-- graduation gift
		registry.Economy.AddGems(player, 10, "tutorial")
		registry.Economy.AddCash(player, 500, "tutorial")
		registry.Notify.Send(player, "success", "Tutorial complete!",
			"You're on your own now, heister. +$500, +10 gems!", 6)
	end
	registry.Data.MarkDirty(player)
end

function QuestService.Start()
	registry.Net.OnRequest("ClaimQuest", function(player, questId)
		QuestService.ClaimQuest(player, questId)
	end)
	registry.Net.OnRequest("CompleteTutorialStep", function(player, stepId)
		stepId = Validate.String(stepId, 32, nil)
		local profile = profileOf(player)
		if not profile or profile.tutorial.done then
			return
		end
		local stepIndex = profile.tutorial.step or 1
		local step = Tutorial.Steps[stepIndex]
		if step and step.Id == stepId and step.Action == "none" then
			QuestService.AdvanceTutorial(player)
		end
	end)
end

return QuestService
