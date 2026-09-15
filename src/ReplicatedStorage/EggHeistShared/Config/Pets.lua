-- EggHeist | Shared/Config/Pets.lua
-- Collectible creatures ("Egg Pals"). Income = cash per second at level 1.
-- XP curve and level scaling live in Economy config; visuals derive from
-- AssetModel (world EggAssets) + FaceId + BodyColor, tinted by mutation.

local Pets = {}

-- Helper to keep the list compact: Id, Name, Rarity, Income, Asset, Color, Blurb
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
	{ "zippy",      "Zippit",        "Rare",   14,  "BasicEgg",  "Bright blue",     "Too fast for cameras." },
	{ "gloom",      "Gloomcap",      "Rare",   15,  "ShadowEgg", "Dark indigo",     "Thrives in the vault." },
	-- EPIC
	{ "aurum",      "Aurum Drake",   "Epic",   30,  "GoldenEgg", "Bright yellow",   "Hoards its own income." },
	{ "frost",      "Frostbite",     "Epic",   34,  "CrystalEgg","Light blue",      "Cools overheated heists." },
	{ "magma",      "Magmaw",        "Epic",   38,  "LavaEgg",   "Really red",      "Do not hug." },
	{ "vined",      "Vinewhip",      "Epic",   42,  "AncientEgg","Forest green",    "Older than your base." },
	{ "jolt",       "Joltx",         "Epic",   46,  "GalaxyEgg", "New Yeller",      "Static-charged snuggles." },
	-- LEGENDARY
	{ "phoenix",    "Pyro Phoenix",  "Legendary", 95,  "LavaEgg",   "Bright orange","Reborn richer every dawn." },
	{ "leviathan",  "Mini Leviathan","Legendary", 110, "CrystalEgg","Deep blue",    "Floods you with cash." },
	{ "golem",      "Vault Golem",   "Legendary", 125, "StoneEgg",  "Brown",         "Guards your fortune." },
	{ "sultan",     "Gilded Sultan", "Legendary", 140, "GoldenEgg", "Gold",          "Taxes the tax collectors." },
	{ "wisp",       "Elder Wisp",    "Legendary", 155, "AncientEgg","Sand blue",     "Whispers stock tips." },
	-- MYTHIC
	{ "hydra",      "Hydroling",     "Mythic", 320,  "ToxicEgg",  "Lime green",      "Three heads, triple income." },
	{ "umbra",      "Umbra Panther", "Mythic", 380,  "ShadowEgg", "Black",           "Steals glances. And wallets." },
	{ "nebula",     "Nebula Whale",  "Mythic", 450,  "GalaxyEgg", "Royal purple",    "Swims through vault walls." },
	{ "titan",      "Clockwork Titan","Mythic", 520, "AncientEgg","Copper",          "Ticks in compound interest." },
	-- SECRET
	{ "voidlord",   "Void Lord",     "Secret", 1200, "VoidEgg",   "Black",           "It hatched YOU." },
	{ "starchild",  "Star Child",    "Secret", 1500, "GalaxyEgg", "White",           "A wish that pays out." },
	{ "nullking",   "Null King",     "Secret", 2000, "VoidEgg",   "Really black",    "The rarest pal in Egg Heist." },
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
	}
	Pets.List[#Pets.List + 1] = def
	Pets.ById[def.Id] = def
	Pets.ByRarity[def.Rarity] = Pets.ByRarity[def.Rarity] or {}
	Pets.ByRarity[def.Rarity][#Pets.ByRarity[def.Rarity] + 1] = def
end

function Pets.IsValid(petId)
	return Pets.ById[petId] ~= nil
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
