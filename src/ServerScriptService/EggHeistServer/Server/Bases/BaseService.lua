-- EggHeist | Server/Bases/BaseService.lua
-- Plot ownership, template builds, base upgrades, vault, decorations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local UpgradesConfig = require(ConfigFolder:WaitForChild("Upgrades"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local ShopConfig = require(ConfigFolder:WaitForChild("Shop"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local BaseService = {}
BaseService.Name = "BaseService"

local registry = nil
local plotOwner = {} -- [plotIndex] = userId
local userPlot = {} -- [userId] = plotIndex

function BaseService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

--------------------------------------------------------------------------------
-- Plot assignment
--------------------------------------------------------------------------------

function BaseService.GetPlotOf(player)
	return userPlot[player.UserId] or 0
end

function BaseService.GetOwnerOfPlot(plotIndex)
	local userId = plotOwner[plotIndex]
	if userId then
		return Players:GetPlayerByUserId(userId)
	end
	return nil
end

function BaseService.GetOwnerUserIdOfPlot(plotIndex)
	return plotOwner[plotIndex]
end

local function findFreePlot()
	for i = 1, Settings.MaxBasePlots do
		if not plotOwner[i] then
			local model = registry.World.GetPlotModel(i)
			if model then
				return i
			end
		end
	end
	return nil
end

-- Clones BaseTemplate contents into the plot, offset to the plot foundation.
local function buildPlotFromTemplate(plotIndex)
	local plot = registry.World.GetPlotModel(plotIndex)
	local template = registry.World.GetBaseTemplate()
	if not plot or not template then
		return false
	end
	if plot:FindFirstChild("BuiltByServer") then
		return true -- already built
	end
	local plotFoundation = plot:FindFirstChild("Foundation")
	local templateFoundation = template:FindFirstChild("Foundation")
	local offset = Vector3.new(0, 0, 0)
	if plotFoundation and plotFoundation:IsA("BasePart")
		and templateFoundation and templateFoundation:IsA("BasePart") then
		offset = plotFoundation.Position - templateFoundation.Position
	end
	for _, child in ipairs(template:GetChildren()) do
		if child.Name ~= "Foundation" and child.Name ~= "PlotLabel"
			and child.Name ~= "BoundaryWall1" and child.Name ~= "BoundaryWall2"
			and child.Name ~= "BoundaryWall3" and child.Name ~= "BoundaryWall4"
			and child.Name ~= "BoundaryStripN" and child.Name ~= "BoundaryStripS"
			and child.Name ~= "BoundaryStripE" and child.Name ~= "BoundaryStripW" then
			local ok, clone = pcall(function() return child:Clone() end)
			if ok and clone then
				-- shift all parts by offset
				if clone:IsA("BasePart") then
					clone.CFrame = clone.CFrame + offset
				elseif clone:IsA("Model") then
					-- PivotTo moves the whole model incl. descendants
					clone:PivotTo(clone:GetPivot() + offset)
				end
				clone.Parent = plot
			end
		end
	end
	local marker = Instance.new("BoolValue")
	marker.Name = "BuiltByServer"
	marker.Parent = plot
	return true
end

local VAULT_PROMPTS = {
	{ Name = "VaultPromptQuick", ActionText = "Quick Grab", Key = Enum.KeyCode.E, Target = "quick" },
	{ Name = "VaultPromptFull", ActionText = "Full Heist", Key = Enum.KeyCode.F, Target = "vault" },
}

local function ensureVaultPrompt(plotIndex)
	local plot = registry.World.GetPlotModel(plotIndex)
	if not plot then
		return
	end
	-- legacy single prompt from older versions: remove in favor of the pair
	local legacy = plot:FindFirstChild("VaultPrompt", true)
	if legacy and legacy.Name == "VaultPrompt" then
		pcall(function() legacy:Destroy() end)
	end
	local anchor = registry.World.GetVaultAnchor(plotIndex)
	if not anchor then
		return
	end
	for _, spec in ipairs(VAULT_PROMPTS) do
		if not anchor:FindFirstChild(spec.Name) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = spec.Name
			prompt.ActionText = spec.ActionText
			prompt.ObjectText = "Base Vault"
			prompt.KeyboardKeyCode = spec.Key
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = anchor
			prompt.Triggered:Connect(function(player)
				local ownerId = plotOwner[plotIndex]
				if not ownerId then
					return
				end
				if player.UserId == ownerId then
					BaseService.CollectVault(player)
				elseif registry.Heist then
					registry.Heist.TryGrab(player, plotIndex, spec.Target)
				end
			end)
		end
	end
end

function BaseService.AssignPlot(player, preferredIndex)
	if userPlot[player.UserId] then
		return userPlot[player.UserId]
	end
	local index = preferredIndex
	if not index or plotOwner[index] or not registry.World.GetPlotModel(index) then
		index = findFreePlot()
	end
	if not index then
		registry.Notify.Send(player, "warning", "Server full",
			"No free base plots. Try another server!", 5)
		return nil
	end
	plotOwner[index] = player.UserId
	userPlot[player.UserId] = index
	local profile = profileOf(player)
	if profile then
		profile.base.plot = index
		registry.Data.MarkDirty(player)
	end
	-- clear any previous owner's decorations before building
	local existingPlot = registry.World.GetPlotModel(index)
	if existingPlot then
		for _, child in ipairs(existingPlot:GetChildren()) do
			if string.sub(child.Name, 1, 6) == "Decor_" then
				child:Destroy()
			end
		end
	end
	buildPlotFromTemplate(index)
	ensureVaultPrompt(index)
	if registry.Security then
		registry.Security.RebuildPlotSecurity(index)
	end
	registry.World.SetPlotLabel(index, player.DisplayName .. "'s Base")
	registry.Notify.Send(player, "success", "Base claimed!",
		"This plot is yours. Upgrade it and fill the vault!", 5)
	if registry.TutorialHook then
		registry.TutorialHook(player, "ClaimBase")
	end
	return index
end

function BaseService.ReleasePlot(player)
	local index = userPlot[player.UserId]
	if not index then
		return
	end
	userPlot[player.UserId] = nil
	if plotOwner[index] == player.UserId then
		plotOwner[index] = nil
	end
	if registry.Security then
		registry.Security.ClearPlotSecurity(index)
	end
	registry.World.SetPlotLabel(index, "Empty Plot")
end

--------------------------------------------------------------------------------
-- Vault
--------------------------------------------------------------------------------

function BaseService.GetVaultCapacity(player)
	local profile = profileOf(player)
	local tier = 0
	if profile and profile.base and profile.base.upgrades then
		tier = profile.base.upgrades.Vault or 0
	end
	return math.floor(Economy.VaultBaseCapacity * UpgradesConfig.Tracks.Vault.Effect(tier))
end

function BaseService.BankToVault(player, amount)
	local profile = profileOf(player)
	if not profile then
		return 0
	end
	local capacity = BaseService.GetVaultCapacity(player)
	local space = math.max(0, capacity - (profile.base.vault or 0))
	local banked = math.min(space, math.floor(amount))
	if banked > 0 then
		profile.base.vault = (profile.base.vault or 0) + banked
		profile.stats.vaultBanked = (profile.stats.vaultBanked or 0) + banked
		registry.Quest.AddProgress(player, "BankVault", banked)
	end
	return banked
end

function BaseService.CollectVault(player)
	local profile = profileOf(player)
	if not profile then
		return 0
	end
	local amount = math.floor(profile.base.vault or 0)
	if amount <= 0 then
		registry.Notify.Send(player, "info", "Vault empty",
			"Your pets bank earnings here over time.", 3)
		return 0
	end
	-- anti-teleport check: must be near own vault
	local plotIndex = userPlot[player.UserId]
	if plotIndex then
		local anchor = registry.World.GetVaultAnchor(plotIndex)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if anchor and hrp and (hrp.Position - anchor.Position).Magnitude > 30 then
			registry.Notify.Send(player, "warning", "Too far",
				"Visit your base vault to collect.", 3)
			return 0
		end
	end
	profile.base.vault = 0
	registry.Economy.AddCash(player, amount, "vault")
	registry.Notify.Send(player, "success", "Vault collected",
		"Collected vault earnings.", 3)
	registry.Net.Fire(player, "Fx", "VaultCollect", amount)
	if registry.TutorialHook then
		registry.TutorialHook(player, "CollectVault")
	end
	return amount
end

--------------------------------------------------------------------------------
-- Upgrades
--------------------------------------------------------------------------------

function BaseService.BuyUpgrade(player, trackId)
	trackId = Validate.String(trackId, 32, nil)
	local track = UpgradesConfig.Tracks[trackId]
	if not track then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local current = profile.base.upgrades[trackId] or 0
	if current >= track.MaxTier then
		registry.Notify.Send(player, "info", "Maxed out", track.DisplayName .. " is maxed!", 3)
		return false
	end
	local nextTier = current + 1
	if profile.level < track.RequiredLevel(nextTier) then
		registry.Notify.Send(player, "warning", "Level locked",
			"Requires level " .. tostring(track.RequiredLevel(nextTier)) .. ".", 4)
		return false
	end
	local cost = UpgradesConfig.GetCost(trackId, nextTier)
	if not registry.Economy.SpendCash(player, cost) then
		registry.Notify.Send(player, "warning", "Not enough cash", "You need more cash.", 4)
		return false
	end
	profile.base.upgrades[trackId] = nextTier
	profile.stats.upgradesBought = (profile.stats.upgradesBought or 0) + 1
	registry.Economy.AddXp(player, 15 * nextTier)
	registry.Quest.AddProgress(player, "UpgradeBase", 1)
	if registry.Achievement then
		registry.Achievement.Check(player, "UpgradeBuy")
	end
	registry.Notify.Send(player, "success", "Upgrade purchased!",
		track.DisplayName .. " tier " .. tostring(nextTier) .. ".", 4)
	registry.Net.Fire(player, "Fx", "Upgrade", trackId, nextTier)
	BaseService.RefreshUpgradeVisuals(player)
	registry.Data.MarkDirty(player)
	if registry.TutorialHook then
		registry.TutorialHook(player, "UpgradeBase")
	end
	return true
end

function BaseService.RefreshUpgradeVisuals(player)
	local plotIndex = userPlot[player.UserId]
	if not plotIndex then
		return
	end
	local profile = profileOf(player)
	if not profile then
		return
	end
	local plot = registry.World.GetPlotModel(plotIndex)
	if not plot then
		return
	end
	-- Tint upgrade slots by Income tier (simple, readable progression cue)
	local tier = profile.base.upgrades.Income or 0
	local color = Color3.fromRGB(120 + math.min(135, tier * 13), 120, 120)
	for _, name in ipairs({ "UpgradeSlot1", "UpgradeSlot2", "UpgradeSlot3" }) do
		local slot = plot:FindFirstChild(name, true)
		if slot and slot:IsA("BasePart") then
			slot.Color = color
		end
	end
end

--------------------------------------------------------------------------------
-- Decorations
--------------------------------------------------------------------------------

local function buildDecoration(plot, decorId)
	local foundation = plot:FindFirstChild("Foundation")
	local baseCf = foundation and foundation.CFrame or CFrame.new(0, 0, 0)
	local count = 0
	for _, child in ipairs(plot:GetChildren()) do
		if string.sub(child.Name, 1, 6) == "Decor_" then
			count = count + 1
		end
	end
	local angle = (count * 0.9) % (math.pi * 2)
	local radius = 12
	local spot = baseCf * CFrame.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
	local model = Instance.new("Model")
	model.Name = "Decor_" .. decorId .. "_" .. tostring(count)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if decorId == "Torch" then
		part.Name = "Pole"
		part.Size = Vector3.new(1, 5, 1)
		part.Color = Color3.fromRGB(100, 70, 40)
		part.CFrame = spot
		part.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 60)
		light.Range = 16
		light.Parent = part
	elseif decorId == "BannerBlue" then
		part.Name = "Banner"
		part.Size = Vector3.new(4, 6, 0.5)
		part.Color = Color3.fromRGB(60, 120, 255)
		part.CFrame = spot
		part.Parent = model
	elseif decorId == "Fountain" then
		part.Name = "Basin"
		part.Size = Vector3.new(6, 2, 6)
		part.Color = Color3.fromRGB(150, 200, 255)
		part.Material = Enum.Material.Glass
		part.CFrame = spot
		part.Parent = model
	else -- StatueGold
		part.Name = "Statue"
		part.Size = Vector3.new(2, 6, 2)
		part.Color = Color3.fromRGB(255, 200, 60)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = spot
		part.Parent = model
	end
	model.Parent = plot
end

function BaseService.BuyDecoration(player, decorId)
	decorId = Validate.String(decorId, 32, nil)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local plotIndex = userPlot[player.UserId]
	if not plotIndex then
		registry.Notify.Send(player, "warning", "No base", "Claim a base first!", 3)
		return false
	end
	local def = nil
	for _, d in ipairs(ShopConfig.Decorations) do
		if d.Id == decorId then
			def = d
			break
		end
	end
	if not def then
		return false
	end
	local paid = false
	if def.Currency == "Gems" then
		paid = registry.Economy.SpendGems(player, def.Price)
	else
		paid = registry.Economy.SpendCash(player, def.Price)
	end
	if not paid then
		registry.Notify.Send(player, "warning", "Can't afford", def.DisplayName .. " costs too much.", 3)
		return false
	end
	profile.base.decorations[#profile.base.decorations + 1] = decorId
	local plot = registry.World.GetPlotModel(plotIndex)
	if plot then
		buildDecoration(plot, decorId)
	end
	registry.Data.MarkDirty(player)
	return true
end

function BaseService.RestoreDecorations(player)
	local profile = profileOf(player)
	local plotIndex = userPlot[player.UserId]
	if not profile or not plotIndex then
		return
	end
	local plot = registry.World.GetPlotModel(plotIndex)
	if not plot then
		return
	end
	for _, decorId in ipairs(profile.base.decorations or {}) do
		buildDecoration(plot, decorId)
	end
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

function BaseService.Start()
	registry.Net.OnRequest("ClaimBase", function(player)
		local profile = profileOf(player)
		if not profile then
			return
		end
		if userPlot[player.UserId] then
			return
		end
		-- must be standing near a free plot foundation (anti-remote abuse)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local best, bestDist = nil, 40
		for i = 1, Settings.MaxBasePlots do
			if not plotOwner[i] then
				local plot = registry.World.GetPlotModel(i)
				local foundation = plot and plot:FindFirstChild("Foundation")
				if foundation and foundation:IsA("BasePart") then
					local dist = (hrp.Position - foundation.Position).Magnitude
					if dist < bestDist then
						best, bestDist = i, dist
					end
				end
			end
		end
		if best then
			BaseService.AssignPlot(player, best)
			BaseService.RestoreDecorations(player)
		else
			registry.Notify.Send(player, "info", "No plot nearby",
				"Walk onto an empty plot and try again.", 4)
		end
	end)

	registry.Net.OnRequest("BuyUpgrade", function(player, trackId)
		BaseService.BuyUpgrade(player, trackId)
	end)

	registry.Net.OnRequest("CollectVault", function(player)
		BaseService.CollectVault(player)
	end)

	registry.Net.OnRequest("BuyDecoration", function(player, decorId)
		BaseService.BuyDecoration(player, decorId)
	end)

	-- Re-claim persistent plots on join (same plot if free)
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, function()
			if not player.Parent then
				return
			end
			local profile = registry.Data.WaitForProfile(player, 20)
			if not profile then
				return
			end
			local preferred = profile.base.plot
			if preferred and preferred > 0 and not plotOwner[preferred] then
				BaseService.AssignPlot(player, preferred)
			end
			BaseService.RestoreDecorations(player)
		end)
	end)
end

return BaseService
