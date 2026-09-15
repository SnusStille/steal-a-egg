-- EggHeist | Client/Screens/MainScreen.luau
-- HUD shell: top resource bar, nav stack, badges, claim-base prompt, ranks, Fx.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))
local SoundManager = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundManager"))

local MainScreen = {}
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
local ranksList = nil -- the ScrollingFrame inside the ranks window
local lastCash = 0

local Theme = UIFactory.Theme

local NAV = {
	{ Id = "Backpack", Label = "Backpack", Screen = "InventoryScreen" },
	{ Id = "Shop", Label = "Shop", Screen = "ShopScreen" },
	{ Id = "Collection", Label = "Collection", Screen = "CollectionScreen" },
	{ Id = "Base", Label = "Base", Screen = "BaseScreen" },
	{ Id = "Quests", Label = "Quests", Screen = "QuestsScreen", Badge = "quests" },
	{ Id = "Daily", Label = "Daily", Screen = "DailyScreen", Badge = "daily" },
	{ Id = "Trade", Label = "Trade", Screen = "TradeScreen" },
	{ Id = "Travel", Label = "Travel", Screen = "TravelScreen" },
	{ Id = "Ranks", Label = "Ranks", Screen = "Ranks" },
	{ Id = "Settings", Label = "Settings", Screen = "SettingsScreen" },
}

function MainScreen.Init(context)
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
			MainScreen.OpenNav(item)
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
	ranksList = UIFactory.ScrollingList(ranksWindow.Content)

	-- keybinds live in Client/Input/InputController.luau
	-- data refresh
	if ctx.Data then
		ctx.Data.Changed:Connect(function(snapshot)
			MainScreen.Refresh(snapshot)
		end)
	end

	-- welcome splash: big title that pops and fades (first impressions!)
	pcall(function()
		local splash = UIFactory.Label("EGG HEIST", UDim2.new(0, 420, 0, 70), Theme.Accent, 52)
		splash.AnchorPoint = Vector2.new(0.5, 0.5)
		splash.Position = UDim2.new(0.5, 0, 0.5, 0)
		splash.Font = Enum.Font.GothamBold
		splash.Parent = gui
		local sub = UIFactory.Label("Steal eggs. Stack cash. Don't get caught.",
			UDim2.new(0, 420, 0, 26), Theme.Text, 16)
		sub.AnchorPoint = Vector2.new(0.5, 0.5)
		sub.Position = UDim2.new(0.5, 0, 0.5, 48)
		sub.Parent = gui
		Effects.Pop(splash, 1.15)
		task.delay(3.2, function()
				if splash then splash:Destroy() end
				if sub then sub:Destroy() end
			end)
	end)

	-- Fx channel
	ctx.Net.On("Fx", function(fxName, ...)
		MainScreen.HandleFx(fxName, ...)
	end)

	-- event chip ticker
	task.spawn(function()
		while true do
			task.wait(1)
			MainScreen.TickEventChip()
		end
	end)
end

function MainScreen.OpenNav(item)
	if item.Screen == "Ranks" then
		MainScreen.RefreshRanks()
		ranksWindow.Toggle()
		return
	end
	local ui = ctx.Screens and ctx.Screens[item.Screen]
	if ui and ui.Toggle then
		ui.Toggle()
	end
end

function MainScreen.CloseAll()
	if not ctx.Screens then
		return
	end
	for _, ui in pairs(ctx.Screens) do
		if type(ui) == "table" and ui.SetVisible and ui ~= MainScreen then
			pcall(function() ui.SetVisible(false) end)
		end
	end
	if ranksWindow then
		ranksWindow.SetVisible(false)
	end
end

function MainScreen.Refresh(snapshot)
	if not snapshot then
		return
	end
	Effects.Configure(snapshot.settings)
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
	for _, state in pairs(snapshot.achievements or {}) do
		if state.done and not state.claimed then
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

function MainScreen.TickEventChip()
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

function MainScreen.RefreshRanks()
	UIFactory.ClearChildren(ranksList, true)
	local boards = { "Richest", "Levels", "Heists", "Collectors" }
	local titles = { Richest = "Richest Heisters (lifetime earned)",
		Levels = "Highest Levels",
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

function MainScreen.HandleFx(fxName, arg1, arg2, arg3, arg4)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local character = Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local hrpPos = hrp and (hrp.Position + Vector3.new(0, 5, 0)) or nil
	if fxName == "LevelUp" then
		SoundManager.Play("Success", 0.7)
		Effects.Flash(playerGui, Color3.fromRGB(80, 220, 120), 0.4)
		Effects.Confetti(playerGui, 30)
		Effects.FovKick(5, 0.5)
		if hrpPos then
			Effects.FloatingText(hrpPos, "LEVEL " .. tostring(arg1 or "?"),
				Color3.fromRGB(120, 255, 160))
		end
	elseif fxName == "VaultCollect" then
		SoundManager.Play("Coins", 0.7)
		if hrpPos then
			Effects.FloatingText(hrpPos, "+" .. Format.Money(tonumber(arg1) or 0),
				Color3.fromRGB(255, 215, 100))
		end
	elseif fxName == "Upgrade" then
		SoundManager.Play("Success", 0.6)
	elseif fxName == "QuestClaim" or fxName == "DailyClaim" then
		SoundManager.Play("Coins", 0.6)
		Effects.Confetti(playerGui, 24)
	elseif fxName == "HeistWin" then
		SoundManager.Play("Success", 0.8)
		Effects.Confetti(playerGui, 50)
		Effects.ShakeCamera(0.4, 0.3)
		Effects.FovKick(7, 0.6)
		if hrpPos then
			Effects.FloatingText(hrpPos, "+" .. Format.Money(tonumber(arg1) or 0),
				Color3.fromRGB(120, 255, 160))
		end
	elseif fxName == "Achievement" then
		SoundManager.Play("Achievement", 0.8, 1.1)
		Effects.Confetti(playerGui, 40)
		if ctx.Screens and ctx.Screens.AnnounceScreen then
			ctx.Screens.AnnounceScreen.Announce("rare", "ACHIEVEMENT UNLOCKED!",
				tostring(arg1 or ""))
		end
	elseif fxName == "Gadget" then
		SoundManager.Play("Gadget", 0.7, 0.9 + math.random() * 0.2)
		Effects.FovKick(4, 0.4)
	elseif fxName == "Travel" then
		SoundManager.Play("Gadget", 0.5, 1.3)
		Effects.FovKick(10, 0.7)
		Effects.Flash(playerGui, Color3.fromRGB(255, 255, 255), 0.25)
	elseif fxName == "TrapStun" then
		SoundManager.Play("Error", 0.7)
		Effects.ShakeCamera(0.8, 0.4)
		Effects.Flash(playerGui, Color3.fromRGB(220, 40, 40), 0.4)
	elseif fxName == "DecoyGrab" then
		SoundManager.Play("Error", 0.6)
		Effects.ShakeCamera(0.4, 0.3)
		if hrpPos then
			Effects.FloatingText(hrpPos, "DECOY!", Color3.fromRGB(255, 170, 60))
		end
	elseif fxName == "HeistAlarm" then
		local alertsOn = not ctx.Data or ctx.Data.GetSetting("heistAlerts") ~= false
		if alertsOn then
			SoundManager.Play("HeistAlert", 0.8)
			Effects.Flash(playerGui, Color3.fromRGB(220, 40, 40), 0.7)
			Effects.ShakeCamera(0.5, 0.4)
			if ctx.Screens and ctx.Screens.AnnounceScreen then
				ctx.Screens.AnnounceScreen.Announce("danger", "VAULT BREACH!",
					tostring(arg1 or "Someone") .. " is robbing you!")
			end
		end
	elseif fxName == "EventStart" then
		SoundManager.Play("Rare", 0.8)
		Effects.Flash(playerGui, Color3.fromRGB(255, 200, 80), 0.4)
		if typeof(arg2) == "Vector3" then
			Effects.Fireworks(arg2)
		end
	elseif fxName == "MeteorLand" then
		-- landing burst always renders (visible across the map), shake only near
		if typeof(arg1) == "Vector3" then
			local near = hrp and (hrp.Position - arg1).Magnitude < 80
			Effects.Burst3D(arg1, Color3.fromRGB(255, 150, 50), near and 40 or 16, 10)
			if near then
				Effects.ShakeCamera(0.6, 0.4)
				Effects.RingShockwave(arg1, Color3.fromRGB(255, 150, 50), 24)
				SoundManager.Play("Error", 0.5, 0.7)
			end
		end
	-- NEW JUICE CHANNELS ------------------------------------------------
	elseif fxName == "Announce" then
		if ctx.Screens and ctx.Screens.AnnounceScreen then
			ctx.Screens.AnnounceScreen.Announce(arg1, arg2, arg3, arg4)
		end
	elseif fxName == "HatchFx" then
		local tier = tonumber(arg1) or 1
		local rarityColor = Rarities.GetColor(arg2)
		SoundManager.Play(tier >= 4 and "Rare" or "Hatch", 0.7, 0.95 + math.random() * 0.1)
		Effects.Flash(playerGui, rarityColor, 0.35)
		Effects.Confetti(playerGui, 8 + tier * 10)
		if tier >= 4 then
			SoundManager.Fanfare(tier)
		end
		if tier >= 5 then
			Effects.ShakeCamera(0.5, 0.4)
			Effects.FovKick(6, 0.6)
		end
		if hrpPos then
			Effects.FloatingText(hrpPos, tostring(arg3 or "???"), rarityColor)
		end
	elseif fxName == "Fireworks" then
		if typeof(arg1) == "Vector3" then
			Effects.Fireworks(arg1)
			SoundManager.Play("Rare", 0.25, 1.4)
		end
	elseif fxName == "Shockwave" then
		if typeof(arg1) == "Vector3" then
			Effects.RingShockwave(arg1, Color3.fromRGB(120, 255, 160), 34)
			Effects.Burst3D(arg1, Color3.fromRGB(120, 255, 160), 30, 8)
			Effects.FovKick(5, 0.5)
		end
	elseif fxName == "GrabFx" then
		SoundManager.Play("Gadget", 0.6, 0.8)
		Effects.FovKick(5, 0.5)
	elseif fxName == "Robbed" then
		SoundManager.Play("HeistAlert", 0.8)
		Effects.Flash(playerGui, Color3.fromRGB(220, 40, 40), 0.7)
		Effects.ShakeCamera(0.5, 0.4)
		if ctx.Screens and ctx.Screens.AnnounceScreen then
			ctx.Screens.AnnounceScreen.Announce("danger", "LOOT EXTRACTED!",
				tostring(arg1 or "Someone") .. " got away with your loot!")
		end
	elseif fxName == "Prestige" then
		SoundManager.Fanfare(6)
		Effects.Flash(playerGui, Color3.fromRGB(190, 130, 255), 0.6)
		Effects.Confetti(playerGui, 100)
		Effects.ShakeCamera(0.6, 0.5)
		Effects.FovKick(8, 0.7)
		if hrp then
			Effects.RingShockwave(hrp.Position, Color3.fromRGB(190, 130, 255), 30)
		end
	end
end

return MainScreen
