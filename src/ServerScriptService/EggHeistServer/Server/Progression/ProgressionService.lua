-- EggHeist | Server/Progression/ProgressionService.lua
-- Long-term progression: prestige/rebirth ranks.
-- Prestige resets currencies, eggs, upgrades and security but keeps the plot,
-- collection, stats and a few best pets, granting a permanent income bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Types = require(Shared:WaitForChild("Types"))

local ProgressionService = {}
ProgressionService.Name = "ProgressionService"

local registry = nil

function ProgressionService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

function ProgressionService.CanPrestige(player)
	local p = profileOf(player)
	if not p then
		return false, "No profile"
	end
	if Settings.Features.Prestige == false then
		return false, "Prestige is disabled"
	end
	if not p.prestige then
		return false, "Prestige disabled"
	end
	if (p.prestige.count or 0) >= Economy.PrestigeMaxStacks then
		return false, "Max prestige reached"
	end
	if p.level < Economy.PrestigeMinLevel then
		return false, "Requires level " .. tostring(Economy.PrestigeMinLevel)
	end
	if p.cash < Economy.PrestigeCashCost then
		return false, "Requires " .. tostring(Economy.PrestigeCashCost) .. " cash"
	end
	return true, "OK"
end

function ProgressionService.DoPrestige(player)
	local can, reason = ProgressionService.CanPrestige(player)
	if not can then
		registry.Notify.Send(player, "warning", "Can't prestige", reason, 4)
		return false
	end
	local p = profileOf(player)
	if not p then
		return false
	end
	-- keep N best pets by income, convert the rest to gems
	table.sort(p.pets, function(a, b)
		return registry.Pet.PetIncomePerSecond(a) > registry.Pet.PetIncomePerSecond(b)
	end)
	local kept = {}
	local sellValue = 0
	for i, pet in ipairs(p.pets) do
		if i <= Economy.PrestigeKeepPets then
			kept[#kept + 1] = pet
		else
			sellValue = sellValue + registry.Pet.GetSellValue(pet)
		end
	end
	p.pets = kept
	-- rebuild equipped from kept pets only
	local keptUids = {}
	for _, pet in ipairs(kept) do
		keptUids[pet.uid] = true
	end
	local equipped = {}
	for _, uid in ipairs(p.equipped) do
		if keptUids[uid] then
			equipped[#equipped + 1] = uid
		end
	end
	p.equipped = equipped
	local gemBonus = math.min(Economy.PrestigeGemBonusCap, math.floor(sellValue / Economy.PrestigeGemBonusDivisor))
	p.gems = math.min(Economy.MaxGems, p.gems + gemBonus)
	-- reset progression (plot, collection, stats kept).
	-- NOTE: defaults come from DataService so new tracks/items never desync.
	p.cash = Economy.StartingCash
	p.xp = 0
	p.level = 1
	p.eggs = {}
	p.base.upgrades = registry.Data.GetDefaultUpgrades()
	p.base.security = registry.Data.GetDefaultSecurity()
	p.base.vault = 0
	p.base.lockdownUntil = 0
	p.base.lockdownCooldownUntil = 0
	p.prestige.count = (p.prestige.count or 0) + 1
	p.prestige.bonus = (p.prestige.bonus or 0) + Economy.PrestigeIncomeBonus
	-- prestige gift
	p.eggs[#p.eggs + 1] = Types.NewEggRecord(registry.Data.GenerateUid(player), Economy.PrestigeGiftEgg)
	registry.Pet.RebuildFollowers(player)
	local plotIndex = registry.Base.GetPlotOf(player)
	if plotIndex and plotIndex > 0 then
		registry.Security.RebuildPlotSecurity(plotIndex)
	end
	registry.Data.MarkDirty(player)
	registry.Notify.Broadcast("secret", "PRESTIGE!",
		player.DisplayName .. " prestiged to rank " .. tostring(p.prestige.count)
			.. " (+" .. tostring(math.floor(p.prestige.bonus * 100)) .. "% income)!", 8)
	if registry.Achievement then
		registry.Achievement.Check(player, "Prestige")
	end
	return true
end

function ProgressionService.Start()
	registry.Net.OnRequest("Prestige", function(player)
		ProgressionService.DoPrestige(player)
	end)
end

return ProgressionService
