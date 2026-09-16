-- EggHeist | Client/Controllers/TutorialController.luau

local TutorialController = {}
local ctx = nil

function TutorialController.Init(context)
	ctx = context
	if ctx.Data then
		ctx.Data.Changed:Connect(function(snapshot)
			local ui = ctx.Screens and ctx.Screens.TutorialScreen
			if ui and snapshot then
				ui.OnData(snapshot)
			end
		end)
	end
end

function TutorialController.CompleteStep(stepId)
	ctx.Net.Fire("CompleteTutorialStep", stepId)
end

function TutorialController.Start()
end

return TutorialController
