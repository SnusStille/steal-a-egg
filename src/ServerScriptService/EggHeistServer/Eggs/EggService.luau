-- EggHeist | Server/Eggs/EggService.luau
-- Egg purchasing + hatching. ALL rolls happen here on the server.

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
local Types = require(Shared:WaitForChild("Types"))

local EggService = {}
EggService.Name = "EggService"

local registry = nil
local rng = Random.new()

function EggService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

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

local function doHatch(player, eggUid)
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
	table.remove(profile.eggs, index)
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
	return {
		pet = pet,
		isNew = isNew,
		rarity = roll.rarity,
		eggName = (sourceDef and sourceDef.DisplayName) or egg.eggId,
	}
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

	-- Auto-hatch: gamepass OR permanent gems unlock
	if profile.settings.autoHatch
		and (profile.gamepasses.AutoHatch or profile.autoHatchUnlock) then
		local results = {}
		for _, egg in ipairs(bought) do
			local result = doHatch(player, egg.uid)
			if result then
				results[#results + 1] = result
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

function EggService.Start()
	registry.Net.OnRequest("BuyEgg", function(player, eggId, count)
		EggService.BuyEgg(player, eggId, count)
	end)

	registry.Net.OnRequest("BuyAutoHatch", function(player)
		EggService.BuyAutoHatch(player)
	end)

	registry.Net.OnRequest("HatchEgg", function(player, eggUid)
		eggUid = Validate.Uid(eggUid)
		if not eggUid then
			return
		end
		local result = doHatch(player, eggUid)
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
		-- copy uids first (doHatch mutates the list)
		local uids = {}
		for _, egg in ipairs(profile.eggs) do
			uids[#uids + 1] = egg.uid
			if #uids >= 25 then
				break
			end
		end
		for _, uid in ipairs(uids) do
			local result = doHatch(player, uid)
			if result then
				results[#results + 1] = result
				hatched = hatched + 1
			else
				break -- storage full
			end
		end
		if hatched > 0 then
			registry.Net.Fire(player, "HatchResult", { results = results, auto = false, bulk = true })
		end
	end)
end

return EggService
