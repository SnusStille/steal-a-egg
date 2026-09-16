-- EggHeist | Server/Pets/PetService.luau
-- Pet inventory, equipping, leveling, and the 3D followers that trail players.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local UpgradesConfig = require(ConfigFolder:WaitForChild("Upgrades"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))
local ModelFactory = require(Shared:WaitForChild("Utilities"):WaitForChild("ModelFactory"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Types = require(Shared:WaitForChild("Types"))

local PetService = {}
PetService.Name = "PetService"

local registry = nil
local followers = {} -- [userId] = { {uid=..., model=..., parts=..., slot=..., phase=..., hidden=...}, ... }
local petFolders = {} -- [userId] = Folder

function PetService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

function PetService.FindPet(profile, petUid)
	for index, pet in ipairs(profile.pets) do
		if pet.uid == petUid then
			return pet, index
		end
	end
	return nil, nil
end

function PetService.IsEquipped(profile, petUid)
	for _, uid in ipairs(profile.equipped) do
		if uid == petUid then
			return true
		end
	end
	return false
end

-- Sums Bonus { Stat, Pct } over EQUIPPED pets (caps prevent runaway stacking).
-- Consumed by Economy (income) and Heist (breach/carry/payout) services.
local BONUS_CAPS = {
	IncomePct = 40,
	BreachSpeedPct = 25,
	CarrySpeedPct = 25,
	HeistPayoutPct = 40,
}

function PetService.GetEquippedBonuses(player)
	local totals = { IncomePct = 0, BreachSpeedPct = 0, CarrySpeedPct = 0, HeistPayoutPct = 0 }
	local profile = profileOf(player)
	if not profile then
		return totals
	end
	for _, uid in ipairs(profile.equipped or {}) do
		local pet = PetService.FindPet(profile, uid)
		local def = pet and Pets.ById[pet.id] or nil
		if def and def.Bonus then
			local stat, pct = def.Bonus[1], tonumber(def.Bonus[2]) or 0
			if totals[stat] ~= nil and pct > 0 then
				totals[stat] = totals[stat] + pct
			end
		end
	end
	for stat, cap in pairs(BONUS_CAPS) do
		if totals[stat] > cap then
			totals[stat] = cap
		end
	end
	return totals
end

function PetService.MaxSlots(player)
	local profile = profileOf(player)
	local slots = Economy.BasePetSlots
	if profile then
		for level, total in pairs(Economy.SlotUnlockLevels) do
			if profile.level >= level and total > slots then
				slots = total
			end
		end
		if profile.gamepasses and profile.gamepasses.ExtraSlots then
			slots = slots + 2
		end
	end
	return math.min(slots, Economy.MaxPetSlots)
end

function PetService.PetIncomePerSecond(pet)
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

function PetService.ComputeEquippedIncome(player)
	local profile = profileOf(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, uid in ipairs(profile.equipped) do
		local pet = PetService.FindPet(profile, uid)
		if pet then
			total = total + PetService.PetIncomePerSecond(pet)
		end
	end
	return total
end

function PetService.GetSellValue(pet)
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

function PetService.GrantEquippedXp(player, seconds)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local comfortMult = 1
	if profile.base and profile.base.upgrades then
		local Upgrades = require(ConfigFolder:WaitForChild("Upgrades"))
		comfortMult = Upgrades.Tracks.Comfort.Effect(profile.base.upgrades.Comfort or 0)
	end
	local changed = false
	for _, uid in ipairs(profile.equipped) do
		local pet = PetService.FindPet(profile, uid)
		if pet and (pet.lvl or 1) < Economy.PetMaxLevel then
			pet.xp = (pet.xp or 0) + seconds * comfortMult
			while (pet.lvl or 1) < Economy.PetMaxLevel
				and (pet.xp or 0) >= Economy.PetXpPerLevel(pet.lvl or 1) do
				pet.xp = pet.xp - Economy.PetXpPerLevel(pet.lvl or 1)
				pet.lvl = (pet.lvl or 1) + 1
			end
			changed = true
		end
	end
	if changed then
		registry.Data.MarkDirty(player)
	end
end

function PetService.Equip(player, petUid)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local pet = PetService.FindPet(profile, petUid)
	if not pet then
		return false
	end
	if PetService.IsEquipped(profile, petUid) then
		return true
	end
	if #profile.equipped >= PetService.MaxSlots(player) then
		registry.Notify.Send(player, "warning", "No free slots",
			"Unequip a pet or unlock more slots.", 4)
		return false
	end
	profile.equipped[#profile.equipped + 1] = petUid
	registry.Data.MarkDirty(player)
	registry.Quest.AddProgress(player, "EquipPets", 0) -- re-evaluated as count check
	if registry.Achievement then
		registry.Achievement.Check(player, "EquipPet")
	end
	if registry.TutorialHook then
		registry.TutorialHook(player, "EquipPet")
	end
	PetService.RebuildFollowers(player)
	PetService.RebuildDisplays(player)
	return true
end

function PetService.Unequip(player, petUid)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	for i, uid in ipairs(profile.equipped) do
		if uid == petUid then
			table.remove(profile.equipped, i)
			registry.Data.MarkDirty(player)
			PetService.RebuildFollowers(player)
			PetService.RebuildDisplays(player)
			return true
		end
	end
	return false
end

-- Sells a pet for full value. DeletePet sells for 50% (quick cleanup).
function PetService.Sell(player, petUid, fraction)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local pet, index = PetService.FindPet(profile, petUid)
	if not pet then
		return false
	end
	if pet.locked then
		registry.Notify.Send(player, "warning", "Pet locked",
			"Unlock this pet before selling or deleting it.", 4)
		return false
	end
	local value = math.floor(PetService.GetSellValue(pet) * (fraction or 1))
	table.remove(profile.pets, index)
	-- remove from equipped
	for i, uid in ipairs(profile.equipped) do
		if uid == petUid then
			table.remove(profile.equipped, i)
			break
		end
	end
	if value > 0 then
		registry.Economy.AddCash(player, value, "sell")
	else
		registry.Data.MarkDirty(player)
	end
	PetService.RebuildFollowers(player)
	PetService.RebuildDisplays(player)
	return true
end

function PetService.ToggleLock(player, petUid)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local pet = PetService.FindPet(profile, petUid)
	if not pet then
		return false
	end
	pet.locked = not pet.locked
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "info", pet.locked and "Pet locked" or "Pet unlocked",
		pet.locked and "Safe from selling, deleting and prestige." or "This pet can be sold again.", 3)
	return true
end

--------------------------------------------------------------------------------
-- Followers (3D pets trailing the player)
--------------------------------------------------------------------------------

-- Captures each child part's CFrame relative to the primary so tilted
-- parts (wings/ears/tails) keep local rotation while following.
local function captureGlue(model, primary)
	local parts = {}
	if not primary then
		return parts
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= primary then
			local rel = nil
			pcall(function()
				rel = primary.CFrame:ToObjectSpace(part.CFrame)
			end)
			if not rel then
				rel = CFrame.new(part.Position - primary.Position)
			end
			parts[#parts + 1] = { part = part, rel = rel }
		end
	end
	return parts
end

local function applyGlue(primary, parts)
	for _, child in ipairs(parts or {}) do
		if child.part and child.part.Parent then
			local ok = pcall(function()
				child.part.CFrame = primary.CFrame:ToWorldSpace(child.rel)
			end)
			if not ok then
				child.part.CFrame = CFrame.new(primary.Position + child.rel.Position)
					* (primary.CFrame - primary.Position)
			end
		end
	end
end

local function buildFollowerModel(pet)
	local model = ModelFactory.BuildCreature(pet.id, pet.mut, 0.55)
	model.Name = "Pet_" .. pet.uid
	local adornee = model.PrimaryPart or model:FindFirstChild("Body")
	if adornee then
		local tag = Instance.new("BillboardGui")
		tag.Name = "Nametag"
		tag.Size = UDim2.new(0, 120, 0, 28)
		tag.StudsOffset = Vector3.new(0, 2.2, 0)
		tag.AlwaysOnTop = false
		tag.MaxDistance = 60
		tag.Parent = adornee
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		local def = Pets.ById[pet.id]
		local displayName = def and def.DisplayName or "Pal"
		if pet.mut then
			displayName = pet.mut .. " " .. displayName
		end
		text.Text = displayName .. " Lv" .. tostring(pet.lvl or 1)
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 13
		text.TextStrokeTransparency = 0.5
		text.Parent = tag
	end
	return model
end

function PetService.RebuildFollowers(player)
	local userId = player.UserId
	local old = followers[userId]
	if old then
		for _, entry in ipairs(old) do
			if entry.model then
				entry.model:Destroy()
			end
		end
	end
	followers[userId] = {}
	local profile = profileOf(player)
	if not profile then
		return
	end
	if profile.settings and profile.settings.showPets == false then
		return
	end
	local liveFolder = registry.World.GetLiveFolder()
	local petFolder = liveFolder:FindFirstChild("Pets_" .. tostring(userId))
	if not petFolder then
		petFolder = Instance.new("Folder")
		petFolder.Name = "Pets_" .. tostring(userId)
		petFolder.Parent = liveFolder
	end
	petFolders[userId] = petFolder
	for slot, uid in ipairs(profile.equipped) do
		if slot > Settings.Pets.MaxVisiblePerPlayer then
			break
		end
		local pet = PetService.FindPet(profile, uid)
		if pet then
			local ok, model = pcall(buildFollowerModel, pet)
			if ok and model then
				model.Parent = petFolder
				local parts = captureGlue(model, model.PrimaryPart)
				followers[userId][#followers[userId] + 1] = {
					uid = uid,
					model = model,
					parts = parts,
					slot = slot,
					phase = math.random() * math.pi * 2,
					hidden = false,
				}
			end
		end
	end
end

function PetService.CleanupPlayer(player)
	local userId = player.UserId
	local old = followers[userId]
	if old then
		for _, entry in ipairs(old) do
			if entry.model then
				pcall(function() entry.model:Destroy() end)
			end
		end
		followers[userId] = nil
	end
	local liveFolder = registry.World.GetLiveFolder()
	if liveFolder then
		local petFolder = liveFolder:FindFirstChild("Pets_" .. tostring(userId))
		if petFolder then
			pcall(function() petFolder:Destroy() end)
		end
	end
	petFolders[userId] = nil
end

-- Single heartbeat updates ALL followers (cheap: anchored CFrame sets).
-- Far-away pets are unparented (with hysteresis) to save replication.
local function updateFollowers(dt)
	local time = os.clock()
	local hideDist = Settings.Pets.HideBeyondDistance or 250
	for _, player in ipairs(Players:GetPlayers()) do
		local list = followers[player.UserId]
		if list and #list > 0 then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local base = hrp.CFrame
				for _, entry in ipairs(list) do
					local model = entry.model
					local primary = model and model.PrimaryPart
					if primary then
						local angle = (entry.slot / (#list + 1)) * math.pi * 2
						local dist = Settings.Pets.FollowDistance + entry.slot * 0.35
						local target = base * CFrame.new(
							math.sin(angle) * dist,
							Settings.Pets.FollowHeight + math.sin(time * 2 + entry.phase) * 0.5,
							math.cos(angle) * dist
						)
						-- face away from player so the face shows outward
						local look = target.Position - base.Position
						if look.Magnitude > 0.01 then
							target = CFrame.new(target.Position, target.Position + look)
						end
						-- distance culling with hysteresis (hide far, show near)
						local playerDist = (target.Position - base.Position).Magnitude
						local farDist = (primary.Position - base.Position).Magnitude
						if not entry.hidden and farDist > hideDist + 60 then
							entry.hidden = true
							model.Parent = nil
						elseif entry.hidden and playerDist < hideDist then
							entry.hidden = false
							model.Parent = petFolders[player.UserId]
						end
						if not entry.hidden then
							local alpha = math.min(1, dt * Settings.Pets.FollowLerp)
							primary.CFrame = primary.CFrame:Lerp(target, alpha)
							applyGlue(primary, entry.parts)
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Base displays (equipped creatures exhibited on plot stands)
--------------------------------------------------------------------------------

local STAND_OFFSETS = {
	Vector3.new(-12, 0, -12), Vector3.new(-4, 0, -12),
	Vector3.new(4, 0, -12), Vector3.new(12, 0, -12),
}
local MAX_DISPLAYS = 4

local displays = {} -- [plotIndex] = { {model=, parts=, basePos=, phase=}, ... }
local standRefs = {} -- [plotIndex] = { [i] = { top, label, prompt } }

local function displayFurniture(plotIndex)
	local plot = registry.World.GetPlotModel(plotIndex)
	if not plot then
		return nil
	end
	local furniture = plot:FindFirstChild("ServerFurniture")
	if not furniture then
		furniture = Instance.new("Folder")
		furniture.Name = "ServerFurniture"
		furniture.Parent = plot
	end
	return furniture
end

--- Builds the 4 display stands for a plot. Idempotent.
function PetService.BuildStands(plotIndex)
	local furniture = displayFurniture(plotIndex)
	if not furniture then
		return
	end
	local plot = registry.World.GetPlotModel(plotIndex)
	local foundation = plot and plot:FindFirstChild("Foundation")
	if not foundation or not foundation:IsA("BasePart") then
		return
	end
	local stands = furniture:FindFirstChild("DisplayStands")
	if not stands then
		stands = Instance.new("Folder")
		stands.Name = "DisplayStands"
		stands.Parent = furniture
	end
	standRefs[plotIndex] = standRefs[plotIndex] or {}
	for i = 1, MAX_DISPLAYS do
		if not stands:FindFirstChild("Stand" .. i) then
			local spot = ModelFactory.FindClearSpot(plot, STAND_OFFSETS[i], 3.5, 15)
			local base = foundation.Position
				+ Vector3.new(0, foundation.Size.Y / 2, 0)
				+ spot
			local stand = Instance.new("Part")
			stand.Name = "Stand" .. i
			stand.Shape = Enum.PartType.Cylinder
			stand.Size = Vector3.new(2.4, 4, 4)
			stand.CFrame = CFrame.new(base + Vector3.new(0, 1.2, 0))
				* CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2)
			stand.Color = Color3.fromRGB(60, 63, 85)
			stand.Material = Enum.Material.SmoothPlastic
			stand.Anchored = true
			stand.CanCollide = true
			stand.TopSurface = Enum.SurfaceType.Smooth
			stand.BottomSurface = Enum.SurfaceType.Smooth
			stand.Parent = stands
			local top = Instance.new("Part")
			top.Name = "Top"
			top.Shape = Enum.PartType.Cylinder
			top.Size = Vector3.new(0.4, 4.6, 4.6)
			top.CFrame = CFrame.new(base + Vector3.new(0, 2.6, 0))
				* CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2)
			top.Color = Color3.fromRGB(120, 160, 255)
			top.Material = Enum.Material.Neon
			top.Transparency = 0.35
			top.Anchored = true
			top.CanCollide = false
			top.CanQuery = false
			top.Parent = stand
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "StandLabel"
			billboard.Size = UDim2.new(0, 150, 0, 50)
			billboard.StudsOffset = Vector3.new(0, 6, 0)
			billboard.AlwaysOnTop = false
			billboard.MaxDistance = 70
			billboard.Parent = stand
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = "Display"
			text.TextColor3 = Color3.fromRGB(160, 165, 190)
			text.Font = Enum.Font.GothamBold
			text.TextScaled = true
			text.TextStrokeTransparency = 0.5
			text.Parent = billboard
			local steal = Instance.new("ProximityPrompt")
			steal.Name = "StealPetPrompt"
			steal.ActionText = "Steal"
			steal.ObjectText = "Creature"
			steal.HoldDuration = 0.5
			steal.MaxActivationDistance = 10
			steal.RequiresLineOfSight = false
			steal.Enabled = false -- enabled when a creature is exhibited
			steal.Parent = stand
			local slot = i
			steal.Triggered:Connect(function(triggerPlayer)
				PetService.OnStealPrompt(triggerPlayer, plotIndex, slot)
			end)
			standRefs[plotIndex][i] = { top = base + Vector3.new(0, 2.8, 0), label = text, prompt = steal }
		end
	end
end

--- Destroys displayed creature models on a plot (stands stay).
function PetService.ClearDisplays(plotIndex)
	local list = displays[plotIndex]
	if list then
		for _, entry in ipairs(list) do
			if entry.model then
				pcall(function() entry.model:Destroy() end)
			end
		end
		displays[plotIndex] = nil
	end
	local refs = standRefs[plotIndex]
	if refs then
		for i = 1, MAX_DISPLAYS do
			local ref = refs[i]
			if ref and ref.label and ref.label.Parent then
				ref.label.Text = "Display"
				ref.label.TextColor3 = Color3.fromRGB(160, 165, 190)
			end
		end
	end
end

local function formatIncome(value)
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return string.format("%.0f", value)
end

--- Exhibits the first equipped pets on the plot stands.
function PetService.RebuildDisplays(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local plotIndex = profile.base.plot or 0
	if plotIndex <= 0 then
		return
	end
	PetService.BuildStands(plotIndex)
	PetService.ClearDisplays(plotIndex)
	local furniture = displayFurniture(plotIndex)
	if not furniture then
		return
	end
	local shown = furniture:FindFirstChild("DisplayedPets")
	if not shown then
		shown = Instance.new("Folder")
		shown.Name = "DisplayedPets"
		shown.Parent = furniture
	end
	displays[plotIndex] = {}
	local occupied = {}
	for slot, uid in ipairs(profile.equipped or {}) do
		if slot > MAX_DISPLAYS then
			break
		end
		local pet = PetService.FindPet(profile, uid)
		local ref = standRefs[plotIndex] and standRefs[plotIndex][slot] or nil
		if pet and ref then
			local ok, model = pcall(ModelFactory.BuildCreature, pet.id, pet.mut, 0.8)
			if ok and model then
				model.Name = "Display_" .. pet.uid
				model.Parent = shown
				ModelFactory.Pose(model, CFrame.new(ref.top + Vector3.new(0, 1.1, 0)))
				local primary = model.PrimaryPart
				displays[plotIndex][#displays[plotIndex] + 1] = {
					model = model,
					parts = captureGlue(model, primary),
					basePos = (primary and primary.Position) or ref.top,
					phase = math.random() * math.pi * 2,
				}
				local def = Pets.ById[pet.id]
				local title = (def and def.DisplayName) or pet.id
				if pet.mut then
					title = pet.mut .. " " .. title
				end
				if ref.label and ref.label.Parent then
					ref.label.Text = title .. "  +$" .. formatIncome(PetService.PetIncomePerSecond(pet)) .. "/s"
					ref.label.TextColor3 = Rarities.GetColor((def and def.Rarity) or "Common")
				end
				if ref.prompt then
					ref.prompt.Enabled = true
					ref.prompt.ObjectText = title
				end
				occupied[slot] = true
			end
		end
	end
	for i = 1, MAX_DISPLAYS do
		local ref = standRefs[plotIndex] and standRefs[plotIndex][i] or nil
		if ref and ref.prompt and not occupied[i] then
			ref.prompt.Enabled = false
		end
	end
end

-- Idle bob for every displayed creature (same heartbeat as followers).
function updateDisplays()
	local time = os.clock()
	for _, list in pairs(displays) do
		for _, entry in ipairs(list) do
			local model = entry.model
			local primary = model and model.PrimaryPart
			if primary and model.Parent then
				local dy = math.sin(time * 1.5 + entry.phase) * 0.25
				primary.CFrame = CFrame.new(entry.basePos + Vector3.new(0, dy, 0))
					* (primary.CFrame - primary.Position)
				applyGlue(primary, entry.parts)
			end
		end
	end
end

--- Grants a pet directly (pet parade, fusion). Mirrors hatch insert:
--- fresh uid, collection count, dirty flag. Never equips.
function PetService.GrantPet(player, petId, mut)
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	if not Pets.ById[petId] then
		return nil
	end
	local pet = Types.NewPetRecord(registry.Data.GenerateUid(player), petId, mut)
	profile.pets[#profile.pets + 1] = pet
	local key = Types.CollectionKey(petId, mut)
	profile.collection[key] = (profile.collection[key] or 0) + 1
	registry.Data.MarkDirty(player)
	return pet
end

--- Snatch: removes a DISPLAYED (equipped) pet from the owner's profile.
--- Returns the pet record, or nil when there is nothing to take.
function PetService.TakeDisplayedPet(owner, petUid)
	local profile = profileOf(owner)
	if not profile then
		return nil
	end
	local pet, index = PetService.FindPet(profile, petUid)
	if not pet or not index then
		return nil
	end
	if not PetService.IsEquipped(profile, petUid) then
		return nil -- only showcased pets can be snatched
	end
	table.remove(profile.pets, index)
	for i, uid in ipairs(profile.equipped) do
		if uid == petUid then
			table.remove(profile.equipped, i)
			break
		end
	end
	registry.Data.MarkDirty(owner)
	PetService.RebuildFollowers(owner)
	PetService.RebuildDisplays(owner)
	return pet
end

--- Snatch fail path: gives a taken pet back (re-equips when a slot is free).
function PetService.RestoreTakenPet(owner, pet)
	local profile = profileOf(owner)
	if not profile or not pet then
		return false
	end
	profile.pets[#profile.pets + 1] = pet
	if #profile.equipped < PetService.MaxSlots(owner) then
		profile.equipped[#profile.equipped + 1] = pet.uid
	end
	registry.Data.MarkDirty(owner)
	PetService.RebuildFollowers(owner)
	PetService.RebuildDisplays(owner)
	return true
end

--- Stand Steal prompt (server-side): routes rival thieves into the heist.
function PetService.OnStealPrompt(thief, plotIndex, slot)
	local owner = registry.Base.GetOwnerOfPlot(plotIndex)
	if not owner or owner == thief then
		if owner == thief then
			registry.Notify.Send(thief, "info", "Your showcase",
				"That's your own creature!", 2)
		end
		return
	end
	if registry.Heist and registry.Heist.TryGrabPet then
		registry.Heist.TryGrabPet(thief, plotIndex, slot)
	end
end

--- Plot lifecycle hooks called by BaseService.
function PetService.OnPlotAssigned(player, _plotIndex)
	PetService.RebuildDisplays(player)
end

function PetService.OnPlotReleased(_player, plotIndex)
	PetService.ClearDisplays(plotIndex)
	standRefs[plotIndex] = nil
	displays[plotIndex] = nil
end

function PetService.Start()
	registry.Net.OnRequest("EquipPet", function(player, petUid)
		petUid = Validate.Uid(petUid)
		if petUid then
			PetService.Equip(player, petUid)
		end
	end)
	registry.Net.OnRequest("UnequipPet", function(player, petUid)
		petUid = Validate.Uid(petUid)
		if petUid then
			PetService.Unequip(player, petUid)
		end
	end)
	registry.Net.OnRequest("SellPet", function(player, petUid)
		petUid = Validate.Uid(petUid)
		if petUid then
			PetService.Sell(player, petUid, 1)
		end
	end)
	registry.Net.OnRequest("DeletePet", function(player, petUid)
		petUid = Validate.Uid(petUid)
		if petUid then
			PetService.Sell(player, petUid, 0.5)
		end
	end)
	registry.Net.OnRequest("TogglePetLock", function(player, petUid)
		petUid = Validate.Uid(petUid)
		if petUid then
			PetService.ToggleLock(player, petUid)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(0.5, function()
				if player.Parent then
					PetService.RebuildFollowers(player)
					PetService.RebuildDisplays(player)
				end
			end)
		end)
	end)
	-- also hook existing players (late load / Studio play solo)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			task.delay(0.5, function()
				if player.Parent then
					PetService.RebuildFollowers(player)
					PetService.RebuildDisplays(player)
				end
			end)
		end)
		task.delay(2, function()
			if player.Parent then
				PetService.RebuildFollowers(player)
				PetService.RebuildDisplays(player)
			end
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		updateFollowers(dt)
		updateDisplays()
	end)
end

return PetService
