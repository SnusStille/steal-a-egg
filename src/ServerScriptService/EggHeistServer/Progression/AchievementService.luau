-- EggHeist | Server/Progression/AchievementService.luau
-- One-time achievements: trigger evaluation + reward claiming.
-- Definitions live in Shared/Config/Achievements.luau (data-driven).
-- State: profile.achievements[achievementId] = { done = bool, claimed = bool }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Achievements = require(ConfigFolder:WaitForChild("Achievements"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))
local TableUtil = require(Shared:WaitForChild("Utilities"):WaitForChild("TableUtil"))

local AchievementService = {}
AchievementService.Name = "AchievementService"

local registry = nil

function AchievementService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

local function sumTiers(tierTable)
	local total = 0
	if type(tierTable) == "table" then
		for _, tier in pairs(tierTable) do
			if type(tier) == "number" then
				total = total + tier
			end
		end
	end
	return total
end

local function conditionsMet(profile, def)
	if def.Stat then
		local value = (profile.stats and profile.stats[def.Stat.Key]) or 0
		if value < (def.Stat.Value or 1) then
			return false
		end
	end
	if def.Level and (profile.level or 1) < def.Level then
		return false
	end
	if def.Collection then
		if TableUtil.Count(profile.collection or {}) < def.Collection then
			return false
		end
	end
	if def.Prestige and ((profile.prestige and profile.prestige.count) or 0) < def.Prestige then
		return false
	end
	if def.Equipped and #(profile.equipped or {}) < def.Equipped then
		return false
	end
	if def.UpgradeTotal then
		local upgrades = profile.base and profile.base.upgrades
		if sumTiers(upgrades) < def.UpgradeTotal then
			return false
		end
	end
	if def.SecurityTotal then
		local security = profile.base and profile.base.security
		if sumTiers(security) < def.SecurityTotal then
			return false
		end
	end
	return true
end

-- Called by other systems when a trigger event fires. Marks newly completed
-- achievements (rewards are claimed via the Quests UI achievements tab).
function AchievementService.Check(player, trigger)
	local profile = profileOf(player)
	if not profile then
		return
	end
	profile.achievements = profile.achievements or {}
	local completedAny = false
	for _, def in ipairs(Achievements.List) do
		if def.Trigger == trigger then
			local state = profile.achievements[def.Id]
			if (not state or not state.done) and conditionsMet(profile, def) then
				profile.achievements[def.Id] = { done = true, claimed = false }
				completedAny = true
				registry.Notify.Send(player, "rare", "Achievement unlocked!",
					def.Name .. " - claim your reward in Quests!", 6)
				registry.Net.Fire(player, "Fx", "Achievement", def.Id)
			end
		end
	end
	if completedAny then
		registry.Data.MarkDirty(player)
	end
end

function AchievementService.Claim(player, achievementId)
	achievementId = Validate.String(achievementId, 32, nil)
	if not achievementId or not Achievements.IsValid(achievementId) then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local state = (profile.achievements or {})[achievementId]
	if not state or not state.done or state.claimed then
		return false
	end
	state.claimed = true
	local def = Achievements.ById[achievementId]
	registry.Economy.GrantBundle(player, def.Reward, "achievement")
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success", "Achievement claimed!", def.Name, 4)
	registry.Net.Fire(player, "Fx", "QuestClaim")
	return true
end

function AchievementService.Start()
	registry.Net.OnRequest("ClaimAchievement", function(player, achievementId)
		AchievementService.Claim(player, achievementId)
	end)
end

return AchievementService
