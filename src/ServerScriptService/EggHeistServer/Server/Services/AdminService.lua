-- EggHeist | Server/Services/AdminService.lua
-- Lightweight admin commands for testing and live-ops.
-- Add your Roblox userId(s) to ADMINS before publishing.

local ADMINS = {
	-- 12345678,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Eggs = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local Validate = require(Shared:WaitForChild("Util"):WaitForChild("Validate"))

local AdminService = {}
AdminService.Name = "AdminService"

local registry = nil

function AdminService.Init(_, reg)
	registry = reg
end

function AdminService.IsAdmin(player)
	if not player then
		return false
	end
	for _, id in ipairs(ADMINS) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

local function handle(player, command, arg1, arg2)
	if not AdminService.IsAdmin(player) then
		return
	end
	command = Validate.String(command, 32, "")
	print("[EggHeist][Admin] " .. player.Name .. " ran " .. command
		.. " " .. tostring(arg1) .. " " .. tostring(arg2))
	if command == "cash" then
		local amount = Validate.ClampNumber(tonumber(arg1) or 0, 1, 100000000, 0)
		registry.Economy.AddCash(player, amount, "admin")
	elseif command == "gems" then
		local amount = Validate.ClampNumber(tonumber(arg1) or 0, 1, 100000, 0)
		registry.Economy.AddGems(player, amount, "admin")
	elseif command == "egg" then
		local eggId = Validate.String(arg1, 32, "Basic")
		if Eggs.IsValid(eggId) then
			registry.Egg.GiftEgg(player, eggId, "admin")
		end
	elseif command == "level" then
		local profile = registry.Data.GetProfile(player)
		local target = Validate.ClampNumber(tonumber(arg1) or 1, 1, 100, 1)
		if profile then
			profile.level = math.floor(target)
			profile.xp = 0
			registry.Data.MarkDirty(player)
		end
	elseif command == "event" then
		local eventId = Validate.String(arg1, 32, "")
		registry.Event.StartEvent(eventId, true)
	elseif command == "event_end" then
		registry.Event.EndEvent()
	elseif command == "save" then
		registry.Data.SaveProfile(player, false)
		registry.Notify.Send(player, "info", "Saved", "Profile saved.", 3)
	end
end

function AdminService.Start()
	registry.Net.OnRequest("Admin", function(player, command, arg1, arg2)
		handle(player, command, arg1, arg2)
	end)
end

return AdminService
