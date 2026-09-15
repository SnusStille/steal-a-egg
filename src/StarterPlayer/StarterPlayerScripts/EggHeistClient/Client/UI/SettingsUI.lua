-- EggHeist | Client/UI/SettingsUI.lua
-- Player settings toggles + prestige panel + stats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Achievements = require(ConfigFolder:WaitForChild("Achievements"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local SettingsUI = {}
local ctx = nil
local window = nil
local list = nil

local Theme = UIFactory.Theme

local SETTING_DEFS = {
	{ Key = "music", Label = "Music" },
	{ Key = "sfx", Label = "Sound effects" },
	{ Key = "notifications", Label = "Notifications" },
	{ Key = "showPets", Label = "Show my pets" },
	{ Key = "autoHatch", Label = "Auto-hatch hatched-on-buy" },
	{ Key = "cameraShake", Label = "Camera shake" },
	{ Key = "reducedEffects", Label = "Reduced effects" },
	{ Key = "performanceMode", Label = "Performance mode" },
	{ Key = "heistAlerts", Label = "Heist banners" },
	{ Key = "npcTips", Label = "NPC tips" },
}

function SettingsUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistSettings", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Settings", UDim2.new(0, 460, 0, 460))
	list = UIFactory.ScrollingList(window.Content)

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				SettingsUI.Refresh()
			end
		end)
	end
end

function SettingsUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	UIFactory.ClearChildren(list, true)
	local settings = snapshot.settings or {}

	local settingsHeader = UIFactory.Label("SETTINGS", UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	settingsHeader.TextXAlignment = Enum.TextXAlignment.Left
	settingsHeader.Parent = list
	local autoHatchOwned = snapshot.autoHatchUnlock == true
		or (snapshot.gamepasses and snapshot.gamepasses.AutoHatch == true)
	for _, def in ipairs(SETTING_DEFS) do
		local card = UIFactory.Card(52)
		local label = UIFactory.Label(def.Label, UDim2.new(1, -80, 1, 0), Theme.Text, 14)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = card
		if def.Key == "autoHatch" and not autoHatchOwned then
			local unlock = UIFactory.PrimaryButton("UNLOCK 299 G", function()
				ctx.Net.Fire("BuyAutoHatch")
			end)
			unlock.Size = UDim2.new(0, 140, 0, 36)
			unlock.Position = UDim2.new(1, -148, 0.5, -18)
			unlock.Parent = card
		else
			local toggle = UIFactory.Toggle(settings[def.Key] ~= false, function(state)
				ctx.Net.Fire("UpdateSetting", def.Key, state)
				-- optimistic local update
				local data = ctx.Data.Get()
				if data and data.settings then
					data.settings[def.Key] = state
				end
			end)
			toggle.Position = UDim2.new(1, -64, 0.5, -15)
			toggle.Parent = card
		end
		card.Parent = list
	end

	-- Prestige panel
	local prestigeHeader = UIFactory.Label("PRESTIGE", UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	prestigeHeader.TextXAlignment = Enum.TextXAlignment.Left
	prestigeHeader.Parent = list
	local prestige = snapshot.prestige or {}
	local card = UIFactory.Card(150)
	local info = UIFactory.Label(
		"Rank: " .. tostring(prestige.count or 0)
			.. "  (+" .. tostring(math.floor((prestige.bonus or 0) * 100)) .. "% income)"
			.. "\nRequires Lv " .. tostring(Economy.PrestigeMinLevel)
			.. " + " .. Format.Money(Economy.PrestigeCashCost)
			.. "\nResets cash, level, eggs & base.\nKeeps plot, collection & best "
			.. tostring(Economy.PrestigeKeepPets) .. " pets.",
		UDim2.new(1, 0, 0, 96), Theme.TextDim, 12)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.Font = Theme.FontRegular
	info.Parent = card
	local canPrestige = (snapshot.level or 1) >= Economy.PrestigeMinLevel
		and (snapshot.cash or 0) >= Economy.PrestigeCashCost
	local prestigeButton = UIFactory.PrimaryButton(canPrestige and "PRESTIGE NOW" or "LOCKED", function()
		if canPrestige then
			ctx.Net.Fire("Prestige")
		end
	end)
	prestigeButton.Size = UDim2.new(1, 0, 0, 38)
	prestigeButton.Position = UDim2.new(0, 0, 1, -44)
	if not canPrestige then
		prestigeButton.BackgroundColor3 = Theme.Button
		prestigeButton.TextColor3 = Theme.TextDim
	end
	prestigeButton.Parent = card
	card.Parent = list

	-- Stats panel
	local statsHeader = UIFactory.Label("STATISTICS", UDim2.new(1, 0, 0, 26), Theme.Accent, 15)
	statsHeader.TextXAlignment = Enum.TextXAlignment.Left
	statsHeader.Parent = list
	local stats = snapshot.stats or {}
	local rep = stats.heistRep or 0
	local repTitle = "Pickpocket"
	for _, tier in ipairs((Settings.Heist or {}).RepTitles or {}) do
		if rep >= (tier.Rep or 0) then
			repTitle = tier.Title
		end
	end
	local achStates = snapshot.achievements or {}
	local achDone = 0
	for _, def in ipairs(Achievements.List) do
		local state = achStates[def.Id]
		if state and state.done then
			achDone = achDone + 1
		end
	end
	local statsCard = UIFactory.Card(190)
	local statsText = UIFactory.Label(
		"Earned: " .. Format.Money(stats.totalEarned or 0)
			.. "\nHatched: " .. tostring(stats.totalHatched or 0)
			.. " (" .. tostring(stats.mutatedHatched or 0) .. " mutated)"
			.. "\nHeists won: " .. tostring(stats.heistsWon or 0)
			.. "  |  Failed: " .. tostring(stats.heistsFailed or 0)
			.. "\nTimes robbed: " .. tostring(stats.timesRobbed or 0)
			.. "\nPlaytime: " .. tostring(stats.playMinutes or 0) .. " min"
			.. "\nHeist rep: " .. tostring(rep) .. " (" .. repTitle .. ")"
			.. "\nAchievements: " .. tostring(achDone) .. "/" .. tostring(#Achievements.List)
			.. "\nGadgets used: " .. tostring(stats.gadgetsUsed or 0),
		UDim2.new(1, 0, 1, 0), Theme.TextDim, 13)
	statsText.TextXAlignment = Enum.TextXAlignment.Left
	statsText.TextYAlignment = Enum.TextYAlignment.Top
	statsText.Font = Theme.FontRegular
	statsText.Parent = statsCard
	statsCard.Parent = list
end

function SettingsUI.SetVisible(visible)
	if visible then
		SettingsUI.Refresh()
	end
	window.SetVisible(visible)
end

function SettingsUI.Toggle()
	SettingsUI.SetVisible(not window.IsVisible())
end

return SettingsUI
