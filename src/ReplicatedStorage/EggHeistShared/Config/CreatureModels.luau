-- EggHeist | Shared/Config/CreatureModels.luau
-- Maps every pet to a procedural creature archetype built by
-- Shared/Utilities/ModelFactory. Body color comes from Pets.BodyColor
-- (brick name); this file only picks shape + accent + scale.
--
-- Fields: A = archetype, S = scale (default 1), Acc = accent {r,g,b},
-- Heads/Tentacles/Stem = archetype params.

local CreatureModels = {}

CreatureModels.Map = {
	-- Common
	chick = { A = "chick" },
	sprout = { A = "blob", Stem = true },
	pebble = { A = "rock" },
	bunny = { A = "bunny" },
	mossy = { A = "blob" },
	-- Rare
	ember = { A = "drake", S = 0.85 },
	splash = { A = "fish" },
	rocky = { A = "rock", S = 1.25 },
	zippy = { A = "bird" },
	gloom = { A = "shroom" },
	frostmite = { A = "blob", S = 0.8 },
	coral = { A = "pup" },
	-- Epic
	aurum = { A = "drake" },
	frost = { A = "pup", Ears = "pointy" },
	magma = { A = "rock", Acc = { 255, 120, 30 } },
	vined = { A = "serpent" },
	jolt = { A = "bot" },
	glacier = { A = "blob", S = 1.4 },
	temprocs = { A = "bird", S = 1.45 },
	monarch = { A = "moth" },
	-- Legendary
	phoenix = { A = "bird", Acc = { 255, 140, 40 } },
	leviathan = { A = "whale", S = 0.8 },
	golem = { A = "golem" },
	sultan = { A = "pup", Ears = "crown" },
	wisp = { A = "ghost" },
	blizzard = { A = "serpent", S = 1.3 },
	kraken = { A = "kraken" },
	-- Mythic
	hydra = { A = "drake", Heads = 3 },
	umbra = { A = "pup", Ears = "pointy" },
	nebula = { A = "whale" },
	titan = { A = "bot", S = 1.5 },
	cyclone = { A = "serpent", S = 1.4 },
	seraph = { A = "bird", S = 1.3 },
	-- Secret
	voidlord = { A = "golem", Acc = { 150, 80, 255 } },
	starchild = { A = "ghost", Acc = { 255, 240, 180 } },
	nullking = { A = "golem", S = 1.4 },
	aurora = { A = "golem", Acc = { 150, 230, 255 } },
}

function CreatureModels.Get(petId)
	return CreatureModels.Map[petId]
end

return CreatureModels
