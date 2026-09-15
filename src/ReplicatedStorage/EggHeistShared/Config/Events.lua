-- EggHeist | Shared/Config/Events.lua
-- Rotating world events. Server schedules; client renders announcements + skybox/fx.

local Events = {}

Events.List = {
	GoldenHour = {
		DisplayName = "Golden Hour",
		Description = "Golden mutations are 3x more likely. +50% income!",
		Color = Color3.fromRGB(255, 200, 80),
		Duration = 300, -- 5 min
		MinCooldown = 1800, -- 30 min
		Weight = 40, -- selection weight
		MinPlayers = 1,
		Modifiers = {
			MutationChanceMult = { Golden = 3.0 },
			IncomeMult = 1.5,
		},
		Lighting = { ClockTime = 17.5, Brightness = 2.5, Ambient = Color3.fromRGB(140, 110, 80) },
	},
	MeteorShower = {
		DisplayName = "Meteor Shower",
		Description = "Galaxy eggs crash around the map. Grab them before they despawn!",
		Color = Color3.fromRGB(150, 120, 255),
		Duration = 240,
		MinCooldown = 2700,
		Weight = 25,
		MinPlayers = 2,
		Modifiers = {
			IncomeMult = 1.25,
		},
		MeteorCount = 12,
		MeteorEgg = "Galaxy",
		MeteorLifetime = 120,
		Lighting = { ClockTime = 0.0, Brightness = 1.6, Ambient = Color3.fromRGB(60, 50, 100) },
	},
	BloodMoon = {
		DisplayName = "Blood Moon",
		Description = "Heists pay double. Security is half as sleepy. Shadow eggs appear!",
		Color = Color3.fromRGB(200, 30, 40),
		Duration = 300,
		MinCooldown = 3600,
		Weight = 20,
		MinPlayers = 2,
		Modifiers = {
			HeistPayoutMult = 2.0,
			IncomeMult = 2.0,
			MutationChanceMult = { Shadow = 4.0 },
		},
		Lighting = { ClockTime = 0.0, Brightness = 1.2, Ambient = Color3.fromRGB(120, 20, 30) },
	},
	VoidEvent = {
		DisplayName = "Void Rift",
		Description = "The void opens. Void mutations possible. Triple income!",
		Color = Color3.fromRGB(40, 20, 80),
		Duration = 180,
		MinCooldown = 5400,
		Weight = 10,
		MinPlayers = 3,
		Modifiers = {
			IncomeMult = 3.0,
			MutationChanceMult = { Void = 6.0, Galaxy = 3.0 },
			SecretLuckMult = 2.0,
		},
		Lighting = { ClockTime = 0.0, Brightness = 1.0, Ambient = Color3.fromRGB(30, 10, 60) },
	},
}

Events.Order = { "GoldenHour", "MeteorShower", "BloodMoon", "VoidEvent" }

-- Time between event rolls when no event is active
Events.IdleRollInterval = 120

return Events
