-- HelpUI: "?" button + quick-start guide popup. Zero dependencies besides UIFactory.
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local HelpUI = {}

local HELP_TOPICS = {
	{ "QUICK START", "1. Walk NORTH to the green plots and CLAIM a base (press E at the glowing totem).\n2. Open SHOP and buy your first egg.\n3. Open BACKPACK, HATCH the egg, then EQUIP the pet.\n4. Earn cash, upgrade your base, and HEIST other players' vaults!" },
	{ "CONTROLS", "Move: WASD / left stick\nJump: Space\nInteract: E (claim plots, vaults, pickups)\nBackpack: B, Quests: Q, Grab loot: H\nScreenshot mode: P (hides all UI)\nChat: /stats /players /time /help" },
	{ "YOUR BASE", "Your vault fills up over time from pet income. Walk to the golden VAULT and press E to COLLECT. Buy INCOME, VAULT and SECURITY upgrades in the BASE panel. Security slows thieves down!" },
	{ "HEISTS", "Walk onto another player's plot and press E at their vault to grab eggs and cash. Watch out for traps and lasers! Escape SOUTH to the green EXTRACTION pad to bank your loot. Getting caught sends you home empty-handed." },
	{ "PETS & EGGS", "Eggs hatch into pets with rarities from Common to SECRET. Better eggs cost more and need higher levels. Equip up to 3 pets (unlock more slots with prestige). Pets boost income and heist power. Sell spares, fill your COLLECTION, and trade with friends!" },
	{ "EVENTS & QUESTS", "World events (Meteor Shower, Blood Moon...) drop rare eggs - check the EVENT board. Daily quests and achievements give gems and rewards. Come back every day for the login streak!" },
	{ "TRAVEL & NEWS", "Open TRAVEL (top buttons) to teleport between districts - 10s cooldown, and never with stolen loot! The bottom-left FEED shows server news: big heists, rare hatches and prestiges." },
	{ "STUCK?", "Green signs at spawn point to every district. Lock favorite pets (LOCK button) so prestige never sells them. If windows ever stop opening, rejoin - your base, pets and cash are saved automatically." },
}

function HelpUI.Init()
	local gui = UIFactory.ScreenGui("EggHeistHelp", 30)

	local helpButton = UIFactory.Button("?", function()
		if HelpUI.window then
			HelpUI.window.Toggle()
		end
	end)
	helpButton.Name = "HelpButton"
	helpButton.AnchorPoint = Vector2.new(1, 1)
	helpButton.Position = UDim2.new(1, -14, 1, -14)
	helpButton.Size = UDim2.new(0, 44, 0, 44)
	helpButton.TextSize = 22
	helpButton.Parent = gui
	UIFactory.Corner(helpButton, 22)

	local window = UIFactory.Window(gui, "HELP & GUIDE", UDim2.new(0, 520, 0, 460))
	HelpUI.window = window

	local scroll = UIFactory.ScrollingList(window.Content)
	for i, topic in ipairs(HELP_TOPICS) do
		local card = UIFactory.Card(0)
		card.LayoutOrder = i
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.Parent = scroll
		local cardLayout = Instance.new("UIListLayout")
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cardLayout.Padding = UDim.new(0, 4)
		cardLayout.Parent = card
		local title = UIFactory.Label(topic[1], UDim2.new(1, 0, 0, 24), UIFactory.Theme.Accent, 15)
		title.LayoutOrder = 1
		title.Font = Enum.Font.GothamBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = card
		local body = UIFactory.Label(topic[2], UDim2.new(1, 0, 0, 0), UIFactory.Theme.Text, 13)
		body.LayoutOrder = 2
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.Parent = card
	end

	print("[EggHeist] HelpUI ready")
end

return HelpUI
