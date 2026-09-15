-- EggHeist | Shared/Config/Shop.luau
-- Monetization catalog. Replace placeholder asset IDs with real ones from
-- Creator Dashboard > Monetization before publishing (see docs/MONETIZATION.md).

local Shop = {}

-- Gamepasses (one-time). ProductId = gamepass ID from dashboard.
Shop.Gamepasses = {
	VIP = {
		DisplayName = "VIP",
		Description = "+25% income, golden nametag, exclusive aura.",
		ProductId = 0, -- TODO: replace with real gamepass id
		PriceRobux = 499,
		IncomeMult = 1.25,
	},
	ExtraSlots = {
		DisplayName = "Extra Pet Slots",
		Description = "+2 equipped pet slots forever.",
		ProductId = 0,
		PriceRobux = 299,
		BonusSlots = 2,
	},
	AutoHatch = {
		DisplayName = "Auto Hatchery",
		Description = "Automatically hatches eggs you buy. Toggleable.",
		ProductId = 0,
		PriceRobux = 399,
	},
	FastHeist = {
		DisplayName = "Swift Shadow",
		Description = "Move 15% faster while carrying loot.",
		ProductId = 0,
		PriceRobux = 249,
		CarrySpeedMult = 1.15,
	},
}

-- Developer products (repeat purchase). ProductId = developer product id.
Shop.Products = {
	Gems100 = {
		DisplayName = "100 Gems",
		ProductId = 0,
		PriceRobux = 99,
		Grants = { Gems = 100 },
	},
	Gems550 = {
		DisplayName = "550 Gems",
		ProductId = 0,
		PriceRobux = 449,
		Grants = { Gems = 550 },
	},
	Cash50k = {
		DisplayName = "$50,000 Cash",
		ProductId = 0,
		PriceRobux = 99,
		Grants = { Cash = 50000 },
	},
	Income2x15m = {
		DisplayName = "2x Income (15 min)",
		ProductId = 0,
		PriceRobux = 79,
		Grants = { Boost = { Id = "Income2x", Duration = 900, IncomeMult = 2.0 } },
	},
	Luck2x15m = {
		DisplayName = "2x Luck (15 min)",
		ProductId = 0,
		PriceRobux = 129,
		Grants = { Boost = { Id = "Luck2x", Duration = 900, LuckMult = 2.0 } },
	},
}

-- In-game decoration shop (cash/gems, no Robux)
Shop.Decorations = {
	{ Id = "Torch",       DisplayName = "Torch",       Price = 500,   Currency = "Cash" },
	{ Id = "BannerBlue",  DisplayName = "Blue Banner", Price = 1500,  Currency = "Cash" },
	{ Id = "Fountain",    DisplayName = "Egg Fountain",Price = 50,    Currency = "Gems" },
	{ Id = "StatueGold",  DisplayName = "Gold Statue", Price = 150,   Currency = "Gems" },
	{ Id = "EggTotem",    DisplayName = "Egg Totem",   Price = 8000,  Currency = "Cash" },
	{ Id = "CrystalSpire", DisplayName = "Crystal Spire", Price = 120, Currency = "Gems" },
}

-- Temporary boosts catalog (also grantable via daily rewards/events)
Shop.Boosts = {
	Income2x = { DisplayName = "2x Income", IncomeMult = 2.0 },
	Luck2x = { DisplayName = "2x Luck", LuckMult = 2.0 },
}

return Shop
