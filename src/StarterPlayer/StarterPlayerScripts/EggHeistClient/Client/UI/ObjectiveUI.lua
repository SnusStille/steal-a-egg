-- EggHeist | Client/UI/ObjectiveUI.lua
-- "What next?" chip: derives the current suggested goal from the profile.
-- Shows after the tutorial completes. Purely client-side (display only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local ObjectiveUI = {}
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

-- Returns { text, ui?, tab? }
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
		return { text = "Buy your first egg", ui = "ShopUI", tab = "Eggs" }
	end
	if #eggs > 0 then
		return { text = "Hatch your egg", ui = "InventoryUI" }
	end
	if #pets > 0 and #equipped == 0 then
		return { text = "Equip a pet to earn income", ui = "InventoryUI" }
	end
	if (upgrades.Income or 0) == 0 then
		return { text = "Buy an Income upgrade", ui = "BaseUI", tab = "Upgrades" }
	end
	if level >= 3 and securityTotal(snapshot) == 0 then
		return { text = "Buy your first security", ui = "BaseUI", tab = "Security" }
	end
	if level >= 2 and (stats.heistsWon or 0) == 0 then
		return { text = "Attempt a heist at an enemy base" }
	end
	if level >= 6 and (stats.maxRarityTier or 0) < 3 then
		return { text = "Hatch stronger eggs", ui = "ShopUI", tab = "Eggs" }
	end
	if level >= Economy.PrestigeMinLevel
		and (snapshot.cash or 0) >= Economy.PrestigeCashCost then
		return { text = "Prestige for +25% income", ui = "SettingsUI" }
	end
	-- endgame rotation: quests vs collection
	if math.floor(os.time() / 120) % 2 == 0 then
		return { text = "Complete quests for rewards", ui = "QuestsUI" }
	end
	return { text = "Grow your collection", ui = "CollectionUI" }
end

function ObjectiveUI.Init(context)
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
		if currentAction and currentAction.ui then
			local ui = ctx.UI and ctx.UI[currentAction.ui]
			if ui then
				if currentAction.tab and type(ui.ShowTab) == "function" then
					ui.ShowTab(currentAction.tab)
				end
				if type(ui.SetVisible) == "function" then
					ui.SetVisible(true)
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
			ObjectiveUI.Refresh(snapshot)
		end)
	end
end

function ObjectiveUI.Refresh(snapshot)
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

return ObjectiveUI
