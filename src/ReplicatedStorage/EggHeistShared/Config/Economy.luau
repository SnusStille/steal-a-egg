-- EggHeist | Shared/Config/Economy.luau
-- EVERY tunable economy number lives here. Systems must require this module
-- instead of hardcoding values.

local Economy = {}

-- Starting resources
Economy.StartingCash = 250
Economy.StartingGems = 10
Economy.MaxCash = 999999999999 -- 999B hard cap (anti-overflow)
Economy.MaxGems = 99999999

-- Passive income tick (server pays equipped pets every IncomeTick seconds)
Economy.IncomeTick = 5 -- seconds
Economy.OfflineCapHours = 8 -- max offline earnings window
Economy.OfflineRate = 0.25 -- 25% of normal income while away

-- Pet leveling: xp needed per level, income growth per level
Economy.PetXpPerLevel = function(level)
	return math.floor(25 * math.pow(level, 1.6))
end
Economy.PetMaxLevel = 25
Economy.PetIncomePerLevel = 0.12 -- +12% income per level above 1

-- Selling pets: sell value = base income * factor * level scaling
Economy.PetSellFactor = 60 -- seconds-of-income equivalent

-- Player XP / levels
Economy.XpPerHatch = function(rarityTier)
	return 10 * rarityTier
end
Economy.XpPerHeistSuccess = 40
Economy.XpPerQuest = 60
Economy.LevelXp = function(level)
	return math.floor(80 * math.pow(level, 1.5))
end
Economy.MaxLevel = 100
Economy.CashPerLevelUp = function(level)
	return 100 + level * 75
end
Economy.GemsPerLevelUp = function(level)
	if level % 5 == 0 then
		return 5
	end
	return 0
end

-- Pet equip slots: base slots + unlocks by level / gamepass
Economy.BasePetSlots = 3
Economy.SlotUnlockLevels = { [4] = 4, [6] = 5, [8] = 6 } -- level -> total slots
Economy.MaxPetSlots = 8 -- with gamepass
Economy.MaxPetsStored = 120 -- inventory cap (soft; oldest commons auto-sell prompt)

-- Vault (base storage that thieves target): fraction of income banked
Economy.VaultBankRate = 0.15 -- 15% of earned cash goes to vault (collectable)
Economy.VaultBaseCapacity = 5000
Economy.HeistStealFraction = 0.25 -- thief takes up to 25% of vault contents

-- Prestige
Economy.PrestigeMinLevel = 30
Economy.PrestigeCashCost = 500000
Economy.PrestigeIncomeBonus = 0.25 -- +25% income per prestige, permanent
Economy.PrestigeMaxStacks = 20
Economy.PrestigeKeepPets = 3 -- keep N highest-income pets (rest converted to gems)
Economy.PrestigeGemBonusCap = 500 -- max gems granted from converted pets
Economy.PrestigeGemBonusDivisor = 5000 -- 1 gem per this much converted sell value
Economy.PrestigeGiftEgg = "Ancient" -- gift egg granted on every prestige

-- Daily rewards (streak day -> reward). Cycles after day 7 with bonus.
Economy.DailyRewards = {
	{ Cash = 500, Gems = 0, Egg = nil },
	{ Cash = 1200, Gems = 3, Egg = nil },
	{ Cash = 0, Gems = 0, Egg = "Stone" },
	{ Cash = 5000, Gems = 5, Egg = nil, Gadget = "Lockpick" },
	{ Cash = 12000, Gems = 8, Egg = nil },
	{ Cash = 0, Gems = 0, Egg = "Golden", Gadget = "Smoke" },
	{ Cash = 30000, Gems = 20, Egg = "Crystal", Gadget = "Sprint" },
}

-- Quest rewards (scaled by difficulty 1-3)
Economy.QuestReward = function(difficulty)
	return {
		Cash = 400 * difficulty * difficulty,
		Gems = difficulty >= 2 and difficulty * 2 or 0,
		Xp = 40 * difficulty,
	}
end

return Economy
