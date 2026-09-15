-- EggHeist | Server/ServerMain.server.lua
-- BOOTSTRAP: loads every domain service in dependency order.
--
-- Layout: ServerScriptService/EggHeistServer/Server/<Domain>/<Name>Service.lua
-- Service contract: module returns a table with optional Init(registry) and Start().
-- Registry key = module name minus the "Service" suffix (e.g. DataService -> Data).

local ROOT = script.Parent
local ServerFolder = ROOT:WaitForChild("Server")

-- "Domain/Module" paths, in load order. Order matters for Init wiring;
-- runtime cross-service calls resolve through the shared registry.
local LOAD_ORDER = {
	"Net/NetService", -- remotes + routing first (everyone depends on Net)
	"World/WorldService", -- world discovery / fallback before gameplay builds on it
	"World/NpcService", -- world NPCs (needs the world root)
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
	"Admin/AdminService",
}

local registry = {}
registry.Name = "EggHeistRegistry"

local function serviceKey(moduleName)
	return (string.gsub(moduleName, "Service$", ""))
end

local function loadService(path)
	local domain, moduleName = string.match(path, "^([^/]+)/([^/]+)$")
	assert(domain and moduleName, "Bad LOAD_ORDER entry: " .. tostring(path))
	local domainFolder = ServerFolder:WaitForChild(domain)
	local moduleScript = domainFolder:WaitForChild(moduleName)
	return serviceKey(moduleName), require(moduleScript)
end

print("[EggHeist] Starting server...")

-- Phase 1: require all services
for _, path in ipairs(LOAD_ORDER) do
	local ok, keyOrErr, service = pcall(function()
		local key, svc = loadService(path)
		return key, svc
	end)
	if not ok then
		warn("[EggHeist] FAILED to require " .. path .. ": " .. tostring(keyOrErr))
	else
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
			warn("[EggHeist] " .. moduleName .. ".Init failed: " .. tostring(err))
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
			warn("[EggHeist] " .. moduleName .. ".Start failed: " .. tostring(err))
		end
	end
end

print("[EggHeist] Server started. Have fun!")
