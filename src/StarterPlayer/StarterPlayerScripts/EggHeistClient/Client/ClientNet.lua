-- EggHeist | Client/ClientNet.lua
-- Client-side remote access (waits for server-created remotes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Remotes = require(Shared:WaitForChild("Remotes"))

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
		local ok, result = pcall(function()
			return rf:InvokeServer(...)
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
