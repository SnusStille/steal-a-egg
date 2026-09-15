-- EggHeist | Server/Services/WorldService.lua
-- Discovers the existing world (workspace.EggHeist) and wires gameplay onto it.
-- If the world model is missing, builds a complete procedural fallback world
-- so the game ALWAYS runs. Never destroys existing content.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings"))

local WorldService = {}
WorldService.Name = "WorldService"

local registry = nil
local root = nil -- workspace.EggHeist (real or fallback-built)
local usingFallback = false
local liveFolder = nil -- runtime instances (pets, meteors, loot)
local extractionPad = nil
local spawnLocation = nil
local defaultLighting = {}

local function find(...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

--------------------------------------------------------------------------------
-- Fallback world builder (only runs when EggHeist model is absent)
--------------------------------------------------------------------------------

local FALLBACK_COLORS = {
	Floor = Color3.fromRGB(70, 75, 90),
	Accent = Color3.fromRGB(255, 200, 80),
	Market = Color3.fromRGB(90, 140, 255),
	Heist = Color3.fromRGB(200, 60, 60),
	Event = Color3.fromRGB(150, 90, 255),
	Plot = Color3.fromRGB(80, 160, 100),
	Path = Color3.fromRGB(110, 110, 120),
}

local function mkPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(150, 150, 150)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = (canCollide ~= false)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function mkSign(parent, name, cframe, text, textColor, size)
	local board = mkPart(parent, name, size or Vector3.new(12, 4, 1), cframe,
		Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(600, 200)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "TextLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	return board
end

local function mkEggModel(parent, name, color, glow)
	local model = Instance.new("Model")
	model.Name = name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.4, 3.2, 2.4)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Egg
	mesh.Scale = Vector3.new(2.4, 3.2, 2.4)
	mesh.Parent = body
	if glow then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Parent = body
	end
	model.Parent = parent
	return model
end

local function buildFallbackWorld()
	print("[EggHeist] World model not found - building fallback world.")
	usingFallback = true
	root = Instance.new("Folder")
	root.Name = "EggHeist"

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = root

	-- Safety baseplate
	mkPart(root, "Baseplate", Vector3.new(600, 2, 600), CFrame.new(0, -4, 0),
		Color3.fromRGB(60, 90, 60), Enum.Material.Grass)

	-- Spawn plaza
	local spawn = Instance.new("Folder")
	spawn.Name = "Spawn"
	spawn.Parent = mapFolder
	mkPart(spawn, "PlazaBase", Vector3.new(40, 2, 40), CFrame.new(0, 0, 0), FALLBACK_COLORS.Floor)
	mkPart(spawn, "PlazaInnerFloor", Vector3.new(24, 2.2, 24), CFrame.new(0, 0.1, 0), FALLBACK_COLORS.Accent)
	mkSign(spawn, "SignBoard", CFrame.new(0, 8, -18), "EGG HEIST", Color3.fromRGB(255, 220, 100))

	-- Market (6 stalls)
	local market = Instance.new("Folder")
	market.Name = "EggMarket"
	market.Parent = mapFolder
	mkPart(market, "MarketFloor", Vector3.new(60, 2, 30), CFrame.new(90, 0, 0), FALLBACK_COLORS.Market)
	mkSign(market, "MarketArchLabel", CFrame.new(90, 9, -13), "EGG MARKET", Color3.fromRGB(255, 255, 255))
	local stalls = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
	for i, stall in ipairs(stalls) do
		local x = 90 - 25 + (i - 1) * 10
		mkPart(market, stall .. "_Platform", Vector3.new(8, 2, 8), CFrame.new(x, 1, 0), FALLBACK_COLORS.Accent)
		mkPart(market, stall .. "_Pedestal", Vector3.new(3, 3, 3), CFrame.new(x, 3.5, 0), FALLBACK_COLORS.Floor)
		mkSign(market, stall .. "_Label", CFrame.new(x, 8, -8), string.upper(stall),
			Color3.fromRGB(255, 255, 255), Vector3.new(8, 3, 1))
	end

	-- Heist vault area
	local heist = Instance.new("Folder")
	heist.Name = "HeistArea"
	heist.Parent = mapFolder
	mkPart(heist, "HeistFloor", Vector3.new(50, 2, 50), CFrame.new(0, 0, 120), FALLBACK_COLORS.Heist)
	mkPart(heist, "VaultWall", Vector3.new(30, 14, 2), CFrame.new(0, 7, 142), FALLBACK_COLORS.Floor)
	mkPart(heist, "VaultDoor", Vector3.new(10, 10, 3), CFrame.new(0, 5, 140), Color3.fromRGB(50, 50, 60))
	mkSign(heist, "HeistAreaLabel", CFrame.new(0, 12, 130), "RESTRICTED VAULT", Color3.fromRGB(255, 120, 120))
	mkPart(heist, "SecurityGateTop", Vector3.new(16, 2, 2), CFrame.new(0, 8, 100), FALLBACK_COLORS.Accent)
	mkPart(heist, "SecurityGateL", Vector3.new(2, 8, 2), CFrame.new(-7, 4, 100), FALLBACK_COLORS.Floor)
	mkPart(heist, "SecurityGateR", Vector3.new(2, 8, 2), CFrame.new(7, 4, 100), FALLBACK_COLORS.Floor)

	-- Event stage
	local eventArea = Instance.new("Folder")
	eventArea.Name = "EventArea"
	eventArea.Parent = mapFolder
	mkPart(eventArea, "EventFloor", Vector3.new(44, 2, 44), CFrame.new(-90, 0, 0), FALLBACK_COLORS.Event)
	mkPart(eventArea, "EventStage", Vector3.new(16, 3, 16), CFrame.new(-90, 1.5, 0), FALLBACK_COLORS.Accent)
	mkSign(eventArea, "EventAreaLabel", CFrame.new(-90, 10, -18), "EVENT GROUNDS", Color3.fromRGB(220, 180, 255))

	-- Bases
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = root
	local template = Instance.new("Model")
	template.Name = "BaseTemplate"
	template.Parent = bases
	mkPart(template, "Foundation", Vector3.new(36, 2, 36), CFrame.new(0, -30, -160), FALLBACK_COLORS.Plot)
	for i = 1, Settings.MaxBasePlots do
		local plot = Instance.new("Model")
		plot.Name = string.format("Plot%02d", i)
		plot.Parent = bases
		local x = -140 + (i - 1) * 40
		mkPart(plot, "Foundation", Vector3.new(36, 2, 36), CFrame.new(x, 0, -90), FALLBACK_COLORS.Plot)
		mkSign(plot, "PlotLabel", CFrame.new(x, 8, -106), string.format("Plot%02d", i),
			Color3.fromRGB(200, 255, 200), Vector3.new(10, 3, 1))
		mkPart(plot, "EggPedestal1", Vector3.new(3, 3, 3), CFrame.new(x - 8, 2.5, -90), FALLBACK_COLORS.Accent)
		mkPart(plot, "VaultAreaFloor", Vector3.new(10, 2, 10), CFrame.new(x + 8, 1, -95), FALLBACK_COLORS.Heist)
	end

	-- Runtime + decor + interactables shells
	local gameplay = Instance.new("Folder")
	gameplay.Name = "Gameplay"
	gameplay.Parent = root
	local interactables = Instance.new("Folder")
	interactables.Name = "Interactables"
	interactables.Parent = root
	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = root
	mkPart(decorations, "PathToMarket", Vector3.new(50, 1, 6), CFrame.new(45, -0.5, 0), FALLBACK_COLORS.Path)
	mkPart(decorations, "PathToHeist", Vector3.new(6, 1, 80), CFrame.new(0, -0.5, 60), FALLBACK_COLORS.Path)

	-- Egg assets
	local assets = Instance.new("Folder")
	assets.Name = "EggAssets"
	assets.Parent = root
	local eggColors = {
		BasicEgg = Color3.fromRGB(240, 230, 200), StoneEgg = Color3.fromRGB(130, 130, 130),
		GoldenEgg = Color3.fromRGB(255, 200, 60), CrystalEgg = Color3.fromRGB(150, 220, 255),
		LavaEgg = Color3.fromRGB(255, 100, 40), ToxicEgg = Color3.fromRGB(120, 255, 60),
		ShadowEgg = Color3.fromRGB(70, 50, 120), GalaxyEgg = Color3.fromRGB(150, 80, 255),
		AncientEgg = Color3.fromRGB(200, 170, 120), VoidEgg = Color3.fromRGB(25, 15, 45),
	}
	for name, color in pairs(eggColors) do
		local model = mkEggModel(assets, name, color, true)
		local body = model:FindFirstChild("Body")
		if body then
			body.CFrame = CFrame.new(0, -20, -160)
		end
	end

	root.Parent = Workspace
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function WorldService.Init(_, reg)
	registry = reg

	root = Workspace:FindFirstChild("EggHeist")
	if not root then
		-- Also accept the model being inserted with a slightly different name
		root = Workspace:FindFirstChild("Egg heist") or Workspace:FindFirstChild("EggHeistModel")
		if root then
			root.Name = "EggHeist"
		end
	end
	if not root then
		buildFallbackWorld()
	else
		print("[EggHeist] Found existing world: " .. root:GetFullName())
		-- Ensure a Gameplay folder exists for runtime content
		if not root:FindFirstChild("Gameplay") then
			local gameplay = Instance.new("Folder")
			gameplay.Name = "Gameplay"
			gameplay.Parent = root
		end
	end

	liveFolder = Workspace:FindFirstChild("EggHeistLive")
	if not liveFolder then
		liveFolder = Instance.new("Folder")
		liveFolder.Name = "EggHeistLive"
		liveFolder.Parent = Workspace
	end

	-- Snapshot default lighting for event restore
	defaultLighting.ClockTime = Lighting.ClockTime
	defaultLighting.Brightness = Lighting.Brightness
	defaultLighting.Ambient = Lighting.Ambient
	defaultLighting.OutdoorAmbient = Lighting.OutdoorAmbient
	defaultLighting.ColorShiftTop = Lighting.ColorShift_Top
	defaultLighting.ColorShiftBottom = Lighting.ColorShift_Bottom

	WorldService.EnsureSpawn()
	WorldService.EnsureExtraction()
end

function WorldService.GetRoot()
	return root
end

function WorldService.IsFallback()
	return usingFallback
end

function WorldService.GetLiveFolder()
	return liveFolder
end

function WorldService.Find(...)
	return find(...)
end

--------------------------------------------------------------------------------
-- Spawn
--------------------------------------------------------------------------------

function WorldService.GetSpawnCFrame()
	local plaza = find("Map", "Spawn", "PlazaBase") or find("Map", "Spawn", "PlazaInnerFloor")
	if plaza and plaza:IsA("BasePart") then
		return plaza.CFrame + Vector3.new(0, plaza.Size.Y / 2 + 4, 0)
	end
	return CFrame.new(0, 10, 0)
end

function WorldService.EnsureSpawn()
	-- Reuse an existing SpawnLocation if the place already has one
	spawnLocation = Workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawnLocation and root then
		spawnLocation = root:FindFirstChild("SpawnLocation", true)
	end
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnLocation"
		spawnLocation.Size = Vector3.new(8, 2, 8)
		spawnLocation.Anchored = true
		spawnLocation.CanCollide = true
		spawnLocation.TopSurface = Enum.SurfaceType.Smooth
		spawnLocation.BottomSurface = Enum.SurfaceType.Smooth
		spawnLocation.Material = Enum.Material.SmoothPlastic
		spawnLocation.Color = Color3.fromRGB(90, 200, 120)
		spawnLocation.Enabled = true
		spawnLocation.Neutral = true
		spawnLocation.AllowTeamChangeOnTouch = false
		spawnLocation.Duration = 0
		spawnLocation.Parent = Workspace
	end
	spawnLocation.CFrame = WorldService.GetSpawnCFrame()
		* CFrame.new(0, -3, 0) -- pad surface under feet
	Players.RespawnLocation = spawnLocation
end

--------------------------------------------------------------------------------
-- Extraction zone (heist drop-off)
--------------------------------------------------------------------------------

function WorldService.EnsureExtraction()
	local gameplay = find("Gameplay")
	if not gameplay then
		return
	end
	extractionPad = gameplay:FindFirstChild("ExtractionPad")
	if not extractionPad then
		extractionPad = Instance.new("Part")
		extractionPad.Name = "ExtractionPad"
		extractionPad.Size = Vector3.new(12, 1, 12)
		extractionPad.Anchored = true
		extractionPad.CanCollide = false
		extractionPad.Material = Enum.Material.Neon
		extractionPad.Color = Color3.fromRGB(80, 255, 140)
		extractionPad.Transparency = 0.25
		extractionPad.Parent = gameplay

		local gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.new(0, 200, 0, 60)
		gui.StudsOffset = Vector3.new(0, 5, 0)
		gui.AlwaysOnTop = true
		gui.Parent = extractionPad
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "EXTRACTION"
		text.TextColor3 = Color3.fromRGB(120, 255, 160)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextStrokeTransparency = 0.4
		text.Parent = gui
	end
	-- Position: center of heist floor (or fallback coords)
	local floor = find("Map", "HeistArea", "HeistFloor")
	if floor and floor:IsA("BasePart") then
		extractionPad.CFrame = floor.CFrame + Vector3.new(0, floor.Size.Y / 2 + 0.6, 0)
	else
		extractionPad.CFrame = CFrame.new(0, 1.5, 120)
	end
end

function WorldService.GetExtractionPad()
	return extractionPad
end

--------------------------------------------------------------------------------
-- Plots / market / assets accessors
--------------------------------------------------------------------------------

function WorldService.GetPlotModel(plotIndex)
	local bases = find("Bases")
	if not bases then
		return nil
	end
	return bases:FindFirstChild(string.format("Plot%02d", plotIndex))
end

function WorldService.GetBaseTemplate()
	return find("Bases", "BaseTemplate")
end

function WorldService.GetPlotSpawnCFrame(plotIndex)
	local plot = WorldService.GetPlotModel(plotIndex)
	if plot then
		local foundation = plot:FindFirstChild("Foundation")
		if foundation and foundation:IsA("BasePart") then
			return foundation.CFrame + Vector3.new(0, foundation.Size.Y / 2 + 4, 0)
		end
		local cf, _ = plot:GetBoundingBox()
		if cf then
			return cf + Vector3.new(0, 6, 0)
		end
	end
	return WorldService.GetSpawnCFrame()
end

function WorldService.GetMarketStall(stallName)
	return find("Map", "EggMarket", stallName .. "_Platform")
		or find("Map", "EggMarket", stallName .. "_Pedestal")
end

function WorldService.GetEggAsset(assetName)
	local assets = find("EggAssets")
	if not assets then
		return nil
	end
	return assets:FindFirstChild(assetName)
end

function WorldService.CloneEggAsset(assetName)
	local template = WorldService.GetEggAsset(assetName)
	if template then
		local clone = template:Clone()
		-- strip lights/particles from gameplay clones? keep them, they look great
		return clone
	end
	-- Procedural egg when the asset is missing
	local model = Instance.new("Model")
	model.Name = assetName or "Egg"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.4, 3.2, 2.4)
	body.Color = Color3.fromRGB(240, 230, 200)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Egg
	mesh.Scale = Vector3.new(2.4, 3.2, 2.4)
	mesh.Parent = body
	return model
end

function WorldService.SetPlotLabel(plotIndex, text)
	local plot = WorldService.GetPlotModel(plotIndex)
	if not plot then
		return
	end
	local labelPart = plot:FindFirstChild("PlotLabel")
	if not labelPart then
		return
	end
	local gui = labelPart:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return
	end
	local label = gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

function WorldService.GetVaultAnchor(plotIndex)
	-- Where thieves grab from / where the vault visual sits for a plot
	local plot = WorldService.GetPlotModel(plotIndex)
	if plot then
		local candidates = { "VaultAreaFloor", "VaultAreaDoor", "DisplayPlatform", "EggPedestal1", "Foundation" }
		for _, name in ipairs(candidates) do
			local part = plot:FindFirstChild(name, true)
			if part and part:IsA("BasePart") then
				return part
			end
		end
	end
	return nil
end

function WorldService.GetHeistVaultDoor()
	return find("Map", "HeistArea", "VaultDoor")
end

--------------------------------------------------------------------------------
-- Lighting presets for events
--------------------------------------------------------------------------------

function WorldService.ApplyLighting(preset)
	if not preset then
		return
	end
	if preset.ClockTime then
		Lighting.ClockTime = preset.ClockTime
	end
	if preset.Brightness then
		Lighting.Brightness = preset.Brightness
	end
	if preset.Ambient then
		Lighting.Ambient = preset.Ambient
	end
end

function WorldService.RestoreLighting()
	Lighting.ClockTime = defaultLighting.ClockTime
	Lighting.Brightness = defaultLighting.Brightness
	Lighting.Ambient = defaultLighting.Ambient
	Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
end

function WorldService.Start()
	-- Void failsafe: nobody should ever fall forever
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp.Position.Y < -80 then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						hrp.CFrame = WorldService.GetSpawnCFrame()
						hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					end
				end
			end
		end
	end)
end

return WorldService
