-- EggHeist | Client/UI/InventoryUI.lua
-- Backpack: unhatched eggs + pet inventory management.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local InventoryUI = {}
local ctx = nil
local window = nil
local tabEggs = nil
local tabPets = nil
local eggsPage = nil
local petsPage = nil
local eggsGrid = nil
local petsGrid = nil
local headerLabel = nil

local Theme = UIFactory.Theme

local function petIncomeDisplay(pet)
	local def = Pets.ById[pet.id]
	if not def then
		return 0
	end
	local level = math.max(1, math.min(pet.lvl or 1, Economy.PetMaxLevel))
	local income = def.BaseIncome * (1 + Economy.PetIncomePerLevel * (level - 1))
	if pet.mut then
		local mut = Mutations.ById[pet.mut]
		if mut then
			income = income * mut.IncomeMult
		end
	end
	return income
end

local function petSellDisplay(pet)
	local def = Pets.ById[pet.id]
	if not def then
		return 0
	end
	local level = math.max(1, pet.lvl or 1)
	local value = def.BaseIncome * Economy.PetSellFactor * (1 + 0.1 * (level - 1))
	if pet.mut then
		local mut = Mutations.ById[pet.mut]
		if mut then
			value = value * mut.SellMult
		end
	end
	return math.floor(value)
end

local function equippedSet(snapshot)
	local set = {}
	for _, uid in ipairs(snapshot.equipped or {}) do
		set[uid] = true
	end
	return set
end

function InventoryUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistInventory", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Backpack", UDim2.new(0, 540, 0, 460))

	-- tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window.Content

	tabEggs = UIFactory.Button("Eggs", function()
		InventoryUI.ShowTab("eggs")
	end)
	tabEggs.Size = UDim2.new(0.5, -4, 1, 0)
	tabEggs.Position = UDim2.new(0, 0, 0, 0)
	tabEggs.Parent = tabBar

	tabPets = UIFactory.Button("Pets", function()
		InventoryUI.ShowTab("pets")
	end)
	tabPets.Size = UDim2.new(0.5, -4, 1, 0)
	tabPets.Position = UDim2.new(0.5, 4, 0, 0)
	tabPets.Parent = tabBar

	headerLabel = UIFactory.Label("", UDim2.new(1, 0, 0, 22), Theme.TextDim, 13)
	headerLabel.Position = UDim2.new(0, 0, 0, 40)
	headerLabel.Font = Theme.FontRegular
	headerLabel.Parent = window.Content

	local pages = Instance.new("Frame")
	pages.Position = UDim2.new(0, 0, 0, 64)
	pages.Size = UDim2.new(1, 0, 1, -64)
	pages.BackgroundTransparency = 1
	pages.Parent = window.Content

	eggsPage = Instance.new("Frame")
	eggsPage.Size = UDim2.fromScale(1, 1)
	eggsPage.BackgroundTransparency = 1
	eggsPage.Parent = pages
	eggsGrid = UIFactory.Grid(eggsPage, UDim2.new(0, 150, 0, 150), 8)

	petsPage = Instance.new("Frame")
	petsPage.Size = UDim2.fromScale(1, 1)
	petsPage.BackgroundTransparency = 1
	petsPage.Visible = false
	petsPage.Parent = pages
	petsGrid = UIFactory.Grid(petsPage, UDim2.new(0, 150, 0, 196), 8)

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				InventoryUI.Refresh()
			end
		end)
	end
end

function InventoryUI.ShowTab(which)
	eggsPage.Visible = which == "eggs"
	petsPage.Visible = which == "pets"
	tabEggs.BackgroundColor3 = which == "eggs" and Theme.Accent or Theme.Button
	tabEggs.TextColor3 = which == "eggs" and Color3.fromRGB(30, 25, 10) or Theme.Text
	tabPets.BackgroundColor3 = which == "pets" and Theme.Accent or Theme.Button
	tabPets.TextColor3 = which == "pets" and Color3.fromRGB(30, 25, 10) or Theme.Text
end

local function eggCard(egg)
	local def = Eggs.ById[egg.eggId]
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 150, 0, 150)
	card.BackgroundColor3 = Theme.Card
	card.BorderSizePixel = 0
	UIFactory.Corner(card, 8)
	UIFactory.Padding(card, 8)

	local name = UIFactory.Label(def and def.DisplayName or egg.eggId,
		UDim2.new(1, 0, 0, 22), Theme.Text, 13)
	name.TextWrapped = true
	name.Parent = card
	local emoji = UIFactory.Label("EGG", UDim2.new(1, 0, 0, 40), Theme.Accent, 28)
	emoji.Position = UDim2.new(0, 0, 0, 28)
	emoji.Parent = card
	local hatch = UIFactory.PrimaryButton("HATCH", function()
		ctx.Controllers.EggController.HatchEgg(egg.uid)
	end)
	hatch.Size = UDim2.new(1, 0, 0, 34)
	hatch.Position = UDim2.new(0, 0, 1, -40)
	hatch.Parent = card
	return card
end

local function petCard(pet, isEquipped)
	local def = Pets.ById[pet.id]
	local rarityColor = Rarities.GetColor(def and def.Rarity or "Common")
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 150, 0, 196)
	card.BackgroundColor3 = Theme.Card
	card.BorderSizePixel = 0
	UIFactory.Corner(card, 8)
	UIFactory.Stroke(card, rarityColor, 2)
	UIFactory.Padding(card, 8)

	local title = (pet.mut and (pet.mut .. " ") or "") .. (def and def.DisplayName or pet.id)
	local name = UIFactory.Label(title, UDim2.new(1, 0, 0, 30), rarityColor, 12)
	name.TextWrapped = true
	name.Parent = card
	local info = UIFactory.Label(
		(def and def.Rarity or "?") .. " Lv" .. tostring(pet.lvl or 1)
			.. "\n" .. Format.Money(petIncomeDisplay(pet)) .. "/s",
		UDim2.new(1, 0, 0, 40), Theme.TextDim, 12)
	info.Position = UDim2.new(0, 0, 0, 36)
	info.Font = Theme.FontRegular
	info.Parent = card

	local equip = UIFactory.Button(isEquipped and "UNEQUIP" or "EQUIP", function()
		if isEquipped then
			ctx.Controllers.PetController.Unequip(pet.uid)
		else
			ctx.Controllers.PetController.Equip(pet.uid)
		end
	end)
	equip.Size = UDim2.new(1, 0, 0, 30)
	equip.Position = UDim2.new(0, 0, 1, -70)
	equip.TextSize = 12
	equip.Parent = card

	local sell = UIFactory.Button("Sell " .. Format.Money(petSellDisplay(pet)), function()
		ctx.Controllers.PetController.Sell(pet.uid)
	end)
	sell.Size = UDim2.new(1, 0, 0, 30)
	sell.Position = UDim2.new(0, 0, 1, -36)
	sell.TextSize = 12
	sell.Parent = card
	return card
end

function InventoryUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	UIFactory.ClearChildren(eggsGrid, true)
	UIFactory.ClearChildren(petsGrid, true)

	local eggs = snapshot.eggs or {}
	local pets = snapshot.pets or {}
	headerLabel.Text = tostring(#eggs) .. " eggs  |  " .. tostring(#pets) .. " pets ("
		.. tostring(#(snapshot.equipped or {})) .. " equipped)"

	if #eggs == 0 then
		local empty = UIFactory.Label("No eggs yet. Visit the Egg Market!", UDim2.new(1, 0, 0, 40), Theme.TextDim, 14)
		empty.Parent = eggsGrid
	else
		if #eggs > 1 then
			local hatchAll = UIFactory.PrimaryButton("HATCH ALL (" .. tostring(math.min(#eggs, 25)) .. ")", function()
				ctx.Controllers.EggController.HatchAll()
			end)
			hatchAll.Size = UDim2.new(0, 150, 0, 44)
			hatchAll.Parent = eggsGrid
		end
		for _, egg in ipairs(eggs) do
			eggCard(egg).Parent = eggsGrid
		end
	end

	if #pets == 0 then
		local empty = UIFactory.Label("No pets yet. Hatch an egg!", UDim2.new(1, 0, 0, 40), Theme.TextDim, 14)
		empty.Parent = petsGrid
	else
		local equipped = equippedSet(snapshot)
		-- sort: equipped first, then rarity tier, then income
		local sorted = {}
		for _, pet in ipairs(pets) do
			sorted[#sorted + 1] = pet
		end
		table.sort(sorted, function(a, b)
			local ae, be = equipped[a.uid] and 1 or 0, equipped[b.uid] and 1 or 0
			if ae ~= be then
				return ae > be
			end
			local ad = Pets.ById[a.id]
			local bd = Pets.ById[b.id]
			local at = Rarities.GetTier(ad and ad.Rarity or "Common")
			local bt = Rarities.GetTier(bd and bd.Rarity or "Common")
			if at ~= bt then
				return at > bt
			end
			return petIncomeDisplay(a) > petIncomeDisplay(b)
		end)
		for _, pet in ipairs(sorted) do
			petCard(pet, equipped[pet.uid] == true).Parent = petsGrid
		end
	end
end

function InventoryUI.SetVisible(visible)
	if visible then
		InventoryUI.Refresh()
	end
	window.SetVisible(visible)
end

function InventoryUI.Toggle()
	InventoryUI.SetVisible(not window.IsVisible())
end

return InventoryUI
