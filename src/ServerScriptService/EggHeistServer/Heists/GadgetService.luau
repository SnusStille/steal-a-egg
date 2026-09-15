-- EggHeist | Server/Heists/GadgetService.luau
-- Heist gadgets: purchase, arming, and effect queries.
-- Definitions live in Shared/Config/Gadgets.luau (data-driven).
--
-- Armed gadgets (Lockpick/Smoke) are consumed when a breach STARTS, so a
-- wasted activation is impossible. Instant gadgets (EMP/Sprint) apply now.
-- State: profile.gadgets[gadgetId] = count owned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Gadgets = require(ConfigFolder:WaitForChild("Gadgets"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local GadgetService = {}
GadgetService.Name = "GadgetService"

local registry = nil
local armed = {} -- [userId] = { lockpickUntil, smokeUntil } (os.clock timestamps)
local sprintUntil = {} -- [userId] = os.clock timestamp

function GadgetService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

local function countOf(profile, gadgetId)
	if not profile.gadgets then
		return 0
	end
	return profile.gadgets[gadgetId] or 0
end

-- Internal grant (rewards, admin). Bypasses MaxHeld purchase cap.
function GadgetService.GrantGadget(player, gadgetId, count)
	if not Gadgets.IsValid(gadgetId) then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	profile.gadgets = profile.gadgets or {}
	profile.gadgets[gadgetId] = math.min(99,
		countOf(profile, gadgetId) + math.max(1, math.floor(count or 1)))
	registry.Data.MarkDirty(player)
	return true
end

local function consume(profile, gadgetId)
	local have = countOf(profile, gadgetId)
	if have <= 0 then
		return false
	end
	profile.gadgets[gadgetId] = have - 1
	if profile.gadgets[gadgetId] <= 0 then
		profile.gadgets[gadgetId] = nil
	end
	return true
end

function GadgetService.BuyGadget(player, gadgetId)
	gadgetId = Validate.String(gadgetId, 32, nil)
	local def = gadgetId and Gadgets.ById[gadgetId] or nil
	if not def then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	if countOf(profile, gadgetId) >= def.MaxHeld then
		registry.Notify.Send(player, "info", "Max held",
			"You can't carry more " .. def.DisplayName .. ".", 3)
		return false
	end
	if not registry.Economy.SpendCash(player, def.Price) then
		registry.Notify.Send(player, "warning", "Not enough cash",
			def.DisplayName .. " costs " .. tostring(def.Price) .. ".", 4)
		return false
	end
	profile.gadgets = profile.gadgets or {}
	profile.gadgets[gadgetId] = countOf(profile, gadgetId) + 1
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success", "Gadget purchased!",
		def.DisplayName .. " ready. Use it from the Shop!", 4)
	return true
end

function GadgetService.UseGadget(player, gadgetId)
	gadgetId = Validate.String(gadgetId, 32, nil)
	local def = gadgetId and Gadgets.ById[gadgetId] or nil
	if not def then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	if countOf(profile, gadgetId) <= 0 then
		registry.Notify.Send(player, "warning", "None left",
			"You don't own a " .. def.DisplayName .. ".", 3)
		return false
	end
	local now = os.clock()

	if def.Kind == "Armed" then
		local state = armed[player.UserId] or {}
		armed[player.UserId] = state
		if gadgetId == "Lockpick" then
			if (state.lockpickUntil or 0) > now then
				registry.Notify.Send(player, "info", "Already armed",
					"Lockpick is already armed for your next breach.", 3)
				return false
			end
			state.lockpickUntil = now + (def.ArmExpirySeconds or 120)
			registry.Notify.Send(player, "success", "Lockpick armed!",
				"Your next breach will be twice as fast.", 4)
		elseif gadgetId == "Smoke" then
			if (state.smokeUntil or 0) > now then
				registry.Notify.Send(player, "info", "Already armed",
					"Smoke is already armed for your next breach.", 3)
				return false
			end
			state.smokeUntil = now + (def.ArmExpirySeconds or 120)
			registry.Notify.Send(player, "success", "Smoke armed!",
				"Your next breach starts silent.", 4)
		elseif gadgetId == "Drill" then
			if (state.drillUntil or 0) > now then
				registry.Notify.Send(player, "info", "Already armed",
					"Drill is already armed for your next grab.", 3)
				return false
			end
			state.drillUntil = now + (def.ArmExpirySeconds or 120)
			registry.Notify.Send(player, "success", "Drill armed!",
				"Your next grab steals 25% more loot.", 4)
		else
			return false
		end
		profile.stats.gadgetsUsed = (profile.stats.gadgetsUsed or 0) + 1
		registry.Data.MarkDirty(player)
		return true
	end

	-- Instant gadgets consume immediately
	if gadgetId == "Sprint" then
		if not consume(profile, gadgetId) then
			return false
		end
		sprintUntil[player.UserId] = now + (def.SprintSeconds or 60)
		profile.stats.gadgetsUsed = (profile.stats.gadgetsUsed or 0) + 1
		registry.Data.MarkDirty(player)
		registry.Notify.Send(player, "success", "Swift boots!",
			"Move faster for " .. tostring(def.SprintSeconds or 60) .. "s!", 4)
		registry.Net.Fire(player, "Fx", "Gadget", gadgetId)
		return true
	elseif gadgetId == "EMP" then
		-- must be near an enemy-owned plot
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return false
		end
		local best, bestDist = nil, def.UseRange or 60
		for i = 1, Settings.MaxBasePlots do
			local owner = registry.Base.GetOwnerOfPlot(i)
			if owner and owner ~= player then
				local plot = registry.World.GetPlotModel(i)
				local foundation = plot and plot:FindFirstChild("Foundation")
				if foundation and foundation:IsA("BasePart") then
					local dist = (hrp.Position - foundation.Position).Magnitude
					if dist < bestDist then
						best, bestDist = i, dist
					end
				end
			end
		end
		if not best then
			registry.Notify.Send(player, "warning", "No target",
				"Get closer to an enemy base first!", 3)
			return false
		end
		if not consume(profile, gadgetId) then
			return false
		end
		registry.Security.SetEmpDisabled(best, def.DisableSeconds or 30)
		profile.stats.gadgetsUsed = (profile.stats.gadgetsUsed or 0) + 1
		registry.Data.MarkDirty(player)
		registry.Notify.Send(player, "success", "EMP blast!",
			"Enemy lasers and traps fried for " .. tostring(def.DisableSeconds or 30) .. "s!", 5)
		registry.Net.Fire(player, "Fx", "Gadget", gadgetId)
		local victim = registry.Base.GetOwnerOfPlot(best)
		if victim then
			registry.Notify.Send(victim, "warning", "Security fault!",
				"Your lasers and traps just went offline!", 4)
		end
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Queries used by HeistService / SecurityService
--------------------------------------------------------------------------------

-- Called when a breach starts. Consumes armed gadgets, returns modifiers.
function GadgetService.ConsumeArmedForBreach(player)
	local profile = profileOf(player)
	local mods = { breachMult = 1, silent = false }
	if not profile then
		return mods
	end
	local state = armed[player.UserId]
	if not state then
		return mods
	end
	local now = os.clock()
	if (state.lockpickUntil or 0) > now then
		state.lockpickUntil = nil
		if consume(profile, "Lockpick") then
			mods.breachMult = Gadgets.ById.Lockpick.BreachMult or 0.5
			registry.Data.MarkDirty(player)
		end
	end
	if (state.smokeUntil or 0) > now then
		state.smokeUntil = nil
		if consume(profile, "Smoke") then
			mods.silent = true
			registry.Data.MarkDirty(player)
		end
	end
	return mods
end

-- Consumed on successful grab only (a failed run keeps the drill armed).
function GadgetService.ConsumeLootBonus(player)
	local state = armed[player and player.UserId]
	if state and (state.drillUntil or 0) > os.clock() then
		state.drillUntil = nil
		local profile = profileOf(player)
		if profile and consume(profile, "Drill") then
			registry.Data.MarkDirty(player)
			return (Gadgets.ById.Drill and Gadgets.ById.Drill.LootMult) or 1.25
		end
	end
	return 1
end

function GadgetService.IsSprintActive(player)
	return (sprintUntil[player.UserId] or 0) > os.clock()
end

function GadgetService.GetSprintMult()
	return Gadgets.ById.Sprint.SprintMult or 1.3
end

function GadgetService.HandlePlayerLeaving(player)
	armed[player.UserId] = nil
	sprintUntil[player.UserId] = nil
end

function GadgetService.Start()
	registry.Net.OnRequest("BuyGadget", function(player, gadgetId)
		GadgetService.BuyGadget(player, gadgetId)
	end)
	registry.Net.OnRequest("UseGadget", function(player, gadgetId)
		GadgetService.UseGadget(player, gadgetId)
	end)
	Players.PlayerRemoving:Connect(function(player)
		GadgetService.HandlePlayerLeaving(player)
	end)
end

return GadgetService
