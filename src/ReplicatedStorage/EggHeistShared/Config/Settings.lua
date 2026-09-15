-- EggHeist | Shared/Config/Settings.lua
-- Global tunables: world layout intent, heist rules, performance budgets.

local Settings = {}

Settings.GameName = "Egg Heist"
Settings.DataStoreVersion = 1 -- bump to invalidate old saves (use with care)
Settings.AutosaveInterval = 120 -- seconds
Settings.MaxBasePlots = 8

-- Heist rules
Settings.Heist = {
	-- Note: grab channel time comes from the victim's Door tier (Security config).
	GrabCooldown = 8, -- seconds before the same thief can grab again
	CarryWalkMult = 0.7, -- loot slows you down
	MaxCarryTime = 180, -- loot auto-drops after 3 min
	DropOnDeath = true,
	DropOnLeave = true,
	StealCooldownPerVictim = 120, -- same victim can't be hit more often
	OwnerOnlineRequired = false, -- if true, can only steal from owners in-server
	MinThiefLevel = 2,
	ExtractionChannelTime = 3.0,
}

-- Pet following
Settings.Pets = {
	FollowDistance = 6,
	FollowHeight = 3,
	FollowLerp = 6, -- studs/sec smoothing on server
	MaxVisiblePerPlayer = 8,
	HideBeyondDistance = 250, -- perf: don't simulate far pets
}

-- Performance budgets
Settings.Performance = {
	MaxMeteors = 16,
	MaxActiveTrapsPerBase = 8,
	IncomeBatchInterval = 5,
	RemoteRatePerSecond = 12, -- anti-spam default per endpoint
}

-- New-player onboarding
Settings.Tutorial = {
	Enabled = true,
	StarterEgg = "Basic",
	StarterCashBonus = 100,
}

-- Feature flags (kill-switch systems without redeploying code)
Settings.Features = {
	Heists = true,
	Events = true,
	Quests = true,
	DailyRewards = true,
	Prestige = true,
	Trading = false, -- NOT IMPLEMENTED (unsafe to rush). See docs/ROADMAP.md
	PvP = false, -- no direct damage; traps/lasers only slow + chip damage
}

return Settings
