-- EggHeist | Shared/Config/Mutations.luau
-- Mutation rolls apply on hatch. Multipliers stack with pet level scaling.

local Mutations = {}

Mutations.List = {
	{ Id = "Golden",  DisplayName = "Golden",  Chance = 0.0400, IncomeMult = 2.0,  SellMult = 2.0,  Color = Color3.fromRGB(255, 200, 60),  Particle = "Sparkles",  MinEggTier = 1 },
	{ Id = "Crystal", DisplayName = "Crystal", Chance = 0.0200, IncomeMult = 3.0,  SellMult = 3.0,  Color = Color3.fromRGB(150, 220, 255), Particle = "Sparkles",  MinEggTier = 1 },
	{ Id = "Neon",    DisplayName = "Neon",    Chance = 0.0120, IncomeMult = 4.5,  SellMult = 4.0,  Color = Color3.fromRGB(80, 255, 170),  Particle = "Glow",      MinEggTier = 2 },
	{ Id = "Toxic",   DisplayName = "Toxic",   Chance = 0.0080, IncomeMult = 6.0,  SellMult = 5.0,  Color = Color3.fromRGB(120, 255, 60),  Particle = "Slime",     MinEggTier = 2 },
	{ Id = "Shadow",  DisplayName = "Shadow",  Chance = 0.0050, IncomeMult = 8.0,  SellMult = 7.0,  Color = Color3.fromRGB(90, 60, 160),   Particle = "Smoke",     MinEggTier = 3 },
	{ Id = "Galaxy",  DisplayName = "Galaxy",  Chance = 0.0025, IncomeMult = 12.0, SellMult = 10.0, Color = Color3.fromRGB(150, 80, 255),  Particle = "Stars",     MinEggTier = 4 },
	{ Id = "Ancient", DisplayName = "Ancient", Chance = 0.0012, IncomeMult = 18.0, SellMult = 15.0, Color = Color3.fromRGB(210, 170, 110), Particle = "Runes",     MinEggTier = 5 },
	{ Id = "Void",    DisplayName = "Void",    Chance = 0.0005, IncomeMult = 30.0, SellMult = 25.0, Color = Color3.fromRGB(20, 10, 40),    Particle = "VoidSwirl", MinEggTier = 6 },
	{ Id = "Celestial", DisplayName = "Celestial", Chance = 0.0008, IncomeMult = 24.0, SellMult = 20.0, Color = Color3.fromRGB(200, 240, 255), Particle = "Stars", MinEggTier = 5 },
}

Mutations.ById = {}
for _, def in ipairs(Mutations.List) do
	Mutations.ById[def.Id] = def
end

function Mutations.IsValid(mutationId)
	return mutationId == nil or Mutations.ById[mutationId] ~= nil
end

function Mutations.GetColor(mutationId)
	local def = Mutations.ById[mutationId]
	if def then
		return def.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

return Mutations
