-- EggHeist | Client/Screens/ObjectiveScreen.luau
-- "What next?" chip: derives the current suggested goal from the profile.
-- Shows after the tutorial completes. Purely client-side (display only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local ObjectiveScreen = {}
local ctx = nil
local chip = nil
local objectiveLabel = nil
local currentAction = nil

local Theme = UIFactory.Theme

local function securityTotal(snapshot)
	local total = 0
	local security = snapshot.base and snapshot.base.security
	if type(security) == "table" then
		for _, tier in pairs(security) do
			if type(tier) == "number" then
				total = total + tier
			end
		end
	end
	return total
end

-- Returns { text, screen?, tab? }
local function computeObjective(snapshot)
	local level = snapshot.level or 1
	local stats = snapshot.stats or {}
	local eggs = snapshot.eggs or {}
	local pets = snapshot.pets or {}
	local equipped = snapshot.equipped or {}
	local upgrades = (snapshot.base and snapshot.base.upgrades) or {}
	local plot = (snapshot.base and snapshot.base.plot) or 0

	if plot == 0 then
		return { text = "Claim a base plot (walk to a glowing plot)" }
	end
	if #eggs == 0 and #pets == 0 then
		return { text = "Buy your first egg", screen = "ShopScreen", tab = "Eggs" }
	end
	if #eggs > 0 then
		return { text = "Hatch your egg", screen = "InventoryScreen" }
	end
	if #pets > 0 and #equipped == 0 then
		return { text = "Equip a pet to earn income", screen = "InventoryScreen" }
	end
	if (upgrades.Income or 0) == 0 then
		return { text = "Buy an Income upgrade", screen = "BaseScreen", tab = "Upgrades" }
	end
	if level >= 3 and securityTotal(snapshot) == 0 then
		return { text = "Buy your first security", screen = "BaseScreen", tab = "Security" }
	end
	for _, state in pairs(snapshot.achievements or {}) do
		if state.done and not state.claimed then
			return { text = "Claim achievement rewards", screen = "QuestsScreen", tab = "Achievements" }
		end
	end
	if level >= 4 and (stats.gadgetsUsed or 0) == 0 then
		return { text = "Buy a gadget for your first heist", screen = "ShopScreen", tab = "Gadgets" }
	end
	if level >= 2 and (stats.heistsWon or 0) == 0 then
		return { text = "Scout an enemy base, then heist it" }
	end
	if level >= 5 and (stats.tradesCompleted or 0) == 0 then
		return { text = "Trade with another player", screen = "TradeScreen" }
	end
	if level >= 6 and (stats.maxRarityTier or 0) < 3 then
		return { text = "Hatch stronger eggs", screen = "ShopScreen", tab = "Eggs" }
	end
	if level >= Economy.PrestigeMinLevel
		and (snapshot.cash or 0) >= Economy.PrestigeCashCost then
		return { text = "Prestige for +25% income", screen = "SettingsScreen" }
	end
	-- endgame rotation: quests vs collection
	if math.floor(os.time() / 120) % 2 == 0 then
		return { text = "Complete quests for rewards", screen = "QuestsScreen" }
	end
	return { text = "Grow your collection", screen = "CollectionScreen" }
end

function ObjectiveScreen.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistObjective", 12)
	gui.Parent = playerGui

	chip = Instance.new("TextButton")
	chip.AnchorPoint = Vector2.new(0, 0)
	chip.Position = UDim2.new(0, 12, 0, 70)
	chip.Size = UDim2.new(0, 300, 0, 52)
	chip.BackgroundColor3 = Theme.Panel
	chip.BackgroundTransparency = 0.1
	chip.BorderSizePixel = 0
	chip.Text = ""
	chip.Visible = false
	chip.AutoButtonColor = true
	UIFactory.Corner(chip, 10)
	UIFactory.Stroke(chip, Theme.Accent, 1.5)
	chip.Parent = gui
	chip.MouseButton1Click:Connect(function()
		if currentAction and currentAction.screen then
			local screen = ctx.Screens and ctx.Screens[currentAction.screen]
			if screen then
				if currentAction.tab and type(screen.ShowTab) == "function" then
					screen.ShowTab(currentAction.tab)
				end
				if type(screen.SetVisible) == "function" then
					screen.SetVisible(true)
				end
			end
		end
	end)

	local caption = UIFactory.Label("NEXT OBJECTIVE", UDim2.new(1, -20, 0, 16), Theme.Accent, 11)
	caption.Position = UDim2.new(0, 10, 0, 4)
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Parent = chip
	objectiveLabel = UIFactory.Label("", UDim2.new(1, -20, 0, 28), Theme.Text, 14)
	objectiveLabel.Position = UDim2.new(0, 10, 0, 20)
	objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectiveLabel.TextTruncate = Enum.TextTruncate.AtEnd
	objectiveLabel.Parent = chip

	if ctx.Data then
		ctx.Data.Changed:Connect(function(snapshot)
			ObjectiveScreen.Refresh(snapshot)
		end)
	end
end

function ObjectiveScreen.Refresh(snapshot)
	snapshot = snapshot or (ctx.Data and ctx.Data.Get())
	if not snapshot then
		chip.Visible = false
		return
	end
	-- the tutorial panel owns onboarding; the chip takes over after
	if not snapshot.tutorial or not snapshot.tutorial.done then
		chip.Visible = false
		return
	end
	currentAction = computeObjective(snapshot)
	objectiveLabel.Text = currentAction.text
	chip.Visible = true
end

return ObjectiveScreen
