-- EggHeist | Shared/Config/Audio.luau
-- Central sound bank: every SFX the game can play, in ONE data module.
-- SoundManager (client) reads this table. Built-in rbxasset:// sounds
-- ship with the client, so no uploads are needed for SFX.
-- Music tracks need uploaded asset IDs: add them to Audio.Music when
-- available. The game runs fine (silently) without them.
local Audio = {}

-- Well-known built-in sounds (shipped with the client)
Audio.Sfx = {
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

-- Background music (uploaded IDs go here; empty = no music).
Audio.Music = {
	-- Lobby = "rbxassetid://0000000000",
}

return Audio
