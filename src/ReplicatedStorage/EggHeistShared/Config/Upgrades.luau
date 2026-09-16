-- EggHeist | Shared/Config/Upgrades.luau
-- Base upgrade tracks. Each track has tiers; cost grows per tier.

local Upgrades = {}

Upgrades.Tracks = {
	Income = {
		DisplayName = "Income Core",
		Description = "+15% pet income per tier.",
		Icon = "rbxassetid://0",
		MaxTier = 10,
		Cost = function(tier) return math.floor(500 * math.pow(3.2, tier - 1)) end,
		RequiredLevel = function(tier) return 1 + (tier - 1) * 2 end,
		Effect = function(tier) return 1 + 0.15 * tier end,
	},
	EggSlots = {
		DisplayName = "Egg Atrium",
		Description = "Display more eggs. +2 pet storage per tier.",
		MaxTier = 8,
		Cost = function(tier) return math.floor(800 * math.pow(3.0, tier - 1)) end,
		RequiredLevel = function(tier) return 2 + (tier - 1) * 2 end,
		Effect = function(tier) return tier * 2 end, -- bonus storage
	},
	Hatchery = {
		DisplayName = "Hatchery",
		Description = "Luckier hatches. +4% rare+ odds per tier.",
		MaxTier = 8,
		Cost = function(tier) return math.floor(1500 * math.pow(3.4, tier - 1)) end,
		RequiredLevel = function(tier) return 4 + (tier - 1) * 2 end,
		Effect = function(tier) return 0.04 * tier end,
	},
	Vault = {
		DisplayName = "Vault Expansion",
		Description = "Doubles vault capacity each tier.",
		MaxTier = 6,
		Cost = function(tier) return math.floor(2000 * math.pow(4.0, tier - 1)) end,
		RequiredLevel = function(tier) return 5 + (tier - 1) * 3 end,
		Effect = function(tier) return math.pow(2, tier) end, -- capacity mult
	},
	Comfort = {
		DisplayName = "Pet Comfort",
		Description = "Pets earn XP 20% faster per tier.",
		MaxTier = 5,
		Cost = function(tier) return math.floor(3000 * math.pow(3.5, tier - 1)) end,
		RequiredLevel = function(tier) return 8 + (tier - 1) * 3 end,
		Effect = function(tier) return 1 + 0.20 * tier end,
	},
}

Upgrades.TrackOrder = { "Income", "EggSlots", "Hatchery", "Vault", "Comfort" }

function Upgrades.GetCost(trackId, nextTier)
	local track = Upgrades.Tracks[trackId]
	if not track then
		return nil
	end
	if nextTier < 1 or nextTier > track.MaxTier then
		return nil
	end
	return track.Cost(nextTier)
end

return Upgrades
