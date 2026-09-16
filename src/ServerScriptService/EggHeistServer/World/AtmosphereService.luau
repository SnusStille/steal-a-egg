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
local orbiters = {} -- { parts = { { part, dx, dy, dz } }, center, radius, y, speed, phase }
local wanderers = {} -- { part, center, rx, ry, rz, sx, sy, sz, px, py, pz }
local built = false

-- Fallback district centers (match the fallback map layout)
local FALLBACK_POS = {
	plaza = Vector3.new(0, 2, 0),
	market = Vector3.new(90, 2, 0),
	heist = Vector3.new(0, 2, 120),
	event = Vector3.new(-90, 2, 0),
	bases = Vector3.new(0, 2, -90),
	grotto = Vector3.new(-118, 2, 95),
	beach = Vector3.new(118, 2, 102),
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

--------------------------------------------------------------------------------
-- Candy builders (cartoon map dressing: trees, lollipops, eggs, rainbow)
--------------------------------------------------------------------------------

local CANDY = {
	pink = Color3.fromRGB(255, 150, 210),
	mint = Color3.fromRGB(130, 240, 190),
	sky = Color3.fromRGB(130, 200, 255),
	lemon = Color3.fromRGB(255, 235, 130),
	grape = Color3.fromRGB(190, 140, 255),
	tangerine = Color3.fromRGB(255, 175, 100),
	white = Color3.fromRGB(255, 255, 255),
	choco = Color3.fromRGB(140, 95, 60),
}
local CANDY_CYCLE = { "pink", "mint", "sky", "lemon", "grape", "tangerine" }

local function mkBall(name, diameter, position, color)
	local part = mkPart(name, Vector3.new(diameter, diameter, diameter), position, color)
	part.Shape = Enum.PartType.Ball
	return part
end

local function buildCandyTrees()
	local spots = {
		{ "plaza", -22, -14 }, { "plaza", 22, -14 },
		{ "plaza", -24, 12 }, { "plaza", 24, 12 },
		{ "market", -20, 10 }, { "market", 20, 10 },
		{ "event", -16, 14 }, { "event", 16, 14 },
	}
	for i, spot in ipairs(spots) do
		local base = anchors[spot[1]] or FALLBACK_POS[spot[1]]
		if base then
			local x, z = base.X + spot[2], base.Z + spot[3]
			local candy = CANDY[CANDY_CYCLE[(i - 1) % #CANDY_CYCLE + 1]]
			mkPart("CandyTrunk" .. i, Vector3.new(1.4, 6, 1.4),
				Vector3.new(x, base.Y + 3, z), CANDY.choco)
			mkBall("CandyTop" .. i, 5, Vector3.new(x, base.Y + 7.5, z), candy)
			mkBall("CandyLeft" .. i, 3.6, Vector3.new(x - 2.4, base.Y + 6, z + 0.8), candy)
			mkBall("CandyRight" .. i, 3.6, Vector3.new(x + 2.4, base.Y + 6, z - 0.8), candy)
			mkBall("CandyDot" .. i, 1.4, Vector3.new(x, base.Y + 10.4, z), CANDY.white)
		end
	end
end

local function buildLollipops()
	local spots = {
		{ "plaza", 30, 7, true }, { "plaza", 45, -7, false },
		{ "plaza", 60, 7, true }, { "plaza", -30, -7, false },
		{ "plaza", -45, 7, true }, { "plaza", -60, -7, false },
	}
	for i, spot in ipairs(spots) do
		local base = anchors[spot[1]] or FALLBACK_POS[spot[1]]
		if base then
			local x, z = base.X + spot[2], base.Z + spot[3]
			local candy = CANDY[CANDY_CYCLE[(i - 1) % #CANDY_CYCLE + 1]]
			mkPart("LolliPole" .. i, Vector3.new(0.7, 7, 0.7),
				Vector3.new(x, base.Y + 3.5, z), CANDY.white)
			local pop = mkBall("LolliPop" .. i, 4,
				Vector3.new(x, base.Y + 8, z), candy)
			if spot[4] then
				mkLight(pop, candy, 26, 1.5)
			end
		end
	end
end

local function buildGiantEggs()
	local spots = {
		{ "plaza", 0, -17, "pink" }, { "market", 0, 12, "lemon" }, { "event", 0, -14, "sky" },
	}
	for i, spot in ipairs(spots) do
		local base = anchors[spot[1]] or FALLBACK_POS[spot[1]]
		if base then
			local body = mkPart("GiantEgg" .. i, Vector3.new(5, 6.5, 5),
				Vector3.new(base.X + spot[2], base.Y + 3.4, base.Z + spot[3]),
				CANDY[spot[4]])
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Egg
			mesh.Scale = Vector3.new(5, 6.5, 5)
			mesh.Parent = body
			mkSparkles(body, CANDY.white, 4, 5, 0.8, 2)
		end
	end
end

local function buildRainbowArch()
	local base = anchors.plaza or FALLBACK_POS.plaza
	local bands = {
		Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 160, 60),
		Color3.fromRGB(255, 230, 90), Color3.fromRGB(120, 240, 140),
		Color3.fromRGB(110, 180, 255), Color3.fromRGB(170, 130, 255),
		Color3.fromRGB(230, 150, 255),
	}
	for i = 1, 7 do
		local a = math.rad(20 + (i - 1) * (140 / 6))
		local pos = Vector3.new(base.X + math.cos(a) * 14, base.Y + math.sin(a) * 12, base.Z + 16)
		local beam = mkPart("Rainbow" .. i, Vector3.new(7.5, 1.8, 1.8), pos, bands[i])
		beam.CFrame = CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(0, 0, a - math.pi / 2)
	end
	mkBall("RainbowCloudL", 6, Vector3.new(base.X - 13.2, base.Y + 4.5, base.Z + 16), CANDY.white)
	mkBall("RainbowCloudR", 6, Vector3.new(base.X + 13.2, base.Y + 4.5, base.Z + 16), CANDY.white)
end

local function buildGumdrops()
	local spots = {
		{ "plaza", -14, 18 }, { "plaza", 14, 18 }, { "plaza", -18, -4 }, { "plaza", 18, -6 },
		{ "market", -12, -8 }, { "market", 12, -8 }, { "event", -10, 8 }, { "event", 10, 8 },
		{ "heist", -12, 10 }, { "heist", 12, 10 },
	}
	for i, spot in ipairs(spots) do
		local base = anchors[spot[1]] or FALLBACK_POS[spot[1]]
		if base then
			local candy = CANDY[CANDY_CYCLE[(i - 1) % #CANDY_CYCLE + 1]]
			local drop = mkPart("Gumdrop" .. i, Vector3.new(3.2, 2.2, 3.2),
				Vector3.new(base.X + spot[2], base.Y + 1, base.Z + spot[3]), candy)
			drop.Shape = Enum.PartType.Ball
		end
	end
end

-- MAP MEGAPASS: crystal grotto (south-west). Walkable amethyst floor,
-- neon spike ring, glowing heart cluster (ActivitiesService hangs the
-- daily-gem prompt on GrottoHeart).
local function buildCrystalGrotto()
	local at = anchors.grotto or FALLBACK_POS.grotto
	local cx, cz = at.X, at.Z
	local floor = mkPart("GrottoFloor", Vector3.new(32, 2, 32),
		Vector3.new(cx, 0, cz), Color3.fromRGB(70, 55, 120), Enum.Material.Slate)
	floor.CanCollide = true
	local rim = mkPart("GrottoRim", Vector3.new(34, 0.6, 34),
		Vector3.new(cx, 1.2, cz), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	rim.Transparency = 0.4
	local colors = {
		Color3.fromRGB(120, 230, 255), Color3.fromRGB(180, 140, 255),
		Color3.fromRGB(255, 150, 220),
	}
	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi * 2
		local h = 5 + (i % 4) * 3
		mkPart("GrottoSpike" .. i, Vector3.new(2, h, 2),
			Vector3.new(cx + math.cos(a) * 11, 1 + h / 2, cz + math.sin(a) * 11),
			colors[(i - 1) % 3 + 1], Enum.Material.Neon)
	end
	local heart = mkPart("GrottoHeart", Vector3.new(3, 16, 3),
		Vector3.new(cx, 9, cz), Color3.fromRGB(170, 230, 255), Enum.Material.Neon)
	mkLight(heart, Color3.fromRGB(150, 210, 255), 45, 2)
	mkSparkles(heart, Color3.fromRGB(170, 230, 255), 8, 6, 0.9, 2)
	mkPart("GrottoHeartL", Vector3.new(2, 9, 2),
		Vector3.new(cx - 3, 5.5, cz + 1), Color3.fromRGB(180, 140, 255), Enum.Material.Neon)
	mkPart("GrottoHeartR", Vector3.new(2, 7, 2),
		Vector3.new(cx + 3, 4.5, cz - 1), Color3.fromRGB(255, 150, 220), Enum.Material.Neon)
	mkBillboard(heart, "CRYSTAL GROTTO", Color3.fromRGB(170, 230, 255),
		UDim2.new(0, 280, 0, 50), Vector3.new(0, 11, 0))
	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi * 2 + 0.4
		mkBall("GrottoStone" .. i, 2.2,
			Vector3.new(cx + math.cos(a) * 15, 2, cz + math.sin(a) * 15),
			Color3.fromRGB(90, 85, 110))
	end
	anchors.grottoHeart = heart.Position
end

-- MAP MEGAPASS: sunny beach (south-east). Sand, wade-through lagoon,
-- palms, umbrellas, a beach ball, and a very suspicious bottle.
local function buildSunnyBeach()
	local at = anchors.beach or FALLBACK_POS.beach
	local cx, cz = at.X, at.Z
	local sand = mkPart("BeachSand", Vector3.new(32, 2, 32),
		Vector3.new(cx, 0, cz), Color3.fromRGB(235, 215, 160), Enum.Material.Sand)
	sand.CanCollide = true
	local lagoon = mkPart("BeachLagoon", Vector3.new(14, 0.6, 10),
		Vector3.new(cx + 6, 1.3, cz + 6), Color3.fromRGB(90, 200, 255), Enum.Material.Glass)
	lagoon.Transparency = 0.25
	local palmSpots = { { -10, -8 }, { -2, -11 }, { 10, -6 } }
	for i, s in ipairs(palmSpots) do
		local px, pz = cx + s[1], cz + s[2]
		mkPart("PalmTrunk" .. i, Vector3.new(1.2, 7, 1.2),
			Vector3.new(px, 4.5, pz), Color3.fromRGB(140, 100, 65))
		mkBall("PalmTop" .. i, 5, Vector3.new(px, 9, pz), Color3.fromRGB(70, 180, 90))
		mkBall("PalmSide" .. i, 3.4, Vector3.new(px + 2.2, 8, pz + 1), Color3.fromRGB(85, 195, 100))
		mkBall("PalmNut" .. i, 1.2, Vector3.new(px - 1, 7, pz + 0.6), Color3.fromRGB(110, 80, 50))
	end
	local umbrellaSpots = { { -9, 7, "pink" }, { 2, 10, "sky" } }
	for i, s in ipairs(umbrellaSpots) do
		local px, pz = cx + s[1], cz + s[2]
		mkPart("UmbrellaPole" .. i, Vector3.new(0.6, 5, 0.6),
			Vector3.new(px, 3.5, pz), CANDY.white)
		mkBall("UmbrellaTop" .. i, 4.4, Vector3.new(px, 6.4, pz), CANDY[s[3]])
	end
	mkBall("BeachBall", 3, Vector3.new(cx - 4, 2.5, cz + 2), CANDY.tangerine)
	local post = mkPart("BeachSignPost", Vector3.new(1, 6, 1),
		Vector3.new(cx - 13, 4, cz - 12), Color3.fromRGB(140, 100, 65))
	mkBillboard(post, "SUNNY SHORES", Color3.fromRGB(255, 235, 150),
		UDim2.new(0, 260, 0, 50), Vector3.new(0, 5, 0))
	anchors.lagoon = lagoon.Position
end

-- MAP MEGAPASS: base boulevard gardens flanking the north road.
local function buildBaseBoulevard()
	local base = anchors.plaza or FALLBACK_POS.plaza
	for side = 1, 2 do
		local gx = base.X + (side == 1 and -14 or 14)
		local gz = base.Z - 40
		local pad = mkPart("BoulevardPad" .. side, Vector3.new(12, 4, 12),
			Vector3.new(gx, -2, gz), Color3.fromRGB(75, 165, 85), Enum.Material.Grass)
		pad.CanCollide = true
		mkPart("BoulevardBasin" .. side, Vector3.new(6, 1.5, 6),
			Vector3.new(gx, 0.75, gz), Color3.fromRGB(150, 150, 165))
		mkPart("BoulevardWater" .. side, Vector3.new(5, 0.5, 5),
			Vector3.new(gx, 1.4, gz), Color3.fromRGB(90, 180, 255), Enum.Material.Glass)
		mkPart("BoulevardSpout" .. side, Vector3.new(1, 3, 1),
			Vector3.new(gx, 2.5, gz), Color3.fromRGB(150, 150, 165))
		mkBall("BoulevardSpray" .. side, 2, Vector3.new(gx, 4.4, gz),
			Color3.fromRGB(150, 220, 255))
		local flowerColors = { CANDY.pink, CANDY.lemon, CANDY.grape }
		for f = 1, 6 do
			local a = (f - 1) / 6 * math.pi * 2
			mkBall("BoulevardFlower" .. side .. "_" .. f, 0.9,
				Vector3.new(gx + math.cos(a) * 4.6, 0.4, gz + math.sin(a) * 4.6),
				flowerColors[(f - 1) % 3 + 1])
		end
		mkPart("BoulevardLamp" .. side, Vector3.new(0.8, 8, 0.8),
			Vector3.new(gx, 4, gz + 5.4), Color3.fromRGB(50, 50, 60))
		local head = mkPart("BoulevardLampHead" .. side, Vector3.new(2, 1.5, 2),
			Vector3.new(gx, 8.7, gz + 5.4), Color3.fromRGB(255, 235, 180), Enum.Material.Neon)
		if side == 1 then
			mkLight(head, Color3.fromRGB(255, 230, 170), 24, 1.5)
		end
	end
end

-- MAP MEGAPASS: entry arches for the event grounds and base row.
local function buildDistrictArches()
	local event = anchors.event or FALLBACK_POS.event
	for _, sx in ipairs({ -12, 12 }) do
		mkPart("EventArchPillar" .. sx, Vector3.new(2, 14, 2),
			Vector3.new(event.X + sx, 4, event.Z + 26), Color3.fromRGB(90, 70, 140))
	end
	local eventBeam = mkPart("EventArchBeam", Vector3.new(26, 2, 2),
		Vector3.new(event.X, 11.5, event.Z + 26), Color3.fromRGB(150, 120, 255))
	mkBillboard(eventBeam, "EVENT GROUNDS", Color3.fromRGB(230, 210, 255),
		UDim2.new(0, 280, 0, 50), Vector3.new(0, 4, 0))
	local base = anchors.plaza or FALLBACK_POS.plaza
	for _, sx in ipairs({ -7, 7 }) do
		mkPart("BaseArchPillar" .. sx, Vector3.new(2, 12, 2),
			Vector3.new(base.X + sx, 3, base.Z - 70), Color3.fromRGB(70, 130, 90))
	end
	local baseBeam = mkPart("BaseArchBeam", Vector3.new(16, 2, 2),
		Vector3.new(base.X, 9.5, base.Z - 70), Color3.fromRGB(120, 220, 150))
	mkBillboard(baseBeam, "BASE ROW", Color3.fromRGB(210, 255, 220),
		UDim2.new(0, 240, 0, 50), Vector3.new(0, 4, 0))
end

-- MAP MEGAPASS: lava river flowing south from the volcano, with an
-- obsidian bridge crossing to the crystal grotto.
local function buildLavaRiver()
	local ref = anchors.volcano or ((anchors.event or FALLBACK_POS.event)
		+ Vector3.new(-30, 0, 28))
	local riverX = ref.X - 20
	for i = 1, 6 do
		local z = ref.Z + 2 + (i - 1) * 26 + 13
		local lava = mkPart("LavaFlow" .. i, Vector3.new(5, 1, 26),
			Vector3.new(riverX, -2.6, z), Color3.fromRGB(255, 110, 25), Enum.Material.Neon)
		pulseBeams[#pulseBeams + 1] = { part = lava, base = 0.1, phase = i * 0.9, speed = 1.4 }
		for _, side in ipairs({ -3.5, 3.5 }) do
			mkPart("LavaBank" .. i .. "_" .. side, Vector3.new(2, 2, 26),
				Vector3.new(riverX + side, -2, z), Color3.fromRGB(35, 30, 45), Enum.Material.Slate)
		end
		if i == 2 or i == 5 then
			mkSparkles(lava, Color3.fromRGB(255, 150, 50), 6, 10, 1, 2)
		end
	end
	local grotto = anchors.grotto or FALLBACK_POS.grotto
	local deck = mkPart("ObsidianBridge", Vector3.new(20, 1, 6),
		Vector3.new(riverX + 6, -1.2, grotto.Z), Color3.fromRGB(40, 35, 55), Enum.Material.Slate)
	deck.CanCollide = true
	for _, dz in ipairs({ -2.75, 2.75 }) do
		mkPart("ObsidianRail" .. dz, Vector3.new(20, 1.5, 0.5),
			Vector3.new(riverX + 6, 0, grotto.Z + dz), Color3.fromRGB(255, 110, 25), Enum.Material.Neon)
	end
end

-- MAP MEGAPASS: hot-air balloon on a slow scenic orbit around the plaza.
local function buildBalloon()
	local base = anchors.plaza or FALLBACK_POS.plaza
	local center = Vector3.new(base.X, 48, base.Z)
	local radius = 70
	local bag = mkPart("BalloonBag", Vector3.new(9, 11, 9), center,
		CANDY.tangerine)
	bag.Shape = Enum.PartType.Ball
	local band = mkPart("BalloonBand", Vector3.new(9.4, 2, 9.4), center,
		CANDY.white)
	band.Shape = Enum.PartType.Ball
	band.Transparency = 0.15
	local basket = mkPart("BalloonBasket", Vector3.new(3.5, 3, 3.5),
		center + Vector3.new(0, -10, 0), Color3.fromRGB(140, 100, 65))
	local ropes = {}
	for i, off in ipairs({ { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } }) do
		ropes[i] = mkPart("BalloonRope" .. i, Vector3.new(0.3, 6, 0.3),
			center + Vector3.new(off[1], -5.5, off[2]), Color3.fromRGB(110, 80, 55))
	end
	local pole = mkPart("BalloonFlagPole", Vector3.new(0.3, 3, 0.3),
		center + Vector3.new(0, 7, 0), CANDY.white)
	local flag = mkPart("BalloonFlag", Vector3.new(2.4, 1.4, 0.2),
		center + Vector3.new(1.3, 7.6, 0), CANDY.pink)
	local parts = {
		{ part = bag, dx = 0, dy = 0, dz = 0 },
		{ part = band, dx = 0, dy = 0, dz = 0 },
		{ part = basket, dx = 0, dy = -10, dz = 0 },
		{ part = pole, dx = 0, dy = 7, dz = 0 },
		{ part = flag, dx = 1.3, dy = 7.6, dz = 0 },
	}
	for i, rope in ipairs(ropes) do
		local off = ({ { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } })[i]
		parts[#parts + 1] = { part = rope, dx = off[1], dy = -5.5, dz = off[2] }
	end
	orbiters[#orbiters + 1] = { parts = parts, center = center,
		radius = radius, y = center.Y, speed = 0.035, phase = 0 }
end

-- MAP MEGAPASS: ambient critters - butterflies over the gardens,
-- fish circling the pond, fireflies dancing in the grotto.
local function buildCritters()
	local plaza = anchors.plaza or FALLBACK_POS.plaza
	local grotto = anchors.grotto or FALLBACK_POS.grotto
	local butterflyColors = { CANDY.pink, CANDY.lemon, CANDY.sky,
		CANDY.mint, CANDY.grape, CANDY.tangerine }
	local gardens = {
		Vector3.new(plaza.X - 14, 3, plaza.Z - 40),
		Vector3.new(plaza.X + 14, 3, plaza.Z - 40),
	}
	for i = 1, 6 do
		local center = gardens[(i - 1) % 2 + 1]
		local fly = mkPart("Butterfly" .. i, Vector3.new(1.2, 0.4, 0.8),
			center, butterflyColors[i], Enum.Material.Neon)
		wanderers[#wanderers + 1] = { part = fly, center = center,
			rx = 7, ry = 1.6, rz = 7,
			sx = 0.5 + i * 0.06, sy = 1.1, sz = 0.4 + i * 0.05,
			px = i * 1.1, py = i * 0.7, pz = i * 1.7 }
	end
	local pond = Vector3.new(plaza.X + 48, 0.2, plaza.Z + 52)
	for i = 1, 3 do
		local fish = mkPart("PondFish" .. i, Vector3.new(1, 0.6, 0.6),
			pond, Color3.fromRGB(255, 150, 80), Enum.Material.Neon)
		fish.Shape = Enum.PartType.Ball
		wanderers[#wanderers + 1] = { part = fish, center = pond,
			rx = 3.5, ry = 0.15, rz = 3.5,
			sx = 0.9, sy = 2, sz = 0.9,
			px = i * 2.1, py = 0, pz = i * 2.1 }
	end
	for i = 1, 4 do
		local mote = mkPart("GrottoMote" .. i, Vector3.new(0.7, 0.7, 0.7),
			Vector3.new(grotto.X, 4, grotto.Z),
			Color3.fromRGB(170, 240, 255), Enum.Material.Neon)
		mote.Shape = Enum.PartType.Ball
		wanderers[#wanderers + 1] = { part = mote,
			center = Vector3.new(grotto.X, 4, grotto.Z),
			rx = 11, ry = 2.5, rz = 11,
			sx = 0.3 + i * 0.04, sy = 0.7, sz = 0.26 + i * 0.05,
			px = i * 1.9, py = i, pz = i * 1.3 }
	end
end

function AtmosphereService.Init(_, reg)
	registry = reg
	ensureLightingRig()
	applyMoodTable(Juice.Moods.Default)

	-- decor root lives next to the world so it never pollutes gameplay folders
	decorFolder = registry.World.GetRuntimeFolder("Decor")

	anchors.plaza = districtPosition("Spawn", "PlazaBase", FALLBACK_POS.plaza)
	anchors.plaza = districtPosition("Spawn", "PlazaInnerFloor", anchors.plaza)
	anchors.market = districtPosition("EggMarket", "MarketFloor", FALLBACK_POS.market)
	anchors.heist = districtPosition("HeistArea", "HeistFloor", FALLBACK_POS.heist)
	anchors.event = districtPosition("EventArea", "EventFloor", FALLBACK_POS.event)
	anchors.stage = districtPosition("EventArea", "EventStage", anchors.event)
	anchors.grotto = anchors.event + Vector3.new(-28, 0, 95)
	anchors.beach = anchors.market + Vector3.new(28, 0, 102)
	if registry and registry.World and registry.World.GetExtractionPad then
		local ok, pad = pcall(registry.World.GetExtractionPad)
		if ok and pad then
			anchors.extraction = pad.Position
		end
	end

	local builders = {
		buildBeacons, buildSkyIslands, buildSpawnStatue,
		buildHeistAlert, buildStageRig, buildVolcano, buildClouds,
		buildCandyTrees, buildLollipops, buildGiantEggs,
		buildRainbowArch, buildGumdrops, buildCrystalGrotto,
		buildSunnyBeach, buildBaseBoulevard, buildDistrictArches,
		buildLavaRiver, buildBalloon, buildCritters,
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
	-- balloon orbit
	task.spawn(function()
		while true do
			task.wait(0.15)
			local t = os.clock()
			for _, orbiter in ipairs(orbiters) do
				local a = t * orbiter.speed + orbiter.phase
				local ox = orbiter.center.X + math.cos(a) * orbiter.radius
				local oz = orbiter.center.Z + math.sin(a) * orbiter.radius
				for _, entry in ipairs(orbiter.parts) do
					pcall(function()
						entry.part.CFrame = CFrame.new(
							ox + entry.dx, orbiter.y + entry.dy, oz + entry.dz)
					end)
				end
			end
		end
	end)
	-- critter wander (butterflies, fish, grotto motes)
	task.spawn(function()
		while true do
			task.wait(0.12)
			local t = os.clock()
			for _, w in ipairs(wanderers) do
				pcall(function()
					w.part.CFrame = CFrame.new(
						w.center.X + math.sin(t * w.sx + w.px) * w.rx,
						w.center.Y + math.sin(t * w.sy + w.py) * w.ry,
						w.center.Z + math.cos(t * w.sz + w.pz) * w.rz)
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
