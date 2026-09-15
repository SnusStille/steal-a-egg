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

return Effects
