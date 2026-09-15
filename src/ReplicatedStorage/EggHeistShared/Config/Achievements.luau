-- EggHeist | Shared/Config/Achievements.luau
-- One-time achievements. Fully data-driven: add a row, no code changes.
--
-- Trigger: server event name that re-evaluates this achievement.
--   "BuyEgg" | "HatchEgg" | "EquipPet" | "HeistWin" | "LevelUp" |
--   "Prestige" | "QuestClaim" | "UpgradeBuy" | "SecurityBuy" |
--   "TradeComplete" | "Scout" | "Defend"
-- Conditions (ALL must pass; omit for trigger-only achievements):
--   Stat = { Key = "<stats key>", Value = n }   -- lifetime stat >= n
--   Level = n                                   -- player level >= n
--   Collection = n                              -- unique discoveries >= n
--   Prestige = n                                -- prestige count >= n
--   Equipped = n                                -- currently equipped >= n
--   UpgradeTotal = n                            -- sum of base upgrade tiers >= n
--   SecurityTotal = n                           -- sum of security tiers >= n
-- Reward: { Cash, Gems, Xp, Egg = "<eggId>", Gadget = "<gadgetId>", GadgetCount }

local Achievements = {}

Achievements.List = {
	{ Id = "first_egg", Name = "First Egg", Text = "Buy your first egg",
		Trigger = "BuyEgg", Stat = { Key = "eggsBought", Value = 1 },
		Reward = { Cash = 250 } },
	{ Id = "egg_hoarder", Name = "Egg Hoarder", Text = "Buy 25 eggs",
		Trigger = "BuyEgg", Stat = { Key = "eggsBought", Value = 25 },
		Reward = { Cash = 2000 } },
	{ Id = "first_hatch", Name = "It Hatches!", Text = "Hatch your first egg",
		Trigger = "HatchEgg", Stat = { Key = "totalHatched", Value = 1 },
		Reward = { Cash = 250 } },
	{ Id = "hatch_25", Name = "Hatchling", Text = "Hatch 25 eggs",
		Trigger = "HatchEgg", Stat = { Key = "totalHatched", Value = 25 },
		Reward = { Cash = 3000 } },
	{ Id = "hatch_100", Name = "Hatch Master", Text = "Hatch 100 eggs",
		Trigger = "HatchEgg", Stat = { Key = "totalHatched", Value = 100 },
		Reward = { Cash = 15000, Gems = 10 } },
	{ Id = "first_mutation", Name = "Shiny!", Text = "Hatch a mutated pet",
		Trigger = "HatchEgg", Stat = { Key = "mutatedHatched", Value = 1 },
		Reward = { Cash = 1000 } },
	{ Id = "mutant_master", Name = "Mutant Master", Text = "Hatch 10 mutated pets",
		Trigger = "HatchEgg", Stat = { Key = "mutatedHatched", Value = 10 },
		Reward = { Egg = "Golden" } },
	{ Id = "mutant_25", Name = "Mutation Surge", Text = "Hatch 25 mutated pets",
		Trigger = "HatchEgg", Stat = { Key = "mutatedHatched", Value = 25 },
		Reward = { Egg = "Crystal", Gems = 10 } },
	{ Id = "legendary_pull", Name = "Legendary Pull", Text = "Hatch a Legendary (or better) pet",
		Trigger = "HatchEgg", Stat = { Key = "legendaryPlusHatched", Value = 1 },
		Reward = { Cash = 2500, Gems = 5 } },
	{ Id = "secret_pull", Name = "Impossible Odds", Text = "Hatch a Secret pet",
		Trigger = "HatchEgg", Stat = { Key = "secretsHatched", Value = 1 },
		Reward = { Cash = 25000, Gems = 25 } },
	{ Id = "first_friend", Name = "First Friend", Text = "Equip your first pet",
		Trigger = "EquipPet",
		Reward = { Cash = 250 } },
	{ Id = "full_squad", Name = "Full Squad", Text = "Have 5 pets equipped at once",
		Trigger = "EquipPet", Equipped = 5,
		Reward = { Cash = 2000 } },
	{ Id = "first_heist", Name = "Sticky Fingers", Text = "Complete your first heist",
		Trigger = "HeistWin", Stat = { Key = "heistsWon", Value = 1 },
		Reward = { Cash = 1000, Gadget = "Smoke" } },
	{ Id = "heist_10", Name = "Professional", Text = "Complete 10 heists",
		Trigger = "HeistWin", Stat = { Key = "heistsWon", Value = 10 },
		Reward = { Cash = 10000, Gadget = "EMP" } },
	{ Id = "ghost", Name = "Ghost", Text = "Reach 30 heist reputation",
		Trigger = "HeistWin", Stat = { Key = "heistRep", Value = 30 },
		Reward = { Cash = 25000, Gems = 25 } },
	{ Id = "level_10", Name = "Rising Star", Text = "Reach level 10",
		Trigger = "LevelUp", Level = 10,
		Reward = { Cash = 2000 } },
	{ Id = "level_25", Name = "Big Shot", Text = "Reach level 25",
		Trigger = "LevelUp", Level = 25,
		Reward = { Egg = "Crystal" } },
	{ Id = "collector_10", Name = "Collector", Text = "Discover 10 collection entries",
		Trigger = "HatchEgg", Collection = 10,
		Reward = { Cash = 1500 } },
	{ Id = "collector_50", Name = "Curator", Text = "Discover 50 collection entries",
		Trigger = "HatchEgg", Collection = 50,
		Reward = { Cash = 12000, Gems = 12 } },
	{ Id = "fortress", Name = "Fort Knox", Text = "Own 8 total security tiers",
		Trigger = "SecurityBuy", SecurityTotal = 8,
		Reward = { Cash = 5000 } },
	{ Id = "mogul", Name = "Mogul", Text = "Own 10 total base upgrade tiers",
		Trigger = "UpgradeBuy", UpgradeTotal = 10,
		Reward = { Cash = 5000 } },
	{ Id = "reborn", Name = "Reborn", Text = "Prestige for the first time",
		Trigger = "Prestige", Prestige = 1,
		Reward = { Gems = 50 } },
	{ Id = "quester", Name = "Errand Runner", Text = "Claim 10 quest rewards",
		Trigger = "QuestClaim", Stat = { Key = "questsDone", Value = 10 },
		Reward = { Cash = 4000 } },
	{ Id = "first_trade", Name = "Deal Maker", Text = "Complete your first trade",
		Trigger = "TradeComplete", Stat = { Key = "tradesCompleted", Value = 1 },
		Reward = { Cash = 1500 } },
	{ Id = "trader_10", Name = "Broker", Text = "Complete 10 trades",
		Trigger = "TradeComplete", Stat = { Key = "tradesCompleted", Value = 10 },
		Reward = { Gems = 15 } },
	{ Id = "scouted", Name = "Casing the Joint", Text = "Scout an enemy base",
		Trigger = "Scout", Reward = { Cash = 500 } },
	{ Id = "untouchable", Name = "Untouchable", Text = "Trigger your defenses 25 times",
		Trigger = "Defend", Stat = { Key = "defensesTriggered", Value = 25 },
		Reward = { Cash = 5000 } },
	{ Id = "heist_10", Name = "Cat Burglar", Text = "Complete 10 heists",
		Trigger = "HeistWin", Stat = { Key = "heistsWon", Value = 10 },
		Reward = { Cash = 8000 } },
	{ Id = "heist_50", Name = "Ghost of the Vaults", Text = "Complete 50 heists",
		Trigger = "HeistWin", Stat = { Key = "heistsWon", Value = 50 },
		Reward = { Cash = 40000, Gems = 20 } },
	{ Id = "secret_luck", Name = "Jackpot Soul", Text = "Hatch a SECRET pet",
		Trigger = "HatchEgg", Stat = { Key = "secretsHatched", Value = 1 },
		Reward = { Gems = 25 } },
	{ Id = "level_25", Name = "Veteran", Text = "Reach level 25",
		Trigger = "LevelUp", Level = 25,
		Reward = { Cash = 20000, Gems = 10 } },
	{ Id = "collector_100", Name = "Archivist", Text = "Discover 100 collection entries",
		Trigger = "HatchEgg", Collection = 100,
		Reward = { Cash = 25000, Gems = 25 } },
	{ Id = "hatch_500", Name = "Hatch Factory", Text = "Hatch 500 eggs",
		Trigger = "HatchEgg", Stat = { Key = "totalHatched", Value = 500 },
		Reward = { Cash = 60000, Gems = 30 } },
	{ Id = "make_wish", Name = "Wish Upon a Well", Text = "Make a wish at the wishing well",
		Trigger = "MakeWish",
		Reward = { Cash = 500 } },
	{ Id = "sky_climb", Name = "Sky High", Text = "Claim the sky vault",
		Trigger = "SkyVault",
		Reward = { Cash = 500 } },
	{ Id = "crystal_harvest", Name = "Shiny Harvest", Text = "Harvest the crystal grotto",
		Trigger = "ClaimCrystal",
		Reward = { Gems = 5 } },
}

Achievements.ById = {}
for _, def in ipairs(Achievements.List) do
	Achievements.ById[def.Id] = def
end

function Achievements.IsValid(achievementId)
	return Achievements.ById[achievementId] ~= nil
end

return Achievements
