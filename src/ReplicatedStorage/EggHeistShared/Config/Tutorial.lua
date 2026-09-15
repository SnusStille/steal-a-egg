-- EggHeist | Shared/Config/Tutorial.lua
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
		Text = "Walk to an glowing empty plot and step on the pad to claim it.",
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
		Id = "hatch_egg",
		Title = "Hatch it!",
		Text = "Open your backpack and hatch the egg. Good luck!",
		Action = "HatchEgg",
		Highlight = "Backpack",
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
