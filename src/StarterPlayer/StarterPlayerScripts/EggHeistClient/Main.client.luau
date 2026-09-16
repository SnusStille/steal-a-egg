-- EggHeist | Client/Main.client.luau
-- BOOTSTRAP: initializes networking, controllers, input, then screens.
--
-- Layout: StarterPlayerScripts/EggHeistClient/{Controllers,Screens,Effects,Input}
-- Controller contract: optional Init(ctx) then Start().
-- Screen contract: optional Init(ctx). Windows expose SetVisible/Toggle.

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
local bootBg = nil
local bootTitle = nil
local bootFill = nil
local bootTip = nil
local bootTips = {
	"Claim a base first: walk north and touch a glowing plot.",
	"Buy eggs at the market, then place and hatch them.",
	"Equip pets to earn coins while you play.",
	"Rob rivals: grab vault loot, eggs, even pets - then reach EXTRACTION.",
	"Got robbed? Chase the thief down and TACKLE them!",
}
local bootTipIndex = 0
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

-- Loading-screen dress-up: full overlay, title, progress bar, rotating tips.
-- Runs inside pcall: if anything here fails, the tiny probe label survives.
pcall(function()
	if not bootGui or not bootLabel then
		return
	end
	bootBg = Instance.new("Frame")
	bootBg.Name = "BootBg"
	bootBg.Size = UDim2.fromScale(1, 1)
	bootBg.BackgroundColor3 = Color3.fromRGB(24, 16, 44)
	bootBg.BorderSizePixel = 0
	bootBg.Parent = bootGui
	bootTitle = Instance.new("TextLabel")
	bootTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	bootTitle.Position = UDim2.new(0.5, 0, 0.34, 0)
	bootTitle.Size = UDim2.new(0, 600, 0, 84)
	bootTitle.BackgroundTransparency = 1
	bootTitle.Text = "EGG HEIST"
	bootTitle.TextColor3 = Color3.fromRGB(255, 210, 110)
	bootTitle.Font = Enum.Font.GothamBold
	bootTitle.TextSize = 64
	bootTitle.Parent = bootBg
	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.34, 48)
	subtitle.Size = UDim2.new(0, 600, 0, 28)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Steal eggs. Hatch legends. Rule the market."
	subtitle.TextColor3 = Color3.fromRGB(200, 190, 230)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 18
	subtitle.Parent = bootBg
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0.55, 0)
	track.Size = UDim2.new(0, 420, 0, 16)
	track.BackgroundColor3 = Color3.fromRGB(52, 40, 84)
	track.BorderSizePixel = 0
	track.Parent = bootBg
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 8)
	trackCorner.Parent = track
	bootFill = Instance.new("Frame")
	bootFill.Size = UDim2.new(0, 0, 1, 0)
	bootFill.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
	bootFill.BorderSizePixel = 0
	bootFill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = bootFill
	-- restyle the probe label into the centered status line
	bootLabel.AnchorPoint = Vector2.new(0.5, 0)
	bootLabel.Position = UDim2.new(0.5, 0, 0.55, 26)
	bootLabel.Size = UDim2.new(0, 460, 0, 24)
	bootLabel.BackgroundTransparency = 1
	bootLabel.TextColor3 = Color3.fromRGB(170, 200, 255)
	bootLabel.TextSize = 14
	bootLabel.Parent = bootBg
	bootTip = Instance.new("TextLabel")
	bootTip.AnchorPoint = Vector2.new(0.5, 0)
	bootTip.Position = UDim2.new(0.5, 0, 0.55, 54)
	bootTip.Size = UDim2.new(0, 560, 0, 44)
	bootTip.BackgroundTransparency = 1
	bootTip.Text = "TIP: " .. bootTips[1]
	bootTip.TextColor3 = Color3.fromRGB(150, 230, 170)
	bootTip.Font = Enum.Font.Gotham
	bootTip.TextSize = 15
	bootTip.TextWrapped = true
	bootTip.Parent = bootBg
	local footer = Instance.new("TextLabel")
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -10)
	footer.Size = UDim2.new(0, 560, 0, 20)
	footer.BackgroundTransparency = 1
	footer.Text = "An original game - every pixel drawn in code"
	footer.TextColor3 = Color3.fromRGB(120, 110, 150)
	footer.Font = Enum.Font.Gotham
	footer.TextSize = 12
	footer.Parent = bootBg
end)

local function bootStatus(text, frac)
	print("[EggHeist] boot: " .. tostring(text))
	pcall(function()
		if bootLabel then
			bootLabel.Text = tostring(text)
		end
		if bootFill and type(frac) == "number" then
			bootFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
		end
		if bootTip then
			bootTipIndex = (bootTipIndex % #bootTips) + 1
			bootTip.Text = "TIP: " .. bootTips[bootTipIndex]
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
		if bootBg then
			bootBg.BackgroundColor3 = Color3.fromRGB(60, 15, 20)
		end
		if bootTitle then
			bootTitle.Text = "SOMETHING BROKE"
			bootTitle.TextColor3 = Color3.fromRGB(255, 120, 120)
		end
		if bootTip then
			bootTip.Visible = false
		end
		if bootFill then
			bootFill.Visible = false
		end
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

local ClientFolder = script.Parent
local ClientNetModule = ClientFolder:WaitForChild("ClientNet", 30)
assert(ClientNetModule, "[EggHeist] FATAL: ClientNet module missing")
bootStatus("loading network...", 0.15)
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

local SCREEN_MODULES = {
	"NotificationsScreen", -- toasts first so later modules can notify during init
	"MainScreen",
	"InventoryScreen",
	"ShopScreen",
	"CollectionScreen",
	"BaseScreen",
	"QuestsScreen",
	"DailyScreen",
	"SettingsScreen",
	"HatchScreen",
	"HeistScreen",
	"EventBannerScreen",
	"AnnounceScreen", -- big queued banners (fed by Fx "Announce")
	"TutorialScreen",
	"ObjectiveScreen",
	"TradeScreen",
	"HelpScreen",
	"FeedScreen",
	"TravelScreen",
}

local ctx = {}
ctx.Net = ClientNet
ctx.Controllers = {}
ctx.Screens = {}

bootStatus("waiting for server remotes...", 0.3)
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
			local ok2, err = pcall(controller.Init, ctx)
			if not ok2 then
				warn("[EggHeist] " .. name .. ".Init failed: " .. tostring(err))
			end
		end
	else
		warn("[EggHeist] Failed to load controller " .. name)
	end
end

bootStatus("loading controllers...", 0.55)
for _, name in ipairs(CONTROLLERS) do
	loadController(name)
end

-- shared ctx shortcuts
ctx.Data = ctx.Controllers.DataController

bootStatus("loading interface...", 0.8)
local screensFolder = ClientFolder:WaitForChild("Screens", 30)
assert(screensFolder, "[EggHeist] FATAL: Screens folder missing")
for _, name in ipairs(SCREEN_MODULES) do
	local moduleScript = screensFolder:FindFirstChild(name)
	if moduleScript then
		local ok, ui = pcall(require, moduleScript)
		if not ok then
			warn("[EggHeist] Screen require failed: " .. name .. ": " .. tostring(ui))
		elseif ok and ui then
			ctx.Screens[name] = ui
			if type(ui.Init) == "function" then
				local ok2, err = pcall(ui.Init, ctx)
				if not ok2 then
					warn("[EggHeist] " .. name .. ".Init failed: " .. tostring(err))
				end
			end
		end
	else
		warn("[EggHeist] Screen module missing: " .. name)
	end
end

bootStatus("starting controllers...", 0.95)
for _, name in ipairs(CONTROLLERS) do
	local controller = ctx.Controllers[name]
	if controller and type(controller.Start) == "function" then
		local ok, err = pcall(controller.Start, controller)
		if not ok then
			warn("[EggHeist] " .. name .. ".Start failed: " .. tostring(err))
		end
	end
end

print("[EggHeist] Client started.")
pcall(function()
	if bootGui then
		bootGui:Destroy()
	end
end)
