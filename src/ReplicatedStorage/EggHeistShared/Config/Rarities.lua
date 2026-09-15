-- EggHeist | Shared/Config/Rarities.lua
-- Single source of truth for rarity definitions.
-- Order matters: index = tier (1 = lowest).

local Rarities = {}

Rarities.List = {
	{ Id = "Common",    DisplayName = "Common",    Color = Color3.fromRGB(185, 196, 213), Short = "C" },
	{ Id = "Rare",      DisplayName = "Rare",      Color = Color3.fromRGB(88, 166, 255),  Short = "R" },
	{ Id = "Epic",      DisplayName = "Epic",      Color = Color3.fromRGB(178, 102, 255), Short = "E" },
	{ Id = "Legendary", DisplayName = "Legendary", Color = Color3.fromRGB(255, 176, 32),  Short = "L" },
	{ Id = "Mythic",    DisplayName = "Mythic",    Color = Color3.fromRGB(255, 80, 120),  Short = "M" },
	{ Id = "Secret",    DisplayName = "Secret",    Color = Color3.fromRGB(60, 255, 210),  Short = "S" },
}

Rarities.ById = {}
Rarities.TierOf = {}
for tier, def in ipairs(Rarities.List) do
	Rarities.ById[def.Id] = def
	Rarities.TierOf[def.Id] = tier
end

function Rarities.IsValid(rarityId)
	return Rarities.ById[rarityId] ~= nil
end

function Rarities.GetColor(rarityId)
	local def = Rarities.ById[rarityId]
	if def then
		return def.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

function Rarities.GetTier(rarityId)
	return Rarities.TierOf[rarityId] or 1
end

-- Rarity weights used when an egg does not define its own table.
Rarities.DefaultHatchWeights = {
	Common = 1000,
	Rare = 350,
	Epic = 120,
	Legendary = 35,
	Mythic = 8,
	Secret = 1,
}

return Rarities
