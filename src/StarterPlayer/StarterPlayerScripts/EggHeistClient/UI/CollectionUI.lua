-- EggHeist | Client/UI/CollectionUI.lua
-- Discovery grid: every pet x Normal/Mutated combos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local CollectionUI = {}
local ctx = nil
local window = nil
local grid = nil
local progressLabel = nil

local Theme = UIFactory.Theme

function CollectionUI.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistCollection", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Collection", UDim2.new(0, 560, 0, 470))
	progressLabel = UIFactory.Label("", UDim2.new(1, 0, 0, 24), Theme.Accent, 14)
	progressLabel.Parent = window.Content
	local holder = Instance.new("Frame")
	holder.Position = UDim2.new(0, 0, 0, 28)
	holder.Size = UDim2.new(1, 0, 1, -28)
	holder.BackgroundTransparency = 1
	holder.Parent = window.Content
	grid = UIFactory.Grid(holder, UDim2.new(0, 158, 0, 120), 8)

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				CollectionUI.Refresh()
			end
		end)
	end
end

function CollectionUI.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	UIFactory.ClearChildren(grid, true)
	local collection = snapshot.collection or {}
	local found = 0
	local total = 0
	-- rows: for each pet, Normal + each mutation
	local entries = {}
	for _, pet in ipairs(Pets.List) do
		entries[#entries + 1] = { pet = pet, mut = nil }
		for _, mut in ipairs(Mutations.List) do
			entries[#entries + 1] = { pet = pet, mut = mut.Id }
		end
	end
	total = #entries
	for _, entry in ipairs(entries) do
		local key = entry.pet.Id .. ":" .. (entry.mut or "Normal")
		local count = collection[key] or 0
		if count > 0 then
			found = found + 1
		end
		local rarityColor = Rarities.GetColor(entry.pet.Rarity)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 158, 0, 120)
		card.BackgroundColor3 = Theme.Card
		card.BorderSizePixel = 0
		UIFactory.Corner(card, 8)
		if count > 0 then
			UIFactory.Stroke(card, entry.mut and Mutations.GetColor(entry.mut) or rarityColor, 2)
		else
			UIFactory.Stroke(card, Color3.fromRGB(50, 54, 75), 1)
		end
		UIFactory.Padding(card, 6)
		local title = (entry.mut and (entry.mut .. " ") or "") .. entry.pet.DisplayName
		if count == 0 then
			title = "???"
		end
		local name = UIFactory.Label(title, UDim2.new(1, 0, 0, 34),
			count > 0 and Theme.Text or Theme.TextDim, 12)
		name.TextWrapped = true
		name.Parent = card
		local sub = UIFactory.Label(
			count > 0 and (entry.pet.Rarity .. "  x" .. tostring(count)) or entry.pet.Rarity,
			UDim2.new(1, 0, 0, 20), rarityColor, 11)
		sub.Position = UDim2.new(0, 0, 0, 40)
		sub.Font = Theme.FontRegular
		sub.Parent = card
		local desc = UIFactory.Label(count > 0 and entry.pet.Description or "Not discovered",
			UDim2.new(1, 0, 0, 44), Theme.TextDim, 10)
		desc.Position = UDim2.new(0, 0, 0, 62)
		desc.TextWrapped = true
		desc.Font = Theme.FontRegular
		desc.Parent = card
		card.Parent = grid
	end
	progressLabel.Text = "Discovered " .. tostring(found) .. " / " .. tostring(total)
		.. "  (" .. tostring(math.floor(found / math.max(1, total) * 100)) .. "%)"
end

function CollectionUI.SetVisible(visible)
	if visible then
		CollectionUI.Refresh()
	end
	window.SetVisible(visible)
end

function CollectionUI.Toggle()
	CollectionUI.SetVisible(not window.IsVisible())
end

return CollectionUI
