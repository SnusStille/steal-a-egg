-- EggHeist | Client/ClientMain.client.lua
-- BOOTSTRAP: initializes networking, controllers, input, then UI.
--
-- Layout: StarterPlayerScripts/EggHeistClient/Client/{Controllers,UI,Effects,Input}
-- Controller contract: optional Init(ctx) then Start().
-- UI contract: optional Init(ctx). Windows expose SetVisible/Toggle.

-- Timeouts + asserts: boot-critical waits must ERROR LOUDLY, never hang
-- the client forever (an infinite yield here = zero UI with zero errors).
local ClientFolder = script.Parent:WaitForChild("Client", 30)
assert(ClientFolder, "[EggHeist] FATAL: Client folder missing next to ClientMain")
local ClientNetModule = ClientFolder:WaitForChild("ClientNet", 30)
assert(ClientNetModule, "[EggHeist] FATAL: ClientNet module missing")
local ClientNet = require(ClientNetModule)

local CONTROLLERS = {
	"DataController", -- profile cache first (others read through ctx.Data)
	"EggController",
	"PetController",
	"BaseController",
	"HeistController",
	"QuestController",
	"ShopController",
	"EventController",
	"TutorialController",
	"GadgetController",
	"CollectionController",
	"NpcController",
	"TradeController",
	"InputController", -- keybinds last (acts on controllers + UI at press time)
}

local UI_MODULES = {
	"NotificationsUI", -- toasts first so later modules can notify during init
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
	"ObjectiveUI",
	"TradeUI",
}

local ctx = {}
ctx.Net = ClientNet
ctx.Controllers = {}
ctx.UI = {}

ClientNet.Init()

local controllersFolder = ClientFolder:WaitForChild("Controllers", 30)
assert(controllersFolder, "[EggHeist] FATAL: Controllers folder missing")
local inputFolder = ClientFolder:WaitForChild("Input", 30)
assert(inputFolder, "[EggHeist] FATAL: Input folder missing")

local function loadController(name)
	-- Controllers live in Controllers/; input handling lives in Input/.
	local moduleScript = controllersFolder:FindFirstChild(name)
		or inputFolder:FindFirstChild(name)
	if not moduleScript then
		warn("[EggHeist] Controller module missing: " .. name)
		return
	end
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

for _, name in ipairs(CONTROLLERS) do
	loadController(name)
end

-- shared ctx shortcuts
ctx.Data = ctx.Controllers.DataController

local uiFolder = ClientFolder:WaitForChild("UI", 30)
assert(uiFolder, "[EggHeist] FATAL: UI folder missing")
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
	else
		warn("[EggHeist] UI module missing: " .. name)
	end
end

for _, name in ipairs(CONTROLLERS) do
	local controller = ctx.Controllers[name]
	if controller and type(controller.Start) == "function" then
		pcall(controller.Start, controller)
	end
end

print("[EggHeist] Client started.")
