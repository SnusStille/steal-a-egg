-- EggHeist | Server/Net/NetService.luau
-- Creates all remotes from the shared registry, routes C2S handlers with
-- validation + rate limiting, and provides S2C fire helpers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local RateLimiter = require(script.Parent.Parent:WaitForChild("Utilities"):WaitForChild("RateLimiter"))

local NetService = {}
NetService.Name = "NetService"

local registry = nil
local limiter = nil
local remoteFolder = nil
local events = {}
local functions = {}

function NetService.Init(_, reg)
	registry = reg
	limiter = RateLimiter.new()

	remoteFolder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = Remotes.FolderName
		remoteFolder.Parent = ReplicatedStorage
	end

	for _, name in ipairs(Remotes.C2S) do
		local re = remoteFolder:FindFirstChild("C2S_" .. name)
		if not re then
			re = Instance.new("RemoteEvent")
			re.Name = "C2S_" .. name
			re.Parent = remoteFolder
		end
		events[name] = re
	end
	for _, name in ipairs(Remotes.S2C) do
		local re = remoteFolder:FindFirstChild("S2C_" .. name)
		if not re then
			re = Instance.new("RemoteEvent")
			re.Name = "S2C_" .. name
			re.Parent = remoteFolder
		end
		events["S2C_" .. name] = re
	end
	for _, name in ipairs(Remotes.Fn) do
		local rf = remoteFolder:FindFirstChild("Fn_" .. name)
		if not rf then
			rf = Instance.new("RemoteFunction")
			rf.Name = "Fn_" .. name
			rf.Parent = remoteFolder
		end
		functions[name] = rf
	end

	Players.PlayerRemoving:Connect(function(player)
		limiter:ClearPlayer(player)
	end)
end

-- Register a C2S handler. validator(player, ...) -> true/false (optional).
function NetService.OnRequest(endpoint, handler, validator)
	local re = events[endpoint]
	assert(re, "[EggHeist] Unknown C2S endpoint: " .. tostring(endpoint))
	local limit = Remotes.RateLimits[endpoint] or 10
	re.OnServerEvent:Connect(function(player, ...)
		if not limiter:Check(player, endpoint, limit) then
			return -- silently drop spam
		end
		if validator then
			local ok, valid = pcall(validator, player, ...)
			if not ok or not valid then
				return
			end
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn("[EggHeist] Handler error (" .. endpoint .. "): " .. tostring(err))
		end
	end)
end

function NetService.OnFunction(endpoint, handler)
	local rf = functions[endpoint]
	assert(rf, "[EggHeist] Unknown Fn endpoint: " .. tostring(endpoint))
	rf.OnServerInvoke = function(player, ...)
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn("[EggHeist] Function error (" .. endpoint .. "): " .. tostring(result))
			return nil
		end
		return result
	end
end

function NetService.Fire(player, endpoint, ...)
	local re = events["S2C_" .. endpoint]
	if re then
		re:FireClient(player, ...)
	end
end

function NetService.FireAll(endpoint, ...)
	local re = events["S2C_" .. endpoint]
	if re then
		re:FireAllClients(...)
	end
end

function NetService.FireExcept(exceptPlayer, endpoint, ...)
	local re = events["S2C_" .. endpoint]
	if not re then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= exceptPlayer then
			re:FireClient(player, ...)
		end
	end
end

function NetService.Start()
end

return NetService
