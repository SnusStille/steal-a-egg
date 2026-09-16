-- EggHeist | Client/Effects/Effects.luau
-- Juice: tweens, confetti, screen shake, rarity flashes.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Effects = {}

-- Settings-aware gates, refreshed by MainScreen from the player snapshot.
local gates = {
	cameraShake = true,
	reducedEffects = false,
	performanceMode = false,
}

function Effects.Configure(settings)
	if type(settings) ~= "table" then
		return
	end
	if settings.cameraShake ~= nil then
		gates.cameraShake = settings.cameraShake ~= false
	end
	if settings.reducedEffects ~= nil then
		gates.reducedEffects = settings.reducedEffects == true
	end
	if settings.performanceMode ~= nil then
		gates.performanceMode = settings.performanceMode == true
	end
end

local function effectsMuted()
	return gates.performanceMode
end

local function effectsReduced()
	return gates.performanceMode or gates.reducedEffects
end

function Effects.Tween(instance, info, goals, callback)
	local tween = TweenService:Create(instance, info, goals)
	if callback then
		tween.Completed:Connect(function()
			pcall(callback)
		end)
	end
	tween:Play()
	return tween
end

function Effects.Pop(instance, amount)
	amount = amount or 1.08
	local original = instance.Size
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Effects.Tween(instance, info, {
		Size = UDim2.new(original.X.Scale * amount, original.X.Offset * amount,
			original.Y.Scale * amount, original.Y.Offset * amount),
	}, function()
		Effects.Tween(instance, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = original,
		})
	end)
end

function Effects.Flash(parent, color, duration)
	if effectsMuted() then
		return
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.4
	flash.BorderSizePixel = 0
	flash.ZIndex = 999
	flash.Parent = parent
	Effects.Tween(flash, TweenInfo.new(duration or 0.4), { BackgroundTransparency = 1 }, function()
		flash:Destroy()
	end)
end

-- Simple UI confetti burst inside a container (anchored center-ish)
function Effects.Confetti(parent, count, colors)
	if effectsMuted() then
		return
	elseif effectsReduced() then
		count = math.min(count or 0, 12)
	end
	count = count or 40
	colors = colors or {
		Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(255, 120, 180), Color3.fromRGB(140, 255, 160),
	}
	local center = UDim2.new(0.5, 0, 0.4, 0)
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.new(0, math.random(5, 10), 0, math.random(5, 10))
		piece.Position = center
		piece.BackgroundColor3 = colors[math.random(1, #colors)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 998
		piece.Parent = parent
		local targetX = math.random(-300, 300)
		local targetY = math.random(-100, 350)
		Effects.Tween(piece, TweenInfo.new(math.random(6, 11) / 10,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = center + UDim2.new(0, targetX, 0, targetY),
			Rotation = piece.Rotation + math.random(-260, 260),
			BackgroundTransparency = 1,
		}, function()
			piece:Destroy()
		end)
	end
end

function Effects.ShakeCamera(intensity, duration)
	if not gates.cameraShake or effectsMuted() then
		return
	end
	intensity = intensity or 0.5
	duration = duration or 0.3
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration do
			local offset = Vector3.new(
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity,
				0)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait()
		end
	end)
end

function Effects.CountUp(label, fromValue, toValue, duration, formatter)
	duration = duration or 0.6
	local start = os.clock()
	task.spawn(function()
		while true do
			local alpha = math.min(1, (os.clock() - start) / duration)
			local value = fromValue + (toValue - fromValue) * alpha
			if formatter then
				label.Text = formatter(value)
			else
				label.Text = tostring(math.floor(value))
			end
			if alpha >= 1 then
				break
			end
			task.wait()
		end
	end)
end

function Effects.LocalPlayerGui()
	local player = Players.LocalPlayer
	return player and player:WaitForChild("PlayerGui") or nil
end

-- World-space floating text (damage-number style popup that rises + fades)
function Effects.FloatingText(worldPos, text, color, duration)
	if effectsMuted() or typeof(worldPos) ~= "Vector3" then
		return
	end
	duration = duration or 1.4
	local holder = Instance.new("Part")
	holder.Name = "FloatText"
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(worldPos)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Parent = Workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 220, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(text)
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	Effects.Tween(billboard, TweenInfo.new(duration,
		Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 7, 0),
	})
	Effects.Tween(label, TweenInfo.new(duration), { TextTransparency = 1 })
	task.delay(duration + 0.2, function()
		if holder then
			holder:Destroy()
		end
	end)
end

-- 3D particle burst at a world position (client-side, zero replication cost)
function Effects.Burst3D(worldPos, color, count, power)
	if effectsMuted() or typeof(worldPos) ~= "Vector3" then
		return
	end
	count = count or 24
	if effectsReduced() then
		count = math.min(count, 10)
	end
	local flashColor = color or Color3.fromRGB(255, 220, 130)
	local holder = Instance.new("Part")
	holder.Name = "Burst3D"
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(worldPos)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(flashColor)
	emitter.LightEmission = 0.9
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(8, 18 + (power or 0))
	emitter.Size = NumberSequence.new(0.9)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = holder
	local flash = Instance.new("PointLight")
	flash.Color = flashColor
	flash.Range = 25
	flash.Brightness = 3
	flash.Shadows = false
	flash.Parent = holder
	pcall(function()
		emitter:Emit(count)
	end)
	task.delay(1.6, function()
		if holder then
			holder:Destroy()
		end
	end)
end

-- Expanding neon shockwave ring, flat on the ground
function Effects.RingShockwave(worldPos, color, maxSize)
	if effectsMuted() or typeof(worldPos) ~= "Vector3" then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "ShockRing"
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.new(4, 1.2, 4)
	ring.CFrame = CFrame.new(worldPos)
	ring.Color = color or Color3.fromRGB(255, 220, 130)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = Workspace
	local target = maxSize or 30
	Effects.Tween(ring, TweenInfo.new(0.55,
		Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(target, 1.2, target),
		Transparency = 1,
	})
	task.delay(0.8, function()
		if ring then
			ring:Destroy()
		end
	end)
end

-- Quick FOV punch that eases back (speed / win / warp feel)
function Effects.FovKick(amount, duration)
	if effectsMuted() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView or 70
	pcall(function()
		camera.FieldOfView = base + (amount or 6)
		Effects.Tween(camera, TweenInfo.new(duration or 0.5,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = base,
		})
	end)
end

-- Firework volley: staggered 3D bursts above a world position
function Effects.Fireworks(worldPos, palette)
	if effectsMuted() or typeof(worldPos) ~= "Vector3" then
		return
	end
	palette = palette or {
		Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(255, 120, 180), Color3.fromRGB(140, 255, 160),
	}
	local shots = 5
	if effectsReduced() then
		shots = 2
	end
	for i = 1, shots do
		local color = palette[math.random(1, #palette)]
		local offset = Vector3.new(math.random(-14, 14), math.random(6, 22), math.random(-14, 14))
		task.delay((i - 1) * 0.28, function()
			Effects.Burst3D(worldPos + offset, color, 30, 14)
		end)
	end
end

-- Cinematic letterbox bars (heist carry mode)
local letterboxTop = nil
local letterboxBottom = nil

function Effects.Letterbox(show)
	local playerGui = Effects.LocalPlayerGui()
	if not playerGui then
		return
	end
	if not letterboxTop then
		letterboxTop = Instance.new("Frame")
		letterboxTop.Name = "LetterboxTop"
		letterboxTop.Size = UDim2.new(1, 0, 0, 64)
		letterboxTop.Position = UDim2.new(0, 0, 0, -64)
		letterboxTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		letterboxTop.BackgroundTransparency = 0.15
		letterboxTop.BorderSizePixel = 0
		letterboxTop.ZIndex = 500
		letterboxTop.Parent = playerGui
		letterboxBottom = Instance.new("Frame")
		letterboxBottom.Name = "LetterboxBottom"
		letterboxBottom.AnchorPoint = Vector2.new(0, 1)
		letterboxBottom.Size = UDim2.new(1, 0, 0, 64)
		letterboxBottom.Position = UDim2.new(0, 0, 1, 64)
		letterboxBottom.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		letterboxBottom.BackgroundTransparency = 0.15
		letterboxBottom.BorderSizePixel = 0
		letterboxBottom.ZIndex = 500
		letterboxBottom.Parent = playerGui
	end
	if show then
		Effects.Tween(letterboxTop, TweenInfo.new(0.4), { Position = UDim2.new(0, 0, 0, 0) })
		Effects.Tween(letterboxBottom, TweenInfo.new(0.4), { Position = UDim2.new(0, 0, 1, 0) })
	else
		Effects.Tween(letterboxTop, TweenInfo.new(0.4), { Position = UDim2.new(0, 0, 0, -64) })
		Effects.Tween(letterboxBottom, TweenInfo.new(0.4), { Position = UDim2.new(0, 0, 1, 64) })
	end
end

return Effects
