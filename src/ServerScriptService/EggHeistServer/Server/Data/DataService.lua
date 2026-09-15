-- EggHeist | Server/Data/DataService.lua
-- Player profiles: load/save (DataStore), defaults, autosave, safe shutdown.
-- Studio-safe: falls back to memory-only profiles when DataStores are
-- unavailable (e.g. Studio with API access disabled).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local SecurityConfig = require(ConfigFolder:WaitForChild("Security"))
local UpgradesConfig = require(ConfigFolder:WaitForChild("Upgrades"))
local TableUtil = require(Shared:WaitForChild("Utilities"):WaitForChild("TableUtil"))

local DataService = {}
DataService.Name = "DataService"

local registry = nil
local profiles = {} -- [userId] = profile
local store = nil
local storeOk = false
local shuttingDown = false

local STORE_NAME = "EggHeist_Profiles_v" .. tostring(Settings.DataStoreVersion)

local function defaultUpgrades()
	local t = {}
	for _, trackId in ipairs(UpgradesConfig.TrackOrder) do
		t[trackId] = 0
	end
	return t
end

local function defaultSecurity()
	local t = {}
	for _, itemId in ipairs(SecurityConfig.ItemOrder) do
		t[itemId] = 0
	end
	return t
end

-- Public default builders so other systems (e.g. prestige resets) never
-- hardcode track/item keys. Always returns a FRESH table (safe to assign).
function DataService.GetDefaultUpgrades()
	return defaultUpgrades()
end

function DataService.GetDefaultSecurity()
	return defaultSecurity()
end

local function defaultProfile(userId)
	return {
		version = Settings.DataStoreVersion,
		userId = userId,
		cash = Economy.StartingCash,
		gems = Economy.StartingGems,
		xp = 0,
		level = 1,
		eggs = {}, -- { {uid=..., eggId=...} }
		pets = {}, -- { {uid=..., id=..., mut=..., lvl=..., xp=...} }
		equipped = {}, -- list of pet uids, in slot order
		collection = {}, -- ["petId:mut"] = hatch count
		gadgets = {}, -- [gadgetId] = count owned
		achievements = {}, -- [achievementId] = { done, claimed }
		collectionRewards = {}, -- [milestoneIndex] = true when claimed
		base = {
			plot = 0,
			upgrades = defaultUpgrades(),
			security = defaultSecurity(),
			vault = 0,
			decorations = {},
			lockdownUntil = 0,
			lockdownCooldownUntil = 0,
		},
		quests = {
			dailyDate = "",
			dailies = {},
			weeklyKey = "",
			weeklies = {},
		},
		daily = { lastClaimDay = -1, streak = 0 },
		prestige = { count = 0, bonus = 0 },
		settings = {
			music = true,
			sfx = true,
			notifications = true,
			showPets = true,
			autoHatch = false,
			cameraShake = true,
			reducedEffects = false,
			performanceMode = false,
			heistAlerts = true,
			npcTips = true,
		},
		tutorial = { done = false, step = 1 },
		boosts = {}, -- { {id=..., expiresAt=...} }
		stats = {
			totalEarned = 0,
			totalHatched = 0,
			mutatedHatched = 0,
			eggsBought = 0,
			maxRarityTier = 0,
			legendaryPlusHatched = 0,
			secretsHatched = 0,
			heistRep = 0,
			heistsWon = 0,
			heistsFailed = 0,
			timesRobbed = 0,
			vaultBanked = 0,
			playMinutes = 0,
			upgradesBought = 0,
			securityBought = 0,
			defensesTriggered = 0,
			questsDone = 0,
			gadgetsUsed = 0,
			tradesCompleted = 0,
		},
		gamepasses = {},
		autoHatchUnlock = false, -- permanent gems unlock (alt. to gamepass)
		lastSeen = os.time(),
		_uidCounter = 0,
	}
end

-- Merge loaded data over defaults (forward-compatible with new fields)
local function mergeDefaults(defaults, loaded)
	if type(loaded) ~= "table" then
		return TableUtil.DeepCopy(defaults)
	end
	if type(defaults) ~= "table" then
		return loaded
	end
	local out = {}
	-- array-like tables: keep loaded as-is (validated separately)
	local isArray = #defaults > 0 or (#loaded > 0 and TableUtil.Count(defaults) == 0)
	if isArray and #loaded > 0 then
		return TableUtil.DeepCopy(loaded)
	end
	for k, v in pairs(defaults) do
		if loaded[k] == nil then
			out[k] = TableUtil.DeepCopy(v)
		elseif type(v) == "table" and type(loaded[k]) == "table" then
			out[k] = mergeDefaults(v, loaded[k])
		else
			out[k] = loaded[k]
		end
	end
	return out
end

local function sanitizeNumber(value, defaultValue, minValue, maxValue)
	if type(value) ~= "number" or value ~= value then
		return defaultValue
	end
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return math.floor(value)
end

local function sanitizeProfile(p)
	p.cash = sanitizeNumber(p.cash, Economy.StartingCash, 0, Economy.MaxCash)
	p.gems = sanitizeNumber(p.gems, Economy.StartingGems, 0, Economy.MaxGems)
	p.xp = sanitizeNumber(p.xp, 0, 0, 1e12)
	p.level = sanitizeNumber(p.level, 1, 1, Economy.MaxLevel)
	if type(p.eggs) ~= "table" then p.eggs = {} end
	if type(p.pets) ~= "table" then p.pets = {} end
	if type(p.equipped) ~= "table" then p.equipped = {} end
	if type(p.collection) ~= "table" then p.collection = {} end
	if type(p.gadgets) ~= "table" then p.gadgets = {} end
	if type(p.achievements) ~= "table" then p.achievements = {} end
	if type(p.collectionRewards) ~= "table" then p.collectionRewards = {} end
	-- clamp gadget counts (exploit/shenanigan guard)
	for gadgetId, count in pairs(p.gadgets) do
		if type(count) ~= "number" or count < 0 then
			p.gadgets[gadgetId] = nil
		elseif count > 99 then
			p.gadgets[gadgetId] = 99
		end
	end
	if type(p.stats.heistRep) ~= "number" or p.stats.heistRep < 0 then
		p.stats.heistRep = 0
	end
	if type(p.base) ~= "table" then p.base = {} end
	p.base.plot = sanitizeNumber(p.base.plot, 0, 0, Settings.MaxBasePlots)
	p.base.vault = sanitizeNumber(p.base.vault, 0, 0, 1e12)
	if type(p.base.upgrades) ~= "table" then p.base.upgrades = defaultUpgrades() end
	if type(p.base.security) ~= "table" then p.base.security = defaultSecurity() end
	if type(p.base.decorations) ~= "table" then p.base.decorations = {} end
	-- trim oversized lists (exploit/shenanigan guard)
	while #p.eggs > 200 do table.remove(p.eggs, 1) end
	while #p.pets > Economy.MaxPetsStored + 20 do table.remove(p.pets, 1) end
	while #p.equipped > Economy.MaxPetSlots do table.remove(p.equipped) end
	return p
end

function DataService.Init(_, reg)
	registry = reg
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		storeOk = true
		print("[EggHeist] DataStore connected: " .. STORE_NAME)
	else
		storeOk = false
		warn("[EggHeist] DataStore unavailable (memory-only profiles): " .. tostring(result))
	end
end

function DataService.GetProfile(player)
	if not player then
		return nil
	end
	return profiles[player.UserId]
end

function DataService.WaitForProfile(player, timeout)
	timeout = timeout or 30
	local waited = 0
	while profiles[player.UserId] == nil and waited < timeout do
		task.wait(0.1)
		waited = waited + 0.1
	end
	return profiles[player.UserId]
end

function DataService.GenerateUid(player)
	local p = profiles[player.UserId]
	if not p then
		return "uid-" .. tostring(math.random(1, 999999999))
	end
	p._uidCounter = (p._uidCounter or 0) + 1
	return "u" .. tostring(player.UserId) .. "-" .. tostring(os.time() % 100000) .. "-" .. tostring(p._uidCounter)
end

-- Marks profile dirty so it syncs to the client (coalesced in Start loop)
local dirtyPlayers = {}
function DataService.MarkDirty(player)
	if player then
		dirtyPlayers[player.UserId] = true
	end
end

local function loadProfile(player)
	local key = "player-" .. tostring(player.UserId)
	local loaded = nil
	if storeOk then
		-- Also attempted in Studio (works when API access is enabled).
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			loaded = result
		elseif not RunService:IsStudio() then
			warn("[EggHeist] Load failed for " .. player.Name .. ": " .. tostring(result))
		end
	end
	local profile
	if loaded and type(loaded) == "table" and loaded.version == Settings.DataStoreVersion then
		profile = sanitizeProfile(mergeDefaults(defaultProfile(player.UserId), loaded))
		profile.isNew = false
	else
		profile = defaultProfile(player.UserId)
		profile.isNew = true
	end
	profile._dirtySync = true
	profiles[player.UserId] = profile
	return profile
end

function DataService.SaveProfile(player, isShutdown)
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	profile.lastSeen = os.time()
	profile.isNew = nil
	profile._dirtySync = nil
	if not storeOk then
		return true -- memory-only mode
	end
	local key = "player-" .. tostring(player.UserId)
	local payload = TableUtil.CopyData(profile)
	local ok, err = pcall(function()
		store:UpdateAsync(key, function()
			return payload
		end)
	end)
	if not ok then
		warn("[EggHeist] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

local function onPlayerAdded(player)
	local profile = loadProfile(player)
	-- gamepass cache refresh (best effort)
	task.spawn(function()
		if registry.Shop then
			registry.Shop.RefreshOwnership(player)
		end
	end)
	-- quest roll + daily availability handled by QuestService/RewardService via hooks
	if registry.Quest then
		registry.Quest.EnsureQuests(player)
	end
	-- offline earnings (returning players only)
	if not profile.isNew and profile.lastSeen then
		task.spawn(function()
			task.wait(2)
			if not player.Parent then
				return
			end
			local away = os.time() - (profile.lastSeen or os.time())
			if away > 300 and registry.Pet and registry.Economy then
				local capped = math.min(away, Economy.OfflineCapHours * 3600)
				local perSecond = registry.Pet.ComputeEquippedIncome(player)
				if perSecond > 0 then
					local earnings = math.floor(perSecond * capped * Economy.OfflineRate)
					if earnings > 0 then
						registry.Economy.AddCash(player, earnings, "offline")
						registry.Notify.Send(player, "success", "Welcome back!",
							"Your pals earned while you were away.", 6)
					end
				end
			end
		end)
	end
	-- starter grant for brand-new players (first 10 minutes matter most)
	if profile.isNew then
		profile.cash = profile.cash + Settings.Tutorial.StarterCashBonus
		profile.eggs[#profile.eggs + 1] = {
			uid = DataService.GenerateUid(player),
			eggId = Settings.Tutorial.StarterEgg,
		}
		task.delay(3, function()
			if player.Parent then
				registry.Notify.Send(player, "success", "Welcome to Egg Heist!",
					"Here's a free egg + cash. Follow the guide (bottom-left)!", 8)
			end
		end)
	end
	-- full sync after a short delay (client needs remotes + UI ready)
	task.delay(1, function()
		if player.Parent then
			DataService.SyncNow(player)
		end
	end)
	print("[EggHeist] Profile loaded for " .. player.Name .. (profile.isNew and " (new player)" or ""))
end

local function onPlayerRemoving(player)
	if registry.Heist then
		registry.Heist.HandlePlayerLeaving(player)
	end
	if registry.Pet then
		registry.Pet.CleanupPlayer(player)
	end
	if registry.Base then
		registry.Base.ReleasePlot(player)
	end
	DataService.SaveProfile(player, shuttingDown)
	profiles[player.UserId] = nil
	dirtyPlayers[player.UserId] = nil
end

-- Builds the client-safe snapshot (drops internal fields)
function DataService.BuildSnapshot(player)
	local profile = profiles[player.UserId]
	if not profile then
		return nil
	end
	local snap = TableUtil.CopyData(profile)
	snap._uidCounter = nil
	return snap
end

function DataService.SyncNow(player)
	local profile = profiles[player.UserId]
	if not profile or not registry.Net then
		return
	end
	dirtyPlayers[player.UserId] = nil
	local snap = DataService.BuildSnapshot(player)
	if snap then
		registry.Net.Fire(player, "DataSync", snap)
	end
end

function DataService.Start()
	-- Net endpoints
	registry.Net.OnRequest("UpdateSetting", function(player, key, value)
		local profile = profiles[player.UserId]
		if not profile then
			return
		end
		if type(key) ~= "string" or #key > 32 then
			return
		end
		if profile.settings[key] == nil then
			return
		end
		if type(value) ~= "boolean" then
			return
		end
		profile.settings[key] = value
		DataService.MarkDirty(player)
	end)

	registry.Net.OnFunction("GetData", function(player)
		return DataService.BuildSnapshot(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Coalesced sync loop (max ~2/sec per dirty player)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local pending = {}
			for userId, _ in pairs(dirtyPlayers) do
				pending[#pending + 1] = userId
			end
			for _, userId in ipairs(pending) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					DataService.SyncNow(player)
				else
					dirtyPlayers[userId] = nil
				end
			end
		end
	end)

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(Settings.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				if profiles[player.UserId] then
					DataService.SaveProfile(player, false)
					task.wait(0.5) -- stagger to avoid throttling
				end
			end
		end
	end)

	-- Playtime ticker (minute granularity)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = profiles[player.UserId]
				if profile then
					profile.stats.playMinutes = (profile.stats.playMinutes or 0) + 1
					if registry.Quest then
						registry.Quest.AddProgress(player, "PlayMinutes", 1)
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.SaveProfile(player, true)
		end
	end)
end

return DataService
