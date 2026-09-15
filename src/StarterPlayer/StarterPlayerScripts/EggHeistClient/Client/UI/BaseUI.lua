-- EggHeist | Client/UI/BaseUI.lua
-- Base management: vault, upgrades, security.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Upgrades = require(ConfigFolder:WaitForChild("Upgrades"))
local Security = require(ConfigFolder:WaitForChild("Security"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local BaseUI = {}
local ctx = nil
local window = nil
local pages = {}
local tabButtons = {}

local Theme = UIFactory.Theme
local TABS = { "Vault", "Upgrades", "Security" }

function BaseUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistBase", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "My Base", UDim2.new(0, 520, 0, 460))

	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window.Content
	for i, tab in ipairs(TABS) do
		local button = UIFactory.Button(tab, function()
			BaseUI.ShowTab(tab)
		end)
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.Position = UDim2.new((i - 1) / 3, 3, 0, 0)
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
	end
	BaseUI.ShowTab("Vault")

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				BaseUI.Refresh()
			end
		end)
	end
end

function BaseUI.ShowTab(tab)
	for name, page in pairs(pages) do
		page.Visible = name == tab
	end
	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = name == tab and Theme.Accent or Theme.Button
		button.TextColor3 = name == tab and Color3.fromRGB(30, 25, 10) or Theme.Text
	end
end

function BaseUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	local base = snapshot.base or {}
	local level = snapshot.level or 1

	-- Vault page
	local vaultPage = pages.Vault
	UIFactory.ClearChildren(vaultPage, false)
	if (base.plot or 0) == 0 then
		local label = UIFactory.Label("You don't own a base yet.\nWalk to an empty plot and press CLAIM!",
			UDim2.new(1, 0, 0, 80), Theme.Warning, 15)
		label.TextWrapped = true
		label.Parent = vaultPage
		local claim = UIFactory.PrimaryButton("CLAIM A BASE", function()
			ctx.Controllers.BaseController.ClaimBase()
		end)
		claim.Size = UDim2.new(0, 220, 0, 44)
		claim.Position = UDim2.new(0.5, -110, 0, 100)
		claim.Parent = vaultPage
	else
		local vault = base.vault or 0
		local amountLabel = UIFactory.Label("Vault: " .. Format.Money(vault),
			UDim2.new(1, 0, 0, 40), Theme.Accent, 22)
		amountLabel.Parent = vaultPage
		local info = UIFactory.Label(
			"15% of your earnings flow into the vault.\nThieves can steal from it - collect often and buy security!",
			UDim2.new(1, 0, 0, 60), Theme.TextDim, 13)
		info.Position = UDim2.new(0, 0, 0, 44)
		info.TextWrapped = true
		info.Font = Theme.FontRegular
		info.Parent = vaultPage
		local collect = UIFactory.PrimaryButton("COLLECT " .. Format.Money(vault), function()
			ctx.Controllers.BaseController.CollectVault()
		end)
		collect.Size = UDim2.new(0, 240, 0, 44)
		collect.Position = UDim2.new(0.5, -120, 0, 120)
		collect.Parent = vaultPage
		local secLevel = Security.ComputeLevel(base.security)
		local secLabel = UIFactory.Label("Security level: " .. tostring(secLevel) .. "/100",
			UDim2.new(1, 0, 0, 26), Theme.Text, 14)
		secLabel.Position = UDim2.new(0, 0, 0, 180)
		secLabel.Parent = vaultPage
		local _, secFill = UIFactory.ProgressBar(vaultPage, 12, Color3.fromRGB(255, 90, 90))
		secFill.Parent.Position = UDim2.new(0, 20, 0, 210)
		secFill.Parent.Size = UDim2.new(1, -40, 0, 12)
		UIFactory.SetProgress(secFill, secLevel / 100)
	end

	-- Upgrades page
	local upgradesPage = pages.Upgrades
	UIFactory.ClearChildren(upgradesPage, false)
	local upgradesScroll = UIFactory.ScrollingList(upgradesPage)
	for _, trackId in ipairs(Upgrades.TrackOrder) do
		local track = Upgrades.Tracks[trackId]
		local current = (base.upgrades and base.upgrades[trackId]) or 0
		local maxed = current >= track.MaxTier
		local card = UIFactory.Card(88)
		local name = UIFactory.Label(track.DisplayName .. "  (Tier " .. tostring(current)
			.. "/" .. tostring(track.MaxTier) .. ")", UDim2.new(1, -130, 0, 24), Theme.Text, 14)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = card
		local desc = UIFactory.Label(track.Description, UDim2.new(1, -130, 0, 44),
			Theme.TextDim, 12)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Position = UDim2.new(0, 0, 0, 26)
		desc.Font = Theme.FontRegular
		desc.Parent = card
		if maxed then
			local maxLabel = UIFactory.Label("MAXED", UDim2.new(0, 110, 0, 40), Theme.Success, 14)
			maxLabel.Position = UDim2.new(1, -118, 0, 16)
			maxLabel.Parent = card
		else
			local nextTier = current + 1
			local cost = Upgrades.GetCost(trackId, nextTier)
			local req = track.RequiredLevel(nextTier)
			local buy = UIFactory.PrimaryButton(Format.Money(cost), function()
				ctx.Controllers.BaseController.BuyUpgrade(trackId)
			end)
			buy.Size = UDim2.new(0, 110, 0, 40)
			buy.Position = UDim2.new(1, -118, 0, 16)
			buy.Parent = card
			if level < req then
				buy.Text = "Lv " .. tostring(req)
				buy.BackgroundColor3 = Theme.Button
				buy.TextColor3 = Theme.TextDim
			end
		end
		card.Parent = upgradesScroll
	end

	-- Security page
	local securityPage = pages.Security
	UIFactory.ClearChildren(securityPage, false)
	local securityScroll = UIFactory.ScrollingList(securityPage)
	for _, itemId in ipairs(Security.ItemOrder) do
		local item = Security.Items[itemId]
		local current = (base.security and base.security[itemId]) or 0
		local maxed = current >= item.MaxTier
		local card = UIFactory.Card(88)
		local name = UIFactory.Label(item.DisplayName .. "  (Tier " .. tostring(current)
			.. "/" .. tostring(item.MaxTier) .. ")", UDim2.new(1, -130, 0, 24), Theme.Text, 14)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = card
		local desc = UIFactory.Label(item.Description, UDim2.new(1, -130, 0, 44),
			Theme.TextDim, 12)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Position = UDim2.new(0, 0, 0, 26)
		desc.Font = Theme.FontRegular
		desc.Parent = card
		if maxed then
			if itemId == "Lockdown" then
				local lockdown = UIFactory.Button("TRIGGER", function()
					ctx.Controllers.BaseController.ToggleLockdown()
				end)
				lockdown.Size = UDim2.new(0, 110, 0, 40)
				lockdown.Position = UDim2.new(1, -118, 0, 16)
				lockdown.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
				lockdown.Parent = card
			else
				local maxLabel = UIFactory.Label("MAXED", UDim2.new(0, 110, 0, 40), Theme.Success, 14)
				maxLabel.Position = UDim2.new(1, -118, 0, 16)
				maxLabel.Parent = card
			end
		else
			local nextTier = current + 1
			local cost = Security.GetCost(itemId, nextTier)
			local req = item.RequiredLevel(nextTier)
			local buy = UIFactory.Button(Format.Money(cost), function()
				ctx.Controllers.BaseController.BuySecurity(itemId)
			end)
			buy.Size = UDim2.new(0, 110, 0, 40)
			buy.Position = UDim2.new(1, -118, 0, 16)
			buy.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
			buy.Parent = card
			if level < req then
				buy.Text = "Lv " .. tostring(req)
				buy.BackgroundColor3 = Theme.Button
				buy.TextColor3 = Theme.TextDim
			end
		end
		card.Parent = securityScroll
	end
end

function BaseUI.SetVisible(visible)
	if visible then
		BaseUI.Refresh()
	end
	window.SetVisible(visible)
end

function BaseUI.Toggle()
	BaseUI.SetVisible(not window.IsVisible())
end

return BaseUI
