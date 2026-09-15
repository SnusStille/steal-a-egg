-- EggHeist | Server/Security/SecurityService.lua
-- Security purchases + runtime defenses (lasers, traps, cameras, lockdown).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Security = require(ConfigFolder:WaitForChild("Security"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local SecurityService = {}
SecurityService.Name = "SecurityService"

local registry = nil
local plotSecurity = {} -- [plotIndex] = { lasers={}, traps={}, cameras={}, folder=... }
local slowUntil = {} -- [userId] = timestamp (laser slow)
local stunUntil = {} -- [userId] = timestamp (trap stun)
local trapCooldown = {} -- [trapPart] = timestamp
local alarmLastPing = {} -- [plotIndex] = timestamp
local empUntil = {} -- [plotIndex] = os.clock timestamp (EMP suppression)
local zapNotifyAt = {} -- [userId] = os.clock timestamp (laser attribution throttle)

function SecurityService.Init(_, reg)
	registry = reg
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

local function ownerOfPlot(plotIndex)
	local userId = registry.Base.GetOwnerUserIdOfPlot(plotIndex)
	if userId then
		return Players:GetPlayerByUserId(userId)
	end
	return nil
end

local function securityTier(owner, itemId)
	if not owner then
		return 0
	end
	local profile = profileOf(owner)
	if not profile or not profile.base or not profile.base.security then
		return 0
	end
	return profile.base.security[itemId] or 0
end

--------------------------------------------------------------------------------
-- Purchases
--------------------------------------------------------------------------------

function SecurityService.BuySecurity(player, itemId)
	itemId = Validate.String(itemId, 32, nil)
	local item = Security.Items[itemId]
	if not item then
		return false
	end
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local current = profile.base.security[itemId] or 0
	if current >= item.MaxTier then
		registry.Notify.Send(player, "info", "Maxed out", item.DisplayName .. " is maxed!", 3)
		return false
	end
	local nextTier = current + 1
	if profile.level < item.RequiredLevel(nextTier) then
		registry.Notify.Send(player, "warning", "Level locked",
			"Requires level " .. tostring(item.RequiredLevel(nextTier)) .. ".", 4)
		return false
	end
	local cost = Security.GetCost(itemId, nextTier)
	if not registry.Economy.SpendCash(player, cost) then
		registry.Notify.Send(player, "warning", "Not enough cash", "You need more cash.", 4)
		return false
	end
	profile.base.security[itemId] = nextTier
	profile.stats.securityBought = (profile.stats.securityBought or 0) + 1
	registry.Economy.AddXp(player, 20 * nextTier)
	registry.Quest.AddProgress(player, "UpgradeSecurity", 1)
	if registry.Achievement then
		registry.Achievement.Check(player, "SecurityBuy")
	end
	registry.Notify.Send(player, "success", "Security upgraded!",
		item.DisplayName .. " tier " .. tostring(nextTier) .. ".", 4)
	local plotIndex = registry.Base.GetPlotOf(player)
	if plotIndex and plotIndex > 0 then
		SecurityService.RebuildPlotSecurity(plotIndex)
		registry.Base.RefreshUpgradeVisuals(player)
	end
	registry.Data.MarkDirty(player)
	return true
end

--------------------------------------------------------------------------------
-- Runtime defense construction
--------------------------------------------------------------------------------

local function clearFolder(folder)
	if folder then
		pcall(function() folder:Destroy() end)
	end
end

function SecurityService.ClearPlotSecurity(plotIndex)
	local state = plotSecurity[plotIndex]
	if state then
		clearFolder(state.folder)
	end
	plotSecurity[plotIndex] = nil
end

local function mkSecurityPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function SecurityService.RebuildPlotSecurity(plotIndex)
	SecurityService.ClearPlotSecurity(plotIndex)
	local owner = ownerOfPlot(plotIndex)
	if not owner then
		return
	end
	local plot = registry.World.GetPlotModel(plotIndex)
	if not plot then
		return
	end
	local foundation = plot:FindFirstChild("Foundation")
	if not foundation or not foundation:IsA("BasePart") then
		return
	end
	local state = { lasers = {}, traps = {}, cameras = {} }
	local folder = Instance.new("Folder")
	folder.Name = "SecurityRuntime"
	folder.Parent = plot
	state.folder = folder
	plotSecurity[plotIndex] = state

	local baseCf = foundation.CFrame
	local halfX = foundation.Size.X / 2
	local halfZ = foundation.Size.Z / 2
	local topY = foundation.Size.Y / 2

	-- Door: tint entrance gates by tier
	local doorTier = securityTier(owner, "Door")
	if doorTier > 0 then
		for _, name in ipairs({ "EntranceGateL", "EntranceGateR", "VaultAreaDoor" }) do
			local gate = plot:FindFirstChild(name, true)
			if gate and gate:IsA("BasePart") then
				gate.Color = Color3.fromRGB(140 - doorTier * 15, 60, 60)
				gate.Material = Enum.Material.Metal
			end
		end
	end

	-- Lasers: beams across the vault approach (visual + damage boxes)
	local laserTier = securityTier(owner, "Laser")
	if laserTier > 0 then
		local vaultAnchor = registry.World.GetVaultAnchor(plotIndex)
		local center = vaultAnchor and vaultAnchor.Position or (baseCf.Position + Vector3.new(0, 4, 0))
		for i = 1, math.min(3, 1 + laserTier) do
			local offsetZ = (i - 2) * 6
			local beam = mkSecurityPart(folder, "LaserBeam" .. i,
				Vector3.new(14, 0.6, 0.6),
				CFrame.new(center + Vector3.new(0, 3, offsetZ)),
				Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
			beam.CanQuery = true
			state.lasers[#state.lasers + 1] = beam
		end
	end

	-- Traps: floor pads that stun intruders
	local trapTier = securityTier(owner, "Trap")
	if trapTier > 0 then
		local count = Security.Items.Trap.TrapCount(trapTier)
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local pos = baseCf * CFrame.new(math.cos(angle) * (halfX - 6), topY + 0.3, math.sin(angle) * (halfZ - 6))
			local trap = mkSecurityPart(folder, "Trap" .. i,
				Vector3.new(4, 0.6, 4), pos,
				Color3.fromRGB(80, 80, 90), Enum.Material.SmoothPlastic)
			trap.CanQuery = true
			trap.Touched:Connect(function(hit)
				SecurityService.OnTrapTouched(plotIndex, trap, hit)
			end)
			state.traps[#state.traps + 1] = trap
		end
	end

	-- Cameras: poles at corners (visual deterrent + detection source)
	local cameraTier = securityTier(owner, "Camera")
	if cameraTier > 0 then
		local corners = {
			Vector3.new(-halfX + 3, 0, -halfZ + 3),
			Vector3.new(halfX - 3, 0, -halfZ + 3),
			Vector3.new(-halfX + 3, 0, halfZ - 3),
			Vector3.new(halfX - 3, 0, halfZ - 3),
		}
		for i = 1, math.min(4, 1 + cameraTier) do
			local polePos = baseCf * CFrame.new(corners[i].X, topY + 5, corners[i].Z)
			mkSecurityPart(folder, "CameraPole" .. i, Vector3.new(1, 10, 1), polePos,
				Color3.fromRGB(60, 60, 70))
			local headPos = baseCf * CFrame.new(corners[i].X, topY + 10, corners[i].Z)
			local lens = mkSecurityPart(folder, "CameraLens" .. i, Vector3.new(1.6, 1.2, 1.6), headPos,
				Color3.fromRGB(255, 50, 50), Enum.Material.Neon)
			state.cameras[#state.cameras + 1] = lens
		end
	end
end

--------------------------------------------------------------------------------
-- EMP suppression (gadget counter-play)
--------------------------------------------------------------------------------

function SecurityService.IsEmpDisabled(plotIndex)
	return (empUntil[plotIndex] or 0) > os.clock()
end

function SecurityService.SetEmpDisabled(plotIndex, seconds)
	local untilAt = os.clock() + math.max(1, seconds or 30)
	empUntil[plotIndex] = untilAt
	-- visual: dim the beams while fried
	local state = plotSecurity[plotIndex]
	if state and state.lasers then
		for _, beam in ipairs(state.lasers) do
			if beam and beam.Parent then
				beam.Color = Color3.fromRGB(90, 90, 100)
				beam.Transparency = 0.7
			end
		end
	end
	task.delay(math.max(1, seconds or 30) + 0.1, function()
		if empUntil[plotIndex] == untilAt then
			empUntil[plotIndex] = nil
			local current = plotSecurity[plotIndex]
			if current and current.lasers then
				for _, beam in ipairs(current.lasers) do
					if beam and beam.Parent then
						beam.Color = Color3.fromRGB(255, 40, 40)
						beam.Transparency = 0
					end
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Queries used by HeistService
--------------------------------------------------------------------------------

function SecurityService.GetBreachTime(victimPlayer)
	local profile = victimPlayer and profileOf(victimPlayer) or nil
	local tier = 0
	if profile and profile.base and profile.base.security then
		tier = profile.base.security.Door or 0
	end
	return Security.Items.Door.BreachTime(tier)
end

function SecurityService.GetProtection(victimPlayer)
	local profile = victimPlayer and profileOf(victimPlayer) or nil
	local tier = 0
	if profile and profile.base and profile.base.security then
		tier = profile.base.security.VaultShield or 0
	end
	return Security.Items.VaultShield.Protection(tier)
end

function SecurityService.RollDecoy(victimPlayer)
	local profile = victimPlayer and profileOf(victimPlayer) or nil
	local tier = 0
	if profile and profile.base and profile.base.security then
		tier = profile.base.security.Decoy or 0
	end
	if tier <= 0 then
		return false
	end
	return math.random() < Security.Items.Decoy.DecoyChance(tier)
end

function SecurityService.IsLockedDown(owner)
	if not owner then
		return false
	end
	local profile = profileOf(owner)
	if not profile then
		return false
	end
	return (profile.base.lockdownUntil or 0) > os.time()
end

function SecurityService.ToggleLockdown(player)
	local profile = profileOf(player)
	if not profile then
		return false
	end
	if (profile.base.security.Lockdown or 0) < 1 then
		registry.Notify.Send(player, "warning", "Not owned",
			"Buy Lockdown Protocol first.", 4)
		return false
	end
	local now = os.time()
	if (profile.base.lockdownCooldownUntil or 0) > now then
		local left = (profile.base.lockdownCooldownUntil or 0) - now
		registry.Notify.Send(player, "info", "Cooling down",
			"Lockdown ready in " .. tostring(left) .. "s.", 3)
		return false
	end
	if (profile.base.lockdownUntil or 0) > now then
		return false -- already active
	end
	profile.base.lockdownUntil = now + Security.Items.Lockdown.Duration
	profile.base.lockdownCooldownUntil = now + Security.Items.Lockdown.Cooldown
	registry.Data.MarkDirty(player)
	registry.Notify.Send(player, "success", "LOCKDOWN ACTIVE",
		"Your base is sealed for 30 seconds!", 5)
	-- eject intruders from the plot
	local plotIndex = registry.Base.GetPlotOf(player)
	if plotIndex and plotIndex > 0 then
		local plot = registry.World.GetPlotModel(plotIndex)
		local foundation = plot and plot:FindFirstChild("Foundation")
		if foundation and foundation:IsA("BasePart") then
			local center = foundation.Position
			local radius = math.max(foundation.Size.X, foundation.Size.Z)
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player and other.Character then
					local hrp = other.Character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - center).Magnitude < radius then
						hrp.CFrame = registry.World.GetSpawnCFrame()
						registry.Notify.Send(other, "warning", "Ejected!",
							player.DisplayName .. " triggered lockdown.", 4)
					end
				end
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- Runtime behaviors
--------------------------------------------------------------------------------

function SecurityService.OnTrapTouched(plotIndex, trap, hit)
	local now = os.clock()
	if (trapCooldown[trap] or 0) > now then
		return
	end
	local character = hit and hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local player = humanoid and Players:GetPlayerFromCharacter(character) or nil
	if not player then
		return
	end
	local owner = ownerOfPlot(plotIndex)
	if not owner or player == owner then
		return -- traps ignore the owner
	end
	if SecurityService.IsLockedDown(owner) then
		return -- sealed base: traps dormant (intruders already ejected)
	end
	if SecurityService.IsEmpDisabled(plotIndex) then
		return -- fried by EMP
	end
	trapCooldown[trap] = now + 6
	local stun = Security.Items.Trap.StunDuration(securityTier(owner, "Trap"))
	stunUntil[player.UserId] = now + stun
	-- small damage chip
	humanoid:TakeDamage(5)
	registry.Notify.Send(player, "error", "Trapped!",
		"You triggered a floor trap!", 3)
	registry.Notify.Send(owner, "warning", "Trap triggered!",
		player.DisplayName .. " triggered your trap!", 4)
	if registry.Achievement then
		registry.Achievement.Check(owner, "Defend")
	end
	registry.Net.Fire(player, "Fx", "TrapStun", stun)
end

-- called by HeistService when an intruder is detected (camera/alarm pings)
function SecurityService.AlertOwner(owner, intruder, reason)
	if not owner or not owner.Parent then
		return
	end
	registry.Notify.Send(owner, "error", "INTRUDER ALERT",
		(intruder and intruder.DisplayName or "Someone") .. " " .. tostring(reason or "is in your base!"), 5)
	if intruder then
		registry.Net.Fire(owner, "HeistUpdate", { alert = true, intruder = intruder.Name })
	end
end

local function applyMovementEffects()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local baseSpeed = 16
			-- heist carry slow handled by HeistService; traps override here
			if (stunUntil[player.UserId] or 0) > now then
				if humanoid.WalkSpeed ~= 0 then
					humanoid.WalkSpeed = 0
				end
			elseif (slowUntil[player.UserId] or 0) > now then
				if humanoid.WalkSpeed ~= 10 then
					humanoid.WalkSpeed = 10
				end
			else
				-- restore (unless heist carry slow active)
				local carrySlow = registry.Heist and registry.Heist.IsCarrying(player) or false
				local want = carrySlow and math.floor(16 * registry.Heist.GetCarrySpeed(player)) or baseSpeed
				if humanoid.WalkSpeed ~= want then
					humanoid.WalkSpeed = want
				end
			end
		end
	end
end

local function laserDamageLoop()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for plotIndex, state in pairs(plotSecurity) do
			if state.lasers and #state.lasers > 0
				and not SecurityService.IsEmpDisabled(plotIndex) then
				local owner = ownerOfPlot(plotIndex)
				if owner and not SecurityService.IsLockedDown(owner) then
					local tier = securityTier(owner, "Laser")
					if tier > 0 then
						local dps = Security.Items.Laser.DamagePerSecond(tier)
						for _, beam in ipairs(state.lasers) do
							if beam and beam.Parent then
								local center = beam.Position
								for _, player in ipairs(Players:GetPlayers()) do
									if player ~= owner and player.Character then
										local hrp = player.Character:FindFirstChild("HumanoidRootPart")
										if hrp and (hrp.Position - center).Magnitude < 9 then
											local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
											if humanoid and humanoid.Health > 0 then
												humanoid:TakeDamage(dps * 0.5)
												slowUntil[player.UserId] = now + 1.5
												-- soft-PvP attribution (throttled): both sides learn what happened
												if (zapNotifyAt[player.UserId] or 0) < now then
													zapNotifyAt[player.UserId] = now + 8
													registry.Notify.Send(player, "error", "Zapped!",
														owner.DisplayName .. "'s lasers are burning you!", 3)
													registry.Notify.Send(owner, "warning", "Lasers firing!",
														player.DisplayName .. " is eating your lasers!", 4)
														if registry.Achievement then
														registry.Achievement.Check(owner, "Defend")
													end
													local ownerProfile = profileOf(owner)
													if ownerProfile then
														ownerProfile.stats.defensesTriggered =
															(ownerProfile.stats.defensesTriggered or 0) + 1
														registry.Data.MarkDirty(owner)
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function cameraWatchLoop()
	while true do
		task.wait(2)
		for plotIndex, _ in pairs(plotSecurity) do
			local owner = ownerOfPlot(plotIndex)
			if owner and owner.Parent then
				local cameraTier = securityTier(owner, "Camera")
				if cameraTier > 0 then
					local plot = registry.World.GetPlotModel(plotIndex)
					local foundation = plot and plot:FindFirstChild("Foundation")
					if foundation and foundation:IsA("BasePart") then
						local radius = Security.Items.Camera.DetectRadius(cameraTier)
						local alarmTier = securityTier(owner, "Alarm")
						for _, player in ipairs(Players:GetPlayers()) do
							if player ~= owner and player.Character then
								local hrp = player.Character:FindFirstChild("HumanoidRootPart")
								if hrp and (hrp.Position - foundation.Position).Magnitude < radius then
									-- camera spot: ping owner (throttled by alarm tier)
									local interval = 30
									if alarmTier > 0 then
										interval = Security.Items.Alarm.PingInterval(alarmTier)
									end
									local last = alarmLastPing[plotIndex] or 0
									if os.clock() - last > interval then
										alarmLastPing[plotIndex] = os.clock()
										SecurityService.AlertOwner(owner, player, "was spotted by your cameras!")
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function SecurityService.Start()
	registry.Net.OnRequest("BuySecurity", function(player, itemId)
		SecurityService.BuySecurity(player, itemId)
	end)
	registry.Net.OnRequest("ToggleLockdown", function(player)
		SecurityService.ToggleLockdown(player)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			applyMovementEffects()
		end
	end)
	task.spawn(laserDamageLoop)
	task.spawn(cameraWatchLoop)
end

return SecurityService
