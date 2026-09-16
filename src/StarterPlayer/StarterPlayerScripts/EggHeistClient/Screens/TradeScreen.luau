-- EggHeist | Client/Screens/TradeScreen.luau
-- Safe trading window: player lobby, offer builder, review + confirm.
-- Server re-validates everything at execute; this UI only displays
-- server snapshots and forwards taps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Eggs = require(ConfigFolder:WaitForChild("Eggs"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))

local TradeScreen = {}
local ctx = nil
local window = nil
local body = nil
local requestFrame = nil
local requestLabel = nil
local pickerKind = nil -- "pet" | "egg" | nil

local Theme = UIFactory.Theme
local CASH_PRESETS = { 100, 1000, 10000, 100000 }

local function controller()
	return ctx.Controllers and ctx.Controllers.TradeController
end

local function petLabel(entry)
	local def = Pets.ById[entry.id]
	local name = def and def.DisplayName or tostring(entry.id)
	if entry.mut then
		name = entry.mut .. " " .. name
	end
	return name .. " Lv" .. tostring(entry.lvl or 1)
end

local function petColor(entry)
	local def = Pets.ById[entry.id]
	if def and def.Rarity then
		return Rarities.GetColor(def.Rarity)
	end
	return Theme.Text
end

local function eggLabel(entry)
	local def = Eggs.ById[entry.eggId]
	return def and def.DisplayName or tostring(entry.eggId)
end

local function sectionHeader(parent, text)
	local header = UIFactory.Label(text, UDim2.new(1, 0, 0, 24), Theme.Accent, 14)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = parent
end

-- Renders the lobby: every other player in the server + TRADE buttons.
local function renderLobby()
	UIFactory.ClearChildren(body, true)
	local hint = UIFactory.Label("Pick a player to trade with. Both traders need Lv 5+.",
		UDim2.new(1, 0, 0, 22), Theme.TextDim, 12)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Font = Theme.FontRegular
	hint.Parent = body
	local anyone = false
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer then
			anyone = true
			local card = UIFactory.Card(52)
			local name = UIFactory.Label(player.DisplayName .. "  (@" .. player.Name .. ")",
				UDim2.new(1, -110, 1, 0), Theme.Text, 14)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Parent = card
			local userId = player.UserId
			local invite = UIFactory.PrimaryButton("TRADE", function()
				local c = controller()
				if c then
					c.Request(userId)
				end
			end)
			invite.Size = UDim2.new(0, 92, 0, 36)
			invite.Position = UDim2.new(1, -100, 0.5, -18)
			invite.Parent = card
			card.Parent = body
		end
	end
	if not anyone then
		local empty = UIFactory.Label("Nobody else is here. Trading needs 2+ players!",
			UDim2.new(1, 0, 0, 30), Theme.TextDim, 13)
		empty.Parent = body
	end
end

-- Picker page: choose an unequipped pet / idle egg to add to the offer.
local function renderPicker(state)
	UIFactory.ClearChildren(body, true)
	local snapshot = ctx.Data and ctx.Data.Get()
	local back = UIFactory.Button("< BACK", function()
		pickerKind = nil
		TradeScreen.OnUpdate(controller() and controller().State or state)
	end)
	back.Size = UDim2.new(0, 110, 0, 32)
	back.Parent = body
	if pickerKind == "pet" then
		sectionHeader(body, "ADD A PET (must be unequipped)")
		local offered = {}
		for _, entry in ipairs(((state.mine or {}).pets) or {}) do
			offered[entry.uid] = true
		end
		local equipped = {}
		for _, uid in ipairs(snapshot and snapshot.equipped or {}) do
			equipped[uid] = true
		end
		for _, pet in ipairs(snapshot and snapshot.pets or {}) do
			if not equipped[pet.uid] and not offered[pet.uid] then
				local card = UIFactory.Card(48)
				local label = UIFactory.Label(petLabel(pet), UDim2.new(1, -90, 1, 0),
					petColor(pet), 13)
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = card
				local uid = pet.uid
				local add = UIFactory.PrimaryButton("ADD", function()
					local c = controller()
					if c then
						c.OfferAdd("pet", uid)
					end
					pickerKind = nil
				end)
				add.Size = UDim2.new(0, 72, 0, 32)
				add.Position = UDim2.new(1, -80, 0.5, -16)
				add.Parent = card
				card.Parent = body
			end
		end
	else
		sectionHeader(body, "ADD AN EGG")
		local offered = {}
		for _, entry in ipairs(((state.mine or {}).eggs) or {}) do
			offered[entry.uid] = true
		end
		for _, egg in ipairs(snapshot and snapshot.eggs or {}) do
			if not offered[egg.uid] then
				local card = UIFactory.Card(48)
				local label = UIFactory.Label(eggLabel(egg), UDim2.new(1, -90, 1, 0),
					Theme.Text, 13)
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = card
				local uid = egg.uid
				local add = UIFactory.PrimaryButton("ADD", function()
					local c = controller()
					if c then
						c.OfferAdd("egg", uid)
					end
					pickerKind = nil
				end)
				add.Size = UDim2.new(0, 72, 0, 32)
				add.Position = UDim2.new(1, -80, 0.5, -16)
				add.Parent = card
				card.Parent = body
			end
		end
	end
end

local function offerRow(parent, text, color, onRemove)
	local card = UIFactory.Card(40)
	local label = UIFactory.Label(text, UDim2.new(1, onRemove and -70 or -8, 1, 0),
		color or Theme.Text, 13)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card
	if onRemove then
		local remove = UIFactory.Button("X", onRemove)
		remove.Size = UDim2.new(0, 44, 0, 28)
		remove.Position = UDim2.new(1, -52, 0.5, -14)
		remove.Parent = card
	end
	card.Parent = parent
end

local function renderSession(state)
	UIFactory.ClearChildren(body, true)
	local mine = state.mine or { pets = {}, eggs = {}, cash = 0 }
	local theirs = state.theirs or { pets = {}, eggs = {}, cash = 0 }
	local locked = state.mineLocked == true
	local phase = state.phase or "Offer"

	local header = UIFactory.Label("Trading with " .. tostring(state.partner or "?")
		.. "  (Lv " .. tostring(state.partnerLevel or 1) .. ")",
		UDim2.new(1, 0, 0, 26), Theme.Text, 15)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = body
	local statusText = phase == "Confirm" and "REVIEW! Confirm only if the offers look right."
		or (locked and "You locked. Waiting for " .. tostring(state.partner or "partner") .. "..."
			or (state.theirsLocked and tostring(state.partner or "Partner") .. " locked. Lock when ready!"
				or "Build your offer, then LOCK."))
	if phase == "Confirm" and (state.confirmAt or 0) > os.time() then
		statusText = "Reviewing... confirm unlocks in "
			.. tostring((state.confirmAt or 0) - os.time()) .. "s"
	end
	local status = UIFactory.Label(statusText, UDim2.new(1, 0, 0, 22),
		phase == "Confirm" and Theme.Accent or Theme.TextDim, 12)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Font = Theme.FontRegular
	status.Parent = body

	-- my offer
	sectionHeader(body, locked and "YOUR OFFER (LOCKED)" or "YOUR OFFER")
	for _, entry in ipairs(mine.pets or {}) do
		local uid = entry.uid
		offerRow(body, petLabel(entry), petColor(entry), (not locked and phase == "Offer") and function()
			local c = controller()
			if c then
				c.OfferRemove("pet", uid)
			end
		end or nil)
	end
	for _, entry in ipairs(mine.eggs or {}) do
		local uid = entry.uid
		offerRow(body, eggLabel(entry), Theme.Text, (not locked and phase == "Offer") and function()
			local c = controller()
			if c then
				c.OfferRemove("egg", uid)
			end
		end or nil)
	end
	offerRow(body, "Cash: " .. Format.Money(mine.cash or 0), Theme.Accent,
		(not locked and phase == "Offer" and (mine.cash or 0) > 0) and function()
			local c = controller()
			if c then
				c.OfferRemove("cash")
			end
		end or nil)
	if not locked and phase == "Offer" then
		local addRow = UIFactory.Card(44)
		local addPet = UIFactory.Button("+ PET", function()
			pickerKind = "pet"
			renderPicker(state)
		end)
		addPet.Size = UDim2.new(0.5, -4, 0, 30)
		addPet.Position = UDim2.new(0, 0, 0.5, -15)
		addPet.Parent = addRow
		local addEgg = UIFactory.Button("+ EGG", function()
			pickerKind = "egg"
			renderPicker(state)
		end)
		addEgg.Size = UDim2.new(0.5, -4, 0, 30)
		addEgg.Position = UDim2.new(0.5, 4, 0.5, -15)
		addEgg.Parent = addRow
		addRow.Parent = body
		local cashRow = UIFactory.Card(44)
		for i, preset in ipairs(CASH_PRESETS) do
			local button = UIFactory.Button("+" .. Format.Compact(preset), function()
				local c = controller()
				if c then
					c.OfferAdd("cash", nil, (mine.cash or 0) + preset)
				end
			end)
			button.Size = UDim2.new(0.25, -6, 0, 30)
			button.Position = UDim2.new((i - 1) * 0.25, 3, 0.5, -15)
			button.Parent = cashRow
		end
		cashRow.Parent = body
	end

	-- their offer (readonly)
	sectionHeader(body, string.upper(tostring(state.partner or "Partner"))
		.. "'S OFFER" .. (state.theirsLocked and " (LOCKED)" or ""))
	for _, entry in ipairs(theirs.pets or {}) do
		offerRow(body, petLabel(entry), petColor(entry))
	end
	for _, entry in ipairs(theirs.eggs or {}) do
		offerRow(body, eggLabel(entry), Theme.Text)
	end
	offerRow(body, "Cash: " .. Format.Money(theirs.cash or 0), Theme.Accent)

	-- actions
	local actionRow = UIFactory.Card(52)
	if phase == "Offer" and not locked then
		local lock = UIFactory.PrimaryButton("LOCK OFFER", function()
			local c = controller()
			if c then
				c.Lock()
			end
		end)
		lock.Size = UDim2.new(0.5, -4, 0, 38)
		lock.Position = UDim2.new(0, 0, 0.5, -19)
		lock.Parent = actionRow
	elseif phase == "Confirm" then
		local ready = (state.confirmAt or 0) <= os.time()
		local confirm = UIFactory.PrimaryButton(ready and "CONFIRM TRADE" or "WAIT...", function()
			local c = controller()
			if c and ready then
				c.Confirm()
			end
		end)
		confirm.Size = UDim2.new(0.5, -4, 0, 38)
		confirm.Position = UDim2.new(0, 0, 0.5, -19)
		if not ready then
			confirm.BackgroundColor3 = Theme.Button
			confirm.TextColor3 = Theme.TextDim
		end
		confirm.Parent = actionRow
	end
	local cancel = UIFactory.Button("CANCEL", function()
		local c = controller()
		if c then
			c.Cancel()
		end
		pickerKind = nil
	end)
	cancel.Size = UDim2.new(0.5, -4, 0, 38)
	cancel.Position = UDim2.new(0.5, 4, 0.5, -19)
	cancel.Parent = actionRow
	actionRow.Parent = body
end

function TradeScreen.OnUpdate(state)
	if not window then
		return
	end
	state = state or {}
	if state.phase == "Request" then
		-- incoming request modal (works even with the window closed)
		requestLabel.Text = tostring(state.from or "Someone")
			.. " (Lv " .. tostring(state.fromLevel or 1) .. ") wants to trade!"
		requestFrame.Visible = true
		task.delay(math.max(1, (state.expiresAt or 0) - os.time()), function()
			local current = controller() and controller().State
			if current and current.phase == "Request" then
				requestFrame.Visible = false
			end
		end)
		return
	end
	requestFrame.Visible = false
	if state.phase == "Closed" then
		pickerKind = nil
		if window.IsVisible() then
			renderLobby()
		end
		return
	end
	pickerKind = nil
	if not window.IsVisible() then
		window.SetVisible(true)
	end
	if state.phase == "Offer" or state.phase == "Confirm" then
		renderSession(state)
	end
end

function TradeScreen.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UIFactory.ScreenGui("EggHeistTrade", 20)
	gui.Parent = playerGui

	window = UIFactory.Window(gui, "Trading", UDim2.new(0, 560, 0, 500))
	body = UIFactory.ScrollingList(window.Content)
	renderLobby()

	-- incoming-request modal (top center, above everything trade-related)
	requestFrame = Instance.new("Frame")
	requestFrame.AnchorPoint = Vector2.new(0.5, 0)
	requestFrame.Position = UDim2.new(0.5, 0, 120)
	requestFrame.Size = UDim2.new(0, 340, 0, 120)
	requestFrame.BackgroundColor3 = Theme.Panel
	requestFrame.BorderSizePixel = 0
	requestFrame.Visible = false
	UIFactory.Corner(requestFrame, 10)
	UIFactory.Stroke(requestFrame, Theme.Accent, 2)
	requestFrame.Parent = gui
	requestLabel = UIFactory.Label("", UDim2.new(1, -16, 0, 52), Theme.Text, 14)
	requestLabel.Position = UDim2.new(0, 8, 0, 8)
	requestLabel.TextWrapped = true
	requestLabel.Parent = requestFrame
	local accept = UIFactory.PrimaryButton("ACCEPT", function()
		requestFrame.Visible = false
		local c = controller()
		if c then
			c.Accept()
		end
	end)
	accept.Size = UDim2.new(0.5, -12, 0, 36)
	accept.Position = UDim2.new(0, 8, 0, 72)
	accept.Parent = requestFrame
	local decline = UIFactory.Button("DECLINE", function()
		requestFrame.Visible = false
		local c = controller()
		if c then
			c.Decline()
		end
	end)
	decline.Size = UDim2.new(0.5, -12, 0, 36)
	decline.Position = UDim2.new(0.5, 4, 0, 72)
	decline.Parent = requestFrame

	if ctx.Data then
		ctx.Data.Changed:Connect(function()
			if window.IsVisible() and pickerKind == nil then
				local current = controller() and controller().State
				if current and (current.phase == "Offer" or current.phase == "Confirm") then
					renderSession(current)
				end
			end
		end)
	end
end

function TradeScreen.SetVisible(visible)
	if visible then
		local current = controller() and controller().State
		if current and (current.phase == "Offer" or current.phase == "Confirm") then
			renderSession(current)
		else
			renderLobby()
		end
	end
	window.SetVisible(visible)
end

function TradeScreen.Toggle()
	TradeScreen.SetVisible(not window.IsVisible())
end

return TradeScreen
