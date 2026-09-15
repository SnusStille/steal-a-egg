-- EggHeist | Shared/Config/Gadgets.lua
-- Heist gadgets: consumable tools that create real tactical choices.
-- Bought with cash in the shop, earned from achievements/dailies.
--
-- Behaviors (implemented in Heists/GadgetService.lua):
--   Lockpick: armed; next breach channel is BreachMult x as long.
--   Smoke:    armed; next breach does NOT alert the owner until the grab.
--   EMP:      instant; disables the nearest enemy base's lasers+traps for
--             DisableSeconds (must be near an enemy base to use).
--   Sprint:   instant; SprintMult move speed for SprintSeconds (stacks with
--             carry slow, capped at normal walk speed).

local Gadgets = {}

Gadgets.List = {
	{
		Id = "Lockpick",
		DisplayName = "Lockpick Set",
		Description = "Next breach takes half as long. Used when a breach starts.",
		Price = 1500,
		MaxHeld = 5,
		Kind = "Armed",
		BreachMult = 0.5,
		ArmExpirySeconds = 120,
	},
	{
		Id = "Smoke",
		DisplayName = "Smoke Capsule",
		Description = "Next breach stays silent until the grab. Used when a breach starts.",
		Price = 2500,
		MaxHeld = 5,
		Kind = "Armed",
		ArmExpirySeconds = 120,
	},
	{
		Id = "EMP",
		DisplayName = "EMP Charge",
		Description = "Fries the nearest enemy base's lasers and traps for 30s.",
		Price = 5000,
		MaxHeld = 3,
		Kind = "Instant",
		DisableSeconds = 30,
		UseRange = 60,
	},
	{
		Id = "Sprint",
		DisplayName = "Swift Boots",
		Description = "+30% move speed for 60s. Perfect for getaways.",
		Price = 3000,
		MaxHeld = 3,
		Kind = "Instant",
		SprintMult = 1.3,
		SprintSeconds = 60,
	},
}

Gadgets.ById = {}
Gadgets.Order = {}
for _, def in ipairs(Gadgets.List) do
	Gadgets.ById[def.Id] = def
	Gadgets.Order[#Gadgets.Order + 1] = def.Id
end

function Gadgets.IsValid(gadgetId)
	return Gadgets.ById[gadgetId] ~= nil
end

return Gadgets
