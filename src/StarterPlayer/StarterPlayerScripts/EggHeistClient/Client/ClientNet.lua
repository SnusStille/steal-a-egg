-- EggHeist | Client/ClientNet.lua
-- Client-side remote access (waits for server-created remotes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared", 30)
assert(Shared, "[EggHeist] FATAL: EggHeistShared missing in ReplicatedStorage - install broken?")
local RemotesModule = Shared:WaitForChild("Remotes", 30)
assert(RemotesModule, "[EggHeist] FATAL: Remotes module missing - install broken?")
local Remotes = require(RemotesModule)

local ClientNet = {}
local folder = nil

function ClientNet.Init()
	folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, 60)
	assert(folder, "[EggHeist] Remotes folder not found")
	for _, name in ipairs(Remotes.C2S) do
		folder:WaitForChild("C2S_" .. name, 30)
	end
	for _, name in ipairs(Remotes.S2C) do
		folder:WaitForChild("S2C_" .. name, 30)
	end
	for _, name in ipairs(Remotes.Fn) do
		folder:WaitForChild("Fn_" .. name, 30)
	end
end

function ClientNet.Fire(name, ...)
	assert(folder, "ClientNet not initialized")
	local re = folder:FindFirstChild("C2S_" .. name)
	if re then
		re:FireServer(...)
	end
end

function ClientNet.On(name, callback)
	assert(folder, "ClientNet not initialized")
	local re = folder:FindFirstChild("S2C_" .. name)
	if re then
		return re.OnClientEvent:Connect(callback)
	end
	return nil
end

function ClientNet.Invoke(name, ...)
	assert(folder, "ClientNet not initialized")
	local rf = folder:FindFirstChild("Fn_" .. name)
	if rf then
		-- NOTE: Luau forbids using '...' inside a nested closure, so the
		-- varargs MUST be packed into a table first (passing '...' straight
		-- into the pcall callback is a compile error that kills the client).
		local args = { ... }
		local ok, result = pcall(function()
			return rf:InvokeServer(unpack(args))
		end)
		if ok then
			return result
		end
	end
	return nil
end

function ClientNet.LocalPlayer()
	return Players.LocalPlayer
end

return ClientNet
