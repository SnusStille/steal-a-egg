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

-- Numeric volume setting (0..100) as a 0..1 multiplier.
local function volumeOf(key, fallback)
	if dataController and dataController.GetSetting then
		local v = tonumber(dataController.GetSetting(key))
		if v then
			return math.clamp(v / 100, 0, 1)
		end
	end
	return fallback
end

local function emit(assetId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = volume
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

-- pitch shifts PlaybackSpeed (1 = normal). Pass 1 +/- small random for variety.
function SoundManager.Play(soundName, volume, pitch)
	if not sfxEnabled() then
		return
	end
	local assetId = SoundManager.Sounds[soundName]
	if not assetId then
		return
	end
	local finalVolume = (volume or 0.6) * volumeOf("sfxVolume", 0.8)
	if finalVolume <= 0.001 then
		return
	end
	emit(assetId, finalVolume, pitch)
end

-- Generative music-box: an original, endless, calm pentatonic melody built
-- from a built-in pluck at pitched playback speeds. Zero uploaded assets,
-- so there is nothing to license and nothing that can be a copy of
-- anything. Respects the music toggle + musicVolume slider live.
local MUSIC_STEPS = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24 }
local musicStarted = false

local function musicEnabled()
	if dataController and dataController.GetSetting then
		return dataController.GetSetting("music") ~= false
	end
	return true
end

function SoundManager.StartMusic()
	if musicStarted then
		return
	end
	musicStarted = true
	task.spawn(function()
		local index = 5
		local beat = 0
		while true do
			if musicEnabled() then
				beat = beat + 1
				-- random walk across two pentatonic octaves: calm + endless
				index = math.clamp(index + math.random(-2, 2), 1, #MUSIC_STEPS)
				local ratio = 2 ^ (MUSIC_STEPS[index] / 12)
				local vol = 0.22 * volumeOf("musicVolume", 0.7)
				if vol > 0.01 and beat % 9 ~= 0 then -- breathing rest
					if beat % 8 == 0 then
						emit(SoundManager.Sounds.Success, vol, 0.5)
					else
						emit(SoundManager.Sounds.Notify, vol, 0.7 * ratio)
					end
				end
				task.wait(0.42)
			else
				task.wait(1)
			end
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
