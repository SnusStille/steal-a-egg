-- EggHeist | Server/Init.server.lua
-- BOOTSTRAP: loads every system in dependency order.
-- Service contract: module returns table with optional Init(registry) and Start().

local ServerScriptService = game:GetService("ServerScriptService")

local ROOT = script.Parent
local ServerFolder = ROOT:WaitForChild("Server")
local ServicesFolder = ServerFolder:WaitForChild("Services")

local LOAD_ORDER = {
	"NetService",
	"WorldService",
	"DataService",
	"NotifyService",
	"EconomyService",
	"EggService",
	"PetService",
	"BaseService",
	"SecurityService",
	"HeistService",
	"QuestService",
	"RewardService",
	"EventService",
	"ShopService",
	"LeaderboardService",
	"AdminService",
}

local registry = {}
registry.Name = "EggHeistRegistry"

local function serviceKey(moduleName)
	return string.gsub(moduleName, "Service$", "")
end

print("[EggHeist] Starting server...")

-- Phase 1: require all services
for _, moduleName in ipairs(LOAD_ORDER) do
	local moduleScript = ServicesFolder:WaitForChild(moduleName)
	local ok, service = pcall(require, moduleScript)
	if not ok then
		warn("[EggHeist] FAILED to require " .. moduleName .. ": " .. tostring(service))
	else
		registry[serviceKey(moduleName)] = service
		print("[EggHeist] Loaded " .. moduleName)
	end
end

-- Make the registry available to any late-requiring code
if not _G.EggHeist then
	_G.EggHeist = {}
end
_G.EggHeist.Registry = registry

-- Phase 2: Init (wiring, no loops yet)
for _, moduleName in ipairs(LOAD_ORDER) do
	local service = registry[serviceKey(moduleName)]
	if service and type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service, registry)
		if not ok then
			warn("[EggHeist] " .. moduleName .. ".Init failed: " .. tostring(err))
		end
	end
end

-- Phase 3: Start (loops, listeners)
for _, moduleName in ipairs(LOAD_ORDER) do
	local service = registry[serviceKey(moduleName)]
	if service and type(service.Start) == "function" then
		local ok, err = pcall(service.Start, service)
		if not ok then
			warn("[EggHeist] " .. moduleName .. ".Start failed: " .. tostring(err))
		end
	end
end

print("[EggHeist] Server started. Have fun!")
