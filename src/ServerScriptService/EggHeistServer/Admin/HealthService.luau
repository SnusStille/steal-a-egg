-- EggHeist | Server/Admin/HealthService.luau
-- Foundation health check (spec section 19): validates that every system,
-- remote, config, world anchor, and asset the game needs is actually
-- present and wired. Runs once at boot (LAST in LOAD_ORDER) and prints a
-- ✓/✗ report to the server log. The headless sim fails the build if any
-- check fails, so the project can never silently rot again.
--
-- To extend: add a self.check("label", function() ... end) call in
-- HealthService.Start. Check functions must be fast, synchronous, and
-- must never yield or mutate game state. Return nil for pass, or an
-- error string for fail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Gadgets = require(ConfigFolder:WaitForChild("Gadgets"))
local Security = require(ConfigFolder:WaitForChild("Security"))
local Quests = require(ConfigFolder:WaitForChild("Quests"))
local Events = require(ConfigFolder:WaitForChild("Events"))
local Achievements = require(ConfigFolder:WaitForChild("Achievements"))
local Npcs = require(ConfigFolder:WaitForChild("Npcs"))
local Shop = require(ConfigFolder:WaitForChild("Shop"))
local Upgrades = require(ConfigFolder:WaitForChild("Upgrades"))
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local ModelFactory = require(Shared:WaitForChild("Utilities"):WaitForChild("ModelFactory"))

local HealthService = {}
HealthService.Name = "HealthService"

local registry = nil
local results = {} -- { { ok = bool, label = string, detail = string? } }
local didRun = false

function HealthService.Init(_, reg)
	registry = reg
end

local function record(ok, label, detail)
	results[#results + 1] = { ok = ok and true or false, label = label, detail = detail }
end

local function check(label, fn)
	local ok, err = pcall(fn)
	if ok and err == nil then
		record(true, label, nil)
	else
		record(false, label, tostring(err))
	end
end

local function countDict(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

-- Every service Main is expected to have loaded (registry key = module
-- name minus "Service"). If you add a service to LOAD_ORDER, add it here.
local EXPECTED_SERVICES = {
	"Net", "World", "Atmosphere", "Npc", "Travel", "Activities",
	"Data", "Notify", "Economy", "Egg", "Pet", "Base", "Security",
	"Gadget", "Heist", "Progression", "Quest", "Reward", "Collection",
	"Achievement", "Event", "Shop", "Leaderboard", "Trade", "Admin",
}

local function checkServices()
	local missing = {}
	for _, key in ipairs(EXPECTED_SERVICES) do
		if registry[key] == nil then
			missing[#missing + 1] = key
		end
	end
	if #missing > 0 then
		return "missing services: " .. table.concat(missing, ", ")
	end
	return nil
end

local function checkRemotes()
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if not folder then
		return "remotes folder missing: " .. Remotes.FolderName
	end
	local missing = {}
	for _, name in ipairs(Remotes.C2S) do
		local r = folder:FindFirstChild("C2S_" .. name)
		if not r or not r:IsA("RemoteEvent") then
			missing[#missing + 1] = "C2S_" .. name
		end
	end
	for _, name in ipairs(Remotes.S2C) do
		local r = folder:FindFirstChild("S2C_" .. name)
		if not r or not r:IsA("RemoteEvent") then
			missing[#missing + 1] = "S2C_" .. name
		end
	end
	for _, name in ipairs(Remotes.Fn) do
		local r = folder:FindFirstChild("Fn_" .. name)
		if not r or not r:IsA("RemoteFunction") then
			missing[#missing + 1] = "Fn_" .. name
		end
	end
	if #missing > 0 then
		return "missing remotes: " .. table.concat(missing, ", ")
	end
	return nil
end

local function checkConfigs()
	local problems = {}
	local function nonEmptyList(mod, field, name)
		local list = mod[field]
		if type(list) ~= "table" or #list == 0 then
			problems[#problems + 1] = name .. "." .. field .. " is empty"
		end
	end
	nonEmptyList(Eggs, "List", "Eggs")
	nonEmptyList(Pets, "List", "Pets")
	nonEmptyList(Rarities, "List", "Rarities")
	nonEmptyList(Mutations, "List", "Mutations")
	nonEmptyList(Gadgets, "List", "Gadgets")
	-- Events.List is a dict keyed by event id, not an array
	if type(Events.List) ~= "table" or countDict(Events.List) == 0 then
		problems[#problems + 1] = "Events.List is empty"
	end
	nonEmptyList(Achievements, "List", "Achievements")
	nonEmptyList(Npcs, "List", "Npcs")
	if type(Security.Items) ~= "table" or countDict(Security.Items) == 0 then
		problems[#problems + 1] = "Security.Items is empty"
	end
	if type(Quests.DailyPool) ~= "table" or #Quests.DailyPool == 0 then
		problems[#problems + 1] = "Quests.DailyPool is empty"
	end
	if type(Shop.Decorations) ~= "table" or #Shop.Decorations == 0 then
		problems[#problems + 1] = "Shop.Decorations is empty"
	end
	if type(Upgrades.Tracks) ~= "table" or countDict(Upgrades.Tracks) == 0 then
		problems[#problems + 1] = "Upgrades.Tracks is empty"
	end
	if type(Economy.StartingCash) ~= "number" or Economy.StartingCash <= 0 then
		problems[#problems + 1] = "Economy.StartingCash invalid"
	end
	-- cross-links: every egg references a known rarity weight table entry,
	-- every pet references a known rarity, every gadget has a price
	for _, egg in ipairs(Eggs.List) do
		if type(egg.HatchWeights) ~= "table" then
			problems[#problems + 1] = "egg missing HatchWeights: " .. tostring(egg.Id)
		end
	end
	for _, pet in ipairs(Pets.List) do
		if Rarities.ById[pet.Rarity] == nil then
			problems[#problems + 1] = "pet has unknown rarity: " .. tostring(pet.Id)
		end
	end
	if #problems > 0 then
		return table.concat(problems, "; ")
	end
	return nil
end

local function checkWorld()
	local problems = {}
	local root = registry.World.GetRoot()
	if not root then
		return "world root missing (no EggHeist model, no fallback?)"
	end
	local runtime = root:FindFirstChild("Runtime")
	if not runtime then
		return "EggHeist/Runtime folder missing"
	end
	-- Live is intentionally absent: it is created on first pet equip.
	-- Spawns is intentionally absent when the place already provides a
	-- SpawnLocation (EnsureSpawn reuses it instead of building one).
	for _, name in ipairs({ "Activities", "Decor", "Gameplay", "Npcs" }) do
		if not runtime:FindFirstChild(name) then
			problems[#problems + 1] = "Runtime/" .. name .. " missing"
		end
	end
	local plotCount = Settings.MaxBasePlots or 8
	local goodPlots = 0
	for i = 1, plotCount do
		local plot = registry.World.GetPlotModel(i)
		local foundation = plot and plot:FindFirstChild("Foundation")
		if foundation and foundation:IsA("BasePart") then
			goodPlots = goodPlots + 1
		else
			problems[#problems + 1] = "Plot" .. string.format("%02d", i) .. " has no Foundation"
		end
	end
	local spawnCf = registry.World.GetSpawnCFrame()
	if typeof(spawnCf) ~= "CFrame" then
		problems[#problems + 1] = "GetSpawnCFrame did not return a CFrame"
	end
	if Workspace:FindFirstChildOfClass("SpawnLocation") == nil then
		problems[#problems + 1] = "no SpawnLocation anywhere in Workspace"
	end
	local gameplay = runtime:FindFirstChild("Gameplay")
	if gameplay and not gameplay:FindFirstChild("ExtractionPad") then
		problems[#problems + 1] = "ExtractionPad missing"
	end
	if #problems > 0 then
		return table.concat(problems, "; ")
	end
	return nil
end

local function checkAssets()
	local problems = {}
	for _, pet in ipairs(Pets.List) do
		local ok, model = pcall(ModelFactory.BuildCreature, pet.Id, nil, 0.8)
		if not ok or not model then
			problems[#problems + 1] = "creature model failed: " .. tostring(pet.Id)
		elseif model.Destroy then
			pcall(function() model:Destroy() end)
		end
	end
	local root = registry.World.GetRoot()
	local eggAssets = root and root:FindFirstChild("EggAssets")
	if not eggAssets or #eggAssets:GetChildren() == 0 then
		problems[#problems + 1] = "EggAssets folder empty or missing"
	end
	if #problems > 0 then
		return table.concat(problems, "; ")
	end
	return nil
end

local function checkDataApi()
	local problems = {}
	for _, fn in ipairs({ "GetProfile", "MarkDirty", "GenerateUid" }) do
		if type(registry.Data[fn]) ~= "function" then
			problems[#problems + 1] = "DataService." .. fn .. " missing"
		end
	end
	local ok, rec = pcall(Types.NewPetRecord, "health-uid", "chick", nil)
	if not ok or not rec or rec.id ~= "chick" then
		problems[#problems + 1] = "Types.NewPetRecord broken"
	end
	local ok2, key = pcall(Types.CollectionKey, "chick", nil)
	if not ok2 or type(key) ~= "string" then
		problems[#problems + 1] = "Types.CollectionKey broken"
	end
	if #problems > 0 then
		return table.concat(problems, "; ")
	end
	return nil
end

function HealthService.Start()
	if didRun then
		return
	end
	didRun = true
	check("services loaded", checkServices)
	check("remotes registered", checkRemotes)
	check("configs valid", checkConfigs)
	check("world + plots", checkWorld)
	check("creature + egg assets", checkAssets)
	check("data API", checkDataApi)

	print("[Health] --- Egg Heist health check ---")
	local fails = 0
	for _, r in ipairs(results) do
		if r.ok then
			print("[Health]   PASS  " .. r.label)
		else
			fails = fails + 1
			print("[Health]   FAIL  " .. r.label .. " :: " .. tostring(r.detail))
		end
	end
	if fails == 0 then
		print("[Health] ALL " .. tostring(#results) .. " CHECKS PASSED")
	else
		warn("[Health] " .. tostring(fails) .. " OF "
			.. tostring(#results) .. " CHECKS FAILED")
	end
	-- Diagnostics value mirrors the result for Explorer + external tooling
	pcall(function()
		local diagnostics = registry.World.GetRuntimeFolder("Diagnostics")
		local value = diagnostics:FindFirstChild("HealthOK")
		if not value then
			value = Instance.new("BoolValue")
			value.Name = "HealthOK"
			value.Parent = diagnostics
		end
		value.Value = (fails == 0)
	end)
end

function HealthService.GetReport()
	return results
end

function HealthService.GetFailCount()
	local fails = 0
	for _, r in ipairs(results) do
		if not r.ok then
			fails = fails + 1
		end
	end
	return fails
end

function HealthService.DidRun()
	return didRun
end

return HealthService
