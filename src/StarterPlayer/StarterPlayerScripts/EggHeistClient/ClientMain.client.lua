-- EggHeist | Client/ClientMain.client.lua
-- BOOTSTRAP: initializes networking, controllers, input, then UI.
--
-- Layout: StarterPlayerScripts/EggHeistClient/Client/{Controllers,UI,Effects,Input}
-- Controller contract: optional Init(ctx) then Start().
-- UI contract: optional Init(ctx). Windows expose SetVisible/Toggle.

-- Timeouts + asserts: boot-critical waits must ERROR LOUDLY, never hang
-- the client forever (an infinite yield here = zero UI with zero errors).
--------------------------------------------------------------------------------
-- BOOT PROBE (dependency-free, runs FIRST). A tiny status label is created
-- before anything else can fail, updated through each boot phase, and
-- hidden on success. If the client ever dies again, the label stays on
-- screen showing EXACTLY where (+ the error), instead of silent nothing.
--------------------------------------------------------------------------------
local bootGui = nil
local bootLabel = nil
pcall(function()
	local playersSvc = game:GetService("Players")
	local player = playersSvc and playersSvc.LocalPlayer
	local playerGui = player and player:WaitForChild("PlayerGui")
	if not playerGui then
		return
	end
	bootGui = Instance.new("ScreenGui")
	bootGui.Name = "EggHeistBoot"
	bootGui.DisplayOrder = 1000
	bootGui.ResetOnSpawn = false
	bootGui.IgnoreGuiInset = true
	bootGui.Parent = playerGui
	bootLabel = Instance.new("TextLabel")
	bootLabel.AnchorPoint = Vector2.new(0.5, 1)
	bootLabel.Position = UDim2.new(0.5, 0, 1, -8)
	bootLabel.Size = UDim2.new(0, 360, 0, 30)
	bootLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	bootLabel.BackgroundTransparency = 0.25
	bootLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
	bootLabel.Font = Enum.Font.GothamBold
	bootLabel.TextSize = 13
	bootLabel.Text = "EGG HEIST: booting..."
	bootLabel.Parent = bootGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bootLabel
end)

local function bootStatus(text)
	print("[EggHeist] boot: " .. tostring(text))
	pcall(function()
		if bootLabel then
			bootLabel.Text = "EGG HEIST: " .. tostring(text)
		end
	end)
end

-- RUNTIME ERROR CATCHER: any uncaught client error (even long after boot)
-- is shown on screen + printed, so it can never hide in Output again.
pcall(function()
	local playersSvc = game:GetService("Players")
	local player = playersSvc and playersSvc.LocalPlayer
	local playerGui = player and player:WaitForChild("PlayerGui", 30)
	if not playerGui then
		return
	end
	game:GetService("ScriptContext").Error:Connect(function(message, stackTrace, callingScript)
		pcall(function()
			local scriptName = callingScript and callingScript:GetFullName() or "?"
			local short = string.sub(tostring(message), 1, 220)
			print("[EggHeist] RUNTIME ERROR in " .. scriptName .. ": " .. tostring(message))
			local old = playerGui:FindFirstChild("EggHeistRuntimeError")
				if old then
					old:Destroy()
				end
				local gui = Instance.new("ScreenGui")
				gui.Name = "EggHeistRuntimeError"
				gui.DisplayOrder = 999
				gui.ResetOnSpawn = false
				gui.IgnoreGuiInset = true
				gui.Parent = playerGui
				local label = Instance.new("TextLabel")
				label.AnchorPoint = Vector2.new(0.5, 1)
				label.Position = UDim2.new(0.5, 0, 1, -76)
				label.Size = UDim2.new(0, 520, 0, 64)
				label.BackgroundColor3 = Color3.fromRGB(120, 25, 25)
				label.BackgroundTransparency = 0.15
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 12
				label.TextWrapped = true
				label.Text = "EGG HEIST RUNTIME ERROR\n" .. scriptName .. "\n" .. short
				label.Parent = gui
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = label
			end)
	end)
end)

local function bootFatal(context, err)
	local message = tostring(context) .. ": " .. tostring(err)
	warn("[EggHeist] CLIENT FATAL - " .. message)
	pcall(function()
		if bootLabel then
			bootLabel.Size = UDim2.new(0, 460, 0, 60)
			bootLabel.BackgroundColor3 = Color3.fromRGB(120, 25, 25)
			bootLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			bootLabel.TextWrapped = true
			bootLabel.Text = "EGG HEIST ERROR\n" .. message
				.. "\n(Open View > Output and send the red text to the dev!)"
		end
	end)
end

local ClientFolder = script.Parent:WaitForChild("Client", 30)
assert(ClientFolder, "[EggHeist] FATAL: Client folder missing next to ClientMain")
local ClientNetModule = ClientFolder:WaitForChild("ClientNet", 30)
assert(ClientNetModule, "[EggHeist] FATAL: ClientNet module missing")
bootStatus("loading network...")
local netOk, ClientNetOrErr = pcall(require, ClientNetModule)
if not netOk then
	bootFatal("ClientNet require failed", ClientNetOrErr)
	return
end
local ClientNet = ClientNetOrErr

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
	"HelpUI",
	"FeedUI",
	"TravelUI",
}

local ctx = {}
ctx.Net = ClientNet
ctx.Controllers = {}
ctx.UI = {}

bootStatus("waiting for server remotes...")
local initOk, initErr = pcall(ClientNet.Init)
if not initOk then
	bootFatal("ClientNet.Init failed (is the server running?)", initErr)
	return
end

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

bootStatus("loading controllers...")
for _, name in ipairs(CONTROLLERS) do
	loadController(name)
end

-- shared ctx shortcuts
ctx.Data = ctx.Controllers.DataController

bootStatus("loading interface...")
local uiFolder = ClientFolder:WaitForChild("UI", 30)
assert(uiFolder, "[EggHeist] FATAL: UI folder missing")
for _, name in ipairs(UI_MODULES) do
	local moduleScript = uiFolder:FindFirstChild(name)
	if moduleScript then
		local ok, ui = pcall(require, moduleScript)
		if not ok then
			warn("[EggHeist] UI require failed: " .. name .. ": " .. tostring(ui))
		elseif ok and ui then
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

bootStatus("starting controllers...")
for _, name in ipairs(CONTROLLERS) do
	local controller = ctx.Controllers[name]
	if controller and type(controller.Start) == "function" then
		pcall(controller.Start, controller)
	end
end

print("[EggHeist] Client started.")
pcall(function()
	if bootGui then
		bootGui:Destroy()
	end
end)
