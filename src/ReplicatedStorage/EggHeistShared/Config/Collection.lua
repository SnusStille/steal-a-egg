-- EggHeist | Shared/Config/Collection.lua
-- Collection milestones: rewards for unique discoveries (pet x mutation).
-- Total possible = #pets x (1 + #mutations). Each milestone claims once.

local Collection = {}

Collection.Milestones = {
	{ Count = 10, Reward = { Cash = 2000 } },
	{ Count = 25, Reward = { Cash = 6000, Gems = 5 } },
	{ Count = 50, Reward = { Cash = 10000, Egg = "Golden" } },
	{ Count = 100, Reward = { Cash = 30000, Gems = 20 } },
	{ Count = 150, Reward = { Egg = "Void", Gems = 30 } },
	{ Count = 200, Reward = { Gems = 100, Egg = "Ancient" } },
	{ Count = 250, Reward = { Gems = 60, Egg = "Storm" } },
	{ Count = 350, Reward = { Gems = 150, Egg = "Ancient" } },
}

return Collection
