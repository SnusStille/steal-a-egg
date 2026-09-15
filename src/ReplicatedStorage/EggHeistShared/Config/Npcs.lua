-- EggHeist | Shared/Config/Npcs.lua
-- Lightweight world NPCs: greeting + shortcut into the right UI.
-- Server builds them (World/NpcService), client wires prompts (NpcController).
--
-- Anchor: {path...} inside workspace.EggHeist; the NPC stands on that part.
-- Fallback: world position used when the anchor part is missing.
-- Action: { Ui = "<UI module>", Tab = "<optional tab>" } opened on talk.

local Npcs = {}

Npcs.List = {
	{
		Id = "Merchant",
		DisplayName = "Egg Merchant",
		Title = "Sells fine eggs",
		Color = { 255, 200, 80 },
		Greetings = {
			"Fresh eggs, friend! Every legend starts with one.",
			"Psst... the Crystal Egg is worth every coin.",
			"Hatch more, earn more. That's the whole economy!",
		},
		Action = { Ui = "ShopUI", Tab = "Eggs" },
		Anchor = { "Map", "EggMarket", "MarketFloor" },
		Offset = { 0, 0, 10 },
		Fallback = { 90, 4, 14 },
	},
	{
		Id = "Guard",
		DisplayName = "Security Specialist",
		Title = "Base defense expert",
		Color = { 90, 140, 255 },
		Greetings = {
			"Thieves hate this one trick: LOCKDOWN.",
			"Lasers first, questions later. That's my motto.",
			"A vault without a shield is just a donation box.",
		},
		Action = { Ui = "BaseUI", Tab = "Security" },
		Anchor = { "Map", "HeistArea", "HeistFloor" },
		Offset = { -14, 0, -14 },
		Fallback = { -14, 4, 106 },
	},
	{
		Id = "Scout",
		DisplayName = "Quest Scout",
		Title = "Always hiring",
		Color = { 140, 255, 160 },
		Greetings = {
			"Quests pay well. Dailies reset every day!",
			"Achievements are permanent glory. Chase them all.",
			"Come back tomorrow — the scout always has work.",
		},
		Action = { Ui = "QuestsUI" },
		Anchor = { "Map", "EventArea", "EventFloor" },
		Offset = { 0, 0, 12 },
		Fallback = { -90, 4, 14 },
	},
	{
		Id = "Fence",
		DisplayName = "Shady Fence",
		Title = "No questions asked",
		Color = { 200, 80, 80 },
		Greetings = {
			"Gadgets make getaways. Just saying.",
			"Quick grabs are quiet. Full vaults are... profitable.",
			"If the alarm screams, you were never here.",
		},
		Action = { Ui = "ShopUI", Tab = "Gadgets" },
		Anchor = { "Map", "HeistArea", "HeistFloor" },
		Offset = { 14, 0, -14 },
		Fallback = { 14, 4, 106 },
	},
}

Npcs.ById = {}
for _, def in ipairs(Npcs.List) do
	Npcs.ById[def.Id] = def
end

return Npcs
