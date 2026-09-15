-- EggHeist | Server/World/ActivitiesService.luau
-- Interactive map hotspots: wishing well, jump pads, crystal-grotto gem
-- claim, beach message-in-a-bottle, and the sky-vault parkour. Server
-- builds every prompt; every reward is server-authoritative with
-- per-player cooldowns and server-side range checks.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local ModelFactory = require(Shared:WaitForChild("Utilities"):WaitForChild("ModelFactory"))

local ActivitiesService = {}
ActivitiesService.Name = "ActivitiesService"

local registry = nil
local folder = nil -- EggHeistActivities, next to the world + decor
local cooldowns = {} -- ["userId:key"] = os.clock() ready-at
local padDebounce = {} -- [userId] = os.clock()

local FALLBACK = {
	plaza = Vector3.new(0, 2, 0),
	market = Vector3.new(90, 2, 0),
	heist = Vector3.new(0, 2, 120),
	event = Vector3.new(-90, 2, 0),
	grotto = Vector3.new(-118, 2, 95),
	beach = Vector3.new(118, 2, 102),
}

local function anchor(name)
	if registry and registry.Atmosphere and registry.Atmosphere.GetAnchor then
		local ok, pos = pcall(registry.Atmosphere.GetAnchor, name)
		if ok and typeof(pos) == "Vector3" then
			return pos
		end
	end
	return FALLBACK[name]
end

local function mkPart(name, size, position, color, material, collide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color or Color3.fromRGB(150, 150, 150)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collide == true
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local function mkPrompt(parent, name, actionText, objectText, hold, dist)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold or 0.5
	prompt.MaxActivationDistance = dist or 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function hrpOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function inRange(player, pos, dist)
	local hrp = hrpOf(player)
	if not hrp or not pos then
		return false
	end
	return (hrp.Position - pos).Magnitude <= (dist or 20)
end

local function onCooldown(player, key, seconds)
	local id = tostring(player.UserId) .. ":" .. key
	local now = os.clock()
	if (cooldowns[id] or 0) > now then
		return true, math.ceil(cooldowns[id] - now)
	end
	cooldowns[id] = now + seconds
	return false, 0
end

--------------------------------------------------------------------------------
-- Wishing well (plaza edge): toss 100 coins, get a blessing
--------------------------------------------------------------------------------

local wellWater = nil
local wellPrompt = nil

local function buildWishingWell()
	local at = anchor("plaza")
	local cx, cz = at.X + 18, at.Z - 2
	local baseY = at.Y
	local stone = Color3.fromRGB(130, 130, 150)
	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi * 2
		mkPart("WellStone" .. i, Vector3.new(1.6, 2, 1.6),
			Vector3.new(cx + math.cos(a) * 3, baseY + 1, cz + math.sin(a) * 3),
			stone, Enum.Material.Slate, true)
	end
	wellWater = mkPart("WishingWellWater", Vector3.new(4.5, 0.5, 4.5),
		Vector3.new(cx, baseY + 1.4, cz), Color3.fromRGB(90, 180, 255), Enum.Material.Glass)
	for _, sx in ipairs({ -3, 3 }) do
		mkPart("WellPost" .. sx, Vector3.new(0.6, 5, 0.6),
			Vector3.new(cx + sx, baseY + 3.5, cz), Color3.fromRGB(120, 90, 60), nil, true)
	end
	mkPart("WellRoof", Vector3.new(7, 1, 7),
		Vector3.new(cx, baseY + 6.4, cz), Color3.fromRGB(180, 70, 70))
	mkPart("WellRoofTop", Vector3.new(5, 1, 5),
		Vector3.new(cx, baseY + 7.4, cz), Color3.fromRGB(200, 90, 90))
	wellPrompt = mkPrompt(wellWater, "WishPrompt", "Make a Wish", "100 coins", 1, 12)
	wellPrompt.Triggered:Connect(function(player)
		if not inRange(player, wellWater.Position, 20) then
			return
		end
		local profile = registry.Data and registry.Data.GetProfile(player)
		if not profile then
			return
		end
		local cooling, left = onCooldown(player, "wish", 120)
		if cooling then
			registry.Notify.Send(player, "info", "The well rests",
				"Make another wish in " .. tostring(left) .. "s.", 3)
			return
		end
		if not registry.Economy.SpendCash(player, 100) then
			registry.Notify.Send(player, "warning", "Empty pockets",
				"Wishes cost 100 coins.", 3)
			return
		end
		local roll = math.random(1, 100)
		if roll <= 30 then
			registry.Economy.AddBoost(player, "WellBlessing", 300, { IncomeMult = 1.5 })
			registry.Notify.Send(player, "success", "Blessing of Wealth!",
				"+50% income for 5 minutes.", 5)
		elseif roll <= 55 then
			registry.Economy.AddBoost(player, "WellBlessing", 300, { LuckMult = 1.5 })
			registry.Notify.Send(player, "success", "Blessing of Luck!",
				"+50% hatch luck for 5 minutes.", 5)
		elseif roll <= 80 then
			local coins = 500 + (profile.level or 1) * 100
			registry.Economy.AddCash(player, coins, "wish")
			registry.Notify.Send(player, "success", "The well provides!",
				"+" .. tostring(coins) .. " coins.", 5)
		elseif roll <= 92 then
			registry.Economy.AddGems(player, 5, "wish")
			registry.Notify.Send(player, "success", "Gems from the deep!",
				"+5 gems.", 5)
		else
			registry.Notify.Send(player, "info", "Glug glug...",
				"The well gurgles. No blessing this time.", 4)
		end
		registry.Quest.AddProgress(player, "MakeWishes", 1)
		if registry.Achievement then
			registry.Achievement.Check(player, "MakeWish")
		end
	end)
end

--------------------------------------------------------------------------------
-- Jump pads: touch to launch between districts
--------------------------------------------------------------------------------

local padCount = 0

local function buildJumpPads()
	local plaza = anchor("plaza")
	local market = anchor("market")
	local heist = anchor("heist")
	local event = anchor("event")
	local defs = {
		{ name = "PadSpawn", pos = plaza + Vector3.new(-10, -0.6, 10), vel = Vector3.new(0, 70, -100) },
		{ name = "PadMarket", pos = market + Vector3.new(-20, -0.6, 0), vel = Vector3.new(-95, 70, 0) },
		{ name = "PadHeist", pos = heist + Vector3.new(0, -0.6, -15), vel = Vector3.new(0, 70, -110) },
		{ name = "PadEvent", pos = event + Vector3.new(20, -0.6, 0), vel = Vector3.new(95, 70, 0) },
	}
	for _, def in ipairs(defs) do
		local base = mkPart(def.name .. "Base", Vector3.new(5, 0.8, 5),
			def.pos, Color3.fromRGB(45, 45, 60), nil, true)
		local top = mkPart(def.name .. "Top", Vector3.new(4, 0.4, 4),
			def.pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.new(0, 140, 0, 30)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.Parent = top
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "JUMP PAD"
		label.TextColor3 = Color3.fromRGB(150, 230, 255)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		local velocity = def.vel
		base.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit and hit.Parent)
			if not player then
				return
			end
			local now = os.clock()
			if (padDebounce[player.UserId] or 0) > now then
				return
			end
			padDebounce[player.UserId] = now + 1
			local hrp = hrpOf(player)
			if hrp then
				pcall(function()
					hrp.AssemblyLinearVelocity = velocity
				end)
				registry.Notify.Send(player, "info", "Boing!",
					"Jump pad away!", 2)
			end
		end)
		padCount = padCount + 1
	end
end

--------------------------------------------------------------------------------
-- Crystal claim (grotto heart): free gems on a timer
--------------------------------------------------------------------------------

local crystalPrompt = nil

local function buildCrystalClaim()
	local decor = Workspace:FindFirstChild("EggHeistDecor")
	local heart = decor and decor:FindFirstChild("GrottoHeart")
	if not heart or not heart:IsA("BasePart") then
		return
	end
	crystalPrompt = mkPrompt(heart, "CrystalPrompt", "Harvest Crystal", "15 gems", 1.5, 12)
	crystalPrompt.Triggered:Connect(function(player)
		if not inRange(player, heart.Position, 22) then
			return
		end
		if not (registry.Data and registry.Data.GetProfile(player)) then
			return
		end
		local cooling, left = onCooldown(player, "crystal", 300)
		if cooling then
			registry.Notify.Send(player, "info", "Crystals regrowing",
				"Harvest again in " .. tostring(left) .. "s.", 3)
			return
		end
		registry.Economy.AddGems(player, 15, "crystal")
		registry.Notify.Send(player, "success", "+15 gems!",
			"The grotto shares its shine.", 5)
		registry.Quest.AddProgress(player, "ClaimCrystals", 1)
		if registry.Achievement then
			registry.Achievement.Check(player, "ClaimCrystal")
		end
	end)
end

--------------------------------------------------------------------------------
-- Beach bottle: a drifting treat that respawns
--------------------------------------------------------------------------------

local bottlePart = nil
local bottlePrompt = nil

local function buildBottle()
	local at = anchor("beach")
	bottlePart = mkPart("MessageBottle", Vector3.new(1.2, 1.2, 2.4),
		Vector3.new(at.X - 4, 1.6, at.Z + 2), Color3.fromRGB(150, 220, 255), Enum.Material.Glass)
	mkPart("BottleCork", Vector3.new(0.6, 0.6, 0.6),
		bottlePart.Position + Vector3.new(0, 0.8, 0), Color3.fromRGB(140, 100, 65))
	bottlePrompt = mkPrompt(bottlePart, "BottlePrompt", "Open Bottle", "???", 0.5, 10)
	bottlePrompt.Enabled = true -- explicit: the handler re-checks this flag
	bottlePrompt.Triggered:Connect(function(player)
		if not bottlePrompt.Enabled then
			return
		end
		if not inRange(player, bottlePart.Position, 18) then
			return
		end
		if not (registry.Data and registry.Data.GetProfile(player)) then
			return
		end
		bottlePrompt.Enabled = false
		bottlePart.Transparency = 1
		local roll = math.random(1, 100)
		if roll <= 45 then
			local coins = math.random(200, 800)
			registry.Economy.AddCash(player, coins, "bottle")
			registry.Notify.Send(player, "success", "Bottled coins!",
				"+" .. tostring(coins) .. " coins.", 5)
		elseif roll <= 80 then
			local gems = math.random(3, 8)
			registry.Economy.AddGems(player, gems, "bottle")
			registry.Notify.Send(player, "success", "Bottled gems!",
				"+" .. tostring(gems) .. " gems.", 5)
		else
			registry.Economy.AddBoost(player, "BottledLuck", 180, { LuckMult = 2 })
			registry.Notify.Send(player, "success", "Bottled luck!",
				"2x hatch luck for 3 minutes.", 5)
		end
		task.delay(120, function()
			bottlePrompt.Enabled = true
			bottlePart.Transparency = 0
		end)
	end)
end

--------------------------------------------------------------------------------
-- Sky vault parkour: floating steps to a coin vault in the sky
--------------------------------------------------------------------------------

local vaultPrompt = nil
local vaultPart = nil

local SKY_STEPS = {
	{ 36, 4, -27 }, { 34, 8, -23 }, { 30, 12, -21 }, { 26, 16, -23 },
	{ 24, 20, -27 }, { 26, 24, -31 }, { 30, 28, -33 }, { 34, 32, -31 },
}

local function buildSkyVault()
	local plaza = anchor("plaza")
	local ox, oz = plaza.X - 0, plaza.Z - 0
	for i, step in ipairs(SKY_STEPS) do
		local top = mkPart("SkyStep" .. i, Vector3.new(4, 1, 4),
			Vector3.new(ox + step[1], step[2], oz + step[3]),
			Color3.fromRGB(240, 240, 250), nil, true)
		mkPart("SkyStepTrim" .. i, Vector3.new(4.2, 0.3, 4.2),
			top.Position + Vector3.new(0, -0.5, 0),
			Color3.fromRGB(150, 200, 255), Enum.Material.Neon)
	end
	local platform = mkPart("SkyPlatform", Vector3.new(10, 1, 10),
		Vector3.new(ox + 30, 34.5, oz - 27), Color3.fromRGB(90, 200, 255), Enum.Material.Glass)
	platform.CanCollide = true
	vaultPart = mkPart("SkyVault", Vector3.new(3, 4, 3),
		platform.Position + Vector3.new(0, 2.5, 0),
		Color3.fromRGB(255, 200, 80), Enum.Material.Neon, true)
	local sign = mkPart("SkyVaultSign", Vector3.new(1, 5, 1),
		Vector3.new(ox + 30, 2.5, oz - 18), Color3.fromRGB(120, 90, 60), nil, true)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 200, 0, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SKY VAULT ^"
	label.TextColor3 = Color3.fromRGB(255, 220, 130)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	vaultPrompt = mkPrompt(vaultPart, "SkyVaultPrompt", "Claim Vault", "250 coins", 1, 12)
	vaultPrompt.Triggered:Connect(function(player)
		if not inRange(player, vaultPart.Position, 20) then
			return
		end
		if not (registry.Data and registry.Data.GetProfile(player)) then
			return
		end
		local cooling, left = onCooldown(player, "skyvault", 300)
		if cooling then
			registry.Notify.Send(player, "info", "Vault empty",
				"Refills in " .. tostring(left) .. "s.", 3)
			return
		end
		registry.Economy.AddCash(player, 250, "skyvault")
		registry.Notify.Send(player, "success", "Sky vault claimed!",
			"+250 coins. Nice climbing!", 5)
		registry.Quest.AddProgress(player, "SkyVault", 1)
		if registry.Achievement then
			registry.Achievement.Check(player, "SkyVault")
		end
	end)
end

--------------------------------------------------------------------------------
-- Pet parade (market conveyor): pets ride the belt, buy them off it
--------------------------------------------------------------------------------

local conveyor = { slots = {}, minX = 0, maxX = 0, y = 0, z = 0, speed = 2.5 }
local PARADE_WEIGHTS = { Common = 45, Rare = 30, Epic = 15, Legendary = 7, Mythic = 2.5, Secret = 0.5 }

local function rollParadeRarity()
	local total = 0
	for _, rarity in ipairs(Rarities.List) do
		total = total + (PARADE_WEIGHTS[rarity.Id] or 0)
	end
	local roll = math.random() * total
	local acc = 0
	for _, rarity in ipairs(Rarities.List) do
		acc = acc + (PARADE_WEIGHTS[rarity.Id] or 0)
		if roll <= acc then
			return rarity.Id
		end
	end
	return "Common"
end

local function randomMutation()
	local list = Mutations.List
	if not list or #list == 0 then
		return nil
	end
	local mut = list[math.random(1, #list)]
	return mut and mut.Id or nil
end

local function paradePrice(petDef, mut)
	local base = (petDef.BaseIncome or 5) * 600
	if mut then
		base = base * 2.5
	end
	return math.floor(base)
end

local function clearSlot(slot)
	if slot.model then
		pcall(function() slot.model:Destroy() end)
	end
	slot.model, slot.prompt, slot.petId, slot.mut, slot.price = nil, nil, nil, nil, nil
end

local function fillSlot(slot)
	clearSlot(slot)
	local petDef = Pets.GetRandomOfRarity(rollParadeRarity())
	if not petDef then
		return
	end
	local mut = nil
	if math.random() < 0.08 then
		mut = randomMutation()
	end
	local ok, model = pcall(ModelFactory.BuildCreature, petDef.Id, mut, 0.8)
	if not ok or not model then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui")
			or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			pcall(function() d:Destroy() end)
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.Parent = folder
	pcall(ModelFactory.Pose, model, CFrame.new(slot.x, conveyor.y, conveyor.z))
	local anchorPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not anchorPart then
		pcall(function() model:Destroy() end)
		return
	end
	local title = (mut and (mut .. " ") or "") .. petDef.DisplayName
	local price = paradePrice(petDef, mut)
	local prompt = mkPrompt(anchorPart, "ParadePrompt", "Buy " .. title,
		"$" .. tostring(price) .. " - " .. petDef.Rarity, 0.5, 12)
	prompt.Triggered:Connect(function(player)
		if slot.petId == nil then
			return -- already sold
		end
		if not inRange(player, anchorPart.Position, 16) then
			return
		end
		if not (registry.Data and registry.Data.GetProfile(player)) then
			return
		end
		if not registry.Economy.SpendCash(player, slot.price) then
			registry.Notify.Send(player, "warning", "Too expensive!",
				title .. " costs $" .. tostring(slot.price) .. ".", 3)
			return
		end
		local petId, mutBought = slot.petId, slot.mut
		clearSlot(slot)
		registry.Pet.GrantPet(player, petId, mutBought)
		registry.Notify.Send(player, "success", "Parade purchase!",
			title .. " joined your pouch.", 5)
		registry.Quest.AddProgress(player, "ParadeBuy", 1)
		if registry.Achievement then
			registry.Achievement.Check(player, "ParadeBuy")
		end
		task.delay(10, function()
			if slot.petId == nil then
				fillSlot(slot)
			end
			end)
	end)
	slot.model, slot.prompt, slot.petId, slot.mut, slot.price = model, prompt, petDef.Id, mut, price
end

local function buildPetParade()
	local m = anchor("market")
	conveyor.minX, conveyor.maxX = m.X - 19, m.X + 19
	conveyor.y = m.Y + 2.1
	conveyor.z = m.Z
	mkPart("ParadeBelt", Vector3.new(46, 1, 3),
		Vector3.new(m.X, m.Y + 0.5, m.Z), Color3.fromRGB(50, 50, 65), nil, true)
	for _, dz in ipairs({ -1.7, 1.7 }) do
		mkPart("ParadeRail" .. dz, Vector3.new(46, 0.5, 0.3),
			Vector3.new(m.X, m.Y + 1.1, m.Z + dz),
			Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
	end
	for i = 1, 5 do
		local lx = m.X - 19 + (i - 1) * 9.5
		mkPart("ParadeLeg" .. i, Vector3.new(1, 3, 2.4),
			Vector3.new(lx, m.Y - 1, m.Z), Color3.fromRGB(70, 70, 85), nil, true)
	end
	for _, endX in ipairs({ conveyor.minX - 1, conveyor.maxX + 1 }) do
		local roller = mkPart("ParadeRoller" .. endX, Vector3.new(2, 2, 3),
			Vector3.new(endX, m.Y + 0.5, m.Z), Color3.fromRGB(150, 150, 170))
		roller.Shape = Enum.PartType.Ball
	end
	local post = mkPart("ParadeSignPost", Vector3.new(1, 7, 1),
		Vector3.new(m.X - 24, m.Y + 3.5, m.Z), Color3.fromRGB(120, 90, 60), nil, true)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 260, 0, 50)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PET PARADE"
	label.TextColor3 = Color3.fromRGB(255, 220, 130)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	for i = 1, 6 do
		local slot = { x = conveyor.minX + (i - 1) * (38 / 5) }
		conveyor.slots[#conveyor.slots + 1] = slot
		fillSlot(slot)
	end
end

local function paradeSlots()
	local out = {}
	for _, slot in ipairs(conveyor.slots) do
		if slot.petId and slot.prompt and slot.prompt.Parent then
			out[#out + 1] = { prompt = slot.prompt,
				pos = slot.prompt.Parent.Position, price = slot.price }
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Fusion machine (market corner): 3 same-rarity pets -> next rarity
--------------------------------------------------------------------------------

local fusePrompt = nil
local fuseChamber = nil

local function bestFuseRarity(profile)
	local equipped = {}
	for _, uid in ipairs(profile.equipped or {}) do
		equipped[uid] = true
	end
	local counts = {}
	for _, pet in ipairs(profile.pets) do
		if not equipped[pet.uid] then
			local def = Pets.ById[pet.id]
			local rarity = def and def.Rarity or "Common"
			counts[rarity] = (counts[rarity] or 0) + 1
		end
	end
	for i = #Rarities.List, 1, -1 do
		local rarity = Rarities.List[i].Id
		if (counts[rarity] or 0) >= 3 then
			return rarity
		end
	end
	return nil
end

-- Fusion core (also the sim hook): fuse 3 UNEQUIPPED pets of a rarity.
function ActivitiesService.TestFuse(player, rarityId)
	local profile = registry.Data and registry.Data.GetProfile(player)
	if not profile then
		return nil
	end
	local equipped = {}
	for _, uid in ipairs(profile.equipped or {}) do
		equipped[uid] = true
	end
	local victims = {}
	for _, pet in ipairs(profile.pets) do
		local def = Pets.ById[pet.id]
		if not equipped[pet.uid] and def and def.Rarity == rarityId then
			victims[#victims + 1] = pet
			if #victims >= 3 then
				break
			end
		end
	end
	if #victims < 3 then
		return nil
	end
	for _, v in ipairs(victims) do
		for i, pet in ipairs(profile.pets) do
			if pet.uid == v.uid then
				table.remove(profile.pets, i)
				break
			end
		end
	end
	local tier = Rarities.TierOf[rarityId] or 1
	local nextRarity = Rarities.List[math.min(tier + 1, #Rarities.List)].Id
	local mut = nil
	if tier >= #Rarities.List then
		mut = randomMutation() -- secret reroll always mutates
	elseif math.random() < 0.25 then
		mut = randomMutation()
	end
	local petDef = Pets.GetRandomOfRarity(nextRarity)
	if not petDef then
		return nil
	end
	local granted = registry.Pet.GrantPet(player, petDef.Id, mut)
	registry.Quest.AddProgress(player, "FusePets", 1)
	if registry.Achievement then
		registry.Achievement.Check(player, "FusePets")
	end
	return granted
end

local function buildFusion()
	local m = anchor("market")
	local cx, cz = m.X - 28, m.Z - 12
	mkPart("FusionBase", Vector3.new(8, 1, 8),
		Vector3.new(cx, m.Y + 0.5, cz), Color3.fromRGB(60, 60, 80), nil, true)
	fuseChamber = mkPart("FusionChamber", Vector3.new(4, 5, 4),
		Vector3.new(cx, m.Y + 3.5, cz), Color3.fromRGB(150, 220, 255), Enum.Material.Glass)
	for _, sx in ipairs({ -3, 3 }) do
		mkPart("FusionTube" .. sx, Vector3.new(1.5, 6, 1.5),
			Vector3.new(cx + sx, m.Y + 3.5, cz),
			Color3.fromRGB(170, 130, 255), Enum.Material.Neon)
	end
	mkPart("FusionTop", Vector3.new(7, 1, 7),
		Vector3.new(cx, m.Y + 6.5, cz), Color3.fromRGB(60, 60, 80))
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 220, 0, 44)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = fuseChamber
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PET FUSION: 3 -> 1 BETTER"
	label.TextColor3 = Color3.fromRGB(200, 170, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	fusePrompt = mkPrompt(fuseChamber, "FusePrompt", "Fuse Pets",
		"3 same-rarity -> next rarity", 2, 12)
	fusePrompt.Triggered:Connect(function(player)
		if not inRange(player, fuseChamber.Position, 18) then
			return
		end
		local profile = registry.Data and registry.Data.GetProfile(player)
		if not profile then
			return
		end
		local rarity = bestFuseRarity(profile)
		if not rarity then
			registry.Notify.Send(player, "warning", "No trio ready",
				"Fuse needs 3 UNEQUIPPED pets of the same rarity.", 4)
			return
		end
		local granted = ActivitiesService.TestFuse(player, rarity)
		if granted then
			local def = Pets.ById[granted.id]
			local title = (granted.mut and (granted.mut .. " ") or "")
				.. ((def and def.DisplayName) or granted.id)
			registry.Notify.Send(player, "secret", "FUSION!",
				"3x " .. rarity .. " became " .. title .. "!", 6)
		end
	end)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function ActivitiesService.Init(_, reg)
	registry = reg
	folder = Workspace:FindFirstChild("EggHeistActivities")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EggHeistActivities"
		folder.Parent = Workspace
	end
	local builders = {
		buildWishingWell, buildJumpPads, buildCrystalClaim,
		buildBottle, buildSkyVault, buildPetParade, buildFusion,
	}
	for _, builder in ipairs(builders) do
		local ok, err = pcall(builder)
		if not ok then
			warn("[EggHeist] Activities builder failed: " .. tostring(err))
		end
	end
	print("[EggHeist] Activities ready ("
		.. tostring(#folder:GetDescendants()) .. " objects).")
end

function ActivitiesService.Start()
	-- parade belt drift (slots wrap around forever)
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, slot in ipairs(conveyor.slots) do
				slot.x = slot.x + conveyor.speed * 0.2
				if slot.x > conveyor.maxX then
					slot.x = conveyor.minX
				end
				if slot.model and slot.model.Parent then
					pcall(ModelFactory.Pose, slot.model,
						CFrame.new(slot.x, conveyor.y, conveyor.z))
				end
			end
		end
	end)
end

-- Travel target: grotto floor / beach sand + a safe drop.
function ActivitiesService.GetSpotCFrame(spot)
	local at = anchor(spot == "beach" and "beach" or "grotto")
	if not at then
		return nil
	end
	return CFrame.new(at.X, 6, at.Z)
end

-- Sim/test hook: live prompt + position handles (never used by gameplay).
function ActivitiesService.TestParts()
	return {
		well = wellPrompt,
		wellPos = wellWater and wellWater.Position,
		crystal = crystalPrompt,
		crystalPos = crystalPrompt and crystalPrompt.Parent
			and crystalPrompt.Parent.Position,
		bottle = bottlePrompt,
		bottlePos = bottlePart and bottlePart.Position,
		vault = vaultPrompt,
		vaultPos = vaultPart and vaultPart.Position,
		pads = padCount,
		fuse = fusePrompt,
		fusePos = fuseChamber and fuseChamber.Position,
		parade = paradeSlots(),
	}
end

return ActivitiesService
