-- EggHeist | Shared/Config/Security.lua
-- Defensive progression. Security slows/detects thieves and protects vault.

local Security = {}

Security.Items = {
	Door = {
		DisplayName = "Security Door",
		Description = "Thieves must channel to breach. Higher tiers take longer.",
		MaxTier = 5,
		Cost = function(tier) return math.floor(1000 * math.pow(3.5, tier - 1)) end,
		RequiredLevel = function(tier) return 3 + (tier - 1) * 3 end,
		-- seconds a thief must channel at the gate (also slows walk)
		BreachTime = function(tier) return 2 + tier * 1.5 end,
	},
	Camera = {
		DisplayName = "Camera Network",
		Description = "Reveals thieves on your minimap... er, overhead. Extends alarm range.",
		MaxTier = 4,
		Cost = function(tier) return math.floor(2500 * math.pow(3.2, tier - 1)) end,
		RequiredLevel = function(tier) return 6 + (tier - 1) * 3 end,
		DetectRadius = function(tier) return 20 + tier * 12 end,
	},
	Laser = {
		DisplayName = "Laser Grid",
		Description = "Lasers damage and slow intruders crossing the vault hall.",
		MaxTier = 4,
		Cost = function(tier) return math.floor(4000 * math.pow(3.6, tier - 1)) end,
		RequiredLevel = function(tier) return 9 + (tier - 1) * 3 end,
		DamagePerSecond = function(tier) return 6 + tier * 4 end,
		SlowFactor = function(tier) return 0.75 - tier * 0.05 end, -- walk mult
	},
	Alarm = {
		DisplayName = "Alarm System",
		Description = "Alerts you instantly and pings thief location periodically.",
		MaxTier = 3,
		Cost = function(tier) return math.floor(6000 * math.pow(4.0, tier - 1)) end,
		RequiredLevel = function(tier) return 12 + (tier - 1) * 4 end,
		PingInterval = function(tier) return 12 - tier * 3 end, -- seconds
	},
	Trap = {
		DisplayName = "Floor Traps",
		Description = "Hidden traps stun thieves for a short time.",
		MaxTier = 4,
		Cost = function(tier) return math.floor(8000 * math.pow(3.4, tier - 1)) end,
		RequiredLevel = function(tier) return 14 + (tier - 1) * 3 end,
		StunDuration = function(tier) return 1.0 + tier * 0.5 end,
		TrapCount = function(tier) return 1 + tier end,
	},
	VaultShield = {
		DisplayName = "Vault Shield",
		Description = "Reduces loot stolen per heist.",
		MaxTier = 5,
		Cost = function(tier) return math.floor(12000 * math.pow(3.8, tier - 1)) end,
		RequiredLevel = function(tier) return 16 + (tier - 1) * 3 end,
		Protection = function(tier) return math.min(0.7, 0.15 * tier) end, -- fraction protected
	},
	Lockdown = {
		DisplayName = "Lockdown Protocol",
		Description = "Unlocks manual lockdown: seals your base for 30s (cooldown 5 min).",
		MaxTier = 1,
		Cost = function(_) return 50000 end,
		RequiredLevel = function(_) return 20 end,
		Duration = 30,
		Cooldown = 300,
	},
	Decoy = {
		DisplayName = "Decoy Eggs",
		Description = "Chance a thief grabs a worthless decoy instead.",
		MaxTier = 3,
		Cost = function(tier) return math.floor(15000 * math.pow(3.0, tier - 1)) end,
		RequiredLevel = function(tier) return 18 + (tier - 1) * 4 end,
		DecoyChance = function(tier) return 0.12 * tier end,
	},
}

Security.ItemOrder = { "Door", "Camera", "Laser", "Alarm", "Trap", "VaultShield", "Lockdown", "Decoy" }

function Security.GetCost(itemId, nextTier)
	local item = Security.Items[itemId]
	if not item then
		return nil
	end
	if nextTier < 1 or nextTier > item.MaxTier then
		return nil
	end
	return item.Cost(nextTier)
end

-- Derived security level (0-100) for matchmaking-ish display + quest checks
function Security.ComputeLevel(securityTable)
	local score = 0
	local maxScore = 0
	for id, item in pairs(Security.Items) do
		local tier = 0
		if securityTable then
			tier = securityTable[id] or 0
		end
		score = score + tier
		maxScore = maxScore + item.MaxTier
	end
	if maxScore == 0 then
		return 0
	end
	return math.floor(score / maxScore * 100)
end

return Security
