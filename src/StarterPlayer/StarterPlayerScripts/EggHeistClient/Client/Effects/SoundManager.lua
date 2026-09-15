-- EggHeist | Client/Effects/SoundManager.lua
-- Centralized SFX using built-in Roblox asset sounds (no uploads needed).
-- Respects the player's sfx/music settings via DataController.

local SoundService = game:GetService("SoundService")

local SoundManager = {}
local dataController = nil

-- Well-known built-in sounds (shipped with the client)
SoundManager.Sounds = {
	Click = "rbxasset://sounds/button.wav",
	Notify = "rbxasset://sounds/electronicpingshort.wav",
	Success = "rbxasset://sounds/electronicping.wav",
	Error = "rbxasset://sounds/bass.wav",
	Hatch = "rbxasset://sounds/snap.mp3",
	Rare = "rbxasset://sounds/unsheath.wav",
	Coins = "rbxasset://sounds/coins.wav",
	Alarm = "rbxasset://sounds/alarm.wav",
	HeistAlert = "rbxasset://sounds/alarm.wav",
	Achievement = "rbxasset://sounds/electronicping.wav",
	Gadget = "rbxasset://sounds/swordslash.wav",
	Extract = "rbxasset://sounds/coins.wav",
}

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

return SoundManager
