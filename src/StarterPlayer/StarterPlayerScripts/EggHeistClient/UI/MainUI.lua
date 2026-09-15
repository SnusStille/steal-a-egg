-- EggHeist | Client/UI/MainUI.lua
-- HUD shell: top resource bar, nav stack, badges, claim-base prompt, ranks, Fx.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))
local SoundManager = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundManager"))

local MainUI = {}
local ctx = nil
local gui = nil
local cashLabel = nil
local gemsLabel = nil
local levelLabel = nil
local xpFill = nil
local incomeLabel = nil
local questBadge = nil
local dailyBadge = nil
local claimButton = nil
local eventChip = nil
local eventChipLabel = nil
local ranksWindow = nil
local ranksList = nil
local lastCash = 0

local Theme = UIFactory.Theme

local NAV = {
	{ Id = "Backpack", Label = "Backpack", UI = "InventoryUI" },
	{ Id = "Shop", Label = "Shop", UI = "ShopUI" },
	{ Id = "Collection", Label = "Collection", UI = "CollectionUI" },
	{ Id = "Base", Label = "Base", UI = "BaseUI" },
	{ Id = "Quests", Label = "Quests", UI = "QuestsUI", Badge = "quests" },
	{ Id = "Daily", Label = "Daily", UI = "DailyUI", Badge = "daily" },
	{ Id = "Ranks", Label = "Ranks", UI = "Ranks" },
	{ Id = "Settings", Label = "Settings", UI = "SettingsUI" },
}

function MainUI.Init(context)
	ctx = context
	SoundManager.Init(ctx)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	gui = UIFactory.ScreenGui("EggHeistMain", 10)
	gui.Parent = playerGui

	-- Top bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 8)
	topBar.Size = UDim2.new(0, 560, 0, 52)
	topBar.BackgroundColor3 = Theme.Panel
	topBar.BackgroundTransparency = 0.1
	topBar.BorderSizePixel = 0
	UIFactory.Corner(topBar, 12)
	UIFactory.Stroke(topBar, Theme.Stroke, 1.5)
	topBar.Parent = gui
	local topConstraint = Instance.new("UISizeConstraint")
	topConstraint.MaxSize = Vector2.new(640, 52)
	topConstraint.MinSize = Vector2.new(320, 52)
	topConstraint.Parent = topBar

	cashLabel = UIFactory.Label("$0", UDim2.new(0, 150, 0, 26), Theme.Accent, 19)
	cashLabel.Position = UDim2.new(0, 14, 0, 4)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.Parent = topBar

	incomeLabel = UIFactory.Label("", UDim2.new(0, 150, 0, 16), Theme.TextDim, 12)
	incomeLabel.Position = UDim2.new(0, 14, 0, 30)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
	incomeLabel.Font = Theme.FontRegular
	incomeLabel.Parent = topBar

	gemsLabel = UIFactory.Label("0", UDim2.new(0, 110, 0, 26), Color3.fromRGB(120, 220, 255), 19)
	gemsLabel.Position = UDim2.new(0, 170, 0, 4)
	gemsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gemsLabel.Parent = topBar

	local gemsSub = UIFactory.Label("GEMS", UDim2.new(0, 110, 0, 16), Theme.TextDim, 11)
	gemsSub.Position = UDim2.new(0, 170, 0, 30)
	gemsSub.TextXAlignment = Enum.TextXAlignment.Left
	gemsSub.Font = Theme.FontRegular
	gemsSub.Parent = topBar

	levelLabel = UIFactory.Label("Lv 1", UDim2.new(0, 70, 0, 26), Theme.Success, 17)
	levelLabel.Position = UDim2.new(0, 290, 0, 4)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = topBar

	local xpBack = Instance.new("Frame")
	xpBack.Position = UDim2.new(0, 290, 0, 32)
	xpBack.Size = UDim2.new(0, 120, 0, 10)
	xpBack.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	xpBack.BorderSizePixel = 0
	UIFactory.Corner(xpBack, 5)
	xpBack.Parent = topBar
	xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Theme.Success
	xpFill.BorderSizePixel = 0
	UIFactory.Corner(xpFill, 5)
	xpFill.Parent = xpBack

	-- Event chip (right side of top bar)
	eventChip = Instance.new("Frame")
	eventChip.AnchorPoint = Vector2.new(1, 0.5)
	eventChip.Position = UDim2.new(1, -10, 0.5, 0)
	eventChip.Size = UDim2.new(0, 130, 0, 36)
	eventChip.BackgroundColor3 = Theme.Card
	eventChip.BorderSizePixel = 0
	eventChip.Visible = false
	UIFactory.Corner(eventChip, 8)
	eventChip.Parent = topBar
	eventChipLabel = UIFactory.Label("", UDim2.new(1, -8, 1, 0), Theme.Text, 12)
	eventChipLabel.Position = UDim2.new(0, 4, 0, 0)
	eventChipLabel.TextWrapped = true
	eventChipLabel.Parent = eventChip

	-- Right nav stack
	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.AnchorPoint = Vector2.new(1, 0.5)
	nav.Position = UDim2.new(1, -10, 0.5, 0)
	nav.Size = UDim2.new(0, 118, 0, 320)
	nav.BackgroundTransparency = 1
	nav.Parent = gui
	local navLayout = Instance.new("UIListLayout")
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Padding = UDim.new(0, 6)
	navLayout.FillDirection = Enum.FillDirection.Vertical
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Parent = nav

	for i, item in ipairs(NAV) do
		local button = UIFactory.Button(item.Label, function()
			SoundManager.Play("Click", 0.4)
			MainUI.OpenNav(item)
		end)
		button.Name = item.Id
		button.Size = UDim2.new(0, 118, 0, 34)
		button.LayoutOrder = i
		button.Parent = nav
		if item.Badge == "quests" then
			questBadge = Instance.new("Frame")
			questBadge.Size = UDim2.new(0, 18, 0, 18)
			questBadge.Position = UDim2.new(0, -6, 0, -6)
			questBadge.BackgroundColor3 = Theme.Error
			questBadge.BorderSizePixel = 0
			questBadge.Visible = false
			UIFactory.Corner(questBadge, 9)
			questBadge.Parent = button
			local count = UIFactory.Label("!", UDim2.fromScale(1, 1), Color3.fromRGB(255, 255, 255), 12)
			count.Parent = questBadge
		elseif item.Badge == "daily" then
			local badge = Instance.new("Frame")
			badge.Size = UDim2.new(0, 18, 0, 18)
			badge.Position = UDim2.new(0, -6, 0, -6)
			badge.BackgroundColor3 = Theme.Success
			badge.BorderSizePixel = 0
			badge.Visible = false
			UIFactory.Corner(badge, 9)
			badge.Parent = button
			local count = UIFactory.Label("!", UDim2.fromScale(1, 1), Color3.fromRGB(255, 255, 255), 12)
			count.Parent = badge
			dailyBadge = badge
		end
	end

	-- Claim base floating button (bottom center)
	claimButton = UIFactory.PrimaryButton("CLAIM THIS PLOT", function()
		ctx.Controllers.BaseController.ClaimBase()
	end)
	claimButton.AnchorPoint = Vector2.new(0.5, 1)
	claimButton.Position = UDim2.new(0.5, 0, 1, -90)
	claimButton.Size = UDim2.new(0, 240, 0, 46)
	claimButton.Visible = false
	claimButton.Parent = gui

	-- Ranks window
	ranksWindow = UIFactory.Window(gui, "Leaderboards", UDim2.new(0, 420, 0, 400))
	ranksList = ranksWindow.Content
	UIFactory.ScrollingList(ranksList)

	-- keybinds
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			MainUI.OpenNav(NAV[1])
		elseif input.KeyCode == Enum.KeyCode.Escape then
			MainUI.CloseAll()
		end
	end)

	-- data refresh
	if ctx.Data then
		ctx.Data.Changed:Connect(function(snapshot)
			MainUI.Refresh(snapshot)
		end)
	end

	-- Fx channel
	ctx.Net.On("Fx", function(fxName, ...)
		MainUI.HandleFx(fxName, ...)
	end)

	-- event chip ticker
	task.spawn(function()
		while true do
			task.wait(1)
			MainUI.TickEventChip()
		end
	end)
end

function MainUI.OpenNav(item)
	if item.UI == "Ranks" then
		MainUI.RefreshRanks()
		ranksWindow.Toggle()
		return
	end
	local ui = ctx.UI and ctx.UI[item.UI]
	if ui and ui.Toggle then
		ui.Toggle()
	end
end

function MainUI.CloseAll()
	if not ctx.UI then
		return
	end
	for _, ui in pairs(ctx.UI) do
		if type(ui) == "table" and ui.SetVisible and ui ~= MainUI then
			pcall(function() ui.SetVisible(false) end)
		end
	end
	if ranksWindow then
		ranksWindow.SetVisible(false)
	end
end

function MainUI.Refresh(snapshot)
	if not snapshot then
		return
	end
	local cash = snapshot.cash or 0
	if cash ~= lastCash then
		Effects.CountUp(cashLabel, lastCash, cash, 0.4, Format.Money)
		lastCash = cash
	else
		cashLabel.Text = Format.Money(cash)
	end
	gemsLabel.Text = Format.Compact(snapshot.gems or 0) .. " G"
	levelLabel.Text = "Lv " .. tostring(snapshot.level or 1)
	local level = snapshot.level or 1
	local need = Economy.LevelXp(level)
	UIFactory.SetProgress(xpFill, (snapshot.xp or 0) / math.max(1, need))

	-- income estimate (equipped sum, pre-global-mult; label as ~)
	if ctx.Controllers then
		incomeLabel.Text = tostring(#(snapshot.equipped or {})) .. " pals equipped"
	end

	-- quest badge: any unclaimed completed quest
	local claimable = 0
	for _, q in ipairs((snapshot.quests and snapshot.quests.dailies) or {}) do
		if q.progress >= q.target and not q.claimed then
			claimable = claimable + 1
		end
	end
	for _, q in ipairs((snapshot.quests and snapshot.quests.weeklies) or {}) do
		if q.progress >= q.target and not q.claimed then
			claimable = claimable + 1
		end
	end
	if questBadge then
		questBadge.Visible = claimable > 0
	end
	-- daily badge
	if dailyBadge then
		local today = math.floor(os.time() / 86400)
		local last = (snapshot.daily and snapshot.daily.lastClaimDay) or -1
		dailyBadge.Visible = last ~= today
	end
	-- claim button
	if claimButton then
		local plot = (snapshot.base and snapshot.base.plot) or 0
		claimButton.Visible = plot == 0 and ctx.Data.Ready
	end
end

function MainUI.TickEventChip()
	if not eventChip then
		return
	end
	local eventController = ctx.Controllers and ctx.Controllers.EventController
	local active = eventController and eventController.Active
	if active then
		eventChip.Visible = true
		eventChipLabel.Text = (active.displayName or "Event") .. "\n" .. Format.Duration(eventController.TimeLeft())
	else
		eventChip.Visible = false
	end
end

function MainUI.RefreshRanks()
	UIFactory.ClearChildren(ranksList, true)
	local boards = { "Richest", "Heists", "Collectors" }
	local titles = { Richest = "Richest Heisters (lifetime earned)",
		Heists = "Master Thieves (successful extractions)",
		Collectors = "Top Collectors (unique discoveries)" }
	for _, board in ipairs(boards) do
		local header = UIFactory.Label(titles[board], UDim2.new(1, 0, 0, 24), Theme.Accent, 14)
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = ranksList
		local entries = ctx.Net.Invoke("GetLeaderboard", board) or {}
		if #entries == 0 then
			local empty = UIFactory.Label("No entries yet.", UDim2.new(1, 0, 0, 22), Theme.TextDim, 13)
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Font = Theme.FontRegular
			empty.Parent = ranksList
		end
		for i, entry in ipairs(entries) do
			if i > 10 then
				break
			end
			local row = UIFactory.Label(tostring(i) .. ". " .. tostring(entry.name or "?")
				.. "  -  " .. Format.Compact(entry.score or 0),
				UDim2.new(1, 0, 0, 22), Theme.Text, 13)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Font = Theme.FontRegular
			row.Parent = ranksList
		end
		local spacer = Instance.new("Frame")
		spacer.Size = UDim2.new(1, 0, 0, 6)
		spacer.BackgroundTransparency = 1
		spacer.Parent = ranksList
	end
end

function MainUI.HandleFx(fxName, arg1, _arg2)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if fxName == "LevelUp" then
		SoundManager.Play("Success", 0.7)
		Effects.Flash(playerGui, Color3.fromRGB(80, 220, 120), 0.4)
		Effects.Confetti(playerGui, 30)
	elseif fxName == "VaultCollect" then
		SoundManager.Play("Coins", 0.7)
	elseif fxName == "Upgrade" then
		SoundManager.Play("Success", 0.6)
	elseif fxName == "QuestClaim" or fxName == "DailyClaim" then
		SoundManager.Play("Coins", 0.6)
		Effects.Confetti(playerGui, 24)
	elseif fxName == "HeistWin" then
		SoundManager.Play("Success", 0.8)
		Effects.Confetti(playerGui, 50)
		Effects.ShakeCamera(0.4, 0.3)
	elseif fxName == "TrapStun" then
		SoundManager.Play("Error", 0.7)
		Effects.ShakeCamera(0.8, 0.4)
	elseif fxName == "DecoyGrab" then
		SoundManager.Play("Error", 0.6)
	elseif fxName == "EventStart" then
		SoundManager.Play("Rare", 0.8)
	elseif fxName == "MeteorLand" then
		-- positional 3D shake if close
		local character = Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and typeof(arg1) == "Vector3" and (hrp.Position - arg1).Magnitude < 80 then
			Effects.ShakeCamera(0.6, 0.4)
			SoundManager.Play("Error", 0.4)
		end
	end
end

return MainUI
