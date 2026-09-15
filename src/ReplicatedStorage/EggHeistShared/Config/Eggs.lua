-- EggHeist | Shared/Config/Eggs.lua
-- Shop eggs: price, hatch odds, visuals, unlock requirements.
-- Economy lives here so rebalancing never requires touching systems code.

local Eggs = {}

Eggs.List = {
	{
		Id = "Basic",
		Tier = 1,
		DisplayName = "Basic Egg",
		Description = "A humble egg. Every legend starts somewhere.",
		Price = 100,
		Currency = "Cash",
		RequiredLevel = 1,
		AssetModel = "BasicEgg",
		MarketStall = "Common",
		HatchWeights = { Common = 1000, Rare = 220, Epic = 40, Legendary = 6, Mythic = 1, Secret = 0 },
	},
	{
		Id = "Stone",
		Tier = 2,
		DisplayName = "Stone Egg",
		Description = "Heavy, rough, and full of surprises.",
		Price = 750,
		Currency = "Cash",
		RequiredLevel = 3,
		AssetModel = "StoneEgg",
		MarketStall = "Rare",
		HatchWeights = { Common = 700, Rare = 420, Epic = 110, Legendary = 18, Mythic = 3, Secret = 0 },
	},
	{
		Id = "Golden",
		Tier = 3,
		DisplayName = "Golden Egg",
		Description = "Shines with promise. Greatly improved odds.",
		Price = 4000,
		Currency = "Cash",
		RequiredLevel = 6,
		AssetModel = "GoldenEgg",
		MarketStall = "Epic",
		HatchWeights = { Common = 350, Rare = 450, Epic = 260, Legendary = 70, Mythic = 10, Secret = 1 },
	},
	{
		Id = "Crystal",
		Tier = 4,
		DisplayName = "Crystal Egg",
		Description = "Refracts luck itself. For serious collectors.",
		Price = 25000,
		Currency = "Cash",
		RequiredLevel = 10,
		AssetModel = "CrystalEgg",
		MarketStall = "Legendary",
		HatchWeights = { Common = 100, Rare = 350, Epic = 400, Legendary = 200, Mythic = 45, Secret = 4 },
	},
	{
		Id = "Lava",
		Tier = 5,
		DisplayName = "Lava Egg",
		Description = "Burning with mythic potential.",
		Price = 150000,
		Currency = "Cash",
		RequiredLevel = 15,
		AssetModel = "LavaEgg",
		MarketStall = "Mythic",
		HatchWeights = { Common = 20, Rare = 150, Epic = 350, Legendary = 380, Mythic = 150, Secret = 12 },
	},
	{
		Id = "Void",
		Tier = 6,
		DisplayName = "Void Egg",
		Description = "It stares back. The rarest egg money can buy.",
		Price = 1000000,
		Currency = "Cash",
		RequiredLevel = 22,
		AssetModel = "VoidEgg",
		MarketStall = "Secret",
		HatchWeights = { Common = 0, Rare = 60, Epic = 250, Legendary = 450, Mythic = 320, Secret = 45 },
	},
	-- Special eggs (not sold in the normal shop rotation)
	{
		Id = "Frost",
		Tier = 3,
		DisplayName = "Frost Egg",
		Description = "Cold to the touch, warm with potential.",
		Price = 9000,
		Currency = "Cash",
		RequiredLevel = 8,
		AssetModel = "CrystalEgg",
		MarketStall = "Epic",
		HatchWeights = { Common = 200, Rare = 450, Epic = 350, Legendary = 120, Mythic = 20, Secret = 2 },
	},
	{
		Id = "Storm",
		Tier = 5,
		DisplayName = "Storm Egg",
		Description = "Crackles with legendary energy. Endgame odds.",
		Price = 400000,
		Currency = "Cash",
		RequiredLevel = 18,
		AssetModel = "GalaxyEgg",
		MarketStall = "Legendary",
		HatchWeights = { Common = 40, Rare = 200, Epic = 380, Legendary = 300, Mythic = 90, Secret = 8 },
	},
	{
		Id = "Toxic",
		Tier = 2,
		DisplayName = "Toxic Egg",
		Description = "Event egg. Oozes with mutated power.",
		Price = 0,
		Currency = "Event",
		RequiredLevel = 1,
		AssetModel = "ToxicEgg",
		MarketStall = nil,
		EventOnly = true,
		HatchWeights = { Common = 200, Rare = 400, Epic = 350, Legendary = 150, Mythic = 40, Secret = 5 },
	},
	{
		Id = "Shadow",
		Tier = 3,
		DisplayName = "Shadow Egg",
		Description = "Blood Moon exclusive. Darkness hatches here.",
		Price = 0,
		Currency = "Event",
		RequiredLevel = 5,
		AssetModel = "ShadowEgg",
		MarketStall = nil,
		EventOnly = true,
		HatchWeights = { Common = 100, Rare = 300, Epic = 400, Legendary = 250, Mythic = 80, Secret = 8 },
	},
	{
		Id = "Galaxy",
		Tier = 4,
		DisplayName = "Galaxy Egg",
		Description = "A universe in a shell. Meteor Shower exclusive.",
		Price = 0,
		Currency = "Event",
		RequiredLevel = 8,
		AssetModel = "GalaxyEgg",
		MarketStall = nil,
		EventOnly = true,
		HatchWeights = { Common = 50, Rare = 250, Epic = 400, Legendary = 350, Mythic = 140, Secret = 15 },
	},
	{
		Id = "Ancient",
		Tier = 5,
		DisplayName = "Ancient Egg",
		Description = "Older than the plaza stones. Prestige reward.",
		Price = 0,
		Currency = "Prestige",
		RequiredLevel = 1,
		AssetModel = "AncientEgg",
		MarketStall = nil,
		EventOnly = true,
		HatchWeights = { Common = 0, Rare = 100, Epic = 350, Legendary = 450, Mythic = 250, Secret = 30 },
	},
}

Eggs.ById = {}
for _, def in ipairs(Eggs.List) do
	Eggs.ById[def.Id] = def
end

function Eggs.IsValid(eggId)
	return Eggs.ById[eggId] ~= nil
end

function Eggs.IsPurchasable(eggId)
	local def = Eggs.ById[eggId]
	return def ~= nil and def.EventOnly ~= true and (def.Price or 0) > 0
end

function Eggs.GetShopEggs()
	local out = {}
	for _, def in ipairs(Eggs.List) do
		if Eggs.IsPurchasable(def.Id) then
			out[#out + 1] = def
		end
	end
	return out
end

return Eggs
