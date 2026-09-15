-- EggHeist | Server/Rewards/RewardService.lua
-- Daily login rewards + streaks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))

local RewardService = {}
RewardService.Name = "RewardService"

local registry = nil

function RewardService.Init(_, reg)
	registry = reg
end

local function dayNumber()
	return math.floor(os.time() / 86400)
end

function RewardService.GetDailyStatus(player)
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return nil
	end
	local today = dayNumber()
	local last = profile.daily.lastClaimDay or -1
	return {
		canClaim = last ~= today,
		streak = profile.daily.streak or 0,
		nextDay = ((profile.daily.streak or 0) % 7) + 1,
		rewards = Economy.DailyRewards,
	}
end

function RewardService.ClaimDaily(player)
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return false
	end
	local today = dayNumber()
	local last = profile.daily.lastClaimDay or -1
	if last == today then
		registry.Notify.Send(player, "info", "Already claimed",
			"Come back tomorrow for more!", 3)
		return false
	end
	if last == today - 1 then
		profile.daily.streak = (profile.daily.streak or 0) + 1
	else
		profile.daily.streak = 1
	end
	profile.daily.lastClaimDay = today
	local dayIndex = ((profile.daily.streak - 1) % 7) + 1
	local reward = Economy.DailyRewards[dayIndex]
	registry.Economy.GrantBundle(player, reward, "daily")
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success",
		"Day " .. tostring(profile.daily.streak) .. " reward claimed!",
		"Streak: " .. tostring(profile.daily.streak) .. " day(s). Keep it up!", 6)
	registry.Net.Fire(player, "Fx", "DailyClaim", dayIndex)
	return true
end

function RewardService.Start()
	registry.Net.OnRequest("ClaimDaily", function(player)
		RewardService.ClaimDaily(player)
	end)
end

return RewardService
