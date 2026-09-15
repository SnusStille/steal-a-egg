-- EggHeist | Client/Effects/SoundManager.luau
-- Centralized SFX using built-in Roblox asset sounds (no uploads needed).
-- Respects the player's sfx/music settings via DataController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))

local SoundManager = {}
local dataController = nil

-- Sound bank lives in Shared/Config/Audio (single source of truth).
SoundManager.Sounds = Audio.Sfx

function SoundManager.Init(ctx)
	if ctx and ctx.Data then
		dataController = ctx.Data
	end
end

local function sfxEnabled()
	if dataController and dataController.GetSetting then
		return dataController.GetSetting("sfx") ~= false
	end
	return true
end

-- pitch shifts PlaybackSpeed (1 = normal). Pass 1 +/- small random for variety.
function SoundManager.Play(soundName, volume, pitch)
	if not sfxEnabled() then
		return
	end
	local assetId = SoundManager.Sounds[soundName]
	if not assetId then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = tonumber(pitch) or 1
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	pcall(function()
		sound:Play()
	end)
	-- safety cleanup
	task.delay(5, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Rising arpeggio for big wins. tier 4..6 scales length + brightness.
function SoundManager.Fanfare(tier)
	tier = tonumber(tier) or 4
	if tier < 4 then
		tier = 4
	elseif tier > 6 then
		tier = 6
	end
	local notes = 2 + tier
	for i = 1, notes do
		local pitch = 1 + i * 0.1
		local last = (i == notes)
		task.delay((i - 1) * 0.09, function()
			SoundManager.Play(last and "Rare" or "Success", 0.55, pitch)
		end)
	end
	if tier >= 5 then
		task.delay(notes * 0.09, function()
			SoundManager.Play("Achievement", 0.7, 1.2)
		end)
	end
end

return SoundManager
