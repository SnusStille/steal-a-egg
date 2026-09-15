-- EggHeist | Server/Heists/HeistService.luau
-- Risk/reward stealing: breach -> grab -> carry (slowed) -> extract.
-- All state is server-side; the client only renders indicators.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local HeistService = {}
HeistService.Name = "HeistService"

local registry = nil
local carrying = {} -- [thiefUserId] = { amount, victimUserId, plotIndex, expiresAt, model }
local grabCooldownUntil = {} -- [thiefUserId] = timestamp
local victimCooldownUntil = {} -- [victimUserId] = timestamp
local channeling = {} -- [thiefUserId] = { plotIndex, endsAt }
local extracting = {} -- [thiefUserId] = endsAt
local deathConnections = {} -- [thiefUserId] = RBXScriptConnection (death drops loot)

function HeistService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

function HeistService.IsCarrying(player)
	return carrying[player.UserId] ~= nil
end

function HeistService.GetCarrySpeed(player)
	local mult = Settings.Heist.CarryWalkMult
	local profile = profileOf(player)
	if profile and profile.gamepasses and profile.gamepasses.FastHeist then
		mult = mult * 1.15
	end
	if registry.Gadget and registry.Gadget.IsSprintActive(player) then
		mult = mult * registry.Gadget.GetSprintMult()
	end
	if registry.Pet and registry.Pet.GetEquippedBonuses then
		mult = mult + (registry.Pet.GetEquippedBonuses(player).CarrySpeedPct or 0) / 100
	end
	return math.min(1, mult) -- bonuses can erase the slow, never exceed walk speed
end

-- Notoriety title from reputation (shared table, client mirrors this logic)
function HeistService.GetRepTitle(rep)
	local title = "Pickpocket"
	for _, entry in ipairs(Settings.Heist.RepTitles or {}) do
		if (rep or 0) >= (entry.Rep or 0) then
			title = entry.Title
		end
	end
	return title
end

local function addRep(player, delta)
	local profile = profileOf(player)
	if not profile then
		return 0
	end
	profile.stats = profile.stats or {}
	local before = profile.stats.heistRep or 0
	profile.stats.heistRep = math.max(0, before + (delta or 0))
	if registry.Leaderboard and registry.Leaderboard.RefreshTitle then
		registry.Leaderboard.RefreshTitle(player)
	end
	return profile.stats.heistRep, HeistService.GetRepTitle(before)
end

local function setCarrySlow(player, active)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if active then
			humanoid.WalkSpeed = math.floor(16 * HeistService.GetCarrySpeed(player))
		else
			humanoid.WalkSpeed = 16
		end
	end
end

local function attachLootVisual(player)
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not hrp or not head then
		return nil
	end
	local model = registry.World.CloneEggAsset("GoldenEgg")
	model.Name = "CarriedLoot"
	local body = model:FindFirstChild("Body")
	-- strip extras, keep one part
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("PointLight")
			or descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant:Destroy()
		end
	end
	if body and body:IsA("BasePart") then
		body.Anchored = false
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.Massless = true
		body.Size = Vector3.new(1.6, 2, 1.6)
		local mesh = body:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.Scale = Vector3.new(1.6, 2, 1.6)
		end
		body.CFrame = head.CFrame + Vector3.new(0, 2.2, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = body
		weld.Parent = body
		model.Parent = character
		-- marker billboard so everyone sees the thief
		local tag = Instance.new("BillboardGui")
		tag.Name = "LootTag"
		tag.Size = UDim2.new(0, 140, 0, 30)
		tag.StudsOffset = Vector3.new(0, 4, 0)
		tag.AlwaysOnTop = true
		tag.Parent = body
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "STOLEN LOOT!"
		text.TextColor3 = Color3.fromRGB(255, 80, 80)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 16
		text.TextStrokeTransparency = 0.3
		text.Parent = tag
		return model
	end
	model:Destroy()
	return nil
end

local function clearLootVisual(player)
	local character = player.Character
	if character then
		local loot = character:FindFirstChild("CarriedLoot")
		if loot then
			loot:Destroy()
		end
	end
	local state = carrying[player.UserId]
	if state and state.model then
		pcall(function() state.model:Destroy() end)
	end
end

local function disconnectDeathWatch(player)
	local state = carrying[player.UserId]
	local conn = state and state.deathConn
	if state then
		state.deathConn = nil
	end
	if conn then
		pcall(function() conn:Disconnect() end)
	end
end

local function returnLootToVictim(thief, reason)
	local state = carrying[thief.UserId]
	if not state then
		return
	end
	disconnectDeathWatch(thief)
	carrying[thief.UserId] = nil
	setCarrySlow(thief, false)
	clearLootVisual(thief)
	local victim = Players:GetPlayerByUserId(state.victimUserId)
	if victim then
		local victimProfile = profileOf(victim)
		if victimProfile then
			local capacity = registry.Base.GetVaultCapacity(victim)
			victimProfile.base.vault = math.min(capacity,
				(victimProfile.base.vault or 0) + state.amount)
			registry.Data.MarkDirty(victim)
			registry.Notify.Send(victim, "success", "Loot recovered!",
				"The thief " .. tostring(reason or "failed") .. ". Your vault was refunded.", 5)
		end
	end
	local thiefProfile = profileOf(thief)
	if thiefProfile then
		thiefProfile.stats.heistsFailed = (thiefProfile.stats.heistsFailed or 0) + 1
		thiefProfile.stats.heistStreak = 0
		addRep(thief, Settings.Heist.RepPerFail or -1)
		registry.Data.MarkDirty(thief)
	end
	registry.Notify.Send(thief, "warning", "Heist failed",
		"You lost the loot (" .. tostring(reason or "expired") .. ").", 4)
	registry.Net.Fire(thief, "HeistUpdate", { carrying = false })
end

--------------------------------------------------------------------------------
-- Grab flow
--------------------------------------------------------------------------------

local scenarioRng = Random.new()
local scoutCooldownUntil = {} -- [userId] = os.clock

local function rollScenario()
	local scenarios = (Settings.Heist or {}).Scenarios or {}
	local total = 0
	for _, entry in ipairs(scenarios) do
		total = total + (entry.Weight or 0)
	end
	if total <= 0 then
		return { Id = "Standard", BreachMult = 1, LootMult = 1 }
	end
	local roll = scenarioRng:NextNumber(0, total)
	local acc = 0
	for _, entry in ipairs(scenarios) do
		acc = acc + (entry.Weight or 0)
		if roll <= acc then
			return entry
		end
	end
	return scenarios[1]
end

function HeistService.TryGrab(player, plotIndex, target)
	if not Settings.Features.Heists then
		return
	end
	target = Validate.String(target, 8, "vault")
	if target ~= "quick" and target ~= "vault" then
		target = "vault"
	end
	local isQuick = target == "quick"
	if carrying[player.UserId] or channeling[player.UserId] then
		return
	end
	local profile = profileOf(player)
	if not profile then
		return
	end
	if profile.level < Settings.Heist.MinThiefLevel then
		registry.Notify.Send(player, "warning", "Too inexperienced",
			"Reach level " .. tostring(Settings.Heist.MinThiefLevel) .. " to attempt heists.", 4)
		return
	end
	local victim = registry.Base.GetOwnerOfPlot(plotIndex)
	if not victim then
		return
	end
	if victim == player then
		return -- vault prompt already routes owners to collect
	end
	if Settings.Heist.OwnerOnlineRequired and not victim.Parent then
		return
	end
	local now = os.clock()
	if (grabCooldownUntil[player.UserId] or 0) > now then
		return
	end
	if (victimCooldownUntil[victim.UserId] or 0) > now then
		registry.Notify.Send(player, "info", "Recently robbed",
			"This vault was recently hit. Try another base!", 4)
		return
	end
	if registry.Security.IsLockedDown(victim) then
		registry.Notify.Send(player, "warning", "Lockdown!",
			"This base is sealed. Come back later.", 4)
		return
	end
	local anchor = registry.World.GetVaultAnchor(plotIndex)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not anchor or not hrp then
		return
	end
	if (hrp.Position - anchor.Position).Magnitude > 20 then
		return -- too far (exploit / desync guard)
	end
	local victimProfile = profileOf(victim)
	if not victimProfile or (victimProfile.base.vault or 0) < 50 then
		registry.Notify.Send(player, "info", "Vault nearly empty",
			"Nothing worth stealing here... yet.", 3)
		return
	end

	-- gadget modifiers (armed gadgets are consumed as the breach starts)
	local mods = { breachMult = 1, silent = false }
	if registry.Gadget then
		mods = registry.Gadget.ConsumeArmedForBreach(player)
	end
	-- begin breach channel: must stay near the vault
	local scenario = rollScenario()
	local petBonus = { BreachSpeedPct = 0 }
	if registry.Pet and registry.Pet.GetEquippedBonuses then
		petBonus = registry.Pet.GetEquippedBonuses(player)
	end
	local breachTime = registry.Security.GetBreachTime(victim)
		* (isQuick and (Settings.Heist.QuickGrabBreachMult or 0.5) or 1)
		* (mods.breachMult or 1)
		* (scenario.BreachMult or 1)
		* (1 - math.min(0.5, (petBonus.BreachSpeedPct or 0) / 100))
	breachTime = math.max(0.8, breachTime)
	channeling[player.UserId] = {
		plotIndex = plotIndex, endsAt = now + breachTime,
		target = target, scenario = scenario.Id,
	}
	local scenarioName = ((Settings.Heist or {}).ScenarioNames or {})[scenario.Id]
		or "Breaching..."
	local breachLabel = isQuick and "Quick grab..." or scenarioName
	registry.Notify.Send(player, "info", breachLabel,
		"Stay by the vault for " .. string.format("%.1f", breachTime) .. "s!", 4)
	registry.Net.Fire(player, "HeistUpdate", {
		channeling = true, duration = breachTime, target = target, scenario = scenario.Id,
	})
	local silent = mods.silent or scenario.SilentBreach == true
	if not isQuick and not silent then
		registry.Security.AlertOwner(victim, player, "is breaching your vault!")
	elseif silent then
		registry.Notify.Send(player, "info", "Silent breach",
			"Nobody heard that... until the grab.", 3)
	end

	task.delay(breachTime, function()
		local state = channeling[player.UserId]
		if not state or state.plotIndex ~= plotIndex then
			return
		end
		channeling[player.UserId] = nil
		registry.Net.Fire(player, "HeistUpdate", { channeling = false })
		-- re-validate everything (player may have moved/died/left)
		if not player.Parent or carrying[player.UserId] then
			return
		end
		local char2 = player.Character
		local hrp2 = char2 and char2:FindFirstChild("HumanoidRootPart")
		local anchor2 = registry.World.GetVaultAnchor(plotIndex)
		local victim2 = registry.Base.GetOwnerOfPlot(plotIndex)
		if not hrp2 or not anchor2 or not victim2 then
			return
		end
		if (hrp2.Position - anchor2.Position).Magnitude > 20 then
			registry.Notify.Send(player, "warning", "Breach failed", "You moved away from the vault!", 3)
			return
		end
		if registry.Security.IsLockedDown(victim2) then
			registry.Notify.Send(player, "warning", "Lockdown!", "Sealed mid-breach!", 3)
			return
		end
		HeistService.CompleteGrab(player, victim2, plotIndex, state.target, state.scenario)
	end)
end

function HeistService.CompleteGrab(thief, victim, plotIndex, target, scenarioId)
	local victimProfile = profileOf(victim)
	local thiefProfile = profileOf(thief)
	if not victimProfile or not thiefProfile then
		return
	end
	grabCooldownUntil[thief.UserId] = os.clock() + Settings.Heist.GrabCooldown
	victimCooldownUntil[victim.UserId] = os.clock() + Settings.Heist.StealCooldownPerVictim

	-- decoy check: thief wastes the run on a fake egg
	if registry.Security.RollDecoy(victim) then
		registry.Notify.Send(thief, "warning", "It's a decoy!",
			"You grabbed a worthless fake egg!", 5)
		registry.Notify.Send(victim, "success", "Decoy worked!",
			thief.DisplayName .. " stole a fake egg!", 5)
		registry.Net.Fire(thief, "Fx", "DecoyGrab")
		return
	end

	local vault = victimProfile.base.vault or 0
	local protection = registry.Security.GetProtection(victim)
	local payoutMult = 1
	if registry.Event then
		payoutMult = registry.Event.GetHeistPayoutMultiplier()
	end
	local scenarioLootMult = 1
	for _, entry in ipairs((Settings.Heist or {}).Scenarios or {}) do
		if entry.Id == scenarioId then
			scenarioLootMult = entry.LootMult or 1
			break
		end
	end
	local petPayoutPct = 0
	if registry.Pet and registry.Pet.GetEquippedBonuses then
		petPayoutPct = registry.Pet.GetEquippedBonuses(thief).HeistPayoutPct or 0
	end
	local drillMult = 1
	if registry.Gadget and registry.Gadget.ConsumeLootBonus then
		drillMult = registry.Gadget.ConsumeLootBonus(thief) or 1
	end
	local loot = math.floor(vault * Economy.HeistStealFraction * (1 - protection)
		* payoutMult * scenarioLootMult * (1 + petPayoutPct / 100) * drillMult)
	if drillMult > 1 then
		registry.Notify.Send(thief, "info", "Vault Drill!",
			"Drill bonus: +" .. tostring(math.floor((drillMult - 1) * 100)) .. "% loot!", 4)
	end
	if target == "quick" then
		loot = math.floor(loot * (Settings.Heist.QuickGrabLootFraction or 0.4))
	end
	loot = math.max(0, loot)
	if loot < 10 then
		registry.Notify.Send(thief, "info", "Vault nearly empty", "Nothing worth carrying.", 3)
		return
	end
	-- deduct now (server-authoritative, no duplication possible)
	local deducted = math.floor(vault * Economy.HeistStealFraction * (1 - protection)
		* scenarioLootMult)
	if target == "quick" then
		deducted = math.floor(deducted * (Settings.Heist.QuickGrabLootFraction or 0.4))
	end
	victimProfile.base.vault = vault - deducted
	victimProfile.stats.timesRobbed = (victimProfile.stats.timesRobbed or 0) + 1
	registry.Data.MarkDirty(victim)

	carrying[thief.UserId] = {
		amount = loot,
		victimUserId = victim.UserId,
		plotIndex = plotIndex,
		expiresAt = os.clock() + Settings.Heist.MaxCarryTime,
		model = attachLootVisual(thief),
	}
	setCarrySlow(thief, true)
	registry.Notify.Send(thief, "success", "Loot grabbed!",
		"Carry it to EXTRACTION before time runs out!", 6)
	registry.Notify.Send(victim, "error", "You've been robbed!",
		thief.DisplayName .. " grabbed loot! Stop them before extraction!", 6)
	registry.Net.Fire(victim, "Fx", "HeistAlarm", thief.DisplayName)
	registry.Net.Fire(thief, "Fx", "GrabFx")
	registry.Net.Fire(thief, "HeistUpdate", {
		carrying = true,
		amount = loot,
		target = target,
		timeLeft = Settings.Heist.MaxCarryTime,
	})
	-- death drops loot
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local carryState = carrying[thief.UserId]
		if carryState then
			carryState.deathConn = humanoid.Died:Connect(function()
				if carrying[thief.UserId] then
					returnLootToVictim(thief, "died")
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Extraction flow
--------------------------------------------------------------------------------

local function updateMostWanted()
	if not registry.World.SetMostWanted then
		return
	end
	local bestName, bestWins = nil, 0
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = registry.Data.GetProfile(player)
		local wins = profile and (profile.stats.heistsWon or 0) or 0
		if wins > bestWins then
			bestWins = wins
			bestName = player.DisplayName
		end
	end
	if bestName then
		registry.World.SetMostWanted("MOST WANTED: " .. bestName .. " (" .. tostring(bestWins) .. " heists)")
	else
		registry.World.SetMostWanted("MOST WANTED: none yet")
	end
end

local function completeExtraction(thief)
	local state = carrying[thief.UserId]
	if not state then
		return
	end
	disconnectDeathWatch(thief)
	carrying[thief.UserId] = nil
	setCarrySlow(thief, false)
	clearLootVisual(thief)
	registry.Economy.AddCash(thief, state.amount, "heist")
	registry.Economy.AddXp(thief, Economy.XpPerHeistSuccess)
	local thiefProfile = profileOf(thief)
	if thiefProfile then
		thiefProfile.stats.heistsWon = (thiefProfile.stats.heistsWon or 0) + 1
		-- streak bonus: +5% per consecutive win, capped at +25%
		local streak = (thiefProfile.stats.heistStreak or 0) + 1
		thiefProfile.stats.heistStreak = streak
		local bonusPct = math.min(streak * 5, 25)
		if bonusPct > 0 and state.amount > 0 then
			local bonus = math.floor(state.amount * bonusPct / 100)
			if bonus > 0 then
				registry.Economy.AddCash(thief, bonus, "heist_streak")
				registry.Notify.Send(thief, "info", "Streak x" .. tostring(streak) .. "!",
					"Streak bonus: +$" .. tostring(bonus) .. " (" .. tostring(bonusPct) .. "%)", 5)
			end
		end
		registry.Data.MarkDirty(thief)
	end
	registry.Quest.AddProgress(thief, "CompleteHeists", 1)
	local newRep, oldTitle = addRep(thief, Settings.Heist.RepPerWin or 2)
	local newTitle = HeistService.GetRepTitle(newRep)
	registry.Notify.Send(thief, "success", "Heist complete!",
		"You extracted loot successfully!", 6)
	if newTitle ~= oldTitle then
		registry.Notify.Send(thief, "secret", "Notoriety up!",
			"You are now known as: " .. newTitle .. "!", 6)
	end
	if registry.Achievement then
		registry.Achievement.Check(thief, "HeistWin")
	end
	registry.Net.Fire(thief, "HeistUpdate", { carrying = false, extracted = true })
	registry.Net.Fire(thief, "Fx", "HeistWin", state.amount)
	if registry.World and registry.World.GetExtractionPad then
		local pad = registry.World.GetExtractionPad()
		if pad then
			registry.Net.Fire(thief, "Fx", "Shockwave", pad.Position)
		end
	end
	local feedVictim = Players:GetPlayerByUserId(state.victimUserId)
	registry.Net.FireAll("Feed", { icon = "HEIST",
		text = thief.DisplayName .. " robbed " .. (feedVictim and feedVictim.DisplayName or "a vault")
			.. " for $" .. tostring(state.amount) })
	if state.amount >= 25000 then
		registry.Notify.Broadcast("rare", "Big heist!",
			thief.DisplayName .. " extracted a massive haul!", 6)
		registry.Net.FireAll("Fx", "Announce", "heist", "BIG HEIST!",
			thief.DisplayName .. " extracted a massive haul!")
	end
	local victim = Players:GetPlayerByUserId(state.victimUserId)
	if victim then
		registry.Notify.Send(victim, "error", "Loot extracted",
			thief.DisplayName .. " got away with your loot!", 6)
		registry.Net.Fire(victim, "Fx", "Robbed", thief.DisplayName)
	end
	updateMostWanted()
end

local function extractionLoop()
	while true do
		task.wait(0.5)
		local pad = registry.World.GetExtractionPad()
		if pad then
			local center = pad.Position
			-- two-phase: decide first, mutate after (never mutate during pairs)
			local toExpire = {}
			local toExtract = {}
			for userId, state in pairs(carrying) do
				local thief = Players:GetPlayerByUserId(userId)
				if thief and thief.Parent then
					if os.clock() > state.expiresAt then
						toExpire[#toExpire + 1] = thief
					else
						local character = thief.Character
						local hrp = character and character:FindFirstChild("HumanoidRootPart")
						if hrp and (hrp.Position - center).Magnitude < 12 then
							local endsAt = extracting[userId]
							if not endsAt then
								extracting[userId] = os.clock() + Settings.Heist.ExtractionChannelTime
								registry.Notify.Send(thief, "info", "Extracting...",
									"Stay in the zone!", 3)
							elseif os.clock() >= endsAt then
								extracting[userId] = nil
								toExtract[#toExtract + 1] = thief
							end
						else
							extracting[userId] = nil
						end
					end
				end
			end
			for _, thief in ipairs(toExpire) do
				if carrying[thief.UserId] then
					returnLootToVictim(thief, "ran out of time")
				end
			end
			for _, thief in ipairs(toExtract) do
				if carrying[thief.UserId] then
					completeExtraction(thief)
				end
			end
		end
	end
end

-- Tactical drop: loot returns to the victim. Kinder than failing (no fail
-- stat, no rep loss) but the run is over and cooldowns were already spent.
function HeistService.AbandonCarry(player)
	local state = carrying[player.UserId]
	if not state then
		return false
	end
	disconnectDeathWatch(player)
	carrying[player.UserId] = nil
	extracting[player.UserId] = nil
	setCarrySlow(player, false)
	clearLootVisual(player)
	local victim = Players:GetPlayerByUserId(state.victimUserId)
	if victim then
		local victimProfile = profileOf(victim)
		if victimProfile then
			local capacity = registry.Base.GetVaultCapacity(victim)
			victimProfile.base.vault = math.min(capacity,
				(victimProfile.base.vault or 0) + state.amount)
			registry.Data.MarkDirty(victim)
			registry.Notify.Send(victim, "info", "Loot dropped",
				"The thief abandoned your loot. Vault refunded.", 4)
		end
	end
	local abandonProfile = profileOf(player)
	if abandonProfile then
		abandonProfile.stats.heistStreak = 0
		registry.Data.MarkDirty(player)
	end
	registry.Notify.Send(player, "info", "Loot abandoned",
		"You dropped the loot and slipped away.", 4)
	registry.Net.Fire(player, "HeistUpdate", { carrying = false })
	return true
end

-- Scouting: range- + cooldown-gated intel on an enemy base. Vault is
-- reported as a BAND (no exact numbers), security as totals.
function HeistService.ScoutBase(player, plotIndex)
	if not Settings.Features.Heists then
		return
	end
	plotIndex = math.floor(tonumber(plotIndex) or 0)
	if plotIndex < 1 or plotIndex > Settings.MaxBasePlots then
		return
	end
	local owner = registry.Base.GetOwnerOfPlot(plotIndex)
	if not owner or owner == player then
		return
	end
	local now = os.clock()
	if (scoutCooldownUntil[player.UserId] or 0) > now then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local plot = registry.World.GetPlotModel(plotIndex)
	local foundation = plot and plot:FindFirstChild("Foundation")
	if not hrp or not foundation or not foundation:IsA("BasePart") then
		return
	end
	if (hrp.Position - foundation.Position).Magnitude > (Settings.Heist.ScoutRange or 60) then
		registry.Notify.Send(player, "warning", "Too far",
			"Get closer to scout this base.", 3)
		return
	end
	scoutCooldownUntil[player.UserId] = now + (Settings.Heist.ScoutCooldown or 10)
	local victimProfile = profileOf(owner)
	local vault = victimProfile and (victimProfile.base.vault or 0) or 0
	local band = "Nearly empty"
	if vault >= 200000 then
		band = "Overflowing"
	elseif vault >= 50000 then
		band = "Loaded"
	elseif vault >= 10000 then
		band = "Stocked"
	elseif vault >= 1000 then
		band = "Light"
	end
	local security = victimProfile and victimProfile.base.security or {}
	local total, door = 0, 0
	for itemId, tier in pairs(security) do
		total = total + (tonumber(tier) or 0)
		if itemId == "Door" then
			door = tonumber(tier) or 0
		end
	end
	registry.Net.Fire(player, "ScoutResult", {
		plotIndex = plotIndex,
		owner = owner.DisplayName,
		ownerLevel = victimProfile and (victimProfile.level or 1) or 1,
		vaultBand = band,
		securityTiers = total,
		doorTier = door,
		hasAlarm = (security.Alarm or 0) > 0,
		hasCamera = (security.Camera or 0) > 0,
		lockdown = registry.Security.IsLockedDown(owner),
	})
	if registry.Achievement then
		registry.Achievement.Check(player, "Scout")
	end
end

function HeistService.HandlePlayerLeaving(player)
	channeling[player.UserId] = nil
	extracting[player.UserId] = nil
	if carrying[player.UserId] then
		returnLootToVictim(player, "left")
	end
end

function HeistService.Start()
	registry.Net.OnRequest("GrabLoot", function(player, target)
		-- client hint only; server finds nearest foreign vault
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local best, bestDist = nil, 20
		for i = 1, Settings.MaxBasePlots do
			local owner = registry.Base.GetOwnerOfPlot(i)
			if owner and owner ~= player then
				local anchor = registry.World.GetVaultAnchor(i)
				if anchor and (hrp.Position - anchor.Position).Magnitude < bestDist then
					best = i
					bestDist = (hrp.Position - anchor.Position).Magnitude
				end
			end
		end
		if best then
			HeistService.TryGrab(player, best, target)
		end
	end)

	registry.Net.OnRequest("AbandonLoot", function(player)
		HeistService.AbandonCarry(player)
	end)

	registry.Net.OnRequest("ScoutBase", function(player, plotIndex)
		HeistService.ScoutBase(player, plotIndex)
	end)

	task.spawn(extractionLoop)
end

return HeistService
