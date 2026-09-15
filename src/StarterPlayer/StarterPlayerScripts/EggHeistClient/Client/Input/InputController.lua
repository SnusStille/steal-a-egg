-- EggHeist | Client/Input/InputController.lua
-- Central keyboard input. Touch players use the on-screen nav buttons in
-- MainUI (TextButtons work with touch), so this module is PC-only by nature
-- and safely no-ops on mobile.
--
-- Add a keybind: InputController.Bind(Enum.KeyCode.X, function() ... end, "Label")

local UserInputService = game:GetService("UserInputService")

local InputController = {}

local ctx = nil
local bindings = {} -- [KeyCode] = { action = fn, label = string }

function InputController.Init(context)
	ctx = context
end

function InputController.Bind(keyCode, action, label)
	assert(typeof(keyCode) == "EnumItem", "Bind expects a KeyCode")
	assert(type(action) == "function", "Bind expects a function")
	bindings[keyCode] = { action = action, label = label or "" }
end

function InputController.Unbind(keyCode)
	bindings[keyCode] = nil
end

function InputController.ListBindings()
	local out = {}
	for keyCode, binding in pairs(bindings) do
		out[#out + 1] = { key = keyCode.Name, label = binding.label }
	end
	table.sort(out, function(a, b)
		return a.key < b.key
	end)
	return out
end

local function toggleUI(name)
	local ui = ctx.UI and ctx.UI[name]
	if ui and type(ui.Toggle) == "function" then
		ui.Toggle()
	end
end

function InputController.Start()
	-- Default bindings (registered in Start: ctx.UI is fully loaded by now).
	InputController.Bind(Enum.KeyCode.B, function()
		toggleUI("InventoryUI")
	end, "Toggle backpack")
	InputController.Bind(Enum.KeyCode.Q, function()
		toggleUI("QuestsUI")
	end, "Toggle quests")
	InputController.Bind(Enum.KeyCode.H, function()
		-- Heist grab attempt (server validates proximity + ownership).
		if ctx.Controllers.HeistController and not ctx.Controllers.HeistController.IsCarrying() then
			ctx.Controllers.HeistController.Grab()
		end
	end, "Grab loot (near enemy vault)")
	InputController.Bind(Enum.KeyCode.Escape, function()
		local main = ctx.UI and ctx.UI.MainUI
		if main and type(main.CloseAll) == "function" then
			main.CloseAll()
		end
	end, "Close all windows")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local binding = bindings[input.KeyCode]
		if binding then
			local ok, err = pcall(binding.action)
			if not ok then
				warn("[EggHeist] Keybind error (" .. input.KeyCode.Name .. "): " .. tostring(err))
			end
		end
	end)
end

return InputController
