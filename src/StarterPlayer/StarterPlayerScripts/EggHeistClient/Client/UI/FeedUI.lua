-- FeedUI: server event ticker (heists, rare hatches, prestige, events).
-- Bottom-left, keeps the last 6 entries, no interaction needed.
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Players = game:GetService("Players")

local FeedUI = {}

local MAX_ENTRIES = 6

local ICON_COLORS = {
	HEIST = Color3.fromRGB(255, 120, 120),
	HATCH = Color3.fromRGB(150, 220, 255),
	SECRET = Color3.fromRGB(255, 200, 80),
	STAR = Color3.fromRGB(220, 160, 255),
	EVENT = Color3.fromRGB(140, 255, 170),
}

local entries = {}
local orderCounter = 0

function FeedUI.Init(ctx)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistFeed", 5)
	gui.ResetOnSpawn = false

	local list = Instance.new("Frame")
	list.Name = "FeedList"
	list.AnchorPoint = Vector2.new(0, 1)
	list.Position = UDim2.new(0, 12, 1, -12)
	list.Size = UDim2.new(0, 300, 0, 150)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 3)
	layout.Parent = list

	local function addEntry(icon, text)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
		row.BackgroundTransparency = 0.25
		row.BorderSizePixel = 0
		UIFactory.Corner(row, 6)
		local tag = UIFactory.Label(icon or "NEWS", UDim2.new(0, 52, 1, 0),
			ICON_COLORS[icon] or UIFactory.Theme.TextDim, 11)
		tag.Font = Enum.Font.GothamBold
		tag.Parent = row
		local body = UIFactory.Label(text or "", UDim2.new(1, -56, 1, 0), UIFactory.Theme.Text, 12)
		body.Position = UDim2.new(0, 54, 0, 0)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextTruncate = Enum.TextTruncate.AtEnd
		body.Parent = row
		orderCounter = orderCounter + 1
		row.LayoutOrder = orderCounter
		row.Parent = list
		entries[#entries + 1] = row
		while #entries > MAX_ENTRIES do
			local oldest = table.remove(entries, 1)
			if oldest then
				oldest:Destroy()
			end
		end
		-- fade out old news after a while (stays readable, never clutters)
		task.delay(25, function()
			if row and row.Parent then
				row:Destroy()
			end
		end)
	end

	if ctx and ctx.Net then
		ctx.Net.On("Feed", function(payload)
			if type(payload) == "table" then
				addEntry(payload.icon, payload.text)
			end
		end)
	end

	print("[EggHeist] FeedUI ready")
end

return FeedUI
