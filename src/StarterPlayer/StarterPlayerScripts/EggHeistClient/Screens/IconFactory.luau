-- EggHeist | Client/Screens/IconFactory.luau
-- ViewportFrame icons for eggs + creatures (zero uploaded assets needed).
-- Models come from Shared/ModelFactory; built templates are cached and
-- cloned per icon so grids stay cheap. Client-side rendering only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ModelFactory = require(Shared:WaitForChild("Utilities"):WaitForChild("ModelFactory"))

local IconFactory = {}
local templateCache = {} -- [key] = unparented template Model

-- Strips world-only extras (prompts/guis/fx) from an icon template.
local function stripped(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui") or descendant:IsA("ParticleEmitter")
			or descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	return model
end

local function getModel(key, builder)
	local cached = templateCache[key]
	if cached then
		local okClone, clone = pcall(function()
			return cached:Clone()
		end)
		if okClone and clone then
			return clone
		end
	end
	local ok, model = pcall(builder)
	if not ok or not model then
		return nil
	end
	stripped(model)
	templateCache[key] = model
	local okClone2, clone2 = pcall(function()
		return model:Clone()
	end)
	if okClone2 and clone2 then
		return clone2
	end
	return nil
end

local function frameModel(vpf, model)
	model.Parent = vpf
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = vpf
	local cf, size = nil, nil
	pcall(function()
		cf, size = model:GetBoundingBox()
	end)
	if cf and size then
		local dist = math.max(size.X, size.Y, size.Z) * 2.4 + 0.5
		local target = cf.Position
		camera.CFrame = CFrame.new(
			target + Vector3.new(dist * 0.55, dist * 0.4, dist), target)
	else
		camera.CFrame = CFrame.new(3, 2.5, 5)
	end
	vpf.CurrentCamera = camera
end

local function makeFrame(size)
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = size or UDim2.new(0, 64, 0, 64)
	vpf.BackgroundTransparency = 1
	vpf.BorderSizePixel = 0
	vpf.Name = "Icon"
	return vpf
end

--- 3D egg icon (world asset when present, procedural fallback otherwise).
function IconFactory.EggIcon(eggId, size)
	local vpf = makeFrame(size)
	local model = getModel("egg:" .. tostring(eggId), function()
		return ModelFactory.BuildEgg(eggId, 1)
	end)
	if model then
		frameModel(vpf, model)
	end
	return vpf
end

--- 3D creature icon, mutation visuals included. Silhouette blacks the clone
--- out (undiscovered collection entries); the cached template stays intact.
function IconFactory.PetIcon(petId, mut, size, silhouette)
	local vpf = makeFrame(size)
	local model = getModel("pet:" .. tostring(petId) .. ":" .. tostring(mut), function()
		return ModelFactory.BuildCreature(petId, mut, 1)
	end)
	if model then
		if silhouette then
			ModelFactory.Silhouette(model)
		end
		frameModel(vpf, model)
	end
	return vpf
end

return IconFactory
