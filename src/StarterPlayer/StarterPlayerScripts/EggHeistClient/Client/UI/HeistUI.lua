-- EggHeist | Client/UI/HeistUI.lua
-- Heist HUD: carrying indicator, breach/extraction channels, intruder alerts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))
local SoundManager = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundManager"))

local HeistUI = {}
local ctx = nil
local carryFrame = nil
local carryLabel = nil
local channelFrame = nil
local channelFill = nil
local channelLabel = nil
local alertFrame = nil
local alertLabel = nil
local channelEndsAt = 0
local channelTotal = 1
local repChip = nil
local carryAmount = 0
local carryTarget = "Vault"
local carryEndsAt = 0
local intelFrame = nil
local intelLabel = nil
local intelHideToken = 0

local Theme = UIFactory.Theme

function HeistUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistHeist", 30)
	gui.Parent = playerGui

	-- carrying indicator (bottom center, above claim button area)
	-- heist rep chip (top-left, under the main HUD strip)
	repChip = Instance.new("Frame")
	repChip.Position = UDim2.new(0, 12, 0, 116)
	repChip.Size = UDim2.new(0, 220, 0, 30)
	repChip.BackgroundColor3 = Theme.Panel
	repChip.BorderSizePixel = 0
	UIFactory.Corner(repChip, 8)
	repChip.Parent = gui

	carryFrame = Instance.new("Frame")
	carryFrame.AnchorPoint = Vector2.new(0.5, 1)
	carryFrame.Position = UDim2.new(0.5, 0, 1, -150)
	carryFrame.Size = UDim2.new(0, 340, 0, 104)
	carryFrame.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	carryFrame.BorderSizePixel = 0
	carryFrame.Visible = false
	UIFactory.Corner(carryFrame, 10)
	UIFactory.Stroke(carryFrame, Color3.fromRGB(255, 80, 80), 2)
	carryFrame.Parent = gui
	carryLabel = UIFactory.Label("CARRYING LOOT", UDim2.new(1, -16, 0, 56), Color3.fromRGB(255, 160, 160), 14)
	carryLabel.Position = UDim2.new(0, 8, 0, 4)
	carryLabel.TextWrapped = true
	carryLabel.Parent = carryFrame
	local abandonButton = UIFactory.Button("DROP LOOT", function()
		if ctx.Controllers and ctx.Controllers.HeistController then
			ctx.Controllers.HeistController.Abandon()
		end
	end)
	abandonButton.Size = UDim2.new(1, -16, 0, 32)
	abandonButton.Position = UDim2.new(0, 8, 0, 64)
	abandonButton.Parent = carryFrame

	-- channel bar (center)
	channelFrame = Instance.new("Frame")
	channelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	channelFrame.Position = UDim2.new(0.5, 0, 0.62, 0)
	channelFrame.Size = UDim2.new(0, 300, 0, 46)
	channelFrame.BackgroundColor3 = Theme.Panel
	channelFrame.BorderSizePixel = 0
	channelFrame.Visible = false
	UIFactory.Corner(channelFrame, 10)
	channelFrame.Parent = gui
	channelLabel = UIFactory.Label("BREACHING...", UDim2.new(1, 0, 0, 20), Theme.Accent, 13)
	channelLabel.Parent = channelFrame
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0, 12, 0, 24)
	barBack.Size = UDim2.new(1, -24, 0, 12)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	barBack.BorderSizePixel = 0
	UIFactory.Corner(barBack, 6)
	barBack.Parent = channelFrame
	channelFill = Instance.new("Frame")
	channelFill.Size = UDim2.new(0, 0, 1, 0)
	channelFill.BackgroundColor3 = Theme.Accent
	channelFill.BorderSizePixel = 0
	UIFactory.Corner(channelFill, 6)
	channelFill.Parent = barBack

	-- intruder alert (top center flash)
	alertFrame = Instance.new("Frame")
	alertFrame.AnchorPoint = Vector2.new(0.5, 0)
	alertFrame.Position = UDim2.new(0.5, 0, 68)
	alertFrame.Size = UDim2.new(0, 340, 0, 40)
	alertFrame.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	alertFrame.BorderSizePixel = 0
	alertFrame.Visible = false
	UIFactory.Corner(alertFrame, 10)
	alertFrame.Parent = gui
	alertLabel = UIFactory.Label("", UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 255, 255), 14)
	alertLabel.Parent = alertFrame

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			HeistUI.Refresh()
		end)
	end

	-- scout button (bottom-right): intel on the nearest enemy base
	local scoutButton = UIFactory.Button("SCOUT", function()
		if ctx.Controllers and ctx.Controllers.HeistController then
			ctx.Controllers.HeistController.Scout()
		end
	end)
	scoutButton.AnchorPoint = Vector2.new(1, 1)
	scoutButton.Position = UDim2.new(1, -12, 1, -150)
	scoutButton.Size = UDim2.new(0, 120, 0, 44)
	scoutButton.Parent = gui

	-- intel panel (center-right card, auto-hides)
	intelFrame = Instance.new("Frame")
	intelFrame.AnchorPoint = Vector2.new(1, 0.5)
	intelFrame.Position = UDim2.new(1, -12, 0.45, 0)
	intelFrame.Size = UDim2.new(0, 250, 0, 170)
	intelFrame.BackgroundColor3 = Theme.Panel
	intelFrame.BorderSizePixel = 0
	intelFrame.Visible = false
	UIFactory.Corner(intelFrame, 10)
	UIFactory.Stroke(intelFrame, Theme.Accent, 2)
	intelFrame.Parent = gui
	local intelTitle = UIFactory.Label("BASE INTEL", UDim2.new(1, 0, 0, 26), Theme.Accent, 14)
	intelTitle.Parent = intelFrame
	intelLabel = UIFactory.Label("", UDim2.new(1, -16, 1, -34), Theme.Text, 13)
	intelLabel.Position = UDim2.new(0, 8, 0, 28)
	intelLabel.TextXAlignment = Enum.TextXAlignment.Left
	intelLabel.TextYAlignment = Enum.TextYAlignment.Top
	intelLabel.Font = Theme.FontRegular
	intelLabel.TextWrapped = true
	intelLabel.Parent = intelFrame

	-- channel + carry tickers
	task.spawn(function()
		while true do
			task.wait(0.05)
			if carryFrame.Visible and carryEndsAt > 0 then
				local left = math.max(0, carryEndsAt - os.clock())
				carryLabel.Text = "CARRYING " .. string.upper(tostring(carryTarget))
					.. " LOOT (" .. Format.Money(carryAmount) .. ")!\nReach EXTRACTION! "
					.. string.format("%.0fs left", left)
			end
			if channelFrame.Visible then
				local left = channelEndsAt - os.clock()
				if left <= 0 then
					channelFrame.Visible = false
				else
					local done = 1 - (left / channelTotal)
					channelFill.Size = UDim2.new(math.max(0, math.min(1, done)), 0, 1, 0)
				end
			end
		end
	end)
end

local function repTitle(rep)
	local title = "Pickpocket"
	for _, tier in ipairs((Settings.Heist or {}).RepTitles or {}) do
		if (rep or 0) >= (tier.Rep or 0) then
			title = tier.Title
		end
	end
	return title
end

function HeistUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	local rep = (snapshot.stats and snapshot.stats.heistRep) or 0
	repChip:ClearAllChildren()
	local label = UIFactory.Label("Heist rep: " .. tostring(rep) .. " (" .. repTitle(rep) .. ")",
		UDim2.new(1, -12, 1, 0), Theme.Accent, 13)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = repChip
end

local function alertsEnabled()
	local snapshot = ctx.Data and ctx.Data.Get()
	return (snapshot and snapshot.settings and snapshot.settings.heistAlerts) ~= false
end

function HeistUI.OnState(state)
	if state.carrying == true then
		carryAmount = tonumber(state.amount) or 0
		carryTarget = tostring(state.target or "Vault")
		carryEndsAt = os.clock() + (tonumber(state.timeLeft) or 60)
		carryFrame.Visible = true
		Effects.Pop(carryFrame, 1.05)
		SoundManager.Play("Coins", 0.7)
	elseif state.carrying == false then
		carryFrame.Visible = false
		carryEndsAt = 0
	end
	if state.channeling == true then
		channelFrame.Visible = true
		local scenarioName = state.scenario
			and ((Settings.Heist or {}).ScenarioNames or {})[state.scenario]
		if scenarioName then
			channelLabel.Text = string.upper(tostring(scenarioName)) .. "! STAY CLOSE!"
		elseif state.target then
			channelLabel.Text = "BREACHING " .. string.upper(tostring(state.target)) .. "... STAY CLOSE!"
		else
			channelLabel.Text = "BREACHING... STAY CLOSE!"
		end
		channelTotal = tonumber(state.duration) or 3
		channelEndsAt = os.clock() + channelTotal
	elseif state.channeling == false then
		channelFrame.Visible = false
	end
	if state.extracted == true then
		carryFrame.Visible = false
		channelFrame.Visible = false
		carryEndsAt = 0
		SoundManager.Play("Extract", 0.8, 1.15)
	end
	if state.alert == true then
		state.alert = false
		if alertsEnabled() then
			alertLabel.Text = "INTRUDER: " .. tostring(state.intruder or "unknown") .. " is in your base!"
			alertFrame.Visible = true
			Effects.Pop(alertFrame, 1.05)
			SoundManager.Play("HeistAlert", 0.7)
			task.delay(5, function()
				alertFrame.Visible = false
			end)
		end
	end
end

function HeistUI.OnScout(intel)
	local lines = {
		"Owner: " .. tostring(intel.owner or "?")
			.. " (Lv " .. tostring(intel.ownerLevel or 1) .. ")",
		"Vault: " .. tostring(intel.vaultBand or "?"),
		"Security: " .. tostring(intel.securityTiers or 0) .. " tiers"
			.. " (Door " .. tostring(intel.doorTier or 0) .. ")",
		((intel.hasAlarm and "ALARM " or "") .. (intel.hasCamera and "CAMERAS" or "")):gsub("^$", "No alarm/cameras"),
		intel.lockdown and "STATUS: LOCKDOWN (sealed!)" or "Status: approachable",
	}
	intelLabel.Text = table.concat(lines, "\n")
	intelFrame.Visible = true
	Effects.Pop(intelFrame, 1.03)
	SoundManager.Play("Notify", 0.6, 1.2)
	intelHideToken = intelHideToken + 1
	local token = intelHideToken
	task.delay(12, function()
		if token == intelHideToken then
			intelFrame.Visible = false
		end
	end)
end

return HeistUI
