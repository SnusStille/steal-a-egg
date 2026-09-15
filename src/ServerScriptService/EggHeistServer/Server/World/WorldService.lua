-- EggHeist | Server/World/WorldService.lua
-- Discovers the existing world (workspace.EggHeist) and wires gameplay onto it.
-- If the world model is missing, builds a complete procedural fallback world
-- so the game ALWAYS runs. Never destroys existing content.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings"))
local Eggs = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))

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

local ASSET_COLORS = {
	BasicEgg = Color3.fromRGB(240, 230, 200), StoneEgg = Color3.fromRGB(130, 130, 130),
	GoldenEgg = Color3.fromRGB(255, 200, 60), CrystalEgg = Color3.fromRGB(150, 220, 255),
	LavaEgg = Color3.fromRGB(255, 100, 40), ToxicEgg = Color3.fromRGB(120, 255, 60),
	ShadowEgg = Color3.fromRGB(70, 50, 120), GalaxyEgg = Color3.fromRGB(150, 80, 255),
	AncientEgg = Color3.fromRGB(200, 170, 120), VoidEgg = Color3.fromRGB(25, 15, 45),
}

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
	-- Directory: where is everything?
	mkSign(spawn, "DirectoryBoard", CFrame.new(-14, 6, 14), "MARKET -> EAST   BASES -> NORTH",
		Color3.fromRGB(160, 220, 255), Vector3.new(16, 3, 1))
	mkSign(spawn, "DirectoryBoard2", CFrame.new(14, 6, 14), "HEIST v SOUTH   EVENTS <- WEST",
		Color3.fromRGB(255, 200, 160), Vector3.new(16, 3, 1))
	-- Tutorial totems: the first 10 minutes, on signs
	local guides = {
		{ "Guide1", "1 CLAIM A BASE: walk north, touch a green plot, press CLAIM" },
		{ "Guide2", "2 BUY AN EGG: open SHOP (top buttons)" },
		{ "Guide3", "3 HATCH + EQUIP: open BACKPACK, hatch, then EQUIP" },
		{ "Guide4", "4 HEIST!: breach enemy vaults, escape SOUTH to EXTRACTION" },
	}
	for i, guide in ipairs(guides) do
		local gx = -15 + (i - 1) * 10
		mkPart(spawn, guide[1] .. "Post", Vector3.new(1, 5, 1), CFrame.new(gx, 3, -8),
			Color3.fromRGB(90, 70, 50))
		mkSign(spawn, guide[1], CFrame.new(gx, 6.5, -8), guide[2],
			Color3.fromRGB(255, 255, 255), Vector3.new(9, 3, 1))
	end
	-- Fountain centerpiece
	mkPart(spawn, "FountainBasin", Vector3.new(8, 1.2, 8), CFrame.new(0, 1.8, 4),
		Color3.fromRGB(120, 120, 140))
	mkPart(spawn, "FountainWater", Vector3.new(7, 0.5, 7), CFrame.new(0, 2.4, 4),
		Color3.fromRGB(80, 170, 255), Enum.Material.Glass)
	mkPart(spawn, "FountainSpout", Vector3.new(1, 3, 1), CFrame.new(0, 3.4, 4),
		Color3.fromRGB(120, 120, 140))
	-- Flag poles
	for _, fx in ipairs({ -17, 17 }) do
		mkPart(spawn, "FlagPole" .. tostring(fx), Vector3.new(0.6, 12, 0.6), CFrame.new(fx, 7, 17),
			Color3.fromRGB(80, 80, 90))
		mkPart(spawn, "Flag" .. tostring(fx), Vector3.new(4, 2.5, 0.3), CFrame.new(fx + 2, 11, 17),
			FALLBACK_COLORS.Accent)
	end

	-- Market (6 stalls)
	local market = Instance.new("Folder")
	market.Name = "EggMarket"
	market.Parent = mapFolder
	mkPart(market, "MarketFloor", Vector3.new(60, 2, 30), CFrame.new(90, 0, 0), FALLBACK_COLORS.Market)
	mkSign(market, "MarketArchLabel", CFrame.new(90, 9, -13), "EGG MARKET", Color3.fromRGB(255, 255, 255))
	-- Arch pillars under the label
	mkPart(market, "ArchPillarL", Vector3.new(2, 8, 2), CFrame.new(78, 4, -13), FALLBACK_COLORS.Floor)
	mkPart(market, "ArchPillarR", Vector3.new(2, 8, 2), CFrame.new(102, 4, -13), FALLBACK_COLORS.Floor)
	mkPart(market, "ArchBeam", Vector3.new(26, 2, 2), CFrame.new(90, 8.6, -13), FALLBACK_COLORS.Accent)
	-- One stall per purchasable egg: platform + pedestal + egg display + price sign
	local shopEggs = Eggs.GetShopEggs and Eggs.GetShopEggs() or {}
	for i, def in ipairs(shopEggs) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local x = 67.5 + col * 15
		local z = -6 + row * 12
		mkPart(market, def.Id .. "_Platform", Vector3.new(12, 1, 9), CFrame.new(x, 1.2, z),
			FALLBACK_COLORS.Accent)
		mkPart(market, def.Id .. "_Pedestal", Vector3.new(3, 2.5, 3), CFrame.new(x, 2.8, z),
			FALLBACK_COLORS.Floor)
		local display = mkEggModel(market, def.Id .. "_Display",
			ASSET_COLORS[def.AssetModel or ""] or Color3.fromRGB(240, 230, 200), false)
		local body = display:FindFirstChild("Body")
		if body then
			body.CFrame = CFrame.new(x, 5.5, z)
		end
		local priceText = string.upper(def.DisplayName or def.Id)
			.. " $" .. tostring(def.Price or 0) .. " Lv" .. tostring(def.RequiredLevel or 1)
		mkSign(market, def.Id .. "_PriceLabel", CFrame.new(x, 8.5, z - 3.4), priceText,
			Color3.fromRGB(255, 255, 255), Vector3.new(13, 2.5, 1))
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
	-- Cover crates (thieves sneak between these)
	local crates = { { -14, 110, 4 }, { 14, 110, 4 }, { -18, 124, 5 }, { 18, 124, 5 }, { -8, 134, 3 }, { 8, 134, 3 } }
	for i, crate in ipairs(crates) do
		mkPart(heist, "Crate" .. tostring(i), Vector3.new(crate[3], crate[3], crate[3]),
			CFrame.new(crate[1], 1 + crate[3] / 2, crate[2]), Color3.fromRGB(120, 95, 60))
	end
	-- Searchlight poles + hazard strips
	for _, sx in ipairs({ -22, 22 }) do
		mkPart(heist, "LightPole" .. tostring(sx), Vector3.new(1, 12, 1), CFrame.new(sx, 7, 120),
			Color3.fromRGB(60, 60, 70))
		mkPart(heist, "LightHead" .. tostring(sx), Vector3.new(3, 1.5, 3), CFrame.new(sx, 13, 120),
			Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	end
	mkPart(heist, "HazardStripW", Vector3.new(1, 2.2, 50), CFrame.new(-24, 0.1, 120),
		Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	mkPart(heist, "HazardStripE", Vector3.new(1, 2.2, 50), CFrame.new(24, 0.1, 120),
		Color3.fromRGB(255, 220, 60), Enum.Material.Neon)

	-- Event stage
	local eventArea = Instance.new("Folder")
	eventArea.Name = "EventArea"
	eventArea.Parent = mapFolder
	mkPart(eventArea, "EventFloor", Vector3.new(44, 2, 44), CFrame.new(-90, 0, 0), FALLBACK_COLORS.Event)
	mkPart(eventArea, "EventStage", Vector3.new(16, 3, 16), CFrame.new(-90, 1.5, 0), FALLBACK_COLORS.Accent)
	mkSign(eventArea, "EventAreaLabel", CFrame.new(-90, 10, -18), "EVENT GROUNDS", Color3.fromRGB(220, 180, 255))
	-- Seating steps facing the stage
	for i = 1, 3 do
		mkPart(eventArea, "SeatStep" .. tostring(i), Vector3.new(24, 1, 3),
			CFrame.new(-90, 1 + i * 0.5, 12 + i * 3), FALLBACK_COLORS.Floor)
	end
	-- Banner poles
	local bannerColors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(150, 120, 255),
		Color3.fromRGB(200, 60, 60), Color3.fromRGB(80, 220, 120) }
	local bannerPos = { { -108, -16 }, { -72, -16 }, { -108, 16 }, { -72, 16 } }
	for i, pos in ipairs(bannerPos) do
		mkPart(eventArea, "BannerPole" .. tostring(i), Vector3.new(0.8, 10, 0.8),
			CFrame.new(pos[1], 6, pos[2]), Color3.fromRGB(70, 70, 80))
		mkPart(eventArea, "Banner" .. tostring(i), Vector3.new(4, 2.5, 0.3),
			CFrame.new(pos[1] + 2, 9.5, pos[2]), bannerColors[i])
	end
	-- Event board: EventService writes the live event name here
	mkSign(eventArea, "EventBoard", CFrame.new(-90, 7, -14), "NEXT EVENT: soon...",
		Color3.fromRGB(220, 200, 255), Vector3.new(18, 4, 1))

	-- Bases
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = root
	local template = Instance.new("Model")
	template.Name = "BaseTemplate"
	template.Parent = bases
	mkPart(template, "Foundation", Vector3.new(36, 2, 36), CFrame.new(0, -30, -160), FALLBACK_COLORS.Plot)
	-- Vault house, built on claim: 3 walls + roof + safe + trigger floor + upgrade pads.
	-- Template coords map to plot-relative: (dx, 30 + dy, -160 + dz).
	mkPart(template, "VaultAreaFloor", Vector3.new(10, 2, 10), CFrame.new(8, 31, -165),
		Color3.fromRGB(150, 60, 60))
	mkPart(template, "VaultSafe", Vector3.new(4, 5, 4), CFrame.new(8, 34.5, -165),
		Color3.fromRGB(45, 45, 55))
	mkPart(template, "VaultTrim", Vector3.new(4.6, 0.6, 4.6), CFrame.new(8, 37.2, -165),
		Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
	mkPart(template, "HouseBack", Vector3.new(14, 8, 1), CFrame.new(8, 35, -171),
		Color3.fromRGB(190, 160, 130))
	mkPart(template, "HouseLeft", Vector3.new(1, 8, 9), CFrame.new(1, 35, -167),
		Color3.fromRGB(190, 160, 130))
	mkPart(template, "HouseRight", Vector3.new(1, 8, 9), CFrame.new(15, 35, -167),
		Color3.fromRGB(190, 160, 130))
	mkPart(template, "HouseRoof", Vector3.new(16, 1, 11), CFrame.new(8, 39.5, -167),
		Color3.fromRGB(140, 60, 60))
	for slot = 1, 3 do
		mkPart(template, "UpgradeSlot" .. tostring(slot), Vector3.new(4, 0.6, 4),
			CFrame.new(-15 + slot * 5, 31.3, -154), FALLBACK_COLORS.Accent).CanCollide = false
	end
	for i = 1, Settings.MaxBasePlots do
		local plot = Instance.new("Model")
		plot.Name = string.format("Plot%02d", i)
		plot.Parent = bases
		local x = -140 + (i - 1) * 40
		mkPart(plot, "Foundation", Vector3.new(36, 2, 36), CFrame.new(x, 0, -90), FALLBACK_COLORS.Plot)
		mkSign(plot, "PlotLabel", CFrame.new(x, 8, -106), string.format("Plot%02d", i),
			Color3.fromRGB(200, 255, 200), Vector3.new(10, 3, 1))
		mkPart(plot, "EggPedestal1", Vector3.new(3, 3, 3), CFrame.new(x - 8, 2.5, -90), FALLBACK_COLORS.Accent)
		-- Low boundary walls (jumpable; tinted by security purchases)
		mkPart(plot, "BoundaryWall1", Vector3.new(36, 3, 1), CFrame.new(x, 1.5, -108),
			FALLBACK_COLORS.Plot)
		mkPart(plot, "BoundaryWall2", Vector3.new(1, 3, 36), CFrame.new(x + 18, 1.5, -90),
			FALLBACK_COLORS.Plot)
		mkPart(plot, "BoundaryWall3", Vector3.new(1, 3, 36), CFrame.new(x - 18, 1.5, -90),
			FALLBACK_COLORS.Plot)
		mkPart(plot, "BoundaryWall4", Vector3.new(36, 3, 1), CFrame.new(x, 1.5, -72),
			FALLBACK_COLORS.Plot)
		-- Claim totem: BaseService attaches the "Claim Base" prompt here
		mkPart(plot, "ClaimTotem", Vector3.new(2, 5, 2), CFrame.new(x - 14, 2.5, -76),
			Color3.fromRGB(90, 200, 120), Enum.Material.Neon)
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
	mkPart(decorations, "PathToEvent", Vector3.new(50, 1, 6), CFrame.new(-45, -0.5, 0), FALLBACK_COLORS.Path)
	mkPart(decorations, "PathToBases", Vector3.new(6, 1, 52), CFrame.new(0, -0.5, -46), FALLBACK_COLORS.Path)
	mkPart(decorations, "BaseRowRoad", Vector3.new(300, 1, 8), CFrame.new(0, -0.5, -70), FALLBACK_COLORS.Path)
	-- World boundary fence (keeps players inside the map)
	mkPart(decorations, "BoundaryN", Vector3.new(364, 12, 4), CFrame.new(0, 6, -140),
		Color3.fromRGB(90, 140, 90))
	mkPart(decorations, "BoundaryS", Vector3.new(364, 12, 4), CFrame.new(0, 6, 180),
		Color3.fromRGB(90, 140, 90))
	mkPart(decorations, "BoundaryW", Vector3.new(4, 12, 324), CFrame.new(-182, 6, 20),
		Color3.fromRGB(90, 140, 90))
	mkPart(decorations, "BoundaryE", Vector3.new(4, 12, 324), CFrame.new(182, 6, 20),
		Color3.fromRGB(90, 140, 90))
	-- Pond between plaza and market
	mkPart(decorations, "PondRim", Vector3.new(16, 1, 16), CFrame.new(48, -0.4, 52),
		Color3.fromRGB(210, 190, 140))
	mkPart(decorations, "PondWater", Vector3.new(14, 0.6, 14), CFrame.new(48, 0.1, 52),
		Color3.fromRGB(70, 160, 255), Enum.Material.Glass)
	-- Trees + rocks scattered on the grass (kept clear of districts and roads)
	local treeSpots = {
		{ -40, -30 }, { -60, 40 }, { -30, 70 }, { 40, -35 }, { 60, 45 }, { 30, 80 },
		{ -120, 50 }, { 130, 60 }, { -150, -30 }, { 150, -30 }, { -60, -60 }, { 60, -60 },
		{ -100, 100 }, { 100, 100 }, { -40, 150 }, { 40, 150 }, { -160, 90 }, { 160, 90 },
		{ -100, -50 }, { 100, -50 },
	}
	for i, spot in ipairs(treeSpots) do
		mkPart(decorations, "TreeTrunk" .. tostring(i), Vector3.new(1.5, 5, 1.5),
			CFrame.new(spot[1], 2.5, spot[2]), Color3.fromRGB(110, 80, 55))
		mkPart(decorations, "TreeLeaves" .. tostring(i), Vector3.new(5, 5, 5),
			CFrame.new(spot[1], 7, spot[2]), Color3.fromRGB(60, 160, 70), Enum.Material.Grass).Shape = Enum.PartType.Ball
	end
	local rockSpots = { { -25, 45 }, { 25, -55 }, { -75, 75 }, { 75, 30 }, { -130, 10 }, { 140, 90 }, { 55, 140 }, { -55, -110 } }
	for i, spot in ipairs(rockSpots) do
		mkPart(decorations, "Rock" .. tostring(i), Vector3.new(3, 2.5, 3),
			CFrame.new(spot[1], 1, spot[2]), Color3.fromRGB(140, 140, 150), Enum.Material.Slate).Shape = Enum.PartType.Ball
	end
	-- Clouds
	local cloudSpots = { { -60, 70, 60 }, { 60, 80, 40 }, { 0, 75, -60 }, { -120, 70, 90 }, { 120, 72, 100 } }
	for i, spot in ipairs(cloudSpots) do
		local cloud = mkPart(decorations, "Cloud" .. tostring(i), Vector3.new(22, 6, 14),
			CFrame.new(spot[1], spot[2], spot[3]), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		cloud.Shape = Enum.PartType.Ball
		cloud.CanCollide = false
		cloud.Anchored = true
		cloud.Transparency = 0.35
	end
	-- Lamp posts along the roads (every 3rd one glows, to save performance)
	local lampSpots = { { 20, 8 }, { 45, -8 }, { 70, 8 }, { 8, 35 }, { -8, 80 }, { -20, -8 }, { -45, 8 }, { -70, -8 }, { 8, -40 }, { -60, -66 }, { 60, -66 } }
	for i, spot in ipairs(lampSpots) do
		mkPart(decorations, "LampPost" .. tostring(i), Vector3.new(0.8, 8, 0.8),
			CFrame.new(spot[1], 4, spot[2]), Color3.fromRGB(50, 50, 60))
		local head = mkPart(decorations, "LampHead" .. tostring(i), Vector3.new(2, 1.5, 2),
			CFrame.new(spot[1], 8.7, spot[2]), Color3.fromRGB(255, 235, 180), Enum.Material.Neon)
		if i % 3 == 1 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 230, 170)
			light.Range = 22
			light.Brightness = 1.5
			light.Parent = head
		end
	end
	-- Welcome rugs where the NPCs stand
	mkPart(decorations, "NpcRugMarket", Vector3.new(7, 0.3, 7), CFrame.new(90, 1.15, 12),
		Color3.fromRGB(180, 60, 60)).CanCollide = false
	mkPart(decorations, "NpcRugHeist", Vector3.new(7, 0.3, 7), CFrame.new(-14, 1.15, 108),
		Color3.fromRGB(60, 60, 180)).CanCollide = false
	mkPart(decorations, "NpcRugEvent", Vector3.new(7, 0.3, 7), CFrame.new(-90, 1.15, 12),
		Color3.fromRGB(120, 60, 180)).CanCollide = false
	-- Warm afternoon lighting for the fallback map
	pcall(function()
		local Lighting = game:GetService("Lighting")
		Lighting.ClockTime = 14.5
		Lighting.Brightness = 2.2
		Lighting.Ambient = Color3.fromRGB(120, 120, 130)
		if not Lighting:FindFirstChild("EggHeistAtmosphere") then
			local atmosphere = Instance.new("Atmosphere")
			atmosphere.Name = "EggHeistAtmosphere"
			atmosphere.Density = 0.25
			atmosphere.Haze = 4
			atmosphere.Parent = Lighting
		end
	end)

	-- Egg assets
	local assets = Instance.new("Folder")
	assets.Name = "EggAssets"
	assets.Parent = root
	for name, color in pairs(ASSET_COLORS) do
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
	-- Sky beacon so carriers can find the pad from anywhere
	if not gameplay:FindFirstChild("ExtractionBeacon") then
		local beacon = Instance.new("Part")
		beacon.Name = "ExtractionBeacon"
		beacon.Size = Vector3.new(3, 120, 3)
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.Material = Enum.Material.Neon
		beacon.Color = Color3.fromRGB(80, 255, 140)
		beacon.Transparency = 0.55
		beacon.TopSurface = Enum.SurfaceType.Smooth
		beacon.BottomSurface = Enum.SurfaceType.Smooth
		beacon.Parent = gameplay
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(80, 255, 140)
		light.Range = 40
		light.Parent = beacon
	end
	local beacon = gameplay:FindFirstChild("ExtractionBeacon")
	if beacon and beacon:IsA("BasePart") then
		beacon.CFrame = extractionPad.CFrame + Vector3.new(0, 60, 0)
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

--- Writes a line of text on the event board (Map/EventArea/EventBoard).
function WorldService.SetEventBoard(text)
	local root = Workspace:FindFirstChild("EggHeist")
	if not root then
		return false
	end
	local eventArea = root:FindFirstChild("Map")
	eventArea = eventArea and eventArea:FindFirstChild("EventArea")
	local board = eventArea and eventArea:FindFirstChild("EventBoard")
	local gui = board and board:FindFirstChild("SignGui")
	local label = gui and gui:FindFirstChild("SignText")
	if label and label:IsA("TextLabel") then
		label.Text = tostring(text)
		return true
	end
	return false
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
