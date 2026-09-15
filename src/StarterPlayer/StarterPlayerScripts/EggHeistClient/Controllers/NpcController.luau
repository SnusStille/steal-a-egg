-- EggHeist | Client/Controllers/NpcController.luau
-- Wires world NPC talk-prompts to UI shortcuts + greeting toasts.
-- Talking to an NPC only opens LOCAL UI: zero exploit surface.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Npcs = require(Shared:WaitForChild("Config"):WaitForChild("Npcs"))

local NpcController = {}
local ctx = nil
local wired = {} -- [ProximityPrompt] = true

function NpcController.Init(context)
	ctx = context
end

local function talkTo(npcId)
	local def = Npcs.ById[npcId]
	if not def then
		return
	end
	-- greeting toast
	local notifications = ctx.Screens and ctx.Screens.NotificationsScreen
	if notifications and def.Greetings and #def.Greetings > 0 then
		local line = def.Greetings[math.random(1, #def.Greetings)]
		notifications.Show("info", def.DisplayName or npcId, line, 5)
	end
	-- open the mapped UI
	local action = def.Action
	if action and action.Screen then
		local ui = ctx.Screens and ctx.Screens[action.Screen]
		if ui then
			if action.Tab and type(ui.ShowTab) == "function" then
				ui.ShowTab(action.Tab)
			end
			if type(ui.SetVisible) == "function" then
				ui.SetVisible(true)
			elseif type(ui.Toggle) == "function" then
				ui.Toggle()
			end
		end
	end
end

local function openShop()
	local shop = ctx.Screens and ctx.Screens.ShopScreen
	if shop then
		if type(shop.ShowTab) == "function" then
			shop.ShowTab("Eggs")
		end
		if type(shop.SetVisible) == "function" then
			shop.SetVisible(true)
		elseif type(shop.Toggle) == "function" then
			shop.Toggle()
		end
	end
end

local function wirePrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	if wired[prompt] then
		return
	end
	if prompt.Name == "NpcPrompt" then
		wired[prompt] = true
		prompt.Triggered:Connect(function()
			local npcId = prompt:GetAttribute("NpcId")
			if npcId then
				talkTo(npcId)
			end
		end)
	elseif prompt.Name == "MarketPrompt" then
		wired[prompt] = true
		prompt.Triggered:Connect(openShop)
	end
end

function NpcController.Start()
	-- NPCs are built during server Start; the client may boot first in
	-- Play Solo, so wire existing prompts AND late-arriving ones.
	local root = Workspace:FindFirstChild("EggHeist")
	if root then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				wirePrompt(descendant)
			end
		end
		root.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("ProximityPrompt") then
				wirePrompt(descendant)
			end
		end)
	else
		task.delay(5, function()
			local lateRoot = Workspace:FindFirstChild("EggHeist")
			if lateRoot then
				for _, descendant in ipairs(lateRoot:GetDescendants()) do
					if descendant:IsA("ProximityPrompt") then
						wirePrompt(descendant)
					end
				end
				lateRoot.DescendantAdded:Connect(function(descendant)
					if descendant:IsA("ProximityPrompt") then
						wirePrompt(descendant)
					end
				end)
			end
		end)
	end
end

return NpcController
