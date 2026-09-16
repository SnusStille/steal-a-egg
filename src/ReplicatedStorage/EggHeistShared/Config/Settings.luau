-- EggHeist | Shared/Config/Settings.luau
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
	TackleHoldDuration = 1,
	TackleDistance = 7,
	-- Loot targets: quick grab (fast, quiet, small) vs full vault (slow, loud, big)
	QuickGrabLootFraction = 0.4, -- of the computed full-vault loot
	QuickGrabBreachMult = 0.5, -- breach channel multiplier for quick grabs
	-- Heist reputation: earned per success, lost per failure (min 0)
	RepPerWin = 2,
	RepPerFail = -1,
	RepTitles = {
		{ Rep = 0, Title = "Pickpocket" },
		{ Rep = 5, Title = "Burglar" },
		{ Rep = 15, Title = "Shadow" },
		{ Rep = 30, Title = "Ghost" },
		{ Rep = 60, Title = "Heist Legend" },
		{ Rep = 100, Title = "Egg Baron" },
		{ Rep = 200, Title = "Vault Reaper" },
		{ Rep = 400, Title = "Living Myth" },
	},
	-- Breach scenarios: rolled per attempt, shown in the channel label.
	-- { Id, Weight, BreachMult, LootMult, SilentAlive (leave owner unpinged) }
	Scenarios = {
		{ Id = "Standard",   Weight = 60, BreachMult = 1.0, LootMult = 1.0 },
		{ Id = "QuickSteal", Weight = 20, BreachMult = 0.7, LootMult = 0.7 },
		{ Id = "VaultRaid",  Weight = 12, BreachMult = 1.5, LootMult = 1.6 },
		{ Id = "GhostRun",   Weight = 8,  BreachMult = 1.2, LootMult = 1.1, SilentBreach = true },
	},
	ScenarioNames = {
		Standard = "Standard breach",
		QuickSteal = "Quick steal! (fast, smaller loot)",
		VaultRaid = "VAULT RAID! (slow, huge loot)",
		GhostRun = "Ghost run! (owner won't be pinged)",
	},
	-- Scouting: intel on enemy bases (range-gated, cooldown-gated)
	ScoutRange = 60,
	ScoutCooldown = 10,
}

-- Safe trading (TradeService). Both sides must meet MinLevel.
Settings.Trading = {
	MinLevel = 5,
	ConfirmDelay = 3, -- review seconds after both sides lock
	RequestExpiry = 30,
	SessionExpiry = 180,
}

-- Auto-hatch: works with the gamepass OR a permanent gems unlock.
Settings.AutoHatch = {
	GemsUnlockCost = 299,
}

-- Pet following
Settings.Pets = {
	FollowDistance = 6,
	FollowHeight = 3,
	FollowLerp = 6, -- studs/sec smoothing on server
	MaxVisiblePerPlayer = 5, -- visual only: 3D followers; every equipped pet still earns
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
	StarterVault = 500, -- one-time vault seeding on first base claim
}

-- Feature flags (kill-switch systems without redeploying code)
Settings.Features = {
	Heists = true,
	Events = true,
	Quests = true,
	DailyRewards = true,
	Prestige = true,
	Trading = true,
	PvP = false, -- no direct damage; traps/lasers only slow + chip damage
}

return Settings
