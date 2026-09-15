-- EggHeist | Server/Main.server.luau
-- BOOTSTRAP: loads every domain service in dependency order.
--
-- Layout: ServerScriptService/EggHeistServer/<Domain>/<Name>Service.luau
-- Service contract: module returns a table with optional Init(registry) and Start().
-- Registry key = module name minus the "Service" suffix (e.g. DataService -> Data).

local ROOT = script.Parent
-- Timeouts + asserts: a missing folder must ERROR LOUDLY, never hang the
-- whole bootstrap in an infinite WaitForChild yield (pcall can't save you).
assert(ROOT, "[EggHeist] FATAL: EggHeistServer folder missing")

-- "Domain/Module" paths, in load order. Order matters for Init wiring;
-- runtime cross-service calls resolve through the shared registry.
local LOAD_ORDER = {
	"Net/NetService", -- remotes + routing first (everyone depends on Net)
	"World/WorldService", -- world discovery / fallback before gameplay builds on it
	"World/AtmosphereService", -- map dressing + sky moods (needs the world root)
	"World/NpcService", -- world NPCs (needs the world root)
	"World/TravelService", -- fast travel (needs world anchors + base/heist state)
	"World/ActivitiesService", -- map hotspots (needs world + decor anchors)
	"Data/DataService", -- profiles before any system touches player data
	"Net/NotifyService",
	"Economy/EconomyService",
	"Eggs/EggService",
	"Pets/PetService",
	"Bases/BaseService",
	"Security/SecurityService",
	"Heists/GadgetService", -- gadget state before heists query it
	"Heists/HeistService",
	"Progression/ProgressionService",
	"Quests/QuestService",
	"Rewards/RewardService",
	"Rewards/CollectionService",
	"Progression/AchievementService",
	"Events/EventService",
	"Monetization/ShopService",
	"Social/LeaderboardService",
	"Social/TradeService",
	"Admin/AdminService",
	"Admin/HealthService", -- health check LAST: validates the booted game
}

local registry = {}
registry.Name = "EggHeistRegistry"

local function serviceKey(moduleName)
	return (string.gsub(moduleName, "Service$", ""))
end

local function loadService(path)
	local domain, moduleName = string.match(path, "^([^/]+)/([^/]+)$")
	assert(domain and moduleName, "Bad LOAD_ORDER entry: " .. tostring(path))
	local domainFolder = ROOT:WaitForChild(domain, 30)
	assert(domainFolder, "[EggHeist] FATAL: domain folder missing: " .. domain)
	local moduleScript = domainFolder:WaitForChild(moduleName, 30)
	assert(moduleScript, "[EggHeist] FATAL: service module missing: " .. path)
	return serviceKey(moduleName), require(moduleScript)
end

print("[EggHeist] Starting server...")

local bootStats = { loaded = 0, loadFail = 0, initOk = 0, initFail = 0, startOk = 0, startFail = 0 }

-- Phase 1: require all services
for _, path in ipairs(LOAD_ORDER) do
	local ok, keyOrErr, service = pcall(function()
		local key, svc = loadService(path)
		return key, svc
	end)
	if not ok then
		bootStats.loadFail = bootStats.loadFail + 1
		warn("[EggHeist] FAILED to require " .. path .. ": " .. tostring(keyOrErr))
	else
		bootStats.loaded = bootStats.loaded + 1
		registry[keyOrErr] = service
		print("[EggHeist] Loaded " .. path)
	end
end

-- Make the registry available to any late-requiring code
if not _G.EggHeist then
	_G.EggHeist = {}
end
_G.EggHeist.Registry = registry

-- Phase 2: Init (wiring, no loops yet)
for _, path in ipairs(LOAD_ORDER) do
	local moduleName = string.match(path, "/([^/]+)$")
	local service = registry[serviceKey(moduleName)]
	if service and type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service, registry)
		if not ok then
			bootStats.initFail = bootStats.initFail + 1
			warn("[EggHeist] " .. moduleName .. ".Init failed: " .. tostring(err))
		else
			bootStats.initOk = bootStats.initOk + 1
		end
	end
end

-- Phase 3: Start (loops, listeners)
for _, path in ipairs(LOAD_ORDER) do
	local moduleName = string.match(path, "/([^/]+)$")
	local service = registry[serviceKey(moduleName)]
	if service and type(service.Start) == "function" then
		local ok, err = pcall(service.Start, service)
		if not ok then
			bootStats.startFail = bootStats.startFail + 1
			warn("[EggHeist] " .. moduleName .. ".Start failed: " .. tostring(err))
		else
			bootStats.startOk = bootStats.startOk + 1
		end
	end
end

print(string.format("[EggHeist] Boot summary: %d loaded (%d failed), %d init ok (%d failed), %d start ok (%d failed)",
	bootStats.loaded, bootStats.loadFail, bootStats.initOk, bootStats.initFail,
	bootStats.startOk, bootStats.startFail))

-- READY marker: visible in Explorer + detectable by diagnostics.
-- ALSO a loud final check that the remotes folder exists (no remotes =
-- no game, same class of failure as the v4.0.1 boot hang).
pcall(function()
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local stale = Workspace:FindFirstChild("EggHeistServerOK")
	if stale then
		pcall(function() stale:Destroy() end)
	end
	local diagnostics = registry.World.GetRuntimeFolder("Diagnostics")
	local okValue = diagnostics:FindFirstChild("ServerOK")
	if not okValue then
		okValue = Instance.new("BoolValue")
		okValue.Name = "ServerOK"
		okValue.Parent = diagnostics
	end
	local remotesOk = ReplicatedStorage:FindFirstChild("EggHeistRemotes") ~= nil
	okValue.Value = remotesOk and bootStats.loadFail == 0
	if remotesOk then
		print("[EggHeist] Server READY. Have fun!")
	else
		warn("[EggHeist] FATAL: remotes folder missing after boot - clients cannot connect!")
	end
end)
