-- EggHeist | Server/Events/EventService.luau
-- Rotating world events: scheduling, modifiers, meteor spawns, lighting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Events = require(ConfigFolder:WaitForChild("Events"))
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))

local EventService = {}
EventService.Name = "EventService"

local registry = nil
local activeEvent = nil -- { id, def, endsAt }
local lastEnded = {} -- [eventId] = timestamp
local meteorFolder = nil
local rng = Random.new()

function EventService.Init(_, reg)
	registry = reg
end

function EventService.GetActive()
	if activeEvent and os.time() < activeEvent.endsAt then
		return activeEvent
	end
	return nil
end

local function modifiers()
	local active = EventService.GetActive()
	if active and active.def.Modifiers then
		return active.def.Modifiers
	end
	return {}
end

function EventService.GetIncomeMultiplier()
	return modifiers().IncomeMult or 1
end

function EventService.GetHeistPayoutMultiplier()
	return modifiers().HeistPayoutMult or 1
end

function EventService.GetMutationMultipliers()
	return modifiers().MutationChanceMult or {}
end

function EventService.GetSecretLuckMultiplier()
	return modifiers().SecretLuckMult or 1
end

--------------------------------------------------------------------------------
-- Meteor / pickup spawns
--------------------------------------------------------------------------------

local function scatterCenters()
	local centers = {}
	local world = registry.World
	local candidates = {
		world.Find("Map", "Spawn", "PlazaBase"),
		world.Find("Map", "EggMarket", "MarketFloor"),
		world.Find("Map", "HeistArea", "HeistFloor"),
		world.Find("Map", "EventArea", "EventFloor"),
	}
	for _, part in ipairs(candidates) do
		if part and part:IsA("BasePart") then
			centers[#centers + 1] = {
				pos = part.Position + Vector3.new(0, part.Size.Y / 2, 0),
				radius = math.min(part.Size.X, part.Size.Z) / 2 + 10,
			}
		end
	end
	if #centers == 0 then
		centers[1] = { pos = Vector3.new(0, 2, 0), radius = 60 }
	end
	return centers
end

local function spawnPickupEgg(eggId, lifetime)
	if not meteorFolder then
		local gameplay = registry.World.Find("Gameplay")
		if not gameplay then
			return
		end
		meteorFolder = gameplay:FindFirstChild("EventPickups")
		if not meteorFolder then
			meteorFolder = Instance.new("Folder")
			meteorFolder.Name = "EventPickups"
			meteorFolder.Parent = gameplay
		end
	end
	local centers = scatterCenters()
	local spot = centers[rng:NextInteger(1, #centers)]
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(4, spot.radius)
	local position = spot.pos + Vector3.new(math.cos(angle) * dist, 2.5, math.sin(angle) * dist)

	local eggDef = Eggs.ById[eggId]
	local model = registry.World.CloneEggAsset(eggDef and eggDef.AssetModel or "GalaxyEgg")
	model.Name = "EventEgg_" .. eggId
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.CFrame = CFrame.new(position)
		body.Anchored = true
		body.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = (eggDef and eggDef.DisplayName) or eggId
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			if model.Parent then
				if registry.Egg.GiftEgg(player, eggId, "event") then
					registry.Notify.Send(player, "success", "Event egg!",
						"You collected a " .. ((eggDef and eggDef.DisplayName) or eggId) .. "!", 4)
					model:Destroy()
				end
			end
		end)
	end
	-- sky beacon so pickups are findable (dies with the model on collect/despawn)
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(2, 60, 2)
	beacon.CFrame = CFrame.new(position.X, 30, position.Z)
	beacon.Color = Color3.fromRGB(180, 130, 255)
	beacon.Material = Enum.Material.Neon
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Parent = model
	model.Parent = meteorFolder
	-- crash landing fx
	registry.Net.FireAll("Fx", "MeteorLand", position)

	task.delay(lifetime or 120, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

local function clearPickups()
	if meteorFolder then
		pcall(function() meteorFolder:Destroy() end)
		meteorFolder = nil
	end
end

--------------------------------------------------------------------------------
-- Golden Egg Hunt (always-on hide-and-seek minigame)
--------------------------------------------------------------------------------

local huntModel = nil

local function ensurePickupFolder()
	if meteorFolder then
		return meteorFolder
	end
	local gameplay = registry.World.Find("Gameplay")
	if not gameplay then
		return nil
	end
	meteorFolder = gameplay:FindFirstChild("EventPickups")
	if not meteorFolder then
		meteorFolder = Instance.new("Folder")
		meteorFolder.Name = "EventPickups"
		meteorFolder.Parent = gameplay
	end
	return meteorFolder
end

local function spawnHuntEgg()
	if huntModel and huntModel.Parent then
		return huntModel
	end
	local folder = ensurePickupFolder()
	if not folder then
		return nil
	end
	local centers = scatterCenters()
	local spot = centers[rng:NextInteger(1, #centers)]
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(6, spot.radius)
	local position = spot.pos + Vector3.new(math.cos(angle) * dist, 2.5, math.sin(angle) * dist)
	local model = registry.World.CloneEggAsset("GoldenEgg")
	model.Name = "GoldenHuntEgg"
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.CFrame = CFrame.new(position)
		body.Anchored = true
		body.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Claim"
		prompt.ObjectText = "GOLDEN EGG!"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			if model.Parent then
				model:Destroy() -- first claim wins
				local gems = Events.EggHunt.GemReward or 25
				registry.Economy.AddGems(player, gems, "egg_hunt")
				registry.Notify.Send(player, "secret", "GOLDEN EGG!",
					"You found the hidden golden egg! +" .. tostring(gems) .. " gems!", 6)
				registry.Net.FireAll("Feed", { icon = "HUNT",
					text = player.DisplayName .. " found the GOLDEN EGG!" })
				registry.Net.Fire(player, "Fx", "GrabFx")
			end
		end)
	end
	-- gold beacon + sparkle halo so hunters can spot it from afar
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(2, 60, 2)
	beacon.CFrame = CFrame.new(position.X, 30, position.Z)
	beacon.Color = Color3.fromRGB(255, 205, 60)
	beacon.Material = Enum.Material.Neon
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Parent = model
	local halo = Instance.new("ParticleEmitter")
	halo.Color = ColorSequence.new(Color3.fromRGB(255, 215, 100))
	halo.LightEmission = 0.9
	halo.Rate = 8
	halo.Speed = NumberRange.new(2, 5)
	halo.Size = NumberSequence.new(0.8)
	halo.Lifetime = NumberRange.new(1, 2)
	halo.SpreadAngle = Vector2.new(180, 180)
	halo.Parent = model:FindFirstChild("Body") or model
	model.Parent = folder
	huntModel = model
	task.delay(Events.EggHunt.Lifetime or 180, function()
		if model and model.Parent then
			model:Destroy()
		end
		if huntModel == model then
			huntModel = nil
		end
	end)
	return model
end

--- Test backdoor: spawns the golden hunt egg immediately (sim coverage).
function EventService.TestSpawnHuntEgg()
	return spawnHuntEgg()
end

--------------------------------------------------------------------------------
-- Event lifecycle
--------------------------------------------------------------------------------

function EventService.StartEvent(eventId, forced)
	if activeEvent then
		return false
	end
	local def = Events.List[eventId]
	if not def then
		return false
	end
	if not forced then
		local lastEnd = lastEnded[eventId] or 0
		if os.time() - lastEnd < (def.MinCooldown or 0) then
			return false
		end
		if #Players:GetPlayers() < (def.MinPlayers or 1) then
			return false
		end
	end
	activeEvent = { id = eventId, def = def, endsAt = os.time() + def.Duration }
	registry.World.ApplyLighting(def.Lighting)
	registry.Notify.Broadcast("rare", def.DisplayName .. "!",
		def.Description, 8)
	registry.Net.FireAll("EventUpdate", {
		active = true,
		id = eventId,
		displayName = def.DisplayName,
		description = def.Description,
		endsAt = activeEvent.endsAt,
		serverNow = os.time(),
	})
	if registry.Atmosphere then
		registry.Atmosphere.ApplyMood(eventId)
	end
	local stagePos = registry.Atmosphere and registry.Atmosphere.GetAnchor("stage") or nil
	registry.Net.FireAll("Fx", "EventStart", eventId, stagePos)
	registry.Net.FireAll("Fx", "Announce", "event", def.DisplayName .. "!", def.Description)
	if registry.Atmosphere then
		registry.Atmosphere.Celebrate("stage")
	end
	if registry.World.SetEventBoard then
		registry.World.SetEventBoard("LIVE NOW: " .. def.DisplayName)
	end
	registry.Net.FireAll("Feed", { icon = "EVENT", text = def.DisplayName .. " has begun!" })

	if eventId == "MeteorShower" or eventId == "EggRain" then
		local count = math.min(def.MeteorCount or 10, Settings.Performance.MaxMeteors)
		for i = 1, count do
			task.delay((i - 1) * 3, function()
				if EventService.GetActive() then
					spawnPickupEgg(def.MeteorEgg or "Galaxy", def.MeteorLifetime or 120)
				end
			end)
		end
	elseif eventId == "BloodMoon" then
		for i = 1, 6 do
			task.delay((i - 1) * 5, function()
				if EventService.GetActive() then
					spawnPickupEgg("Shadow", 150)
				end
			end)
		end
	elseif eventId == "VoidEvent" then
		for i = 1, 4 do
			task.delay((i - 1) * 8, function()
				if EventService.GetActive() then
					spawnPickupEgg("Void", 150)
				end
			end)
		end
	end

	task.delay(def.Duration, function()
		if activeEvent and activeEvent.id == eventId then
			EventService.EndEvent()
		end
	end)
	print("[EggHeist] Event started: " .. eventId)
	return true
end

function EventService.EndEvent()
	if not activeEvent then
		return
	end
	local def = activeEvent.def
	lastEnded[activeEvent.id] = os.time()
	activeEvent = nil
	clearPickups()
	registry.World.RestoreLighting()
	if registry.Atmosphere then
		registry.Atmosphere.RestoreMood()
	end
	registry.Notify.Broadcast("info", "Event over",
		def.DisplayName .. " has ended.", 5)
	registry.Net.FireAll("EventUpdate", { active = false, serverNow = os.time() })
	if registry.World.SetEventBoard then
		registry.World.SetEventBoard("NEXT EVENT: soon...")
	end
	print("[EggHeist] Event ended: " .. def.DisplayName)
end

local function rollEvent()
	if activeEvent then
		return
	end
	local total = 0
	for _, id in ipairs(Events.Order) do
		local def = Events.List[id]
		local cooled = (os.time() - (lastEnded[id] or 0)) >= (def.MinCooldown or 0)
		local players = #Players:GetPlayers() >= (def.MinPlayers or 1)
		if cooled and players then
			total = total + (def.Weight or 10)
		end
	end
	if total <= 0 then
		return
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, id in ipairs(Events.Order) do
		local def = Events.List[id]
		local cooled = (os.time() - (lastEnded[id] or 0)) >= (def.MinCooldown or 0)
		local players = #Players:GetPlayers() >= (def.MinPlayers or 1)
		if cooled and players then
			acc = acc + (def.Weight or 10)
			if roll <= acc then
				EventService.StartEvent(id, false)
				return
			end
		end
	end
end

function EventService.Start()
	-- push current state to joining players
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, function()
			if player.Parent then
				local active = EventService.GetActive()
				if active then
					registry.Net.Fire(player, "EventUpdate", {
						active = true,
						id = active.id,
						displayName = active.def.DisplayName,
						description = active.def.Description,
						endsAt = active.endsAt,
						serverNow = os.time(),
					})
				else
					registry.Net.Fire(player, "EventUpdate", { active = false, serverNow = os.time() })
				end
			end
		end)
	end)

	task.spawn(function()
		task.wait(Events.EggHunt.FirstDelay or 90)
		while true do
			if Settings.Features.Events and Events.EggHunt.Enabled then
				pcall(spawnHuntEgg)
			end
			task.wait(Events.EggHunt.Interval or 300)
		end
	end)

	task.spawn(function()
		task.wait(60) -- grace period after server start
		while true do
			task.wait(Events.IdleRollInterval)
			if Settings.Features.Events then
				local ok, err = pcall(rollEvent)
				if not ok then
					warn("[EggHeist] Event roll error: " .. tostring(err))
				end
			end
		end
	end)
end

return EventService
