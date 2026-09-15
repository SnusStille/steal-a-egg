-- EggHeist | Server/Services/HeistService.lua
-- Risk/reward stealing: breach -> grab -> carry (slowed) -> extract.
-- All state is server-side; the client only renders indicators.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))

local HeistService = {}
HeistService.Name = "HeistService"

local registry = nil
local carrying = {} -- [thiefUserId] = { amount, victimUserId, plotIndex, expiresAt, model }
local grabCooldownUntil = {} -- [thiefUserId] = timestamp
local victimCooldownUntil = {} -- [victimUserId] = timestamp
local channeling = {} -- [thiefUserId] = { plotIndex, endsAt }
local extracting = {} -- [thiefUserId] = endsAt

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
	return mult
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

local function returnLootToVictim(thief, reason)
	local state = carrying[thief.UserId]
	if not state then
		return
	end
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
		registry.Data.MarkDirty(thief)
	end
	registry.Notify.Send(thief, "warning", "Heist failed",
		"You lost the loot (" .. tostring(reason or "expired") .. ").", 4)
	registry.Net.Fire(thief, "HeistUpdate", { carrying = false })
end

--------------------------------------------------------------------------------
-- Grab flow
--------------------------------------------------------------------------------

function HeistService.TryGrab(player, plotIndex)
	if not Settings.Features.Heists then
		return
	end
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

	-- begin breach channel: must stay near the vault
	local breachTime = registry.Security.GetBreachTime(victim)
	channeling[player.UserId] = { plotIndex = plotIndex, endsAt = now + breachTime }
	registry.Notify.Send(player, "info", "Breaching...",
		"Stay by the vault for " .. string.format("%.1f", breachTime) .. "s!", 4)
	registry.Net.Fire(player, "HeistUpdate", { channeling = true, duration = breachTime })
	registry.Security.AlertOwner(victim, player, "is breaching your vault!")

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
		HeistService.CompleteGrab(player, victim2, plotIndex)
	end)
end

function HeistService.CompleteGrab(thief, victim, plotIndex)
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
	local loot = math.floor(vault * Economy.HeistStealFraction * (1 - protection) * payoutMult)
	loot = math.max(0, loot)
	if loot < 10 then
		registry.Notify.Send(thief, "info", "Vault nearly empty", "Nothing worth carrying.", 3)
		return
	end
	-- deduct now (server-authoritative, no duplication possible)
	victimProfile.base.vault = vault - math.floor(vault * Economy.HeistStealFraction * (1 - protection))
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
	registry.Net.Fire(thief, "HeistUpdate", {
		carrying = true,
		amount = loot,
		timeLeft = Settings.Heist.MaxCarryTime,
	})
	-- death drops loot
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if carrying[thief.UserId] then
				returnLootToVictim(thief, "died")
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Extraction flow
--------------------------------------------------------------------------------

local function completeExtraction(thief)
	local state = carrying[thief.UserId]
	if not state then
		return
	end
	carrying[thief.UserId] = nil
	setCarrySlow(thief, false)
	clearLootVisual(thief)
	registry.Economy.AddCash(thief, state.amount, "heist")
	registry.Economy.AddXp(thief, Economy.XpPerHeistSuccess)
	local thiefProfile = profileOf(thief)
	if thiefProfile then
		thiefProfile.stats.heistsWon = (thiefProfile.stats.heistsWon or 0) + 1
		registry.Data.MarkDirty(thief)
	end
	registry.Quest.AddProgress(thief, "CompleteHeists", 1)
	registry.Notify.Send(thief, "success", "Heist complete!",
		"You extracted loot successfully!", 6)
	registry.Net.Fire(thief, "HeistUpdate", { carrying = false, extracted = true })
	registry.Net.Fire(thief, "Fx", "HeistWin", state.amount)
	if state.amount >= 25000 then
		registry.Notify.Broadcast("rare", "Big heist!",
			thief.DisplayName .. " extracted a massive haul!", 6)
	end
	local victim = Players:GetPlayerByUserId(state.victimUserId)
	if victim then
		registry.Notify.Send(victim, "error", "Loot extracted",
			thief.DisplayName .. " got away with your loot!", 6)
	end
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

function HeistService.HandlePlayerLeaving(player)
	channeling[player.UserId] = nil
	extracting[player.UserId] = nil
	if carrying[player.UserId] then
		returnLootToVictim(player, "left")
	end
end

function HeistService.Start()
	registry.Net.OnRequest("GrabLoot", function(player)
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
			HeistService.TryGrab(player, best)
		end
	end)

	task.spawn(extractionLoop)
end

return HeistService
