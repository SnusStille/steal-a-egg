-- EggHeist | Server/Economy/EconomyService.luau
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
		if registry.Achievement then
			registry.Achievement.Check(player, "LevelUp")
		end
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
	-- equipped pet bonuses
	if registry.Pet and registry.Pet.GetEquippedBonuses and player then
		local bonus = registry.Pet.GetEquippedBonuses(player)
		mult = mult * (1 + (bonus.IncomePct or 0) / 100)
	end
	-- egg totem decor: each totem boosts pet income, up to the cap
	if p.base and p.base.decorations then
		local totems = 0
		for _, decorId in ipairs(p.base.decorations) do
			if decorId == "EggTotem" then
				totems = totems + 1
			end
		end
		if totems > 0 then
			local pct = math.min(totems * (Economy.TotemIncomePct or 10),
				Economy.TotemMaxBonus or 50)
			mult = mult * (1 + pct / 100)
		end
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

-- Grants a reward bundle { Cash, Gems, Xp, Egg, Gadget, GadgetCount }.
-- Single choke point for achievement / milestone / daily-style rewards.
function EconomyService.GrantBundle(player, bundle, source)
	if type(bundle) ~= "table" then
		return false
	end
	if bundle.Cash and bundle.Cash > 0 then
		EconomyService.AddCash(player, bundle.Cash, source)
	end
	if bundle.Gems and bundle.Gems > 0 then
		EconomyService.AddGems(player, bundle.Gems, source)
	end
	if bundle.Xp and bundle.Xp > 0 then
		EconomyService.AddXp(player, bundle.Xp)
	end
	if bundle.Egg and registry.Egg then
		registry.Egg.GiftEgg(player, bundle.Egg, source)
	end
	if bundle.Gadget and registry.Gadget then
		registry.Gadget.GrantGadget(player, bundle.Gadget, bundle.GadgetCount or 1)
	end
	return true
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

-- NOTE: prestige/rebirth lives in Progression/ProgressionService.luau.
-- EconomyService only owns currencies, XP and multipliers.

-- One income payout for one player. The loop calls this every tick; the
-- sim calls it directly to prove equipped pets generate income.
function EconomyService.PayIncomeTick(player)
	local p = profileOf(player)
	if not p or not registry.Pet then
		return 0
	end
	local perSecond = registry.Pet.ComputeEquippedIncome(player)
	if perSecond <= 0 then
		return 0
	end
	local amount = perSecond * Economy.IncomeTick
		* EconomyService.GetIncomeMultiplier(player)
	EconomyService.AddCash(player, amount, "income")
	-- trickle pet XP to equipped pets
	registry.Pet.GrantEquippedXp(player, Economy.IncomeTick)
	return amount
end

function EconomyService.Start()
	-- Passive income loop: pays all players for equipped pets
	task.spawn(function()
		while true do
			task.wait(Economy.IncomeTick)
			for _, player in ipairs(Players:GetPlayers()) do
				EconomyService.PayIncomeTick(player)
			end
		end
	end)
end

return EconomyService
