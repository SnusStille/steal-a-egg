-- EggHeist | Shared/Config/Pets.luau
-- Collectible creatures ("Egg Pals"). Income = cash per second at level 1.
-- XP curve and level scaling live in Economy config; visuals derive from
-- AssetModel (world EggAssets) + FaceId + BodyColor, tinted by mutation.

local Pets = {}

-- Helper to keep the list compact: Id, Name, Rarity, Income, Asset, Color, Blurb, Bonus?
-- Bonus = { Stat, Pct }: "IncomePct" | "BreachSpeedPct" | "CarrySpeedPct" | "HeistPayoutPct"
-- (equipped pets only; summed with caps in PetService.GetEquippedBonuses)
local D = {
	-- COMMON (Basic/Stone eggs)
	{ "chick",      "Pip Chick",     "Common", 2,   "BasicEgg",  "Bright yellow",   "Cheerful and quick." },
	{ "sprout",     "Sproutie",      "Common", 3,   "BasicEgg",  "Bright green",    "Grew legs. Nobody knows why." },
	{ "pebble",     "Pebbles",       "Common", 3,   "StoneEgg",  "Medium stone grey","Heavier than he looks." },
	{ "bunny",      "Hopsy",         "Common", 4,   "BasicEgg",  "White",           "Hops toward money." },
	{ "mossy",      "Mossball",      "Common", 5,   "StoneEgg",  "Dark green",      "Soft, round, profitable." },
	-- RARE
	{ "ember",      "Emberling",     "Rare",   9,   "LavaEgg",   "Bright orange",   "Warm to the touch." },
	{ "splash",     "Splash Fin",    "Rare",   11,  "CrystalEgg","Bright bluish green","Loves vault humidity." },
	{ "rocky",      "Boulder Buddy", "Rare",   12,  "StoneEgg",  "Dark stone grey", "A reliable rock." },
	{ "zippy",      "Zippit",        "Rare",   14,  "BasicEgg",  "Bright blue",     "Too fast for cameras.", { "BreachSpeedPct", 5 } },
	{ "gloom",      "Gloomcap",      "Rare",   15,  "ShadowEgg", "Dark indigo",     "Thrives in the vault.", { "HeistPayoutPct", 4 } },
	-- EPIC
	{ "aurum",      "Aurum Drake",   "Epic",   30,  "GoldenEgg", "Bright yellow",   "Hoards its own income.", { "IncomePct", 4 } },
	{ "frost",      "Frostbite",     "Epic",   34,  "CrystalEgg","Light blue",      "Cools overheated heists.", { "CarrySpeedPct", 5 } },
	{ "magma",      "Magmaw",        "Epic",   38,  "LavaEgg",   "Really red",      "Do not hug." },
	{ "vined",      "Vinewhip",      "Epic",   42,  "AncientEgg","Forest green",    "Older than your base." },
	{ "jolt",       "Joltx",         "Epic",   46,  "GalaxyEgg", "New Yeller",      "Static-charged snuggles.", { "BreachSpeedPct", 6 } },
	-- LEGENDARY
	{ "phoenix",    "Pyro Phoenix",  "Legendary", 95,  "LavaEgg",   "Bright orange","Reborn richer every dawn." },
	{ "leviathan",  "Mini Leviathan","Legendary", 110, "CrystalEgg","Deep blue",    "Floods you with cash." },
	{ "golem",      "Vault Golem",   "Legendary", 125, "StoneEgg",  "Brown",         "Guards your fortune.", { "CarrySpeedPct", 8 } },
	{ "sultan",     "Gilded Sultan", "Legendary", 140, "GoldenEgg", "Gold",          "Taxes the tax collectors.", { "IncomePct", 6 } },
	{ "wisp",       "Elder Wisp",    "Legendary", 155, "AncientEgg","Sand blue",     "Whispers stock tips.", { "HeistPayoutPct", 8 } },
	-- MYTHIC
	{ "hydra",      "Hydroling",     "Mythic", 320,  "ToxicEgg",  "Lime green",      "Three heads, triple income." },
	{ "umbra",      "Umbra Panther", "Mythic", 380,  "ShadowEgg", "Black",           "Steals glances. And wallets.", { "HeistPayoutPct", 10 } },
	{ "nebula",     "Nebula Whale",  "Mythic", 450,  "GalaxyEgg", "Royal purple",    "Swims through vault walls.", { "BreachSpeedPct", 10 } },
	{ "titan",      "Clockwork Titan","Mythic", 520, "AncientEgg","Copper",          "Ticks in compound interest.", { "IncomePct", 10 } },
	-- SECRET
	{ "voidlord",   "Void Lord",     "Secret", 1200, "VoidEgg",   "Black",           "It hatched YOU.", { "HeistPayoutPct", 15 } },
	{ "starchild",  "Star Child",    "Secret", 1500, "GalaxyEgg", "White",           "A wish that pays out." },
	{ "nullking",   "Null King",     "Secret", 2000, "VoidEgg",   "Really black",    "The rarest pal in Egg Heist.", { "IncomePct", 15 } },
	-- v4 additions (Frost/Storm hatch pools)
	{ "frostmite",  "Frost Mite",      "Rare",   16,  "CrystalEgg","Light blue",      "Sneezes snowflakes.", { "IncomePct", 3 } },
	{ "glacier",    "Glacier Cub",     "Epic",   50,  "CrystalEgg","White",           "Slides into vaults.", { "HeistPayoutPct", 6 } },
	{ "temprocs",   "Tempest Roc",     "Epic",   55,  "GalaxyEgg", "Dark blue",       "Rides the storm out.", { "CarrySpeedPct", 7 } },
	{ "blizzard",   "Blizzard Wyrm",   "Legendary", 170, "CrystalEgg", "Institutional white", "Whiteout with teeth.", { "IncomePct", 7 } },
	{ "cyclone",    "Cyclone Serpent", "Mythic", 600, "GalaxyEgg", "Royal purple",    "The heist IS the storm.", { "BreachSpeedPct", 12 } },
	{ "aurora",     "Aurora Titan",    "Secret", 2500, "CrystalEgg","Bright bluish green", "Dawn, but profitable.", { "CarrySpeedPct", 12 } },
	-- v6 additions
	{ "coral",      "Coral Pup",       "Rare",   18,  "CrystalEgg","Bright reddish violet", "Barks in bubbles." },
	{ "monarch",    "Monarch Moth",    "Epic",   60,  "GoldenEgg", "Bright yellow",   "Royalty, but tiny.", { "IncomePct", 5 } },
	{ "kraken",     "Pocket Kraken",   "Legendary", 190, "ShadowEgg", "Black",         "Eight arms, all counting cash.", { "HeistPayoutPct", 9 } },
	{ "seraph",     "Seraph Cub",      "Mythic", 700,  "AncientEgg","White",           "Blesses your vault daily.", { "IncomePct", 12 } },
}

Pets.List = {}
Pets.ById = {}
Pets.ByRarity = {}

for _, row in ipairs(D) do
	local def = {
		Id = row[1],
		DisplayName = row[2],
		Rarity = row[3],
		BaseIncome = row[4],
		AssetModel = row[5],
		BodyColor = row[6],
		Description = row[7],
		Bonus = row[8], -- { Stat, Pct } or nil
	}
	Pets.List[#Pets.List + 1] = def
	Pets.ById[def.Id] = def
	Pets.ByRarity[def.Rarity] = Pets.ByRarity[def.Rarity] or {}
	Pets.ByRarity[def.Rarity][#Pets.ByRarity[def.Rarity] + 1] = def
end

function Pets.IsValid(petId)
	return Pets.ById[petId] ~= nil
end

Pets.BonusLabels = {
	IncomePct = "income",
	BreachSpeedPct = "breach speed",
	CarrySpeedPct = "carry speed",
	HeistPayoutPct = "heist payout",
}

-- "+6% income" style text, or nil when the pet has no bonus.
function Pets.BonusText(petId)
	local def = Pets.ById[petId]
	if not def or not def.Bonus then
		return nil
	end
	local label = Pets.BonusLabels[def.Bonus[1]] or def.Bonus[1]
	return "+" .. tostring(def.Bonus[2]) .. "% " .. label
end

function Pets.GetRandomOfRarity(rarityId, rng)
	local pool = Pets.ByRarity[rarityId]
	if not pool or #pool == 0 then
		return nil
	end
	if typeof(rng) == "Random" then
		return pool[rng:NextInteger(1, #pool)]
	end
	return pool[math.random(1, #pool)]
end

return Pets
