-- EggHeist | Client/Controllers/QuestController.luau

local QuestController = {}
local ctx = nil

function QuestController.Init(context)
	ctx = context
end

function QuestController.Claim(questId)
	ctx.Net.Fire("ClaimQuest", questId)
end

function QuestController.ClaimDaily()
	ctx.Net.Fire("ClaimDaily")
end

function QuestController.ClaimAchievement(achievementId)
	ctx.Net.Fire("ClaimAchievement", achievementId)
end

function QuestController.Start()
end

return QuestController
