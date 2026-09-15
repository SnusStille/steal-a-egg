-- EggHeist | Server/Pets/PetService.lua
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
	return true
end

--------------------------------------------------------------------------------
-- Followers (3D pets trailing the player)
--------------------------------------------------------------------------------

local FACE_TEXT = {
	Common = "(•‿•)",
	Rare = "(◕‿◕)",
	Epic = "(✧‿✧)",
	Legendary = "(★‿★)",
	Mythic = "(◉‿◉)",
	Secret = "(♦‿♦)",
}

local function applyMutationVisuals(model, mutationId)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local mut = Mutations.ById[mutationId]
	if not mut then
		return
	end
	body.Color = mut.Color
	if mutationId == "Neon" or mutationId == "Galaxy" or mutationId == "Void" then
		body.Material = Enum.Material.Neon
	elseif mutationId == "Crystal" then
		body.Material = Enum.Material.Glass
	elseif mutationId == "Golden" then
		body.Material = Enum.Material.SmoothPlastic
	end
	-- sparkle for flashy mutations
	if mutationId == "Golden" or mutationId == "Galaxy" or mutationId == "Void"
		or mutationId == "Ancient" or mutationId == "Neon" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mut.Color
		sparkles.Parent = body
	end
end

local function buildFollowerModel(pet)
	local def = Pets.ById[pet.id]
	local assetName = def and def.AssetModel or "BasicEgg"
	local model = registry.World.CloneEggAsset(assetName)
	model.Name = "Pet_" .. pet.uid
	-- normalize: anchor everything, no collisions, scale to pal size
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		model.PrimaryPart = body
		-- shrink to pal size (assets are display-sized); keep child-part
		-- offsets proportional so multi-part eggs (bumps, facets) stay glued
		local targetSize = Vector3.new(1.4, 1.8, 1.4)
		local scale = targetSize.X / math.max(0.1, body.Size.X)
		local bodyPos = body.Position
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("SpecialMesh") then
				descendant.Scale = descendant.Scale * scale
			elseif descendant:IsA("BasePart") and descendant ~= body then
				descendant.Size = descendant.Size * scale
				local offset = descendant.Position - bodyPos
				local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 =
					descendant.CFrame:GetComponents()
				local newPos = bodyPos + offset * scale
				descendant.CFrame = CFrame.new(newPos.X, newPos.Y, newPos.Z,
					r00, r01, r02, r10, r11, r12, r20, r21, r22)
			end
		end
		body.Size = targetSize
		-- cute face
		local face = Instance.new("SurfaceGui")
		face.Name = "Face"
		face.Face = Enum.NormalId.Front
		face.CanvasSize = Vector2.new(128, 128)
		face.Parent = body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = FACE_TEXT[def and def.Rarity or "Common"] or "(•‿•)"
		label.TextColor3 = Color3.fromRGB(30, 30, 30)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = face
	end
	applyMutationVisuals(model, pet.mut)
	-- nametag
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
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
				-- capture child-part offsets so multi-part eggs stay glued
				local parts = {}
				local primary = model.PrimaryPart
				if primary then
					for _, part in ipairs(model:GetDescendants()) do
						if part:IsA("BasePart") and part ~= primary then
							parts[#parts + 1] = {
								part = part,
								offset = part.Position - primary.Position,
							}
						end
					end
				end
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
							-- keep child parts glued via captured offsets
							for _, child in ipairs(entry.parts or {}) do
								if child.part and child.part.Parent then
									child.part.CFrame = CFrame.new(primary.Position + child.offset)
										* (primary.CFrame - primary.Position)
								end
							end
						end
					end
				end
			end
		end
	end
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

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(0.5, function()
				if player.Parent then
					PetService.RebuildFollowers(player)
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
				end
			end)
		end)
		task.delay(2, function()
			if player.Parent then
				PetService.RebuildFollowers(player)
			end
		end)
	end

	RunService.Heartbeat:Connect(updateFollowers)
end

return PetService
