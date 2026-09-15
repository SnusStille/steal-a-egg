-- EggHeist | Server/World/NpcService.lua
-- Builds lightweight world NPCs from Shared/Config/Npcs.lua.
-- NPCs are anchored display models (no AI, no pathfinding): a body, a head,
-- a floating nametag, and a Talk prompt the CLIENT wires to UI (NpcController).
-- Zero exploit surface: talking only opens local UI.

local NpcService = {}
NpcService.Name = "NpcService"

local registry = nil

function NpcService.Init(_, reg)
	registry = reg
end

local function resolvePosition(def)
	-- Prefer the world anchor part; fall back to the configured position.
	local root = registry.World.GetRoot()
	if root then
		local current = root
		for _, name in ipairs(def.Anchor or {}) do
			current = current and current:FindFirstChild(name) or nil
		end
		if current and current:IsA("BasePart") then
			local offset = def.Offset or { 0, 0, 0 }
			return current.Position + Vector3.new(
				offset[1] + current.Size.X / 2 - 4,
				current.Size.Y / 2 + 3,
				offset[3]
			)
		end
	end
	local fallback = def.Fallback or { 0, 6, 0 }
	return Vector3.new(fallback[1], fallback[2], fallback[3])
end

local function buildNpc(def)
	local color = Color3.fromRGB(200, 200, 200)
	if def.Color then
		color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	end
	local model = Instance.new("Model")
	model.Name = "Npc_" .. def.Id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 3, 1.4)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = true
	body.CanQuery = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.Color = Color3.fromRGB(255, 220, 180)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent = model

	local tag = Instance.new("BillboardGui")
	tag.Name = "Nametag"
	tag.Size = UDim2.new(0, 200, 0, 56)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 80
	tag.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.DisplayName or def.Id
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = tag
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.new(0, 0, 0, 26)
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = def.Title or "Talk to me!"
	titleLabel.TextColor3 = color
	titleLabel.Font = Enum.Font.Gotham
	titleLabel.TextSize = 13
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.Parent = tag

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NpcPrompt"
	prompt:SetAttribute("NpcId", def.Id)
	prompt.ActionText = "Talk"
	prompt.ObjectText = def.DisplayName or def.Id
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	return model, body, head
end

function NpcService.Start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
	local Npcs = require(Shared:WaitForChild("Config"):WaitForChild("Npcs"))

	local root = registry.World.GetRoot()
	if not root then
		warn("[EggHeist] NpcService: no world root, skipping NPCs.")
		return
	end
	local folder = root:FindFirstChild("Npcs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Npcs"
		folder.Parent = root
	end
	for _, def in ipairs(Npcs.List) do
		if not folder:FindFirstChild("Npc_" .. def.Id) then
			local model, body, head = buildNpc(def)
			local position = resolvePosition(def)
			body.CFrame = CFrame.new(position)
			head.CFrame = CFrame.new(position + Vector3.new(0, 2.4, 0))
			model.Parent = folder
		end
	end
	print("[EggHeist] NPCs ready (" .. tostring(#Npcs.List) .. ").")
end

return NpcService
