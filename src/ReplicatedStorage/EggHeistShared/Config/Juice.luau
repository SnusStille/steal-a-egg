-- EggHeist | Shared/Config/Juice.luau
-- DATA for game feel: announcement banner styles, per-tier hatch FX,
-- world mood presets (fog/atmosphere/post) per event, fireworks.
-- Pure data, no logic. Client + AtmosphereService read this.

local Juice = {}

-- Announcement banner styles: Announce(styleId, title, sub, duration?)
Juice.Announce = {
	info = {
		Color = Color3.fromRGB(120, 180, 255),
		Sound = "Notify",
		Duration = 4,
	},
	event = {
		Color = Color3.fromRGB(255, 200, 80),
		Sound = "Rare",
		Duration = 6,
	},
	rare = {
		Color = Color3.fromRGB(255, 176, 32),
		Sound = "Rare",
		Duration = 6,
	},
	secret = {
		Color = Color3.fromRGB(60, 255, 210),
		Sound = "Achievement",
		Duration = 7,
	},
	heist = {
		Color = Color3.fromRGB(255, 90, 90),
		Sound = "HeistAlert",
		Duration = 6,
	},
	prestige = {
		Color = Color3.fromRGB(190, 130, 255),
		Sound = "Achievement",
		Duration = 7,
	},
	danger = {
		Color = Color3.fromRGB(220, 40, 40),
		Sound = "Alarm",
		Duration = 5,
	},
}

-- Hatch FX per rarity tier (1 Common .. 6 Secret). Colors default to the
-- rarity color; only overrides live here.
Juice.HatchFx = {
	[1] = { Confetti = 10, Shake = 0, Fov = 0, Fanfare = false, Sound = "Hatch" },
	[2] = { Confetti = 18, Shake = 0, Fov = 0, Fanfare = false, Sound = "Hatch" },
	[3] = { Confetti = 30, Shake = 0.25, Fov = 2, Fanfare = false, Sound = "Hatch" },
	[4] = { Confetti = 55, Shake = 0.4, Fov = 4, Fanfare = true, Sound = "Rare" },
	[5] = { Confetti = 80, Shake = 0.6, Fov = 6, Fanfare = true, Sound = "Rare" },
	[6] = { Confetti = 120, Shake = 0.9, Fov = 9, Fanfare = true, Sound = "Achievement" },
}

-- World moods. Applied by AtmosphereService on top of the event's base
-- Lighting preset (ClockTime/Brightness/Ambient still come from Events).
-- Every field is optional; missing fields keep their current value.
Juice.Moods = {
	Default = {
		FogColor = Color3.fromRGB(190, 200, 215),
		FogStart = 120,
		FogEnd = 900,
		Atmosphere = { Density = 0.28, Haze = 3, Glare = 0.4,
			Color = Color3.fromRGB(200, 215, 230), Decay = Color3.fromRGB(120, 140, 160) },
		Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.2 },
		SunRays = { Intensity = 0.06, Spread = 0.7 },
		ColorCorrection = { Saturation = 0.08, Contrast = 0.04,
			TintColor = Color3.fromRGB(255, 250, 242) },
	},
	GoldenHour = {
		FogColor = Color3.fromRGB(255, 205, 140),
		FogStart = 100,
		FogEnd = 700,
		Atmosphere = { Density = 0.32, Haze = 6, Glare = 0.9,
			Color = Color3.fromRGB(255, 200, 130), Decay = Color3.fromRGB(200, 120, 60) },
		Bloom = { Intensity = 0.7, Size = 32, Threshold = 1.0 },
		SunRays = { Intensity = 0.25, Spread = 0.8 },
		ColorCorrection = { Saturation = 0.22, Contrast = 0.06,
			TintColor = Color3.fromRGB(255, 225, 180) },
	},
	EggRain = {
		FogColor = Color3.fromRGB(150, 220, 140),
		FogStart = 80,
		FogEnd = 500,
		Atmosphere = { Density = 0.42, Haze = 7, Glare = 0.3,
			Color = Color3.fromRGB(170, 240, 150), Decay = Color3.fromRGB(70, 140, 70) },
		Bloom = { Intensity = 0.5, Size = 28, Threshold = 1.0 },
		SunRays = { Intensity = 0.04, Spread = 0.6 },
		ColorCorrection = { Saturation = 0.25, Contrast = 0.05,
			TintColor = Color3.fromRGB(220, 255, 215) },
	},
	MeteorShower = {
		FogColor = Color3.fromRGB(60, 50, 110),
		FogStart = 90,
		FogEnd = 600,
		Atmosphere = { Density = 0.35, Haze = 4, Glare = 0.7,
			Color = Color3.fromRGB(150, 120, 255), Decay = Color3.fromRGB(60, 40, 120) },
		Bloom = { Intensity = 0.9, Size = 40, Threshold = 0.85 },
		SunRays = { Intensity = 0.02, Spread = 0.5 },
		ColorCorrection = { Saturation = 0.3, Contrast = 0.12,
			TintColor = Color3.fromRGB(200, 180, 255) },
	},
	BloodMoon = {
		FogColor = Color3.fromRGB(140, 30, 35),
		FogStart = 70,
		FogEnd = 450,
		Atmosphere = { Density = 0.45, Haze = 8, Glare = 0.5,
			Color = Color3.fromRGB(255, 90, 80), Decay = Color3.fromRGB(140, 20, 30) },
		Bloom = { Intensity = 0.8, Size = 36, Threshold = 0.9 },
		SunRays = { Intensity = 0.03, Spread = 0.6 },
		ColorCorrection = { Saturation = 0.28, Contrast = 0.15,
			TintColor = Color3.fromRGB(255, 170, 170) },
	},
	HeistNight = {
		FogColor = Color3.fromRGB(30, 35, 80),
		FogStart = 80,
		FogEnd = 550,
		Atmosphere = { Density = 0.38, Haze = 5, Glare = 0.4,
			Color = Color3.fromRGB(90, 110, 220), Decay = Color3.fromRGB(25, 30, 80) },
		Bloom = { Intensity = 0.65, Size = 32, Threshold = 0.9 },
		SunRays = { Intensity = 0.02, Spread = 0.5 },
		ColorCorrection = { Saturation = 0.18, Contrast = 0.12,
			TintColor = Color3.fromRGB(180, 195, 255) },
	},
	LuckyDay = {
		FogColor = Color3.fromRGB(210, 235, 200),
		FogStart = 140,
		FogEnd = 1000,
		Atmosphere = { Density = 0.22, Haze = 2, Glare = 0.6,
			Color = Color3.fromRGB(220, 255, 215), Decay = Color3.fromRGB(130, 180, 130) },
		Bloom = { Intensity = 0.55, Size = 30, Threshold = 1.0 },
		SunRays = { Intensity = 0.15, Spread = 0.8 },
		ColorCorrection = { Saturation = 0.3, Contrast = 0.02,
			TintColor = Color3.fromRGB(240, 255, 235) },
	},
	VoidEvent = {
		FogColor = Color3.fromRGB(20, 10, 40),
		FogStart = 50,
		FogEnd = 380,
		Atmosphere = { Density = 0.5, Haze = 9, Glare = 0.9,
			Color = Color3.fromRGB(120, 60, 220), Decay = Color3.fromRGB(15, 5, 35) },
		Bloom = { Intensity = 1.1, Size = 48, Threshold = 0.8 },
		SunRays = { Intensity = 0.01, Spread = 0.4 },
		ColorCorrection = { Saturation = 0.35, Contrast = 0.2,
			TintColor = Color3.fromRGB(190, 150, 255) },
	},
}

-- Fireworks: color palette + pacing (seconds between volleys).
Juice.Fireworks = {
	Palette = {
		Color3.fromRGB(255, 200, 80),
		Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(140, 255, 160),
		Color3.fromRGB(190, 130, 255),
	},
	IdleEvery = 90, -- ambient celebration over the plaza when calm
	EventEvery = 30, -- volleys over the stage while an event is live
}

return Juice
