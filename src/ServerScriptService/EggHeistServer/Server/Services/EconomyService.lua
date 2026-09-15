-- EggHeist | Server/Services/EconomyService.lua
-- THE ONLY module allowed to mutate cash/gems/xp. All grants/expenses flow here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local UpgradesConfig = require(ConfigFolder:WaitForChild("Upgrades"))

local EconomyService = {}
EconomyService.Name = "EconomyService"

local registry = nil

function EconomyService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

function EconomyService.GetCash(player)
	local p = profileOf(player)
	return p and p.cash or 0
end

function EconomyService.GetGems(player)
	local p = profileOf(player)
	return p and p.gems or 0
end

-- Adds cash (amount can be fractional internally; floored on sync).
-- source: string tag for stats/quests ("income", "quest", "heist", "sell", "admin"...)
function EconomyService.AddCash(player, amount, source)
	local p = profileOf(player)
	if not p then
		return 0
	end
	if type(amount) ~= "number" or amount ~= amount then
		return 0
	end
	if amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	p.cash = math.min(Economy.MaxCash, p.cash + amount)
	p.stats.totalEarned = (p.stats.totalEarned or 0) + amount
	-- Vault banking (only for organic earnings, not vault collects/admin)
	if source == "income" or source == "heist" then
		local bank = math.floor(amount * Economy.VaultBankRate)
		if bank > 0 and registry.Base then
			registry.Base.BankToVault(player, bank)
		end
	end
	if registry.Quest and (source == "income" or source == "heist" or source == "sell" or source == "quest") then
		registry.Quest.AddProgress(player, "EarnCash", amount)
	end
	registry.Data.MarkDirty(player)
	return amount
end

function EconomyService.SpendCash(player, amount)
	local p = profileOf(player)
	if not p then
		return false
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	amount = math.floor(amount)
	if p.cash < amount then
		return false
	end
	p.cash = p.cash - amount
	registry.Data.MarkDirty(player)
	return true
end

function EconomyService.AddGems(player, amount, _source)
	local p = profileOf(player)
	if not p then
		return 0
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	p.gems = math.min(Economy.MaxGems, p.gems + amount)
	registry.Data.MarkDirty(player)
	return amount
end

function EconomyService.SpendGems(player, amount)
	local p = profileOf(player)
	if not p then
		return false
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	amount = math.floor(amount)
	if p.gems < amount then
		return false
	end
	p.gems = p.gems - amount
	registry.Data.MarkDirty(player)
	return true
end

function EconomyService.AddXp(player, amount)
	local p = profileOf(player)
	if not p then
		return
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	if p.level >= Economy.MaxLevel then
		return
	end
	p.xp = p.xp + amount
	local leveled = false
	while p.level < Economy.MaxLevel and p.xp >= Economy.LevelXp(p.level) do
		p.xp = p.xp - Economy.LevelXp(p.level)
		p.level = p.level + 1
		leveled = true
		-- level-up rewards (direct grant to avoid recursion weirdness)
		p.cash = math.min(Economy.MaxCash, p.cash + Economy.CashPerLevelUp(p.level))
		local gems = Economy.GemsPerLevelUp(p.level)
		if gems > 0 then
			p.gems = math.min(Economy.MaxGems, p.gems + gems)
		end
	end
	if leveled then
		registry.Notify.Send(player, "success", "Level up!",
			"You reached level " .. tostring(p.level) .. "! Rewards added.", 5)
		registry.Net.Fire(player, "Fx", "LevelUp", p.level)
	end
	registry.Data.MarkDirty(player)
end

-- Computes a player's total income multiplier (upgrades, prestige, events, boosts, gamepass)
function EconomyService.GetIncomeMultiplier(player)
	local p = profileOf(player)
	if not p then
		return 1
	end
	local mult = 1
	-- base upgrade track
	local incomeTier = 0
	if p.base and p.base.upgrades then
		incomeTier = p.base.upgrades.Income or 0
	end
	mult = mult * UpgradesConfig.Tracks.Income.Effect(incomeTier)
	-- prestige
	if p.prestige and p.prestige.bonus then
		mult = mult * (1 + p.prestige.bonus)
	end
	-- active boosts
	if p.boosts then
		local now = os.time()
		for _, boost in ipairs(p.boosts) do
			if boost.expiresAt and boost.expiresAt > now and boost.IncomeMult then
				mult = mult * boost.IncomeMult
			end
		end
	end
	-- event modifier
	if registry.Event then
		mult = mult * registry.Event.GetIncomeMultiplier()
	end
	-- VIP gamepass
	if p.gamepasses and p.gamepasses.VIP then
		mult = mult * 1.25
	end
	return mult
end

function EconomyService.GetLuckMultiplier(player)
	local p = profileOf(player)
	if not p then
		return 1
	end
	local mult = 1
	if p.base and p.base.upgrades then
		mult = mult + UpgradesConfig.Tracks.Hatchery.Effect(p.base.upgrades.Hatchery or 0)
	end
	if p.boosts then
		local now = os.time()
		for _, boost in ipairs(p.boosts) do
			if boost.expiresAt and boost.expiresAt > now and boost.LuckMult then
				mult = mult * boost.LuckMult
			end
		end
	end
	if registry.Event then
		mult = mult * registry.Event.GetSecretLuckMultiplier()
	end
	return mult
end

function EconomyService.AddBoost(player, boostId, duration, modifiers)
	local p = profileOf(player)
	if not p then
		return false
	end
	local expiresAt = os.time() + math.max(1, math.floor(duration or 60))
	local entry = { id = boostId, expiresAt = expiresAt }
	if modifiers then
		for k, v in pairs(modifiers) do
			entry[k] = v
		end
	end
	p.boosts = p.boosts or {}
	p.boosts[#p.boosts + 1] = entry
	registry.Data.MarkDirty(player)
	return true
end

function EconomyService.CanPrestige(player)
	local p = profileOf(player)
	if not p then
		return false, "No profile"
	end
	if not p.prestige then
		return false, "Prestige disabled"
	end
	if (p.prestige.count or 0) >= Economy.PrestigeMaxStacks then
		return false, "Max prestige reached"
	end
	if p.level < Economy.PrestigeMinLevel then
		return false, "Requires level " .. tostring(Economy.PrestigeMinLevel)
	end
	if p.cash < Economy.PrestigeCashCost then
		return false, "Requires cash"
	end
	return true, "OK"
end

function EconomyService.DoPrestige(player)
	local can, reason = EconomyService.CanPrestige(player)
	if not can then
		registry.Notify.Send(player, "warning", "Can't prestige", reason, 4)
		return false
	end
	local p = profileOf(player)
	-- keep N best pets by income, convert the rest to gems
	table.sort(p.pets, function(a, b)
		return registry.Pet.PetIncomePerSecond(a) > registry.Pet.PetIncomePerSecond(b)
	end)
	local kept = {}
	local sellValue = 0
	for i, pet in ipairs(p.pets) do
		if i <= Economy.PrestigeKeepPets then
			kept[#kept + 1] = pet
		else
			sellValue = sellValue + registry.Pet.GetSellValue(pet)
		end
	end
	p.pets = kept
	-- rebuild equipped from kept pets only
	local keptUids = {}
	for _, pet in ipairs(kept) do
		keptUids[pet.uid] = true
	end
	local equipped = {}
	for _, uid in ipairs(p.equipped) do
		if keptUids[uid] then
			equipped[#equipped + 1] = uid
		end
	end
	p.equipped = equipped
	local gemBonus = math.min(500, math.floor(sellValue / 5000))
	p.gems = math.min(Economy.MaxGems, p.gems + gemBonus)
	-- reset progression (plot, collection, stats kept)
	p.cash = Economy.StartingCash
	p.xp = 0
	p.level = 1
	p.eggs = {}
	p.base.upgrades = { Income = 0, EggSlots = 0, Hatchery = 0, Vault = 0, Comfort = 0 }
	p.base.security = { Door = 0, Camera = 0, Laser = 0, Alarm = 0, Trap = 0, VaultShield = 0, Lockdown = 0, Decoy = 0 }
	p.base.vault = 0
	p.base.lockdownUntil = 0
	p.base.lockdownCooldownUntil = 0
	p.prestige.count = (p.prestige.count or 0) + 1
	p.prestige.bonus = (p.prestige.bonus or 0) + Economy.PrestigeIncomeBonus
	-- prestige gift
	p.eggs[#p.eggs + 1] = { uid = registry.Data.GenerateUid(player), eggId = "Ancient" }
	registry.Pet.RebuildFollowers(player)
	local plotIndex = registry.Base.GetPlotOf(player)
	if plotIndex and plotIndex > 0 then
		registry.Security.RebuildPlotSecurity(plotIndex)
	end
	registry.Data.MarkDirty(player)
	registry.Notify.Broadcast("secret", "PRESTIGE!",
		player.DisplayName .. " prestiged to rank " .. tostring(p.prestige.count)
			.. " (+" .. tostring(math.floor(p.prestige.bonus * 100)) .. "% income)!", 8)
	return true
end

function EconomyService.Start()
	registry.Net.OnRequest("Prestige", function(player)
		EconomyService.DoPrestige(player)
	end)

	-- Passive income loop: pays all players for equipped pets
	task.spawn(function()
		while true do
			task.wait(Economy.IncomeTick)
			for _, player in ipairs(Players:GetPlayers()) do
				local p = profileOf(player)
				if p and registry.Pet then
					local perSecond = registry.Pet.ComputeEquippedIncome(player)
					if perSecond > 0 then
						local amount = perSecond * Economy.IncomeTick
							* EconomyService.GetIncomeMultiplier(player)
						EconomyService.AddCash(player, amount, "income")
						-- trickle pet XP to equipped pets
						registry.Pet.GrantEquippedXp(player, Economy.IncomeTick)
					end
				end
			end
		end
	end)
end

return EconomyService
