-- EggHeist | Client/UI/ShopUI.lua
-- Egg shop, boosts/gamepasses (Robux), decorations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Shop = require(ConfigFolder:WaitForChild("Shop"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local ShopUI = {}
local ctx = nil
local window = nil
local pages = {}
local tabButtons = {}
local currentTab = "Eggs"

local Theme = UIFactory.Theme
local TABS = { "Eggs", "Boosts", "Passes", "Decor" }

function ShopUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistShop", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Shop", UDim2.new(0, 540, 0, 460))

	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window.Content
	for i, tab in ipairs(TABS) do
		local button = UIFactory.Button(tab, function()
			ShopUI.ShowTab(tab)
		end)
		button.Size = UDim2.new(0.25, -6, 1, 0)
		button.Position = UDim2.new((i - 1) * 0.25, 3, 0, 0)
		button.Parent = tabBar
		tabButtons[tab] = button
	end

	local pageHolder = Instance.new("Frame")
	pageHolder.Position = UDim2.new(0, 0, 0, 42)
	pageHolder.Size = UDim2.new(1, 0, 1, -42)
	pageHolder.BackgroundTransparency = 1
	pageHolder.Parent = window.Content
	for _, tab in ipairs(TABS) do
		local page = Instance.new("Frame")
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = pageHolder
		pages[tab] = page
		UIFactory.ScrollingList(page)
	end
	ShopUI.ShowTab("Eggs")

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				ShopUI.Refresh()
			end
		end)
	end
end

function ShopUI.ShowTab(tab)
	currentTab = tab
	for name, page in pairs(pages) do
		page.Visible = name == tab
	end
	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = name == tab and Theme.Accent or Theme.Button
		button.TextColor3 = name == tab and Color3.fromRGB(30, 25, 10) or Theme.Text
	end
end

local function rowCard(height)
	return UIFactory.Card(height or 76)
end

function ShopUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	local level = snapshot.level or 1
	local cash = snapshot.cash or 0

	-- Eggs tab
	local eggsPage = pages.Eggs:FindFirstChildOfClass("ScrollingFrame")
	UIFactory.ClearChildren(eggsPage, true)
	for _, def in ipairs(Eggs.GetShopEggs()) do
		local locked = level < (def.RequiredLevel or 1)
		local afford = cash >= def.Price
		local card = rowCard(84)
		local name = UIFactory.Label(def.DisplayName, UDim2.new(1, -130, 0, 24), Theme.Text, 15)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = card
		local desc = UIFactory.Label(def.Description or "", UDim2.new(1, -130, 0, 40),
			Theme.TextDim, 12)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Position = UDim2.new(0, 0, 0, 26)
		desc.Font = Theme.FontRegular
		desc.Parent = card
		local buy = UIFactory.PrimaryButton(Format.Money(def.Price), function()
			ctx.Controllers.EggController.BuyEgg(def.Id)
		end)
		buy.Size = UDim2.new(0, 110, 0, 40)
		buy.Position = UDim2.new(1, -118, 0, 14)
		buy.Parent = card
		if locked then
			buy.Text = "Lv " .. tostring(def.RequiredLevel)
			buy.BackgroundColor3 = Theme.Button
			buy.TextColor3 = Theme.TextDim
		elseif not afford then
			buy.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
		end
		card.Parent = eggsPage
	end

	-- Boosts tab (dev products)
	local boostsPage = pages.Boosts:FindFirstChildOfClass("ScrollingFrame")
	UIFactory.ClearChildren(boostsPage, true)
	for key, product in pairs(Shop.Products) do
		local card = rowCard(76)
		local name = UIFactory.Label(product.DisplayName or key, UDim2.new(1, -130, 0, 24), Theme.Text, 15)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = card
		local buy = UIFactory.Button("R$ " .. tostring(product.PriceRobux or "?"), function()
			ctx.Controllers.ShopController.Prompt("Product", key)
		end)
		buy.Size = UDim2.new(0, 110, 0, 40)
		buy.Position = UDim2.new(1, -118, 0, 10)
		buy.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
		buy.Parent = card
		card.Parent = boostsPage
	end

	-- Passes tab
	local passesPage = pages.Passes:FindFirstChildOfClass("ScrollingFrame")
	UIFactory.ClearChildren(passesPage, true)
	for key, pass in pairs(Shop.Gamepasses) do
		local owned = snapshot.gamepasses and snapshot.gamepasses[key] == true
		local card = rowCard(84)
		local name = UIFactory.Label(pass.DisplayName or key, UDim2.new(1, -130, 0, 24),
			owned and Theme.Success or Theme.Text, 15)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = card
		local desc = UIFactory.Label(pass.Description or "", UDim2.new(1, -130, 0, 40),
			Theme.TextDim, 12)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Position = UDim2.new(0, 0, 0, 26)
		desc.Font = Theme.FontRegular
		desc.Parent = card
		if owned then
			local ownedLabel = UIFactory.Label("OWNED", UDim2.new(0, 110, 0, 40), Theme.Success, 14)
			ownedLabel.Position = UDim2.new(1, -118, 0, 14)
			ownedLabel.Parent = card
		else
			local buy = UIFactory.Button("R$ " .. tostring(pass.PriceRobux or "?"), function()
				ctx.Controllers.ShopController.Prompt("Gamepass", key)
			end)
			buy.Size = UDim2.new(0, 110, 0, 40)
			buy.Position = UDim2.new(1, -118, 0, 14)
			buy.BackgroundColor3 = Color3.fromRGB(90, 110, 220)
			buy.Parent = card
		end
		card.Parent = passesPage
	end

	-- Decor tab
	local decorPage = pages.Decor:FindFirstChildOfClass("ScrollingFrame")
	UIFactory.ClearChildren(decorPage, true)
	for _, decor in ipairs(Shop.Decorations) do
		local card = rowCard(64)
		local name = UIFactory.Label(decor.DisplayName, UDim2.new(1, -130, 0, 24), Theme.Text, 15)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.new(0, 0, 0, 12)
		name.Parent = card
		local priceText = decor.Currency == "Gems"
			and (tostring(decor.Price) .. " G") or Format.Money(decor.Price)
		local buy = UIFactory.Button(priceText, function()
			ctx.Controllers.BaseController.BuyDecoration(decor.Id)
		end)
		buy.Size = UDim2.new(0, 110, 0, 36)
		buy.Position = UDim2.new(1, -118, 0, 8)
		buy.Parent = card
		card.Parent = decorPage
	end
end

function ShopUI.SetVisible(visible)
	if visible then
		ShopUI.Refresh()
	end
	window.SetVisible(visible)
end

function ShopUI.Toggle()
	ShopUI.SetVisible(not window.IsVisible())
end

return ShopUI
