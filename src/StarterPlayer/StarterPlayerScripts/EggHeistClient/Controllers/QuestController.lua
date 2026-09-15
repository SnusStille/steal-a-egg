-- EggHeist | Client/Controllers/QuestController.lua

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

function QuestController.Start()
end

return QuestController
