-- EggHeist | Client/Init.client.lua
-- BOOTSTRAP: initializes networking, controllers, then UI.

local ClientNet = require(script.Parent:WaitForChild("ClientNet"))

local CONTROLLERS = {
	"DataController",
	"EggController",
	"PetController",
	"BaseController",
	"HeistController",
	"QuestController",
	"ShopController",
	"EventController",
	"TutorialController",
}

local UI_MODULES = {
	"NotificationsUI",
	"MainUI",
	"InventoryUI",
	"ShopUI",
	"CollectionUI",
	"BaseUI",
	"QuestsUI",
	"DailyUI",
	"SettingsUI",
	"HatchUI",
	"HeistUI",
	"EventBannerUI",
	"TutorialUI",
}

local ctx = {}
ctx.Net = ClientNet
ctx.Controllers = {}
ctx.UI = {}

ClientNet.Init()

local controllersFolder = script.Parent:WaitForChild("Controllers")
for _, name in ipairs(CONTROLLERS) do
	local moduleScript = controllersFolder:WaitForChild(name)
	local ok, controller = pcall(require, moduleScript)
	if ok and controller then
		ctx.Controllers[name] = controller
		if type(controller.Init) == "function" then
			local ok2, err = pcall(controller.Init, controller, ctx)
			if not ok2 then
				warn("[EggHeist] " .. name .. ".Init failed: " .. tostring(err))
			end
		end
	else
		warn("[EggHeist] Failed to load controller " .. name)
	end
end

-- shared ctx shortcuts
ctx.Data = ctx.Controllers.DataController

local uiFolder = script.Parent:WaitForChild("UI")
for _, name in ipairs(UI_MODULES) do
	local moduleScript = uiFolder:FindFirstChild(name)
	if moduleScript then
		local ok, ui = pcall(require, moduleScript)
		if ok and ui then
			ctx.UI[name] = ui
			if type(ui.Init) == "function" then
				local ok2, err = pcall(ui.Init, ui, ctx)
				if not ok2 then
					warn("[EggHeist] " .. name .. ".Init failed: " .. tostring(err))
				end
			end
		end
	end
end

for _, name in ipairs(CONTROLLERS) do
	local controller = ctx.Controllers[name]
	if controller and type(controller.Start) == "function" then
		pcall(controller.Start, controller)
	end
end

print("[EggHeist] Client started.")
