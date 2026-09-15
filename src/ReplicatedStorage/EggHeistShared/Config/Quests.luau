-- EggHeist | Shared/Config/Quests.luau
-- Data-driven quest pools. Types map to stat hooks in QuestService.

local Quests = {}

-- Daily pool (3 assigned per day). difficulty 1-3 scales rewards.
Quests.DailyPool = {
	{ Id = "hatch_5",     Type = "HatchEggs",     Target = 5,   Difficulty = 1, Text = "Hatch 5 eggs" },
	{ Id = "hatch_15",    Type = "HatchEggs",     Target = 15,  Difficulty = 2, Text = "Hatch 15 eggs" },
	{ Id = "earn_5k",     Type = "EarnCash",      Target = 5000,   Difficulty = 1, Text = "Earn $5,000" },
	{ Id = "earn_25k",    Type = "EarnCash",      Target = 25000,  Difficulty = 2, Text = "Earn $25,000" },
	{ Id = "heist_1",     Type = "CompleteHeists",Target = 1,   Difficulty = 2, Text = "Complete 1 heist" },
	{ Id = "heist_3",     Type = "CompleteHeists",Target = 3,   Difficulty = 3, Text = "Complete 3 heists" },
	{ Id = "upgrade_1",   Type = "UpgradeBase",   Target = 1,   Difficulty = 1, Text = "Upgrade your base once" },
	{ Id = "equip_3",     Type = "EquipPets",     Target = 3,   Difficulty = 1, Text = "Have 3 pets equipped" },
	{ Id = "collect_3",   Type = "NewCollection", Target = 3,   Difficulty = 2, Text = "Discover 3 new collection entries" },
	{ Id = "secure_1",    Type = "UpgradeSecurity", Target = 1, Difficulty = 2, Text = "Buy a security upgrade" },
	{ Id = "vault_10k",   Type = "BankVault",     Target = 10000, Difficulty = 2, Text = "Bank $10,000 into your vault" },
	{ Id = "play_15m",    Type = "PlayMinutes",   Target = 15,  Difficulty = 1, Text = "Play for 15 minutes" },
	{ Id = "trade_1",     Type = "CompleteTrades",Target = 1,   Difficulty = 1, Text = "Complete 1 trade" },
	{ Id = "hatch_30",    Type = "HatchEggs",     Target = 30,  Difficulty = 2, Text = "Hatch 30 eggs" },
	{ Id = "earn_100k",   Type = "EarnCash",      Target = 100000, Difficulty = 3, Text = "Earn $100,000" },
	{ Id = "heist_2",     Type = "CompleteHeists",Target = 2,   Difficulty = 3, Text = "Complete 2 heists" },
	{ Id = "vault_50k",   Type = "BankVault",     Target = 50000, Difficulty = 3, Text = "Bank $50,000 into your vault" },
	{ Id = "wish_1",      Type = "MakeWishes",    Target = 1,   Difficulty = 1, Text = "Make a wish at the wishing well" },
	{ Id = "crystal_1",   Type = "ClaimCrystals", Target = 1,   Difficulty = 1, Text = "Harvest the crystal grotto" },
	{ Id = "skyvault_1",  Type = "SkyVault",      Target = 1,   Difficulty = 2, Text = "Claim the sky vault" },
}

-- Weekly pool (2 assigned per week, bigger targets)
Quests.WeeklyPool = {
	{ Id = "w_hatch_75",  Type = "HatchEggs",     Target = 75,     Difficulty = 3, Text = "Hatch 75 eggs" },
	{ Id = "w_earn_250k", Type = "EarnCash",      Target = 250000, Difficulty = 3, Text = "Earn $250,000" },
	{ Id = "w_heist_10",  Type = "CompleteHeists",Target = 10,     Difficulty = 3, Text = "Complete 10 heists" },
	{ Id = "w_mutation",  Type = "HatchMutated",  Target = 5,      Difficulty = 3, Text = "Hatch 5 mutated pets" },
	{ Id = "w_legendary", Type = "HatchLegendaryPlus", Target = 3, Difficulty = 3, Text = "Hatch 3 Legendary+ pets" },
	{ Id = "w_security",  Type = "UpgradeSecurity", Target = 3,    Difficulty = 3, Text = "Buy 3 security upgrades" },
	{ Id = "w_earn_1m",   Type = "EarnCash",      Target = 1000000, Difficulty = 3, Text = "Earn $1,000,000" },
	{ Id = "w_trade_5",   Type = "CompleteTrades",Target = 5,      Difficulty = 3, Text = "Complete 5 trades" },
}

Quests.DailiesPerDay = 3
Quests.WeekliesPerWeek = 2

return Quests
