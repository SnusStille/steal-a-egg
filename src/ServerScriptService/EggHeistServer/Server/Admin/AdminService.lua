-- EggHeist | Server/Admin/AdminService.lua
-- Lightweight admin commands for testing and live-ops.
-- Add your Roblox userId(s) to ADMINS before publishing.

local ADMINS = {
	-- 12345678,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Eggs = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

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

-- Safe chat commands for EVERYONE (no admin needed): /stats /players /time /help
local function handleChat(player, message)
	if type(message) ~= "string" or string.sub(message, 1, 1) ~= "/" then
		return
	end
	local command = string.lower(Validate.String(message:match("^/(%S+)") or "", 16, ""))
	if command == "stats" then
		local profile = registry.Data.GetProfile(player)
		if profile then
			registry.Notify.Send(player, "info", "Your stats",
				"Lv" .. tostring(profile.level or 1)
				.. " | $" .. tostring(profile.cash or 0)
				.. " | " .. tostring(#(profile.pets or {})) .. " pets"
				.. " | " .. tostring(profile.stats.heistsWon or 0) .. " heists won"
				.. " | " .. tostring(profile.stats.totalHatched or 0) .. " hatched", 6)
		end
	elseif command == "players" then
		local names = {}
		for _, other in ipairs(Players:GetPlayers()) do
			names[#names + 1] = other.DisplayName
		end
		registry.Notify.Send(player, "info", "Players online (" .. tostring(#names) .. ")",
			table.concat(names, ", "), 6)
	elseif command == "time" then
		local lighting = game:GetService("Lighting")
		registry.Notify.Send(player, "info", "World time",
			"Clock: " .. string.format("%.1f", lighting.ClockTime), 4)
	elseif command == "help" then
		registry.Notify.Send(player, "info", "Chat commands",
			"/stats /players /time /help - plus the ? button for the full guide!", 6)
	end
end

function AdminService.Start()
	registry.Net.OnRequest("Admin", function(player, command, arg1, arg2)
		handle(player, command, arg1, arg2)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.Chatted:Connect(function(message)
			pcall(handleChat, player, message)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			pcall(handleChat, player, message)
		end)
	end)
end

return AdminService
