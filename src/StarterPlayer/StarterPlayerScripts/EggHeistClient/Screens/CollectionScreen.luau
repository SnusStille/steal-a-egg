-- EggHeist | Client/Screens/CollectionScreen.luau
-- Discovery grid: every pet x Normal/Mutated combos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Collection = require(ConfigFolder:WaitForChild("Collection"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local CollectionScreen = {}
local ctx = nil
local window = nil
local grid = nil
local progressLabel = nil
local milestoneBox = nil
local gridHolder = nil
local rarityButton = nil
local mutButton = nil
local searchBox = nil
local rarityFilter = nil -- nil = all rarities
local mutOnly = false
local searchText = ''

local Theme = UIFactory.Theme

function CollectionScreen.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistCollection", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Collection", UDim2.new(0, 560, 0, 560))
	progressLabel = UIFactory.Label("", UDim2.new(1, 0, 0, 24), Theme.Accent, 14)
	progressLabel.Parent = window.Content
	local milestoneHeight = 30 + #Collection.Milestones * 28 + 8
	milestoneBox = Instance.new("Frame")
	milestoneBox.Position = UDim2.new(0, 0, 0, 28)
	milestoneBox.Size = UDim2.new(1, 0, 0, milestoneHeight)
	milestoneBox.BackgroundColor3 = Theme.Panel
	milestoneBox.BorderSizePixel = 0
	milestoneBox.Parent = window.Content
	local milestoneCorner = Instance.new("UICorner")
	milestoneCorner.CornerRadius = UDim.new(0, 8)
	milestoneCorner.Parent = milestoneBox
	local milestonePad = Instance.new("UIPadding")
	milestonePad.PaddingTop = UDim.new(0, 6)
	milestonePad.PaddingLeft = UDim.new(0, 10)
	milestonePad.PaddingRight = UDim.new(0, 10)
	milestonePad.Parent = milestoneBox
	local filterTop = 28 + milestoneHeight + 6
	local filterBar = Instance.new("Frame")
	filterBar.Position = UDim2.new(0, 0, 0, filterTop)
	filterBar.Size = UDim2.new(1, 0, 0, 34)
	filterBar.BackgroundTransparency = 1
	filterBar.Parent = window.Content
	rarityButton = UIFactory.Button("Rarity: All", function()
		local order = {}
		for _, rarity in ipairs(Rarities.List) do
			order[#order + 1] = rarity.Id
		end
		if rarityFilter == nil then
			rarityFilter = order[1]
		else
			local nextIndex = nil
			for i, id in ipairs(order) do
				if id == rarityFilter then
					nextIndex = i + 1
					break
				end
			end
			if nextIndex and order[nextIndex] then
				rarityFilter = order[nextIndex]
			else
				rarityFilter = nil
			end
		end
		rarityButton.Text = "Rarity: " .. tostring(rarityFilter or "All")
		CollectionScreen.Refresh()
	end)
	rarityButton.Size = UDim2.new(0, 130, 0, 30)
	rarityButton.Position = UDim2.new(0, 0, 0, 2)
	rarityButton.Parent = filterBar
	mutButton = UIFactory.Button("Mutated: Off", function()
		mutOnly = not mutOnly
		mutButton.Text = mutOnly and "Mutated: ON" or "Mutated: Off"
		mutButton.BackgroundColor3 = mutOnly and Theme.Accent or Theme.Button
		CollectionScreen.Refresh()
	end)
	mutButton.Size = UDim2.new(0, 130, 0, 30)
	mutButton.Position = UDim2.new(0, 136, 0, 2)
	mutButton.Parent = filterBar
	searchBox = Instance.new("TextBox")
	searchBox.PlaceholderText = "Search..."
	searchBox.Text = ""
	searchBox.ClearTextOnFocus = false
	searchBox.Size = UDim2.new(1, -272, 0, 30)
	searchBox.Position = UDim2.new(0, 272, 0, 2)
	searchBox.BackgroundColor3 = Theme.Button
	searchBox.TextColor3 = Theme.Text
	searchBox.PlaceholderColor3 = Theme.TextDim
	searchBox.Font = Theme.FontRegular
	searchBox.TextSize = 13
	UIFactory.Corner(searchBox, 8)
	searchBox.Parent = filterBar
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = string.lower(searchBox.Text or "")
		CollectionScreen.Refresh()
	end)
	gridHolder = Instance.new("Frame")
	gridHolder.Position = UDim2.new(0, 0, 0, filterTop + 38)
	gridHolder.Size = UDim2.new(1, 0, 1, -(filterTop + 38))
	gridHolder.BackgroundTransparency = 1
	gridHolder.Parent = window.Content
	grid = UIFactory.Grid(gridHolder, UDim2.new(0, 158, 0, 120), 8)

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() then
				CollectionScreen.Refresh()
			end
		end)
	end
end

function CollectionScreen.Refresh()
	local snapshot = ctx.Data and ctx.Data.Get()
	if not snapshot then
		return
	end
	UIFactory.ClearChildren(grid, true)
	-- Milestone panel (rewards granted automatically by the server)
	UIFactory.ClearChildren(milestoneBox, true)
	local milestoneHeader = UIFactory.Label("COLLECTION MILESTONES", UDim2.new(1, 0, 0, 24),
		Theme.Accent, 13)
	milestoneHeader.TextXAlignment = Enum.TextXAlignment.Left
	milestoneHeader.Parent = milestoneBox
	local claimedMilestones = snapshot.collectionRewards or {}
	for i, milestone in ipairs(Collection.Milestones) do
		local id = milestone.Id or ("tier" .. tostring(i))
		local claimed = claimedMilestones[id] == true
		local parts = {}
		if milestone.Cash and milestone.Cash > 0 then
			parts[#parts + 1] = Format.Money(milestone.Cash)
		end
		if milestone.Gems and milestone.Gems > 0 then
			parts[#parts + 1] = tostring(milestone.Gems) .. " G"
		end
		if milestone.Xp and milestone.Xp > 0 then
			parts[#parts + 1] = "+" .. tostring(milestone.Xp) .. " XP"
		end
		local row = UIFactory.Label(tostring(milestone.Required) .. " pets  ->  "
			.. table.concat(parts, "  +  ") .. (claimed and "   (claimed)" or ""),
			UDim2.new(1, 0, 0, 26), claimed and Theme.TextDim or Theme.Text, 12)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Position = UDim2.new(0, 0, 0, 24 + (i - 1) * 28)
		row.Font = Theme.FontRegular
		row.Parent = milestoneBox
	end
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
	-- Showcase: 3 rarest OWNED entries (gold frames, spoiler-free)
	local owned = {}
	for _, entry in ipairs(entries) do
		local key = entry.pet.Id .. ":" .. (entry.mut or "Normal")
		if (collection[key] or 0) > 0 then
			owned[#owned + 1] = entry
		end
	end
	table.sort(owned, function(a, b)
		local tierA = Rarities.GetTier(a.pet.Rarity)
		local tierB = Rarities.GetTier(b.pet.Rarity)
		if tierA ~= tierB then
			return tierA > tierB
		end
		if (a.mut ~= nil) ~= (b.mut ~= nil) then
			return a.mut ~= nil
		end
		return (a.pet.BaseIncome or 0) > (b.pet.BaseIncome or 0)
	end)
	for i = 1, math.min(3, #owned) do
		local entry = owned[i]
		local showcase = Instance.new("Frame")
		showcase.Size = UDim2.new(0, 158, 0, 44)
		showcase.BackgroundColor3 = Theme.Card
		showcase.BorderSizePixel = 0
		UIFactory.Corner(showcase, 8)
		UIFactory.Stroke(showcase, Color3.fromRGB(255, 205, 60), 2)
		UIFactory.Padding(showcase, 6)
		local title = (entry.mut and (entry.mut .. " ") or "") .. entry.pet.DisplayName
		local star = UIFactory.Label("SHOWCASE: " .. title, UDim2.new(1, 0, 1, 0),
			Color3.fromRGB(255, 220, 120), 11)
		star.TextWrapped = true
		star.Font = Theme.FontRegular
		star.Parent = showcase
		showcase.Parent = grid
		showcase.LayoutOrder = -10 + i
	end
	for _, entry in ipairs(entries) do
		local key = entry.pet.Id .. ":" .. (entry.mut or "Normal")
		local count = collection[key] or 0
		-- filters (spoiler-safe: search only matches discovered names)
		local show = true
		if rarityFilter and entry.pet.Rarity ~= rarityFilter then
			show = false
		end
		if mutOnly and entry.mut == nil then
			show = false
		end
		if searchText ~= "" then
			if count == 0 or not string.find(string.lower(entry.pet.DisplayName), searchText, 1, true) then
				show = false
			end
		end
		if count > 0 then
			found = found + 1
		end
		if show then
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
		::skipEntry::
	end
	progressLabel.Text = "Discovered " .. tostring(found) .. " / " .. tostring(total)
		.. "  (" .. tostring(math.floor(found / math.max(1, total) * 100)) .. "%)"
end

function CollectionScreen.SetVisible(visible)
	if visible then
		CollectionScreen.Refresh()
	end
	window.SetVisible(visible)
end

function CollectionScreen.Toggle()
	CollectionScreen.SetVisible(not window.IsVisible())
end

return CollectionScreen
