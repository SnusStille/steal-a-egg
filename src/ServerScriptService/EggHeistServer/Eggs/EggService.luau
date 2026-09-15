-- EggHeist | Server/Eggs/EggService.luau
-- Egg purchasing, BASE PLACEMENT, timed hatching. ALL rolls happen here.
--
-- The playable loop: BuyEgg -> PlaceEgg on a base pad (physical egg with
-- a live timer) -> READY -> HATCH! prompt (or backpack button) -> doHatch
-- -> creature. Server validates owners, pads, positions and timers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))
local ModelFactory = require(Shared:WaitForChild("Utilities"):WaitForChild("ModelFactory"))
local Types = require(Shared:WaitForChild("Types"))

local EggService = {}
EggService.Name = "EggService"

local registry = nil
local rng = Random.new()

EggService.MaxPads = 6

-- Foundation-relative pad offsets (two rows of three, front half of plot)
local PAD_OFFSETS = {
	Vector3.new(-10, 0, 8), Vector3.new(0, 0, 8), Vector3.new(10, 0, 8),
	Vector3.new(-10, 0, 13), Vector3.new(0, 0, 13), Vector3.new(10, 0, 13),
}

local pendingReady = {} -- [userId] = { [eggUid] = hatchAt }
local padLabels = {} -- [plotIndex] = { [padIndex] = TextLabel }

function EggService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

--------------------------------------------------------------------------------
-- Rolls (unchanged math)
--------------------------------------------------------------------------------

-- Weighted rarity roll with luck applied to Rare+ weights
local function rollRarity(weights, luckMult)
	luckMult = luckMult or 1
	local total = 0
	local adjusted = {}
	for _, rarity in ipairs(Rarities.List) do
		local w = weights[rarity.Id] or 0
		if Rarities.GetTier(rarity.Id) >= 3 then
			w = w * luckMult -- Epic+ benefits from luck
		elseif Rarities.GetTier(rarity.Id) == 2 then
			w = w * (1 + (luckMult - 1) * 0.5)
		end
		adjusted[rarity.Id] = w
		total = total + w
	end
	if total <= 0 then
		return "Common"
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, rarity in ipairs(Rarities.List) do
		acc = acc + adjusted[rarity.Id]
		if roll <= acc then
			return rarity.Id
		end
	end
	return "Common"
end

-- Single mutation roll: rarest-first, first success wins.
local function rollMutation(eggTier, mutationMults)
	mutationMults = mutationMults or {}
	for i = #Mutations.List, 1, -1 do
		local mut = Mutations.List[i]
		if eggTier >= (mut.MinEggTier or 1) then
			local chance = mut.Chance * (mutationMults[mut.Id] or 1)
			if rng:NextNumber(0, 1) < chance then
				return mut.Id
			end
		end
	end
	return nil
end

function EggService.EggTierOf(eggId)
	local def = Eggs.ById[eggId]
	if def and type(def.Tier) == "number" then
		return def.Tier
	end
	return 1
end

-- Core hatch roll. Returns pet record (not yet inserted) + flags.
function EggService.RollHatch(player, eggId)
	local eggDef = Eggs.ById[eggId]
	if not eggDef then
		return nil
	end
	local luckMult = registry.Economy.GetLuckMultiplier(player)
	local mutationMults = {}
	if registry.Event then
		mutationMults = registry.Event.GetMutationMultipliers()
	end
	local rarity = rollRarity(eggDef.HatchWeights, luckMult)
	local petDef = Pets.GetRandomOfRarity(rarity, rng)
	if not petDef then
		petDef = Pets.ById["chick"]
		rarity = "Common"
	end
	local mutation = rollMutation(EggService.EggTierOf(eggId), mutationMults)
	return {
		id = petDef.Id,
		rarity = rarity,
		mut = mutation,
	}
end

local function findEgg(profile, eggUid)
	for index, egg in ipairs(profile.eggs) do
		if egg.uid == eggUid then
			return egg, index
		end
	end
	return nil, nil
end

-- Public lookup for TradeService (server-only, profile already in hand).
function EggService.FindEgg(profile, eggUid)
	if type(profile) ~= "table" or type(profile.eggs) ~= "table" then
		return nil, nil
	end
	return findEgg(profile, eggUid)
end

local function insertPet(player, profile, roll)
	local pet = Types.NewPetRecord(registry.Data.GenerateUid(player), roll.id, roll.mut)
	profile.pets[#profile.pets + 1] = pet
	local key = Types.CollectionKey(roll.id, roll.mut)
	local isNew = (profile.collection[key] or 0) == 0
	profile.collection[key] = (profile.collection[key] or 0) + 1
	return pet, isNew
end

--------------------------------------------------------------------------------
-- Plot pads + placed-egg visuals
--------------------------------------------------------------------------------

local function furnitureFolder(plotIndex)
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

local function padBasePosition(plotIndex, padIndex)
	local plot = registry.World.GetPlotModel(plotIndex)
	local foundation = plot and plot:FindFirstChild("Foundation")
	if not foundation or not foundation:IsA("BasePart") then
		return nil
	end
	local preferred = PAD_OFFSETS[padIndex]
	if not preferred then
		return nil
	end
	local offset = ModelFactory.FindClearSpot(plot, preferred, 3, 15)
	return foundation.Position
		+ Vector3.new(0, foundation.Size.Y / 2, 0)
		+ offset
end

--- World position of a pad (heist range checks). Nil when plot/pad missing.
function EggService.GetPadPosition(plotIndex, padIndex)
	return padBasePosition(plotIndex, padIndex)
end

--- Finds the egg record a player has placed on a pad (snatch lookups).
function EggService.FindPlacedEgg(player, padIndex)
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	for _, egg in ipairs(profile.eggs) do
		if egg.placedPad == padIndex then
			return egg
		end
	end
	return nil
end

function EggService.IsReady(egg)
	return egg ~= nil and egg.placedPad ~= nil
		and egg.hatchAt ~= nil and os.time() >= egg.hatchAt
end

local function setPadLabel(plotIndex, padIndex, text, color)
	local plotLabels = padLabels[plotIndex]
	local label = plotLabels and plotLabels[padIndex] or nil
	if label and label.Parent then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
end

local function formatTimer(secondsLeft)
	secondsLeft = math.max(0, math.floor(secondsLeft))
	local mins = math.floor(secondsLeft / 60)
	local secs = secondsLeft % 60
	if mins > 0 then
		return string.format("%d:%02d", mins, secs)
	end
	return string.format("%ds", secs)
end

--- Builds the 6 physical pads for a plot. Idempotent.
function EggService.BuildPads(plotIndex)
	local furniture = furnitureFolder(plotIndex)
	if not furniture then
		return
	end
	local pads = furniture:FindFirstChild("EggPads")
	if not pads then
		pads = Instance.new("Folder")
		pads.Name = "EggPads"
		pads.Parent = furniture
	end
	padLabels[plotIndex] = padLabels[plotIndex] or {}
	for i = 1, EggService.MaxPads do
		if not pads:FindFirstChild("Pad" .. i) then
			local base = padBasePosition(plotIndex, i)
			if base then
				local pad = Instance.new("Part")
				pad.Name = "Pad" .. i
				pad.Shape = Enum.PartType.Cylinder
				pad.Size = Vector3.new(1.2, 5, 5)
				pad.CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0))
					* CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2)
				pad.Color = Color3.fromRGB(70, 74, 95)
				pad.Material = Enum.Material.SmoothPlastic
				pad.Anchored = true
				pad.CanCollide = true
				pad.TopSurface = Enum.SurfaceType.Smooth
				pad.BottomSurface = Enum.SurfaceType.Smooth
				pad.Parent = pads
				local ring = Instance.new("Part")
				ring.Name = "Ring"
				ring.Shape = Enum.PartType.Cylinder
				ring.Size = Vector3.new(0.4, 5.8, 5.8)
				ring.CFrame = CFrame.new(base + Vector3.new(0, 0.35, 0))
					* CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2)
				ring.Color = Color3.fromRGB(255, 200, 80)
				ring.Material = Enum.Material.Neon
				ring.Transparency = 0.4
				ring.Anchored = true
				ring.CanCollide = false
				ring.CanQuery = false
				ring.Parent = pad
				local billboard = Instance.new("BillboardGui")
				billboard.Name = "PadLabel"
				billboard.Size = UDim2.new(0, 140, 0, 44)
				billboard.StudsOffset = Vector3.new(0, 4.5, 0)
				billboard.AlwaysOnTop = false
				billboard.MaxDistance = 60
				billboard.Parent = pad
				local text = Instance.new("TextLabel")
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Text = "EMPTY PAD"
				text.TextColor3 = Color3.fromRGB(160, 165, 190)
				text.Font = Enum.Font.GothamBold
				text.TextScaled = true
				text.TextStrokeTransparency = 0.5
				text.Parent = billboard
				padLabels[plotIndex][i] = text
			end
		end
	end
end

local function clearPlacedVisual(plotIndex, padIndex)
	local plot = registry.World.GetPlotModel(plotIndex)
	local furniture = plot and plot:FindFirstChild("ServerFurniture")
	local placed = furniture and furniture:FindFirstChild("PlacedEggs")
	local visual = placed and placed:FindFirstChild("Pad" .. padIndex)
	if visual then
		pcall(function() visual:Destroy() end)
	end
	setPadLabel(plotIndex, padIndex, "EMPTY PAD", Color3.fromRGB(160, 165, 190))
end

--- Destroys every placed-egg visual on a plot (release/prestige/wipe).
function EggService.ClearPlotEggVisuals(plotIndex)
	local plot = registry.World.GetPlotModel(plotIndex)
	local furniture = plot and plot:FindFirstChild("ServerFurniture")
	local placed = furniture and furniture:FindFirstChild("PlacedEggs")
	if placed then
		pcall(function() placed:Destroy() end)
	end
	padLabels[plotIndex] = nil
end

local function shakeEgg(eggModel, seconds)
	task.spawn(function()
		local primary = eggModel.PrimaryPart or eggModel:FindFirstChild("Body")
		if not primary or not primary:IsA("BasePart") then
			return
		end
		local startPos = primary.Position
		local stopAt = os.clock() + (seconds or 1.2)
		while os.clock() < stopAt and eggModel.Parent do
			task.wait(0.08)
			if not eggModel.Parent then
				return
			end
			local jitter = Vector3.new((math.random() - 0.5) * 0.6, 0, (math.random() - 0.5) * 0.6)
			pcall(function()
				ModelFactory.Pose(eggModel, CFrame.new(startPos + jitter))
			end)
		end
		if eggModel.Parent then
			pcall(function()
				ModelFactory.Pose(eggModel, CFrame.new(startPos))
			end)
		end
	end)
end

local function buildPlacedVisual(player, plotIndex, egg)
	local furniture = furnitureFolder(plotIndex)
	if not furniture then
		return nil
	end
	local placed = furniture:FindFirstChild("PlacedEggs")
	if not placed then
		placed = Instance.new("Folder")
		placed.Name = "PlacedEggs"
		placed.Parent = furniture
	end
	clearPlacedVisual(plotIndex, egg.placedPad)
	local base = padBasePosition(plotIndex, egg.placedPad)
	if not base then
		return nil
	end
	local holder = Instance.new("Model")
	holder.Name = "Pad" .. egg.placedPad
	local eggModel = ModelFactory.BuildEgg(egg.eggId, 0.55)
	eggModel.Parent = holder
	ModelFactory.Pose(eggModel, CFrame.new(base + Vector3.new(0, 2.2, 0)))
	local body = eggModel:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		-- HATCH! (owner, enabled when ready)
		local hatchPrompt = Instance.new("ProximityPrompt")
		hatchPrompt.Name = "EggHatchPrompt"
		hatchPrompt.ActionText = "HATCH!"
		hatchPrompt.ObjectText = (Eggs.ById[egg.eggId] and Eggs.ById[egg.eggId].DisplayName) or egg.eggId
		hatchPrompt.KeyboardKeyCode = Enum.KeyCode.E
		hatchPrompt.HoldDuration = 0.3
		hatchPrompt.MaxActivationDistance = 14
		hatchPrompt.RequiresLineOfSight = false
		hatchPrompt.Enabled = EggService.IsReady(egg)
		hatchPrompt.Parent = body
		hatchPrompt.Triggered:Connect(function(triggerPlayer)
			EggService.HatchEgg(triggerPlayer, egg.uid)
		end)
		-- Pick up (owner)
		local pickupPrompt = Instance.new("ProximityPrompt")
		pickupPrompt.Name = "EggPickupPrompt"
		pickupPrompt.ActionText = "Pick Up"
		pickupPrompt.ObjectText = "Egg"
		pickupPrompt.KeyboardKeyCode = Enum.KeyCode.F
		pickupPrompt.HoldDuration = 0.3
		pickupPrompt.MaxActivationDistance = 14
		pickupPrompt.RequiresLineOfSight = false
		pickupPrompt.Parent = body
		pickupPrompt.Triggered:Connect(function(triggerPlayer)
			EggService.PickupEgg(triggerPlayer, egg.uid)
		end)
		-- Steal (non-owners; server validates)
		local stealPrompt = Instance.new("ProximityPrompt")
		stealPrompt.Name = "EggStealPrompt"
		stealPrompt.ActionText = "Steal Egg"
		stealPrompt.ObjectText = "Heist target"
		stealPrompt.KeyboardKeyCode = Enum.KeyCode.E
		stealPrompt.HoldDuration = 1.5
		stealPrompt.MaxActivationDistance = 14
		stealPrompt.RequiresLineOfSight = false
		stealPrompt.Parent = body
		local padIndex = egg.placedPad
		stealPrompt.Triggered:Connect(function(triggerPlayer)
			if registry.Heist and registry.Heist.TryGrabEgg then
				registry.Heist.TryGrabEgg(triggerPlayer, plotIndex, padIndex)
			end
		end)
	end
	holder.Parent = placed
	-- reset the pad timer label immediately
	local def = Eggs.ById[egg.eggId]
	if EggService.IsReady(egg) then
		setPadLabel(plotIndex, egg.placedPad, "READY!", Color3.fromRGB(120, 255, 160))
	else
		local left = (egg.hatchAt or os.time()) - os.time()
		setPadLabel(plotIndex, egg.placedPad,
			(def and def.DisplayName or "Egg") .. " " .. formatTimer(left),
			Color3.fromRGB(255, 215, 100))
	end
	return holder
end

local function refreshPlacedVisual(player, egg)
	local profile = profileOf(player)
	local plotIndex = profile and profile.base.plot or 0
	if plotIndex <= 0 or not egg.placedPad then
		return
	end
	buildPlacedVisual(player, plotIndex, egg)
end

--------------------------------------------------------------------------------
-- Placement API (all server-validated)
--------------------------------------------------------------------------------

local function trackPending(player, egg)
	pendingReady[player.UserId] = pendingReady[player.UserId] or {}
	if egg.placedPad and egg.hatchAt and os.time() < egg.hatchAt then
		pendingReady[player.UserId][egg.uid] = egg.hatchAt
	else
		pendingReady[player.UserId][egg.uid] = nil
	end
end

local function nearOwnPlot(player, plotIndex, maxDist)
	local plot = registry.World.GetPlotModel(plotIndex)
	local foundation = plot and plot:FindFirstChild("Foundation")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not foundation or not foundation:IsA("BasePart") or not hrp then
		return false
	end
	return (hrp.Position - foundation.Position).Magnitude <= (maxDist or 40)
end

--- Places an egg from the pouch onto the first free pad of the player's base.
function EggService.PlaceEgg(player, eggUid)
	eggUid = Validate.Uid(eggUid)
	if not eggUid then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local egg = findEgg(profile, eggUid)
	if not egg then
		return false
	end
	if egg.placedPad then
		return true -- already placed
	end
	local plotIndex = registry.Base.GetPlotOf(player)
	if plotIndex <= 0 then
		registry.Notify.Send(player, "warning", "No base",
			"Claim a base plot first!", 4)
		return false
	end
	if not nearOwnPlot(player, plotIndex, 45) then
		registry.Notify.Send(player, "warning", "Too far",
			"Visit your base to place eggs.", 4)
		return false
	end
	-- first free pad
	local used = {}
	for _, other in ipairs(profile.eggs) do
		if other.placedPad then
			used[other.placedPad] = true
		end
	end
	local pad = nil
	for i = 1, EggService.MaxPads do
		if not used[i] then
			pad = i
			break
		end
	end
	if not pad then
		registry.Notify.Send(player, "warning", "Pads full",
			"Hatch or pick up eggs to free a pad.", 4)
		return false
	end
	egg.placedPad = pad
	egg.hatchAt = os.time() + Eggs.GetHatchTime(egg.eggId)
	registry.Data.MarkDirty(player)
	EggService.BuildPads(plotIndex)
	buildPlacedVisual(player, plotIndex, egg)
	trackPending(player, egg)
	local def = Eggs.ById[egg.eggId]
	registry.Notify.Send(player, "success", "Egg placed!",
		(def and def.DisplayName or "Egg") .. " is hatching on pad " .. tostring(pad) .. ".", 4)
	registry.Net.Fire(player, "Fx", "PlaceEgg")
	if registry.TutorialHook then
		registry.TutorialHook(player, "PlaceEgg")
	end
	return true
end

--- Returns a placed egg to the pouch (timer resets on next placement).
function EggService.PickupEgg(player, eggUid)
	eggUid = Validate.Uid(eggUid)
	if not eggUid then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local egg = findEgg(profile, eggUid)
	if not egg or not egg.placedPad then
		return false
	end
	local plotIndex = profile.base.plot or 0
	local wasPad = egg.placedPad
	egg.placedPad = nil
	egg.hatchAt = nil
	registry.Data.MarkDirty(player)
	if plotIndex > 0 and wasPad then
		clearPlacedVisual(plotIndex, wasPad)
	end
	trackPending(player, egg)
	registry.Notify.Send(player, "info", "Picked up", "Egg returned to your pouch.", 3)
	return true
end

--- Removes every placed egg back to the pouch (plot release / wipe).
function EggService.UnplaceAllEggs(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local plotIndex = profile.base.plot or 0
	for _, egg in ipairs(profile.eggs) do
		if egg.placedPad then
			if plotIndex > 0 then
				clearPlacedVisual(plotIndex, egg.placedPad)
			end
			egg.placedPad = nil
			egg.hatchAt = nil
		end
	end
	pendingReady[player.UserId] = nil
	registry.Data.MarkDirty(player)
end

--- Rebuilds visuals + timers after (re)claiming a plot.
function EggService.RestorePlacedEggs(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local plotIndex = profile.base.plot or 0
	if plotIndex <= 0 then
		return
	end
	EggService.BuildPads(plotIndex)
	for _, egg in ipairs(profile.eggs) do
		if egg.placedPad then
			buildPlacedVisual(player, plotIndex, egg)
			trackPending(player, egg)
		end
	end
end

--- Plot lifecycle hooks called by BaseService.
function EggService.OnPlotAssigned(player, plotIndex)
	EggService.BuildPads(plotIndex)
	EggService.RestorePlacedEggs(player)
end

function EggService.OnPlotReleased(player, _plotIndex)
	EggService.UnplaceAllEggs(player)
end

--- Server-only test backdoor: force every placed egg ready (sim uses this).
function EggService.TestForceReady(player)
	local profile = profileOf(player)
	if not profile then
		return 0
	end
	local count = 0
	for _, egg in ipairs(profile.eggs) do
		if egg.placedPad and egg.hatchAt and egg.hatchAt > os.time() then
			egg.hatchAt = os.time()
			count = count + 1
			trackPending(player, egg)
			refreshPlacedVisual(player, egg)
		end
	end
	if count > 0 then
		registry.Data.MarkDirty(player)
	end
	return count
end

-- Snatch support: lift a placed egg OFF the victim (visual + record removed,
-- record returned with placement fields intact for restore-on-fail).
function EggService.TakePlacedEgg(owner, eggUid)
	local profile = profileOf(owner)
	if not profile then
		return nil
	end
	for index, egg in ipairs(profile.eggs) do
		if egg.uid == eggUid and egg.placedPad then
			local padIndex = egg.placedPad
			table.remove(profile.eggs, index)
			local plotIndex = profile.base.plot or 0
			if plotIndex > 0 then
				clearPlacedVisual(plotIndex, padIndex)
			end
			if pendingReady[owner.UserId] then
				pendingReady[owner.UserId][egg.uid] = nil
			end
			registry.Data.MarkDirty(owner)
			return egg
		end
	end
	return nil
end

-- Snatch fail path: put a taken egg back on the victim's pad.
function EggService.RestoreTakenEgg(owner, egg)
	local profile = profileOf(owner)
	if not profile or not egg then
		return false
	end
	profile.eggs[#profile.eggs + 1] = egg
	registry.Data.MarkDirty(owner)
	refreshPlacedVisual(owner, egg)
	trackPending(owner, egg)
	return true
end

--------------------------------------------------------------------------------
-- Hatching (placed + ready only, except force paths)
--------------------------------------------------------------------------------

local function doHatch(player, eggUid, forceReady)
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	local egg, index = findEgg(profile, eggUid)
	if not egg then
		return nil
	end
	if #profile.pets >= Economy.MaxPetsStored + (profile.base.upgrades.EggSlots or 0) * 2 then
		registry.Notify.Send(player, "warning", "Storage full",
			"Sell or delete pets to hatch more eggs.", 4)
		return nil
	end
	if not Eggs.ById[egg.eggId] then
		-- stale egg id (removed content / corrupted record): drop the dead
		-- record loudly instead of consuming it into a failed hatch.
		table.remove(profile.eggs, index)
		registry.Data.MarkDirty(player)
		warn("[EggHeist] Dropped unknown egg id: " .. tostring(egg.eggId))
		return nil
	end
	if egg.placedPad and not forceReady and not EggService.IsReady(egg) then
		local left = (egg.hatchAt or os.time()) - os.time()
		registry.Notify.Send(player, "info", "Not ready yet",
			"Hatches in " .. formatTimer(left) .. ".", 3)
		return nil
	end
	local wasPad = egg.placedPad
	local plotIndex = profile.base.plot or 0
	table.remove(profile.eggs, index)
	if pendingReady[player.UserId] then
		pendingReady[player.UserId][eggUid] = nil
	end
	if wasPad and plotIndex > 0 then
		clearPlacedVisual(plotIndex, wasPad)
	end
	local roll = EggService.RollHatch(player, egg.eggId)
	if not roll then
		return nil
	end
	local pet, isNew = insertPet(player, profile, roll)

	-- progression hooks
	profile.stats.totalHatched = (profile.stats.totalHatched or 0) + 1
	local hatchTier = Rarities.GetTier(roll.rarity)
	profile.stats.maxRarityTier = math.max(profile.stats.maxRarityTier or 0, hatchTier)
	if hatchTier >= 4 then
		profile.stats.legendaryPlusHatched = (profile.stats.legendaryPlusHatched or 0) + 1
	end
	if hatchTier >= 6 then
		profile.stats.secretsHatched = (profile.stats.secretsHatched or 0) + 1
	end
	if registry.Achievement then
		registry.Achievement.Check(player, "HatchEgg")
	end
	if roll.mut then
		profile.stats.mutatedHatched = (profile.stats.mutatedHatched or 0) + 1
		registry.Quest.AddProgress(player, "HatchMutated", 1)
	end
	registry.Economy.AddXp(player, Economy.XpPerHatch(Rarities.GetTier(roll.rarity)))
	registry.Quest.AddProgress(player, "HatchEggs", 1)
	if Rarities.GetTier(roll.rarity) >= 4 then
		registry.Quest.AddProgress(player, "HatchLegendaryPlus", 1)
	end
	registry.Quest.AddProgress(player, "NewCollection", isNew and 1 or 0)
	if registry.TutorialHook then
		registry.TutorialHook(player, "HatchEgg")
	end

	-- celebrations for big hits
	local tier = Rarities.GetTier(roll.rarity)
	local petName = (Pets.ById[roll.id] and Pets.ById[roll.id].DisplayName) or roll.id
	if tier >= 6 or (roll.mut and (roll.mut == "Ancient" or roll.mut == "Void")) then
		registry.Notify.Broadcast("secret", "SECRET HATCH!",
			player.DisplayName .. " hatched a " .. (roll.mut or "") .. " " .. petName .. "!", 8)
		registry.Net.FireAll("Feed", { icon = "SECRET", text = player.DisplayName .. " hatched " .. petName })
	elseif tier >= 4 then
		registry.Notify.Broadcast("rare", "Rare hatch!",
			player.DisplayName .. " hatched a " .. roll.rarity .. " " .. petName .. "!", 6)
		registry.Net.FireAll("Feed", { icon = "HATCH", text = player.DisplayName .. " hatched " .. petName })
	end

	registry.Data.MarkDirty(player)
	local sourceDef = Eggs.ById[egg.eggId]

	-- auto-equip when a slot is free so income starts immediately
	if registry.Pet and #profile.equipped < registry.Pet.MaxSlots(player) then
		registry.Pet.Equip(player, pet.uid)
		registry.Notify.Send(player, "info", "Auto-equipped",
			petName .. " is now earning for you!", 4)
	end

	-- client juice: rarity-scaled hatch celebration for the hatcher
	registry.Net.Fire(player, "Fx", "HatchFx", tier, roll.rarity, petName, isNew)
	if tier >= 6 then
		registry.Net.FireAll("Fx", "Announce", "secret", "SECRET HATCH!",
			player.DisplayName .. " hatched " .. petName .. "!")
	elseif tier >= 4 then
		registry.Net.FireAll("Fx", "Announce", "rare", "LEGENDARY HATCH!",
			player.DisplayName .. " hatched " .. petName .. "!")
	end

	return {
		pet = pet,
		isNew = isNew,
		rarity = roll.rarity,
		eggId = egg.eggId,
		eggName = (sourceDef and sourceDef.DisplayName) or egg.eggId,
	}
end

--- HATCH! entry: prompt + backpack button + HatchEgg remote all land here.
function EggService.HatchEgg(player, eggUid)
	eggUid = Validate.Uid(eggUid)
	if not eggUid then
		return nil
	end
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	local egg = findEgg(profile, eggUid)
	if not egg then
		return nil
	end
	if not egg.placedPad then
		registry.Notify.Send(player, "info", "Place it first",
			"Place this egg on a pad in your base to hatch it!", 4)
		return nil
	end
	return doHatch(player, eggUid, false)
end

function EggService.BuyEgg(player, eggId, count)
	eggId = Validate.String(eggId, 32, nil)
	count = math.clamp(math.floor(tonumber(count) or 1), 1, 10)
	if not Eggs.IsPurchasable(eggId) then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local eggDef = Eggs.ById[eggId]
	if profile.level < (eggDef.RequiredLevel or 1) then
		registry.Notify.Send(player, "warning", "Level locked",
			"Requires level " .. tostring(eggDef.RequiredLevel) .. ".", 4)
		return false
	end
	if #profile.eggs + count > 200 then
		registry.Notify.Send(player, "warning", "Egg pouch full", "Hatch some eggs first!", 4)
		return false
	end
	local total = eggDef.Price * count
	if not registry.Economy.SpendCash(player, total) then
		registry.Notify.Send(player, "warning", "Not enough cash",
			"You need " .. tostring(total) .. " cash.", 4)
		return false
	end
	local bought = {}
	for _ = 1, count do
		local egg = Types.NewEggRecord(registry.Data.GenerateUid(player), eggId)
		profile.eggs[#profile.eggs + 1] = egg
		bought[#bought + 1] = egg
	end
	profile.stats.eggsBought = (profile.stats.eggsBought or 0) + count
	if registry.Achievement then
		registry.Achievement.Check(player, "BuyEgg")
	end
	registry.Data.MarkDirty(player)
	if registry.TutorialHook then
		registry.TutorialHook(player, "BuyEgg")
	end

	-- Auto-hatch: gamepass OR permanent gems unlock. Auto-places each egg
	-- on a free pad and hatches instantly; leftovers stay in the pouch.
	if profile.settings.autoHatch
		and (profile.gamepasses.AutoHatch or profile.autoHatchUnlock) then
		local results = {}
		for _, egg in ipairs(bought) do
			if EggService.PlaceEgg(player, egg.uid) then
				local result = doHatch(player, egg.uid, true)
				if result then
					results[#results + 1] = result
				end
			end
		end
		if #results > 0 then
			registry.Net.Fire(player, "HatchResult", {
				eggId = eggId,
				results = results,
				auto = true,
			})
		end
	end
	return true
end

-- Permanent auto-hatch unlock for gems (no Robux pass required).
function EggService.BuyAutoHatch(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	if profile.autoHatchUnlock or profile.gamepasses.AutoHatch then
		return
	end
	local cost = (Settings.AutoHatch or {}).GemsUnlockCost or 299
	if not registry.Economy.SpendGems(player, cost) then
		registry.Notify.Send(player, "warning", "Not enough gems",
			"Auto Hatchery costs " .. tostring(cost) .. " gems.", 4)
		return
	end
	profile.autoHatchUnlock = true
	profile.settings.autoHatch = true
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success", "Auto Hatchery unlocked!",
		"Eggs you buy will hatch instantly. Toggle it in Settings.", 5)
end

-- Grants an egg without payment (events, quests, admin, daily rewards)
function EggService.GiftEgg(player, eggId, source)
	if not Eggs.IsValid(eggId) then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	if #profile.eggs >= 200 then
		return false
	end
	profile.eggs[#profile.eggs + 1] = Types.NewEggRecord(registry.Data.GenerateUid(player), eggId)
	registry.Data.MarkDirty(player)
	return true
end

--------------------------------------------------------------------------------
-- Ready loop: timers -> READY! (shake + prompt + toast)
--------------------------------------------------------------------------------

local function markReady(player, egg)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local plotIndex = profile.base.plot or 0
	if plotIndex > 0 and egg.placedPad then
		refreshPlacedVisual(player, egg)
		local plot = registry.World.GetPlotModel(plotIndex)
		local furniture = plot and plot:FindFirstChild("ServerFurniture")
		local placed = furniture and furniture:FindFirstChild("PlacedEggs")
		local holder = placed and placed:FindFirstChild("Pad" .. egg.placedPad)
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Model") then
					shakeEgg(child, 1.5)
				end
			end
		end
	end
	local def = Eggs.ById[egg.eggId]
	registry.Notify.Send(player, "success", "Egg ready!",
		(def and def.DisplayName or "Egg") .. " is ready to HATCH!", 5)
	registry.Net.Fire(player, "Fx", "EggReady")
end

local function readyLoop()
	while true do
		task.wait(2)
		local now = os.time()
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = profileOf(player)
			if profile then
				local plotIndex = profile.base.plot or 0
				for _, egg in ipairs(profile.eggs) do
					if egg.placedPad and egg.hatchAt then
						if now >= egg.hatchAt then
							local tracked = pendingReady[player.UserId]
							if tracked and tracked[egg.uid] then
								tracked[egg.uid] = nil
								markReady(player, egg)
							end
						elseif plotIndex > 0 then
							-- live countdown on the pad label
							local def = Eggs.ById[egg.eggId]
							setPadLabel(plotIndex, egg.placedPad,
								(def and def.DisplayName or "Egg") .. " "
									.. formatTimer(egg.hatchAt - now),
								Color3.fromRGB(255, 215, 100))
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Physical egg market: shop prompts on every stall pedestal (all worlds)
--------------------------------------------------------------------------------

--- Attaches "Shop" prompts to every market stall pedestal. Works in the
--- rbxm world (Common_Pedestal...) and the fallback world (<Egg>_Pedestal).
--- The CLIENT opens the shop UI (NpcController): zero exploit surface.
function EggService.BuildMarketStalls()
	if not registry.World or not registry.World.GetRoot then
		return
	end
	local root = registry.World.GetRoot()
	local map = root and root:FindFirstChild("Map")
	local market = map and map:FindFirstChild("EggMarket")
	if not market then
		return
	end
	for _, child in ipairs(market:GetChildren()) do
		if child:IsA("BasePart") and child.Name:match("_Pedestal$") then
			if not child:FindFirstChild("MarketPrompt") then
				local stall = child.Name:gsub("_Pedestal$", "")
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "MarketPrompt"
				prompt:SetAttribute("MarketStall", stall)
				prompt.ActionText = "Shop"
				prompt.ObjectText = stall .. " Eggs"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = child
			end
		end
	end
end

function EggService.Start()
	EggService.BuildMarketStalls()
	registry.Net.OnRequest("BuyEgg", function(player, eggId, count)
		EggService.BuyEgg(player, eggId, count)
	end)

	registry.Net.OnRequest("BuyAutoHatch", function(player)
		EggService.BuyAutoHatch(player)
	end)

	registry.Net.OnRequest("PlaceEgg", function(player, eggUid)
		EggService.PlaceEgg(player, eggUid)
	end)

	registry.Net.OnRequest("PickupEgg", function(player, eggUid)
		EggService.PickupEgg(player, eggUid)
	end)

	registry.Net.OnRequest("HatchEgg", function(player, eggUid)
		local result = EggService.HatchEgg(player, eggUid)
		if result then
			registry.Net.Fire(player, "HatchResult", {
				results = { result },
				auto = false,
			})
		end
	end)

	registry.Net.OnRequest("HatchAll", function(player)
		local profile = profileOf(player)
		if not profile then
			return
		end
		local results = {}
		local hatched = 0
		-- copy uids first (doHatch mutates the list); ready placed eggs only
		local uids = {}
		for _, egg in ipairs(profile.eggs) do
			if egg.placedPad and EggService.IsReady(egg) then
				uids[#uids + 1] = egg.uid
				if #uids >= 25 then
					break
				end
			end
		end
		for _, uid in ipairs(uids) do
			local result = doHatch(player, uid, false)
			if result then
				results[#results + 1] = result
				hatched = hatched + 1
			else
				break -- storage full
			end
		end
		if hatched > 0 then
			registry.Net.Fire(player, "HatchResult", { results = results, auto = false, bulk = true })
		else
			registry.Notify.Send(player, "info", "Nothing ready",
				"Place eggs on pads and wait for them to hatch!", 4)
		end
	end)

	task.spawn(readyLoop)
end

return EggService
