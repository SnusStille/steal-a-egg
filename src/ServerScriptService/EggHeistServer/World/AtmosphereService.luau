-- EggHeist | Server/World/AtmosphereService.luau
-- MAP UPGRADE: builds animated dressing on top of whatever world exists
-- (real EggHeist model or fallback) at runtime. Never touches the world
-- model itself. Owns: lighting rig (atmosphere/bloom/sunrays/color),
-- per-event sky moods, beacon towers, floating islands, spawn statue,
-- heist alert props, event stage rig, volcano landmark, drifting clouds,
-- and ambient firework celebrations.
--
-- Sim-safe rules (this runs in sim_boot): no CFrame.Angles, no UDim2 math,
-- every loop waits FIRST, particle Emit wrapped in pcall.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Juice = require(Shared:WaitForChild("Config"):WaitForChild("Juice"))

local AtmosphereService = {}
AtmosphereService.Name = "AtmosphereService"

local registry = nil
local decorFolder = nil
local anchors = {} -- name -> Vector3 (statue, stage, plaza, event, heist)
local islands = {} -- { root, baseY, phase, speed }
local pulseBeams = {} -- { part, base, phase, speed }
local clouds = {} -- { part, base, axis, range, speed, phase }
local built = false

-- Fallback district centers (match the fallback map layout)
local FALLBACK_POS = {
	plaza = Vector3.new(0, 2, 0),
	market = Vector3.new(90, 2, 0),
	heist = Vector3.new(0, 2, 120),
	event = Vector3.new(-90, 2, 0),
	bases = Vector3.new(0, 2, -90),
}

--------------------------------------------------------------------------------
-- Small builders
--------------------------------------------------------------------------------

local function mkPart(name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color or Color3.fromRGB(150, 150, 150)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = decorFolder
	return part
end

local function mkLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 30
	light.Brightness = brightness or 2
	light.Shadows = false
	light.Parent = parent
	return light
end

local function mkSparkles(parent, color, rate, speed, size, lifetime)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Rate = rate or 6
	emitter.Speed = NumberRange.new((speed or 6) * 0.5, speed or 6)
	emitter.Size = NumberSequence.new(size or 0.7)
	emitter.Lifetime = NumberRange.new((lifetime or 1.5) * 0.6, lifetime or 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
	return emitter
end

local function mkBillboard(parent, text, textColor, size, studsOffset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.new(0, 220, 0, 60)
	gui.StudsOffset = studsOffset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return gui
end

local function districtPosition(areaName, floorName, fallback)
	if registry and registry.World and registry.World.Find then
		local ok, part = pcall(function()
			return registry.World.Find("Map", areaName, floorName)
		end)
		if ok and part and part:IsA("BasePart") then
			return part.Position + Vector3.new(0, part.Size.Y / 2, 0)
		end
	end
	return fallback
end

--------------------------------------------------------------------------------
-- Lighting rig + moods
--------------------------------------------------------------------------------

local function ensureLightingRig()
	local function ensure(className, name)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	ensure("Atmosphere", "EggHeistAtmosphere")
	ensure("BloomEffect", "EggHeistBloom")
	ensure("SunRaysEffect", "EggHeistSunRays")
	ensure("ColorCorrectionEffect", "EggHeistColor")
end

local function applyMoodTable(mood)
	if not mood then
		return
	end
	pcall(function()
		if mood.FogColor then
			Lighting.FogColor = mood.FogColor
		end
		if mood.FogStart then
			Lighting.FogStart = mood.FogStart
		end
		if mood.FogEnd then
			Lighting.FogEnd = mood.FogEnd
		end
		local atmo = Lighting:FindFirstChild("EggHeistAtmosphere")
		if atmo and mood.Atmosphere then
			local a = mood.Atmosphere
			if a.Density then atmo.Density = a.Density end
			if a.Haze then atmo.Haze = a.Haze end
			if a.Glare then atmo.Glare = a.Glare end
			if a.Color then atmo.Color = a.Color end
			if a.Decay then atmo.Decay = a.Decay end
		end
		local bloom = Lighting:FindFirstChild("EggHeistBloom")
		if bloom and mood.Bloom then
			if mood.Bloom.Intensity then bloom.Intensity = mood.Bloom.Intensity end
			if mood.Bloom.Size then bloom.Size = mood.Bloom.Size end
			if mood.Bloom.Threshold then bloom.Threshold = mood.Bloom.Threshold end
		end
		local rays = Lighting:FindFirstChild("EggHeistSunRays")
		if rays and mood.SunRays then
			if mood.SunRays.Intensity then rays.Intensity = mood.SunRays.Intensity end
			if mood.SunRays.Spread then rays.Spread = mood.SunRays.Spread end
		end
		local cc = Lighting:FindFirstChild("EggHeistColor")
		if cc and mood.ColorCorrection then
			local c = mood.ColorCorrection
			if c.Saturation then cc.Saturation = c.Saturation end
			if c.Contrast then cc.Contrast = c.Contrast end
			if c.TintColor then cc.TintColor = c.TintColor end
		end
	end)
end

--- Full-sky mood for an event id (falls back to Default when unknown).
function AtmosphereService.ApplyMood(eventId)
	applyMoodTable(Juice.Moods[eventId] or Juice.Moods.Default)
end

function AtmosphereService.RestoreMood()
	applyMoodTable(Juice.Moods.Default)
end

--- Named world anchor for FX positions (statue/stage/plaza/heist/event).
function AtmosphereService.GetAnchor(name)
	return anchors[name]
end

--- Fire a firework volley over an anchor for every client.
function AtmosphereService.Celebrate(anchorName)
	local pos = anchors[anchorName or "plaza"]
	if not pos or not registry or not registry.Net then
		return
	end
	registry.Net.FireAll("Fx", "Fireworks", pos)
end

--------------------------------------------------------------------------------
-- Dressing builders (each pcall-guarded so one failure never kills boot)
--------------------------------------------------------------------------------

local function buildBeacons()
	-- Four corner towers with sky beams; positions adapt to the real map
	-- bounds when boundary walls exist, else the fallback footprint.
	local hx, hz = 165, 165
	if registry and registry.World and registry.World.Find then
		local n = registry.World.Find("Decorations", "BoundaryN")
		local e = registry.World.Find("Decorations", "BoundaryE")
		if n and n:IsA("BasePart") then
			hz = math.abs(n.Position.Z) - 15
		end
		if e and e:IsA("BasePart") then
			hx = math.abs(e.Position.X) - 15
		end
	end
	local corners = {
		Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz),
		Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz),
	}
	local colors = {
		Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(255, 120, 180), Color3.fromRGB(140, 255, 160),
	}
	for i, corner in ipairs(corners) do
		local color = colors[i]
		mkPart("BeaconBase" .. i, Vector3.new(6, 4, 6),
			Vector3.new(corner.X, 2, corner.Z), Color3.fromRGB(45, 48, 62))
		local beam = mkPart("BeaconBeam" .. i, Vector3.new(2.5, 160, 2.5),
			Vector3.new(corner.X, 82, corner.Z), color, Enum.Material.Neon)
		beam.Transparency = 0.45
		local gem = mkPart("BeaconGem" .. i, Vector3.new(4, 4, 4),
			Vector3.new(corner.X, 8, corner.Z), color, Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
		mkLight(gem, color, 45, 2)
		pulseBeams[#pulseBeams + 1] = { part = beam, base = 0.45, phase = i * 1.7, speed = 1.4 }
		pulseBeams[#pulseBeams + 1] = { part = gem, base = 0, phase = i * 1.7, speed = 1.4 }
	end
end

local function buildSkyIslands()
	local spots = {
		{ x = -50, y = 55, z = -40 }, { x = 55, y = 65, z = -30 },
		{ x = 0, y = 72, z = 60 }, { x = -70, y = 60, z = 70 }, { x = 75, y = 58, z = 75 },
	}
	local eggColors = {
		Color3.fromRGB(255, 200, 60), Color3.fromRGB(150, 220, 255),
		Color3.fromRGB(255, 100, 40), Color3.fromRGB(150, 80, 255),
		Color3.fromRGB(120, 255, 60),
	}
	for i, spot in ipairs(spots) do
		local rootPos = Vector3.new(spot.x, spot.y, spot.z)
		local rock = mkPart("IslandRock" .. i, Vector3.new(14, 8, 14),
			rootPos, Color3.fromRGB(110, 105, 115), Enum.Material.Slate)
		rock.Shape = Enum.PartType.Ball
		local grass = mkPart("IslandGrass" .. i, Vector3.new(13, 2, 13),
			rootPos + Vector3.new(0, 4, 0), Color3.fromRGB(80, 190, 90), Enum.Material.Grass)
		local ring = mkPart("IslandRing" .. i, Vector3.new(15, 0.8, 15),
			rootPos + Vector3.new(0, -2, 0), eggColors[i], Enum.Material.Neon)
		ring.Transparency = 0.25
		local egg = mkPart("IslandEgg" .. i, Vector3.new(3, 4, 3),
			rootPos + Vector3.new(0, 8, 0), eggColors[i], Enum.Material.SmoothPlastic)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Egg
		mesh.Scale = Vector3.new(3, 4, 3)
		mesh.Parent = egg
		mkSparkles(egg, eggColors[i], 4, 5, 0.6, 1.5)
		islands[#islands + 1] = { root = rock, baseY = spot.y,
			phase = i * 1.3, speed = 0.7,
			extras = {
				{ part = grass, dy = 4 }, { part = ring, dy = -2 }, { part = egg, dy = 8 },
			} }
	end
end

local function buildSpawnStatue()
	local plaza = anchors.plaza
	local base = plaza + Vector3.new(0, 0, -10)
	mkPart("StatuePedestal", Vector3.new(10, 3, 10), base + Vector3.new(0, 1.5, 0),
		Color3.fromRGB(50, 52, 68))
	mkPart("StatueTrim", Vector3.new(10.6, 0.7, 10.6), base + Vector3.new(0, 3.2, 0),
		Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
	local egg = mkPart("StatueEgg", Vector3.new(5, 7, 5), base + Vector3.new(0, 8, 0),
		Color3.fromRGB(255, 205, 70), Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Egg
	mesh.Scale = Vector3.new(5, 7, 5)
	mesh.Parent = egg
	mkLight(egg, Color3.fromRGB(255, 205, 70), 40, 2)
	mkSparkles(egg, Color3.fromRGB(255, 220, 130), 8, 7, 0.8, 2)
	mkBillboard(egg, "EGG HEIST", Color3.fromRGB(255, 220, 130),
		UDim2.new(0, 260, 0, 60), Vector3.new(0, 8, 0))
	anchors.statue = egg.Position
	-- neon ring around the plaza floor
	local ring = mkPart("PlazaRing", Vector3.new(30, 0.4, 30), plaza + Vector3.new(0, 0.3, 0),
		Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
	ring.Transparency = 0.35
	pulseBeams[#pulseBeams + 1] = { part = ring, base = 0.35, phase = 0, speed = 1.0 }
end

local function buildHeistAlert()
	local heist = anchors.heist
	-- warning arch over the approach
	local archZ = heist.Z - 24
	mkPart("AlertPillarL", Vector3.new(2, 12, 2), Vector3.new(heist.X - 9, 6, archZ),
		Color3.fromRGB(50, 50, 60))
	mkPart("AlertPillarR", Vector3.new(2, 12, 2), Vector3.new(heist.X + 9, 6, archZ),
		Color3.fromRGB(50, 50, 60))
	local beam = mkPart("AlertBeam", Vector3.new(20, 1.6, 1.6), Vector3.new(heist.X, 12, archZ),
		Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	mkBillboard(beam, "RESTRICTED", Color3.fromRGB(255, 120, 120),
		UDim2.new(0, 240, 0, 50), Vector3.new(0, 3, 0))
	pulseBeams[#pulseBeams + 1] = { part = beam, base = 0, phase = 0.5, speed = 2.5 }
	-- two red beacon poles flanking the vault floor
	for i, dx in ipairs({ -16, 16 }) do
		mkPart("AlertPole" .. i, Vector3.new(1, 14, 1),
			Vector3.new(heist.X + dx, 7, heist.Z), Color3.fromRGB(60, 60, 70))
		local head = mkPart("AlertHead" .. i, Vector3.new(3, 2, 3),
			Vector3.new(heist.X + dx, 14.5, heist.Z), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		mkLight(head, Color3.fromRGB(255, 60, 60), 35, 2)
		pulseBeams[#pulseBeams + 1] = { part = head, base = 0, phase = i * 2.1, speed = 2.5 }
	end
end

local function buildStageRig()
	local stage = anchors.stage
	-- four spotlight poles around the stage, aimed at center
	local offsets = { Vector3.new(-14, 0, -14), Vector3.new(14, 0, -14),
		Vector3.new(-14, 0, 14), Vector3.new(14, 0, 14) }
	local colors = {
		Color3.fromRGB(255, 200, 80), Color3.fromRGB(150, 120, 255),
		Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 120, 180),
	}
	for i, offset in ipairs(offsets) do
		local foot = stage + offset
		mkPart("StagePole" .. i, Vector3.new(1, 12, 1), foot + Vector3.new(0, 6, 0),
			Color3.fromRGB(55, 55, 66))
		local headPos = foot + Vector3.new(0, 12.5, 0)
		local head = mkPart("StageHead" .. i, Vector3.new(2.4, 1.6, 2.4), headPos,
			colors[i], Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Color = colors[i]
		spot.Range = 60
		spot.Brightness = 3
		spot.Angle = 35
		spot.Shadows = false
		spot.Parent = head
		-- aim the head at the stage (position-accurate in sim, rotated live)
		pcall(function()
			head.CFrame = CFrame.lookAt(headPos, stage + Vector3.new(0, 2, 0))
		end)
	end
	-- glowing dance floor inlay
	local floor = mkPart("StageGlow", Vector3.new(18, 0.4, 18), stage + Vector3.new(0, 0.4, 0),
		Color3.fromRGB(150, 120, 255), Enum.Material.Neon)
	floor.Transparency = 0.3
	pulseBeams[#pulseBeams + 1] = { part = floor, base = 0.3, phase = 1, speed = 2.0 }
end

local function buildVolcano()
	-- egg-volcano landmark on the far side of the event grounds
	local at = anchors.event + Vector3.new(-30, 0, 28)
	mkPart("VolcanoBase", Vector3.new(24, 10, 24), at + Vector3.new(0, 5, 0),
		Color3.fromRGB(90, 80, 95), Enum.Material.Slate).Shape = Enum.PartType.Ball
	mkPart("VolcanoMid", Vector3.new(17, 8, 17), at + Vector3.new(0, 10, 0),
		Color3.fromRGB(80, 70, 85), Enum.Material.Slate).Shape = Enum.PartType.Ball
	local crater = mkPart("VolcanoCrater", Vector3.new(10, 4, 10), at + Vector3.new(0, 14, 0),
		Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	crater.Shape = Enum.PartType.Ball
	mkLight(crater, Color3.fromRGB(255, 130, 40), 45, 2.5)
	mkSparkles(crater, Color3.fromRGB(255, 150, 50), 10, 14, 1.2, 2.5)
	local smoke = mkSparkles(crater, Color3.fromRGB(70, 60, 75), 6, 10, 3.5, 4)
	smoke.LightEmission = 0
	pulseBeams[#pulseBeams + 1] = { part = crater, base = 0, phase = 2, speed = 0.8 }
	anchors.volcano = crater.Position
end

local function buildClouds()
	local spots = {
		{ x = -60, y = 70, z = 60 }, { x = 60, y = 78, z = 40 }, { x = 0, y = 74, z = -60 },
		{ x = -120, y = 68, z = 90 }, { x = 120, y = 70, z = 100 }, { x = 40, y = 82, z = 130 },
	}
	for i, spot in ipairs(spots) do
		local cloud = mkPart("DriftCloud" .. i, Vector3.new(24, 6, 15),
			Vector3.new(spot.x, spot.y, spot.z), Color3.fromRGB(255, 255, 255))
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.4
		clouds[#clouds + 1] = { part = cloud, base = Vector3.new(spot.x, spot.y, spot.z),
			axis = (i % 2 == 0) and "x" or "z", range = 25 + i * 3, speed = 1.2 + i * 0.15 }
	end
end

--------------------------------------------------------------------------------
-- Service lifecycle
--------------------------------------------------------------------------------

function AtmosphereService.Init(_, reg)
	registry = reg
	ensureLightingRig()
	applyMoodTable(Juice.Moods.Default)

	-- decor root lives next to the world so it never pollutes gameplay folders
	decorFolder = Workspace:FindFirstChild("EggHeistDecor")
	if not decorFolder then
		decorFolder = Instance.new("Folder")
		decorFolder.Name = "EggHeistDecor"
		decorFolder.Parent = Workspace
	end

	anchors.plaza = districtPosition("Spawn", "PlazaBase", FALLBACK_POS.plaza)
	anchors.plaza = districtPosition("Spawn", "PlazaInnerFloor", anchors.plaza)
	anchors.market = districtPosition("EggMarket", "MarketFloor", FALLBACK_POS.market)
	anchors.heist = districtPosition("HeistArea", "HeistFloor", FALLBACK_POS.heist)
	anchors.event = districtPosition("EventArea", "EventFloor", FALLBACK_POS.event)
	anchors.stage = districtPosition("EventArea", "EventStage", anchors.event)
	if registry and registry.World and registry.World.GetExtractionPad then
		local ok, pad = pcall(registry.World.GetExtractionPad)
		if ok and pad then
			anchors.extraction = pad.Position
		end
	end

	local builders = {
		buildBeacons, buildSkyIslands, buildSpawnStatue,
		buildHeistAlert, buildStageRig, buildVolcano, buildClouds,
	}
	for _, builder in ipairs(builders) do
		local ok, err = pcall(builder)
		if not ok then
			warn("[EggHeist] Atmosphere builder failed: " .. tostring(err))
		end
	end
	built = true
	print("[EggHeist] Atmosphere dressed the map ("
		.. tostring(#decorFolder:GetDescendants()) .. " decor objects).")
end

function AtmosphereService.IsBuilt()
	return built
end

function AtmosphereService.Start()
	-- island bob
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = os.clock()
			for _, island in ipairs(islands) do
				local dy = math.sin(t * island.speed + island.phase) * 1.6
				pcall(function()
					island.root.CFrame = CFrame.new(island.root.Position.X,
						island.baseY + dy, island.root.Position.Z)
					for _, extra in ipairs(island.extras) do
						extra.part.CFrame = CFrame.new(extra.part.Position.X,
							island.baseY + extra.dy + dy, extra.part.Position.Z)
					end
				end)
			end
		end
	end)
	-- neon pulse
	task.spawn(function()
		while true do
			task.wait(0.12)
			local t = os.clock()
			for _, beam in ipairs(pulseBeams) do
				pcall(function()
					beam.part.Transparency = math.clamp(beam.base
						+ math.sin(t * beam.speed + beam.phase) * 0.22, 0, 0.9)
				end)
			end
		end
	end)
	-- cloud drift
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = os.clock()
			for _, cloud in ipairs(clouds) do
				pcall(function()
					local off = math.sin(t * 0.05 * cloud.speed) * cloud.range
					if cloud.axis == "x" then
						cloud.part.CFrame = CFrame.new(
							cloud.base.X + off, cloud.base.Y, cloud.base.Z)
					else
						cloud.part.CFrame = CFrame.new(
							cloud.base.X, cloud.base.Y, cloud.base.Z + off)
					end
				end)
			end
		end
	end)
	-- ambient firework celebrations
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(15)
			tick = tick + 1
			local active = registry.Event and registry.Event.GetActive()
			local every = active and Juice.Fireworks.EventEvery or Juice.Fireworks.IdleEvery
			if tick * 15 >= every then
				tick = 0
				AtmosphereService.Celebrate(active and "stage" or "plaza")
			end
		end
	end)
end

return AtmosphereService
