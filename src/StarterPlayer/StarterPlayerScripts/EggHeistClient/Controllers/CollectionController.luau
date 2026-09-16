-- EggHeist | Client/Controllers/CollectionController.luau
-- Collection milestone claims. Progress is computed server-side.

local CollectionController = {}
local ctx = nil

function CollectionController.Init(context)
	ctx = context
end

function CollectionController.ClaimMilestone(milestoneIndex)
	ctx.Net.Fire("ClaimMilestone", milestoneIndex)
end

function CollectionController.Start()
end

return CollectionController
