-- EggHeist | Shared/Config/Tutorial.luau
-- Short interactive onboarding. Each step: id, text, target check.
-- Checks are evaluated client-side with server-confirmed events.

local Tutorial = {}

Tutorial.Steps = {
	{
		Id = "welcome",
		Title = "Welcome to Egg Heist!",
		Text = "This plaza is your home base. Let's earn your first fortune.",
		Action = "none",
		Highlight = "Spawn",
	},
	{
		Id = "claim_base",
		Title = "Claim your base",
		Text = "Walk to a glowing empty plot and step on the pad to claim it.",
		Action = "ClaimBase",
		Highlight = "Bases",
	},
	{
		Id = "buy_egg",
		Title = "Buy your first egg",
		Text = "Visit the Egg Market and buy a Basic Egg.",
		Action = "BuyEgg",
		Highlight = "Market",
	},
	{
		Id = "place_egg",
		Title = "Place your egg",
		Text = "Walk to a glowing pad in YOUR base and place the egg. It must incubate before it can hatch!",
		Action = "PlaceEgg",
		Highlight = "Bases",
	},
	{
		Id = "hatch_egg",
		Title = "Hatch it!",
		Text = "Wait for the timer to hit READY, then hold E on your egg to hatch it. Good luck!",
		Action = "HatchEgg",
		Highlight = "Bases",
	},
	{
		Id = "equip_pet",
		Title = "Equip your pal",
		Text = "Equipped pals earn cash for you every few seconds.",
		Action = "EquipPet",
		Highlight = "Backpack",
	},
	{
		Id = "collect_vault",
		Title = "Check your vault",
		Text = "Some earnings flow into your base vault. Collect them!",
		Action = "CollectVault",
		Highlight = "Bases",
	},
	{
		Id = "heist_intro",
		Title = "Feeling sneaky?",
		Text = "Sneak into another player's vault and carry loot to extraction. Or fortify your own base first!",
		Action = "none",
		Highlight = "Heist",
	},
}

return Tutorial
