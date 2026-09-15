-- EggHeist | Server/Rewards/CollectionService.lua
-- Collection milestones: claim-once rewards for unique discoveries.
-- Definitions live in Shared/Config/Collection.lua (data-driven).
-- State: profile.collectionRewards[milestoneIndex] = true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Collection = require(ConfigFolder:WaitForChild("Collection"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))
local TableUtil = require(Shared:WaitForChild("Utilities"):WaitForChild("TableUtil"))

local CollectionService = {}
CollectionService.Name = "CollectionService"

local registry = nil

function CollectionService.Init(_, reg)
	registry = reg
end

function CollectionService.UniqueCount(player)
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return 0
	end
	return TableUtil.Count(profile.collection or {})
end

function CollectionService.ClaimMilestone(player, milestoneIndex)
	milestoneIndex = Validate.ClampNumber(tonumber(milestoneIndex), 1, #Collection.Milestones, nil)
	if not milestoneIndex then
		return false
	end
	milestoneIndex = math.floor(milestoneIndex)
	local milestone = Collection.Milestones[milestoneIndex]
	if not milestone then
		return false
	end
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return false
	end
	profile.collectionRewards = profile.collectionRewards or {}
	if profile.collectionRewards[milestoneIndex] then
		return false
	end
	if TableUtil.Count(profile.collection or {}) < milestone.Count then
		registry.Notify.Send(player, "warning", "Not yet",
			"Discover " .. tostring(milestone.Count) .. " unique entries first!", 4)
		return false
	end
	profile.collectionRewards[milestoneIndex] = true
	registry.Economy.GrantBundle(player, milestone.Reward, "collection")
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success", "Milestone claimed!",
		tostring(milestone.Count) .. " discoveries — nice collection!", 5)
	registry.Net.Fire(player, "Fx", "QuestClaim")
	return true
end

function CollectionService.Start()
	registry.Net.OnRequest("ClaimMilestone", function(player, milestoneIndex)
		CollectionService.ClaimMilestone(player, milestoneIndex)
	end)
end

return CollectionService
