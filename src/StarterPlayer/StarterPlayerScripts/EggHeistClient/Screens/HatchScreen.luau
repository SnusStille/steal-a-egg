-- EggHeist | Client/Screens/HatchScreen.luau
-- Full-screen hatch ceremony: shake -> burst -> pet reveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Pets = require(ConfigFolder:WaitForChild("Pets"))
local Rarities = require(ConfigFolder:WaitForChild("Rarities"))
local Mutations = require(ConfigFolder:WaitForChild("Mutations"))
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Effects"))
local SoundManager = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundManager"))

local HatchScreen = {}
local ctx = nil
local gui = nil
local overlay = nil
local eggLabel = nil
local revealCard = nil
local revealTitle = nil
local revealSub = nil
local tapToContinue = nil
local queue = {}
local playing = false

local Theme = UIFactory.Theme

function HatchScreen.Init(context)
	ctx = context
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = UIFactory.ScreenGui("EggHeistHatch", 50)
	gui.Parent = playerGui

	overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	overlay.BackgroundTransparency = 0.25
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = gui

	eggLabel = UIFactory.Label("EGG", UDim2.new(0, 200, 0, 200), Theme.Accent, 72)
	eggLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	eggLabel.Position = UDim2.new(0.5, 0, 0.42, 0)
	eggLabel.Parent = overlay

	revealCard = Instance.new("Frame")
	revealCard.AnchorPoint = Vector2.new(0.5, 0.5)
	revealCard.Position = UDim2.new(0.5, 0, 0.42, 0)
	revealCard.Size = UDim2.new(0, 320, 0, 220)
	revealCard.BackgroundColor3 = Theme.Panel
	revealCard.BorderSizePixel = 0
	revealCard.Visible = false
	UIFactory.Corner(revealCard, 16)
	UIFactory.Padding(revealCard, 16)
	revealCard.Parent = overlay

	revealTitle = UIFactory.Label("", UDim2.new(1, 0, 0, 40), Theme.Text, 24)
	revealTitle.Parent = revealCard
	revealSub = UIFactory.Label("", UDim2.new(1, 0, 0, 120), Theme.TextDim, 15)
	revealSub.Position = UDim2.new(0, 0, 0, 50)
	revealSub.TextWrapped = true
	revealSub.Font = Theme.FontRegular
	revealSub.Parent = revealCard

	tapToContinue = UIFactory.Button("TAP TO CONTINUE", function()
		HatchScreen.Next()
	end)
	tapToContinue.AnchorPoint = Vector2.new(0.5, 0)
	tapToContinue.Position = UDim2.new(0.5, 0, 0.72, 0)
	tapToContinue.Size = UDim2.new(0, 260, 0, 46)
	tapToContinue.Visible = false
	tapToContinue.Parent = overlay
end

function HatchScreen.ShowResults(result)
	if not result or not result.results then
		return
	end
	for _, entry in ipairs(result.results) do
		queue[#queue + 1] = entry
	end
	if not playing then
		HatchScreen.PlayNext()
	end
end

function HatchScreen.PlayNext()
	local entry = queue[1]
	if not entry then
		playing = false
		overlay.Visible = false
		return
	end
	playing = true
	overlay.Visible = true
	revealCard.Visible = false
	tapToContinue.Visible = false
	eggLabel.Visible = true
	eggLabel.Text = string.upper(tostring(entry.eggName or "Egg"))
	eggLabel.TextColor3 = Theme.Accent
	eggLabel.Rotation = 0

	-- shake phase
	SoundManager.Play("Hatch", 0.6)
	local shakes = 0
	task.spawn(function()
		while playing and eggLabel.Visible and shakes < 10 do
			shakes = shakes + 1
			eggLabel.Rotation = (shakes % 2 == 0) and 12 or -12
			task.wait(0.12)
		end
		if playing then
			HatchScreen.Reveal(entry)
		end
	end)
end

function HatchScreen.Reveal(entry)
	table.remove(queue, 1)
	eggLabel.Visible = false
	local pet = entry.pet or {}
	local def = Pets.ById[pet.id]
	local rarity = entry.rarity or (def and def.Rarity) or "Common"
	local rarityColor = Rarities.GetColor(rarity)
	local tier = Rarities.GetTier(rarity)

	local displayName = def and def.DisplayName or tostring(pet.id)
	if pet.mut then
		displayName = pet.mut .. " " .. displayName
	end
	revealTitle.Text = displayName
	revealTitle.TextColor3 = pet.mut and Mutations.GetColor(pet.mut) or rarityColor

	local lines = {
		rarity .. (entry.isNew and "  -  NEW!" or ""),
		"from " .. tostring(entry.eggName or "an egg"),
	}
	if pet.mut then
		lines[#lines + 1] = "Mutation: " .. pet.mut
	end
	if def then
		lines[#lines + 1] = def.Description or ""
	end
	if #queue > 0 then
		lines[#lines + 1] = "(" .. tostring(#queue) .. " more...)"
	end
	revealSub.Text = table.concat(lines, "\n")
	revealCard.Visible = true
	Effects.Pop(revealCard, 1.1)

	-- juice by tier
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if tier >= 6 or pet.mut == "Void" then
		SoundManager.Play("Rare", 0.9)
		Effects.Flash(playerGui, rarityColor, 0.6)
		Effects.Confetti(playerGui, 80)
		Effects.ShakeCamera(0.5, 0.4)
	elseif tier >= 4 then
		SoundManager.Play("Rare", 0.7)
		Effects.Flash(playerGui, rarityColor, 0.4)
		Effects.Confetti(playerGui, 45)
	elseif tier >= 2 or pet.mut then
		SoundManager.Play("Success", 0.6)
		Effects.Confetti(playerGui, 20)
	else
		SoundManager.Play("Notify", 0.5)
	end

	tapToContinue.Visible = true
end

function HatchScreen.Next()
	if #queue > 0 then
		HatchScreen.PlayNext()
	else
		playing = false
		overlay.Visible = false
	end
end

return HatchScreen
