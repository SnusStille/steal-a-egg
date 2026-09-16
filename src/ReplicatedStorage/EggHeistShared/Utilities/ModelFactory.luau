-- EggHeist | Shared/Utilities/ModelFactory.luau
-- CENTRAL ASSET PIPELINE: builds every egg + creature model in the game.
-- Server uses it for placed eggs, followers and base displays; the client
-- uses it for ViewportFrame icons (shop/inventory/collection/hatch).
-- Fully procedural: zero uploaded assets required.
--
-- Sim-safe: rotations use CFrame.fromEulerAnglesXYZ (stubbed), no UDim2
-- math, no Lerp, property sets only.

local Workspace = game:GetService("Workspace")

local ModelFactory = {}

local EGG_FALLBACK_COLORS = {
	Basic = Color3.fromRGB(240, 230, 200), Stone = Color3.fromRGB(130, 130, 130),
	Golden = Color3.fromRGB(255, 200, 60), Crystal = Color3.fromRGB(150, 220, 255),
	Lava = Color3.fromRGB(255, 100, 40), Toxic = Color3.fromRGB(120, 255, 60),
	Shadow = Color3.fromRGB(70, 50, 120), Galaxy = Color3.fromRGB(150, 80, 255),
	Ancient = Color3.fromRGB(200, 170, 120), Void = Color3.fromRGB(25, 15, 45),
	Frost = Color3.fromRGB(200, 235, 255), Storm = Color3.fromRGB(90, 110, 200),
	Ember = Color3.fromRGB(255, 150, 80), Phantom = Color3.fromRGB(160, 140, 200),
}

-- Brick color name (Pets.BodyColor) -> Color3. Never errors.
function ModelFactory.ColorFromBrickName(name)
	local ok, color = pcall(function()
		return BrickColor.new(tostring(name or "")).Color
	end)
	if ok and color then
		return color
	end
	return Color3.fromRGB(200, 200, 200)
end

local function newPart(parent, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe or CFrame.new(0, 0, 0)
	part.Color = color or Color3.fromRGB(200, 200, 200)
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function tilt(pos, rx, ry, rz)
	return CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(rx or 0, ry or 0, rz or 0)
end

-- Cute 3D eyes on the face (-Z front). face = {y, z, spread}
local function addEyes(model, face, eyeSize)
	eyeSize = eyeSize or 0.42
	local white = Color3.fromRGB(255, 255, 255)
	local pupil = Color3.fromRGB(25, 25, 30)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (face.spread or 0.55)
		newPart(model, side < 0 and "EyeL" or "EyeR",
			Vector3.new(eyeSize, eyeSize, 0.3),
			CFrame.new(Vector3.new(x, face.y, face.z)), white, nil, Enum.PartType.Ball)
		newPart(model, side < 0 and "PupilL" or "PupilR",
			Vector3.new(eyeSize * 0.5, eyeSize * 0.5, 0.2),
			CFrame.new(Vector3.new(x, face.y, face.z - 0.18)), pupil, nil, Enum.PartType.Ball)
	end
end

-- Small helpers shared by builders
local function addFeet(model, color, y, spread, size)
	size = size or 0.5
	for _, side in ipairs({ -1, 1 }) do
		newPart(model, side < 0 and "FootL" or "FootR",
			Vector3.new(size, size * 0.7, size * 1.3),
			CFrame.new(Vector3.new(side * spread, y, 0.2)),
			color, nil, Enum.PartType.Ball)
	end
end

local function addSparkles(part, color)
	local ok, sparkles = pcall(function()
		local s = Instance.new("Sparkles")
		s.SparkleColor = color
		s.Parent = part
		return s
	end)
	if ok then
		return sparkles
	end
	return nil
end

--------------------------------------------------------------------------------
-- Creature archetype builders. C = { body, accent, dark }. All roughly
-- 2-3 studs tall at scale 1, facing -Z.
--------------------------------------------------------------------------------

local builders = {}

function builders.chick(model, C)
	local body = newPart(model, "Body", Vector3.new(1.8, 2.2, 1.8),
		CFrame.new(0, 1.4, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Beak", Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(Vector3.new(0, 1.35, -1.05)), Color3.fromRGB(255, 160, 40), nil, Enum.PartType.Ball)
	newPart(model, "WingL", Vector3.new(0.4, 1.1, 0.9),
		tilt(Vector3.new(-1.0, 1.3, 0), 0, 0, 0.35), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "WingR", Vector3.new(0.4, 1.1, 0.9),
		tilt(Vector3.new(1.0, 1.3, 0), 0, 0, -0.35), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "Tuft", Vector3.new(0.5, 0.6, 0.5),
		CFrame.new(Vector3.new(0, 2.7, 0)), C.accent, nil, Enum.PartType.Ball)
	addFeet(model, Color3.fromRGB(255, 160, 40), 0.2, 0.5, 0.5)
	addEyes(model, { y = 1.7, z = -0.95, spread = 0.45 }, 0.4)
	return body
end

function builders.bunny(model, C)
	local body = builders.chick(model, C)
	newPart(model, "EarL", Vector3.new(0.45, 1.5, 0.45),
		tilt(Vector3.new(-0.45, 3.4, 0), 0, 0, 0.18), C.body, nil, Enum.PartType.Cylinder)
	newPart(model, "EarR", Vector3.new(0.45, 1.5, 0.45),
		tilt(Vector3.new(0.45, 3.4, 0), 0, 0, -0.18), C.body, nil, Enum.PartType.Cylinder)
	newPart(model, "EarTipL", Vector3.new(0.28, 0.7, 0.28),
		tilt(Vector3.new(-0.58, 3.9, 0), 0, 0, 0.18), C.accent, nil, Enum.PartType.Cylinder)
	newPart(model, "EarTipR", Vector3.new(0.28, 0.7, 0.28),
		tilt(Vector3.new(0.58, 3.9, 0), 0, 0, -0.18), C.accent, nil, Enum.PartType.Cylinder)
	return body
end

function builders.blob(model, C, params)
	local body = newPart(model, "Body", Vector3.new(2.2, 1.9, 2.2),
		CFrame.new(0, 1.1, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Belly", Vector3.new(1.4, 1.2, 0.6),
		CFrame.new(Vector3.new(0, 0.9, -0.95)), C.accent, nil, Enum.PartType.Ball)
	addFeet(model, C.dark, 0.15, 0.7, 0.55)
	addEyes(model, { y = 1.5, z = -1.05, spread = 0.5 }, 0.44)
	if params and params.Stem then
		newPart(model, "Stem", Vector3.new(0.3, 0.9, 0.3),
			CFrame.new(Vector3.new(0, 2.4, 0)), Color3.fromRGB(60, 150, 70))
		newPart(model, "Leaf", Vector3.new(0.9, 0.25, 0.5),
			tilt(Vector3.new(0.45, 2.7, 0), 0, 0, -0.5), Color3.fromRGB(80, 200, 90))
	end
	return body
end

function builders.rock(model, C)
	local body = newPart(model, "Body", Vector3.new(2.2, 1.9, 2.0),
		CFrame.new(0, 1.1, 0), C.body, Enum.Material.Slate)
	newPart(model, "BumpT", Vector3.new(1.0, 0.8, 1.0),
		CFrame.new(Vector3.new(-0.5, 2.2, 0.2)), C.dark, Enum.Material.Slate)
	newPart(model, "BumpS", Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(Vector3.new(1.2, 1.4, 0.3)), C.dark, Enum.Material.Slate, Enum.PartType.Ball)
	newPart(model, "Moss", Vector3.new(1.2, 0.4, 1.2),
		CFrame.new(Vector3.new(0.4, 2.1, -0.3)), C.accent, Enum.Material.Grass)
	addFeet(model, C.dark, 0.15, 0.7, 0.55)
	addEyes(model, { y = 1.35, z = -1.05, spread = 0.5 }, 0.42)
	return body
end

function builders.shroom(model, C)
	newPart(model, "Stem", Vector3.new(1.2, 1.4, 1.2),
		CFrame.new(0, 0.9, 0), Color3.fromRGB(240, 230, 215), nil, Enum.PartType.Cylinder)
	local body = newPart(model, "Body", Vector3.new(2.6, 1.4, 2.6),
		CFrame.new(0, 2.2, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Spot1", Vector3.new(0.6, 0.4, 0.6),
		CFrame.new(Vector3.new(-0.7, 2.8, -0.5)), Color3.fromRGB(255, 255, 255), nil, Enum.PartType.Ball)
	newPart(model, "Spot2", Vector3.new(0.45, 0.35, 0.45),
		CFrame.new(Vector3.new(0.6, 2.9, 0.4)), Color3.fromRGB(255, 255, 255), nil, Enum.PartType.Ball)
	addEyes(model, { y = 1.1, z = -0.65, spread = 0.35 }, 0.34)
	return body
end

function builders.bot(model, C)
	local body = newPart(model, "Body", Vector3.new(1.9, 1.9, 1.6),
		CFrame.new(0, 1.4, 0), C.body, Enum.Material.Metal)
	newPart(model, "Core", Vector3.new(0.8, 0.8, 0.3),
		CFrame.new(Vector3.new(0, 1.2, -0.85)), C.accent, Enum.Material.Neon, Enum.PartType.Ball)
	newPart(model, "Antenna", Vector3.new(0.2, 0.9, 0.2),
		CFrame.new(Vector3.new(0, 2.8, 0)), C.dark, Enum.Material.Metal)
	newPart(model, "AntennaTip", Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(Vector3.new(0, 3.3, 0)), C.accent, Enum.Material.Neon, Enum.PartType.Ball)
	newPart(model, "ArmL", Vector3.new(0.45, 1.3, 0.45),
		CFrame.new(Vector3.new(-1.2, 1.3, 0)), C.dark, Enum.Material.Metal)
	newPart(model, "ArmR", Vector3.new(0.45, 1.3, 0.45),
		CFrame.new(Vector3.new(1.2, 1.3, 0)), C.dark, Enum.Material.Metal)
	newPart(model, "WheelL", Vector3.new(0.6, 0.6, 0.4),
		CFrame.new(Vector3.new(-0.6, 0.3, 0)), C.dark, nil, Enum.PartType.Cylinder)
	newPart(model, "WheelR", Vector3.new(0.6, 0.6, 0.4),
		CFrame.new(Vector3.new(0.6, 0.3, 0)), C.dark, nil, Enum.PartType.Cylinder)
	addEyes(model, { y = 1.9, z = -0.85, spread = 0.45 }, 0.36)
	return body
end

local function drakeHead(model, C, basePos, name)
	local head = newPart(model, name, Vector3.new(1.1, 1.0, 1.1),
		CFrame.new(basePos), C.body, nil, Enum.PartType.Ball)
	newPart(model, name .. "Snout", Vector3.new(0.7, 0.55, 0.6),
		CFrame.new(basePos + Vector3.new(0, -0.15, -0.7)), C.accent, nil, Enum.PartType.Ball)
	newPart(model, name .. "HornL", Vector3.new(0.3, 0.8, 0.3),
		tilt(basePos + Vector3.new(-0.4, 0.75, 0.2), 0, 0, 0.4), C.accent)
	newPart(model, name .. "HornR", Vector3.new(0.3, 0.8, 0.3),
		tilt(basePos + Vector3.new(0.4, 0.75, 0.2), 0, 0, -0.4), C.accent)
	-- eyes sit on the head: white + pupils positioned absolutely
	local white = Color3.fromRGB(255, 255, 255)
	local pupil = Color3.fromRGB(25, 25, 30)
	for _, side in ipairs({ -1, 1 }) do
		local x = basePos.X + side * 0.28
		newPart(model, name .. (side < 0 and "EyeL" or "EyeR"),
			Vector3.new(0.3, 0.3, 0.2), CFrame.new(Vector3.new(x, basePos.Y + 0.15, basePos.Z - 0.55)),
			white, nil, Enum.PartType.Ball)
		newPart(model, name .. (side < 0 and "PupilL" or "PupilR"),
			Vector3.new(0.15, 0.15, 0.15), CFrame.new(Vector3.new(x, basePos.Y + 0.15, basePos.Z - 0.68)),
			pupil, nil, Enum.PartType.Ball)
	end
	return head
end

function builders.drake(model, C, params)
	local body = newPart(model, "Body", Vector3.new(1.9, 1.7, 2.2),
		CFrame.new(0, 1.2, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Belly", Vector3.new(1.3, 1.2, 0.6),
		CFrame.new(Vector3.new(0, 1.0, -1.0)), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "WingL", Vector3.new(0.25, 1.6, 1.4),
		tilt(Vector3.new(-1.3, 1.9, 0.3), 0, 0.25, 0.5), C.accent)
	newPart(model, "WingR", Vector3.new(0.25, 1.6, 1.4),
		tilt(Vector3.new(1.3, 1.9, 0.3), 0, -0.25, -0.5), C.accent)
	newPart(model, "Tail", Vector3.new(0.6, 0.6, 1.6),
		tilt(Vector3.new(0, 0.9, 1.6), 0.5, 0, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Spike1", Vector3.new(0.35, 0.7, 0.35),
		CFrame.new(Vector3.new(0, 2.2, -0.3)), C.accent)
	newPart(model, "Spike2", Vector3.new(0.35, 0.7, 0.35),
		CFrame.new(Vector3.new(0, 2.0, 0.5)), C.accent)
	local heads = (params and params.Heads) or 1
	if heads <= 1 then
		drakeHead(model, C, Vector3.new(0, 2.7, -0.4), "Head")
	else
		newPart(model, "Neck", Vector3.new(1.4, 1.0, 0.8),
			CFrame.new(Vector3.new(0, 2.3, -0.3)), C.body, nil, Enum.PartType.Ball)
		drakeHead(model, C, Vector3.new(-0.9, 3.0, -0.4), "HeadL")
		drakeHead(model, C, Vector3.new(0, 3.2, -0.5), "HeadM")
		drakeHead(model, C, Vector3.new(0.9, 3.0, -0.4), "HeadR")
	end
	addFeet(model, C.dark, 0.2, 0.65, 0.55)
	return body
end

function builders.bird(model, C)
	local body = newPart(model, "Body", Vector3.new(1.5, 1.9, 1.7),
		CFrame.new(0, 1.4, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Head", Vector3.new(1.1, 1.0, 1.1),
		CFrame.new(Vector3.new(0, 2.7, -0.2)), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Beak", Vector3.new(0.45, 0.45, 0.6),
		CFrame.new(Vector3.new(0, 2.6, -0.95)), Color3.fromRGB(255, 170, 50), nil, Enum.PartType.Ball)
	newPart(model, "WingL", Vector3.new(0.3, 1.3, 1.0),
		tilt(Vector3.new(-0.95, 1.5, 0.1), 0, 0, 0.4), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "WingR", Vector3.new(0.3, 1.3, 1.0),
		tilt(Vector3.new(0.95, 1.5, 0.1), 0, 0, -0.4), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "Tail", Vector3.new(0.9, 0.25, 1.0),
		tilt(Vector3.new(0, 1.2, 1.2), -0.5, 0, 0), C.accent)
	newPart(model, "Crest", Vector3.new(0.3, 0.7, 0.3),
		CFrame.new(Vector3.new(0, 3.4, -0.2)), C.accent)
	-- head-mounted eyes
	local white = Color3.fromRGB(255, 255, 255)
	local pupil = Color3.fromRGB(25, 25, 30)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.3
		newPart(model, side < 0 and "EyeL" or "EyeR",
			Vector3.new(0.3, 0.3, 0.2), CFrame.new(Vector3.new(x, 2.9, -0.72)),
			white, nil, Enum.PartType.Ball)
		newPart(model, side < 0 and "PupilL" or "PupilR",
			Vector3.new(0.15, 0.15, 0.15), CFrame.new(Vector3.new(x, 2.9, -0.85)),
			pupil, nil, Enum.PartType.Ball)
	end
	addFeet(model, Color3.fromRGB(255, 170, 50), 0.2, 0.45, 0.45)
	return body
end

function builders.fish(model, C)
	local body = newPart(model, "Body", Vector3.new(1.4, 1.4, 2.2),
		CFrame.new(0, 1.4, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Tail", Vector3.new(0.25, 1.2, 0.9),
		tilt(Vector3.new(0, 1.4, 1.4), 0, 0, 0), C.accent)
	newPart(model, "FinTop", Vector3.new(0.25, 0.8, 0.7),
		CFrame.new(Vector3.new(0, 2.3, 0.2)), C.accent)
	newPart(model, "FinL", Vector3.new(0.7, 0.25, 0.5),
		tilt(Vector3.new(-0.85, 1.1, -0.2), 0, 0, 0.5), C.accent)
	newPart(model, "FinR", Vector3.new(0.7, 0.25, 0.5),
		tilt(Vector3.new(0.85, 1.1, -0.2), 0, 0, -0.5), C.accent)
	-- fish float: little bubble ring under them
	newPart(model, "Bubble", Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(Vector3.new(0.5, 0.4, 0)), Color3.fromRGB(180, 230, 255),
		Enum.Material.Glass, Enum.PartType.Ball)
	addEyes(model, { y = 1.6, z = -1.05, spread = 0.4 }, 0.36)
	return body
end

function builders.whale(model, C)
	local body = newPart(model, "Body", Vector3.new(2.6, 2.2, 3.4),
		CFrame.new(0, 1.7, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Belly", Vector3.new(1.8, 1.4, 2.2),
		CFrame.new(Vector3.new(0, 1.2, -0.3)), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "Tail", Vector3.new(1.4, 0.3, 1.0),
		tilt(Vector3.new(0, 2.2, 2.2), 0.4, 0, 0), C.accent)
	newPart(model, "FinL", Vector3.new(1.0, 0.3, 0.6),
		tilt(Vector3.new(-1.6, 1.2, -0.4), 0, 0, 0.5), C.accent)
	newPart(model, "FinR", Vector3.new(1.0, 0.3, 0.6),
		tilt(Vector3.new(1.6, 1.2, -0.4), 0, 0, -0.5), C.accent)
	newPart(model, "Spout", Vector3.new(0.4, 0.8, 0.4),
		CFrame.new(Vector3.new(0, 3.0, -0.6)), Color3.fromRGB(180, 230, 255), Enum.Material.Glass)
	addEyes(model, { y = 2.0, z = -1.6, spread = 0.75 }, 0.44)
	return body
end

function builders.golem(model, C)
	local body = newPart(model, "Body", Vector3.new(2.4, 2.4, 1.8),
		CFrame.new(0, 1.7, 0), C.body, Enum.Material.Slate)
	newPart(model, "Head", Vector3.new(1.4, 1.1, 1.3),
		CFrame.new(Vector3.new(0, 3.4, -0.1)), C.body, Enum.Material.Slate)
	newPart(model, "Core", Vector3.new(0.9, 0.9, 0.4),
		CFrame.new(Vector3.new(0, 1.9, -0.95)), C.accent, Enum.Material.Neon, Enum.PartType.Ball)
	newPart(model, "Brow", Vector3.new(1.5, 0.35, 0.3),
		CFrame.new(Vector3.new(0, 3.7, -0.75)), C.dark, Enum.Material.Slate)
	newPart(model, "ArmL", Vector3.new(0.7, 2.0, 0.7),
		CFrame.new(Vector3.new(-1.6, 1.6, 0)), C.dark, Enum.Material.Slate)
	newPart(model, "ArmR", Vector3.new(0.7, 2.0, 0.7),
		CFrame.new(Vector3.new(1.6, 1.6, 0)), C.dark, Enum.Material.Slate)
	newPart(model, "LegL", Vector3.new(0.8, 1.0, 0.8),
		CFrame.new(Vector3.new(-0.6, 0.5, 0)), C.dark, Enum.Material.Slate)
	newPart(model, "LegR", Vector3.new(0.8, 1.0, 0.8),
		CFrame.new(Vector3.new(0.6, 0.5, 0)), C.dark, Enum.Material.Slate)
	-- glowing golem eyes on the head
	for _, side in ipairs({ -1, 1 }) do
		newPart(model, side < 0 and "EyeL" or "EyeR",
			Vector3.new(0.32, 0.32, 0.2), CFrame.new(Vector3.new(side * 0.35, 3.4, -0.78)),
			C.accent, Enum.Material.Neon, Enum.PartType.Ball)
	end
	return body
end

function builders.ghost(model, C)
	local body = newPart(model, "Body", Vector3.new(1.9, 2.3, 1.9),
		CFrame.new(0, 1.6, 0), C.body, Enum.Material.Glass, Enum.PartType.Ball)
	body.Transparency = 0.25
	newPart(model, "Tail", Vector3.new(1.2, 1.0, 1.2),
		CFrame.new(Vector3.new(0, 0.4, 0)), C.body, Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.45
	newPart(model, "Halo", Vector3.new(1.4, 0.25, 1.4),
		CFrame.new(Vector3.new(0, 3.1, 0)), C.accent, Enum.Material.Neon, Enum.PartType.Ball)
	addEyes(model, { y = 1.9, z = -0.95, spread = 0.45 }, 0.42)
	return body
end

function builders.serpent(model, C)
	local body = newPart(model, "Body", Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(0, 2.6, -0.6), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Seg1", Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(Vector3.new(0, 1.7, 0.1)), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Seg2", Vector3.new(1.5, 1.2, 1.5),
		CFrame.new(Vector3.new(0, 0.9, 0.5)), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "Coil", Vector3.new(2.2, 0.8, 2.2),
		CFrame.new(Vector3.new(0, 0.4, 0.5)), C.dark, nil, Enum.PartType.Ball)
	newPart(model, "Tongue", Vector3.new(0.25, 0.15, 0.7),
		CFrame.new(Vector3.new(0, 2.3, -1.6)), Color3.fromRGB(255, 80, 120))
	newPart(model, "FinL", Vector3.new(0.25, 0.9, 0.7),
		tilt(Vector3.new(-0.9, 2.8, -0.5), 0, 0, 0.5), C.accent)
	newPart(model, "FinR", Vector3.new(0.25, 0.9, 0.7),
		tilt(Vector3.new(0.9, 2.8, -0.5), 0, 0, -0.5), C.accent)
	-- head-mounted eyes
	local white = Color3.fromRGB(255, 255, 255)
	local pupil = Color3.fromRGB(25, 25, 30)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.4
		newPart(model, side < 0 and "EyeL" or "EyeR",
			Vector3.new(0.34, 0.34, 0.2), CFrame.new(Vector3.new(x, 2.9, -1.3)),
			white, nil, Enum.PartType.Ball)
		newPart(model, side < 0 and "PupilL" or "PupilR",
			Vector3.new(0.17, 0.17, 0.15), CFrame.new(Vector3.new(x, 2.9, -1.42)),
			pupil, nil, Enum.PartType.Ball)
	end
	return body
end

function builders.moth(model, C)
	local body = newPart(model, "Body", Vector3.new(1.1, 1.5, 1.1),
		CFrame.new(0, 1.5, 0), C.body, nil, Enum.PartType.Ball)
	newPart(model, "WingL", Vector3.new(1.6, 2.0, 0.25),
		tilt(Vector3.new(-1.2, 1.7, 0.1), 0, 0.2, 0.35), C.accent)
	newPart(model, "WingR", Vector3.new(1.6, 2.0, 0.25),
		tilt(Vector3.new(1.2, 1.7, 0.1), 0, -0.2, -0.35), C.accent)
	newPart(model, "SpotL", Vector3.new(0.5, 0.5, 0.28),
		tilt(Vector3.new(-1.35, 1.9, 0.1), 0, 0.2, 0.35), C.body, nil, Enum.PartType.Ball)
	newPart(model, "SpotR", Vector3.new(0.5, 0.5, 0.28),
		tilt(Vector3.new(1.35, 1.9, 0.1), 0, -0.2, -0.35), C.body, nil, Enum.PartType.Ball)
	newPart(model, "AntennaL", Vector3.new(0.15, 0.8, 0.15),
		tilt(Vector3.new(-0.3, 2.6, 0), 0, 0, 0.4), C.dark)
	newPart(model, "AntennaR", Vector3.new(0.15, 0.8, 0.15),
		tilt(Vector3.new(0.3, 2.6, 0), 0, 0, -0.4), C.dark)
	addEyes(model, { y = 1.8, z = -0.55, spread = 0.3 }, 0.32)
	return body
end

function builders.pup(model, C, params)
	local body = newPart(model, "Body", Vector3.new(1.5, 1.3, 2.2),
		CFrame.new(0, 1.0, 0.2), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Head", Vector3.new(1.4, 1.3, 1.3),
		CFrame.new(Vector3.new(0, 1.9, -0.8)), C.body, nil, Enum.PartType.Ball)
	newPart(model, "Snout", Vector3.new(0.7, 0.55, 0.5),
		CFrame.new(Vector3.new(0, 1.7, -1.6)), C.accent, nil, Enum.PartType.Ball)
	newPart(model, "Nose", Vector3.new(0.3, 0.3, 0.25),
		CFrame.new(Vector3.new(0, 1.85, -1.9)), Color3.fromRGB(30, 30, 35), nil, Enum.PartType.Ball)
	local earStyle = params and params.Ears or "floppy"
	if earStyle == "crown" then
		newPart(model, "Crown", Vector3.new(0.9, 0.5, 0.9),
			CFrame.new(Vector3.new(0, 2.8, -0.8)), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	else
		local tiltAmt = (earStyle == "pointy") and 0 or 0.5
		local earH = (earStyle == "pointy") and 1.1 or 0.9
		newPart(model, "EarL", Vector3.new(0.45, earH, 0.4),
			tilt(Vector3.new(-0.55, 2.7, -0.7), 0, 0, tiltAmt), C.dark, nil, Enum.PartType.Ball)
		newPart(model, "EarR", Vector3.new(0.45, earH, 0.4),
			tilt(Vector3.new(0.55, 2.7, -0.7), 0, 0, -tiltAmt), C.dark, nil, Enum.PartType.Ball)
	end
	newPart(model, "Tail", Vector3.new(0.35, 0.9, 0.35),
		tilt(Vector3.new(0, 1.4, 1.4), 0.6, 0, 0), C.body, nil, Enum.PartType.Ball)
	for i, leg in ipairs({ "LegFL", "LegFR", "LegBL", "LegBR" }) do
		local sx = (i % 2 == 1) and -0.55 or 0.55
		local sz = (i <= 2) and -0.5 or 1.0
		newPart(model, leg, Vector3.new(0.45, 0.8, 0.45),
			CFrame.new(Vector3.new(sx, 0.4, sz)), C.dark, nil, Enum.PartType.Ball)
	end
	-- head-mounted eyes
	local white = Color3.fromRGB(255, 255, 255)
	local pupil = Color3.fromRGB(25, 25, 30)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.38
		newPart(model, side < 0 and "EyeL" or "EyeR",
			Vector3.new(0.32, 0.32, 0.2), CFrame.new(Vector3.new(x, 2.15, -1.4)),
			white, nil, Enum.PartType.Ball)
		newPart(model, side < 0 and "PupilL" or "PupilR",
			Vector3.new(0.16, 0.16, 0.15), CFrame.new(Vector3.new(x, 2.15, -1.52)),
			pupil, nil, Enum.PartType.Ball)
	end
	return body
end

function builders.kraken(model, C)
	local body = builders.blob(model, C)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local x, z = math.cos(angle) * 1.4, math.sin(angle) * 1.4
		newPart(model, "Tent" .. i, Vector3.new(0.5, 0.9, 0.5),
			tilt(Vector3.new(x, 0.45, z), z * 0.3, 0, -x * 0.3), C.accent, nil, Enum.PartType.Ball)
	end
	return body
end

ModelFactory.Builders = builders

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function ModelFactory.GetPets()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:FindFirstChild("EggHeistShared")
	local folder = Shared and Shared:FindFirstChild("Config")
	local mod = folder and folder:FindFirstChild("Pets")
	if mod then
		local ok, pets = pcall(require, mod)
		if ok then
			return pets
		end
	end
	return nil
end

function ModelFactory.GetCreatureDef(petId)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:FindFirstChild("EggHeistShared")
	local folder = Shared and Shared:FindFirstChild("Config")
	local mod = folder and folder:FindFirstChild("CreatureModels")
	if mod then
		local ok, models = pcall(require, mod)
		if ok and models then
			return models.Get(petId)
		end
	end
	return nil
end

local function accentFor(petId, params)
	if params and params.Acc then
		return Color3.fromRGB(params.Acc[1], params.Acc[2], params.Acc[3])
	end
	-- default accent: lighter version of body color
	local pets = ModelFactory.GetPets()
	local def = pets and pets.ById[petId] or nil
	local body = ModelFactory.ColorFromBrickName(def and def.BodyColor or nil)
	return Color3.new(
		math.min(1, body.R + 0.25),
		math.min(1, body.G + 0.25),
		math.min(1, body.B + 0.25))
end

--- Builds a creature model for a pet id (+ optional mutation). Never errors:
--- unknown pets become a gray blob.
function ModelFactory.BuildCreature(petId, mutation, scale)
	local model = Instance.new("Model")
	model.Name = "Creature_" .. tostring(petId)
	local params = ModelFactory.GetCreatureDef(petId) or { A = "blob" }
	local pets = ModelFactory.GetPets()
	local def = pets and pets.ById[petId] or nil
	local bodyColor = ModelFactory.ColorFromBrickName(def and def.BodyColor or nil)
	local accent = accentFor(petId, params)
	local dark = Color3.new(bodyColor.R * 0.6, bodyColor.G * 0.6, bodyColor.B * 0.6)
	local C = { body = bodyColor, accent = accent, dark = dark }
	local builder = builders[params.A] or builders.blob
	local ok, primary = pcall(builder, model, C, params)
	if not ok or not primary then
		pcall(builders.blob, model, C, params)
		primary = model:FindFirstChild("Body")
	end
	if primary and primary:IsA("BasePart") then
		model.PrimaryPart = primary
	end
	local s = (tonumber(scale) or 1) * (tonumber(params.S) or 1)
	if s ~= 1 then
		ModelFactory.ScaleModel(model, s)
	end
	if mutation then
		ModelFactory.ApplyMutation(model, mutation)
	end
	return model
end

--- Recolors + effects a built model for a mutation id. Safe no-op when unknown.
function ModelFactory.ApplyMutation(model, mutationId)
	if not model or not mutationId then
		return
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:FindFirstChild("EggHeistShared")
	local folder = Shared and Shared:FindFirstChild("Config")
	local mod = folder and folder:FindFirstChild("Mutations")
	local mut = nil
	if mod then
		local ok, mutations = pcall(require, mod)
		if ok and mutations then
			mut = mutations.ById[mutationId]
		end
	end
	if not mut then
		return
	end
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		if mutationId == "Shadow" or mutationId == "Void" then
			body.Color = mut.Color
			body.Material = Enum.Material.Neon
		elseif mutationId == "Crystal" or mutationId == "Celestial" then
			body.Material = Enum.Material.Glass
		elseif mutationId == "Neon" or mutationId == "Galaxy" then
			body.Color = mut.Color
			body.Material = Enum.Material.Neon
		elseif mutationId == "Toxic" then
			body.Color = mut.Color
		elseif mutationId == "Golden" or mutationId == "Ancient" then
			body.Color = mut.Color
		end
		if mutationId == "Golden" or mutationId == "Galaxy" or mutationId == "Void"
			or mutationId == "Ancient" or mutationId == "Neon" or mutationId == "Celestial" then
			addSparkles(body, mut.Color)
		end
		if mutationId == "Void" or mutationId == "Shadow" then
			pcall(function()
				local smoke = Instance.new("Smoke")
				smoke.Color = mut.Color
				smoke.Parent = body
			end)
		end
		if mutationId == "Neon" or mutationId == "Void" or mutationId == "Celestial" then
			pcall(function()
				local light = Instance.new("PointLight")
				light.Color = mut.Color
				light.Range = 12
				light.Brightness = 1.5
				light.Shadows = false
				light.Parent = body
			end)
		end
	end
end

--- Turns a model into a black silhouette (undiscovered collection icons).
function ModelFactory.Silhouette(model)
	if not model then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = Color3.fromRGB(15, 15, 22)
			descendant.Material = Enum.Material.SmoothPlastic
		elseif descendant:IsA("Light") or descendant:IsA("ParticleEmitter")
			or descendant.ClassName == "Sparkles" or descendant.ClassName == "Smoke" then
			pcall(function() descendant:Destroy() end)
		end
	end
end

--- Uniform scale around the model origin (keeps multi-part offsets glued).
function ModelFactory.ScaleModel(model, s)
	if not model or not s or s == 1 then
		return
	end
	local primary = model.PrimaryPart or model:FindFirstChild("Body")
	local pivot = (primary and primary:IsA("BasePart")) and primary.Position or Vector3.new(0, 0, 0)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local offset = descendant.Position - pivot
			descendant.Size = descendant.Size * s
			local ok = pcall(function()
				local rot = descendant.CFrame - descendant.Position
				descendant.CFrame = CFrame.new(pivot + offset * s) * rot
			end)
			if not ok then
				descendant.CFrame = CFrame.new(pivot + offset * s)
			end
		elseif descendant:IsA("SpecialMesh") then
			local meshScale = descendant.Scale
			if meshScale then
				descendant.Scale = meshScale * s
			end
		end
	end
end

--- Moves the whole model so its PrimaryPart sits at the target CFrame.
function ModelFactory.Pose(model, cframe)
	local primary = model and (model.PrimaryPart or model:FindFirstChild("Body"))
	if not primary or not primary:IsA("BasePart") then
		return
	end
	local delta = cframe.Position - primary.Position
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CFrame = descendant.CFrame + delta
		end
	end
end

--------------------------------------------------------------------------------
-- Eggs (world assets when present, procedural fallback otherwise)
--------------------------------------------------------------------------------

function ModelFactory.GetEggAssetModel(assetName)
	local root = Workspace:FindFirstChild("EggHeist")
	local assets = root and root:FindFirstChild("EggAssets")
	local template = assets and assets:FindFirstChild(assetName or "")
	if template then
		local ok, clone = pcall(function() return template:Clone() end)
		if ok and clone then
			return clone
		end
	end
	return nil
end

function ModelFactory.BuildEgg(eggId, scale)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:FindFirstChild("EggHeistShared")
	local folder = Shared and Shared:FindFirstChild("Config")
	local eggMod = folder and folder:FindFirstChild("Eggs")
	local def = nil
	if eggMod then
		local ok, eggs = pcall(require, eggMod)
		if ok and eggs then
			def = eggs.ById[eggId]
		end
	end
	local model = nil
	if def and def.AssetModel then
		model = ModelFactory.GetEggAssetModel(def.AssetModel)
	end
	if not model then
		-- procedural egg fallback
		model = Instance.new("Model")
		model.Name = tostring(eggId or "Egg")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2.4, 3.2, 2.4)
		body.Color = EGG_FALLBACK_COLORS[eggId] or Color3.fromRGB(240, 230, 200)
		body.Material = Enum.Material.SmoothPlastic
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.TopSurface = Enum.SurfaceType.Smooth
		body.BottomSurface = Enum.SurfaceType.Smooth
		body.Parent = model
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Egg
		mesh.Scale = Vector3.new(2.4, 3.2, 2.4)
		mesh.Parent = body
	end
	model.Name = "Egg_" .. tostring(eggId)
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		model.PrimaryPart = body
	end
	if scale and scale ~= 1 then
		ModelFactory.ScaleModel(model, scale)
	end
	return model
end

-- Finds a plot-local XZ spot near `preferred` that does not overlap any
-- existing plot part (template buildings, pedestals, totems...). Returns a
-- plot-local Vector3 (Y = 0). Pure math + part bounds: sim-safe.
local NUDGE_SPIRAL = {
	{ 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 },
	{ 4, 4 }, { 4, -4 }, { -4, 4 }, { -4, -4 },
	{ 8, 0 }, { -8, 0 }, { 0, 8 }, { 0, -8 },
	{ 8, 8 }, { 8, -8 }, { -8, 8 }, { -8, -8 },
	{ 12, 0 }, { -12, 0 }, { 0, 12 }, { 0, -12 },
}

function ModelFactory.FindClearSpot(plot, preferred, clearance, halfExtent)
	clearance = clearance or 3
	halfExtent = halfExtent or 15
	local foundation = plot and plot:FindFirstChild("Foundation")
	if not foundation or not foundation:IsA("BasePart") then
		return preferred
	end
	local center = foundation.Position
	local blockers = {}
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= foundation then
			local own = false
			local node = descendant.Parent
			while node and node ~= plot do
				if node.Name == "ServerFurniture" then
					own = true
					break
				end
				node = node.Parent
			end
			if not own then
				blockers[#blockers + 1] = descendant
			end
		end
	end
	local function overlaps(x, z)
		for _, part in ipairs(blockers) do
			local size = part.Size
			local radius = math.max(size.X, size.Z) / 2 + clearance
			if math.abs(x - part.Position.X) < radius
				and math.abs(z - part.Position.Z) < radius then
				return true
			end
		end
		return false
	end
	for _, nudge in ipairs(NUDGE_SPIRAL) do
		local lx = preferred.X + nudge[1]
		local lz = preferred.Z + nudge[2]
		if lx > halfExtent then lx = halfExtent end
		if lx < -halfExtent then lx = -halfExtent end
		if lz > halfExtent then lz = halfExtent end
		if lz < -halfExtent then lz = -halfExtent end
		if not overlaps(center.X + lx, center.Z + lz) then
			return Vector3.new(lx, 0, lz)
		end
	end
	local fx = preferred.X
	local fz = preferred.Z
	if fx > halfExtent then fx = halfExtent end
	if fx < -halfExtent then fx = -halfExtent end
	if fz > halfExtent then fz = halfExtent end
	if fz < -halfExtent then fz = -halfExtent end
	return Vector3.new(fx, 0, fz)
end

return ModelFactory
