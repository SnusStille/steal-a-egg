-- EggHeist | Server/Social/LeaderboardService.lua
-- OrderedDataStore rankings: richest, heists, collectors, levels.
-- Studio-safe: falls back to in-session rankings when stores are unavailable.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local TableUtil = require(Shared:WaitForChild("Utilities"):WaitForChild("TableUtil"))

local LeaderboardService = {}
LeaderboardService.Name = "LeaderboardService"

local registry = nil
local stores = {}
local storesOk = false
local cache = {} -- [board] = { entries, updatedAt }

local BOARDS = {
	Richest = { Store = "EggHeist_Board_Richest", Stat = "totalEarned", Display = "Richest Heisters" },
	Heists = { Store = "EggHeist_Board_Heists", Stat = "heistsWon", Display = "Master Thieves" },
	Collectors = { Store = "EggHeist_Board_Collectors", Stat = "__collection", Display = "Top Collectors" },
	Levels = { Store = "EggHeist_Board_Levels", Stat = "__level", Display = "Highest Level" },
}

function LeaderboardService.Init(_, reg)
	registry = reg
	for board, def in pairs(BOARDS) do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(def.Store)
		end)
		if ok and store then
			stores[board] = store
		end
	end
	storesOk = TableUtil.Count(stores) > 0
	if not storesOk then
		warn("[EggHeist] Leaderboard stores unavailable; using session-only boards.")
	end
end

local function playerScore(player, board)
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return 0
	end
	if board == "Collectors" then
		return TableUtil.Count(profile.collection or {})
	end
	if board == "Levels" then
		return math.floor(profile.level or 1)
	end
	local stat = BOARDS[board].Stat
	return math.floor((profile.stats and profile.stats[stat]) or 0)
end

local function submitScore(player, board)
	local score = playerScore(player, board)
	local key = "p-" .. tostring(player.UserId)
	if stores[board] then
		pcall(function()
			stores[board]:UpdateAsync(key, function(old)
				old = tonumber(old) or 0
				if score > old then
					return score
				end
				return old
			end)
		end)
	end
	-- also tag the player for session boards
	return score
end

function LeaderboardService.GetBoard(board)
	if cache[board] and os.clock() - cache[board].updatedAt < 60 then
		return cache[board].entries
	end
	local entries = {}
	if stores[board] then
		local ok, pages = pcall(function()
			return stores[board]:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local ok2, items = pcall(function()
				return pages:GetCurrentPage()
			end)
			if ok2 and items then
				for _, item in ipairs(items) do
					local userId = tonumber(string.match(item.key, "p%-(%d+)")) or 0
					local name = "Player"
					if userId > 0 then
						local ok3, playerName = pcall(function()
							return Players:GetNameFromUserIdAsync(userId)
						end)
						if ok3 then
							name = playerName
						end
					end
					entries[#entries + 1] = { name = name, score = item.value }
				end
			end
		end
	end
	-- session fallback: rank current players
	if #entries == 0 then
		for _, player in ipairs(Players:GetPlayers()) do
			entries[#entries + 1] = { name = player.DisplayName, score = playerScore(player, board) }
		end
		table.sort(entries, function(a, b) return a.score > b.score end)
	end
	cache[board] = { entries = entries, updatedAt = os.clock() }
	return entries
end

local function buildPhysicalBoard()
	-- A "Top Heisters" billboard near spawn
	local plaza = registry.World.Find("Map", "Spawn", "SignBoard")
	local parent = registry.World.Find("Map", "Spawn") or Workspace
	local anchor = plaza
	local board = Instance.new("Part")
	board.Name = "LeaderboardBoard"
	board.Size = Vector3.new(14, 10, 1)
	board.Anchored = true
	board.CanCollide = true
	board.Color = Color3.fromRGB(35, 35, 48)
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth
	if anchor and anchor:IsA("BasePart") then
		board.CFrame = anchor.CFrame * CFrame.new(12, 2, 0)
	else
		board.CFrame = registry.World.GetSpawnCFrame() * CFrame.new(12, 6, -10)
	end
	board.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 400)
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "TOP HEISTERS"
	title.TextColor3 = Color3.fromRGB(255, 215, 100)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 40
	title.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, 64)
	list.Size = UDim2.new(1, 0, 1, -64)
	list.BackgroundTransparency = 1
	list.Text = "Loading..."
	list.TextColor3 = Color3.fromRGB(255, 255, 255)
	list.Font = Enum.Font.Gotham
	list.TextSize = 28
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = gui
	return list
end

function LeaderboardService.Start()
	local boardLabel = nil
	pcall(function()
		boardLabel = buildPhysicalBoard()
	end)

	registry.Net.OnFunction("GetLeaderboard", function(_, boardName)
		if BOARDS[boardName] then
			return LeaderboardService.GetBoard(boardName)
		end
		return {}
	end)

	-- submit + refresh loop
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				for board, _ in pairs(BOARDS) do
					submitScore(player, board)
				end
			end
			cache = {} -- invalidate
			if boardLabel and boardLabel.Parent then
				local entries = LeaderboardService.GetBoard("Heists")
				local lines = {}
				for i, entry in ipairs(entries) do
					lines[#lines + 1] = tostring(i) .. ". " .. entry.name .. " - " .. tostring(entry.score)
					if i >= 7 then
						break
					end
				end
				boardLabel.Text = table.concat(lines, "\n")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for board, _ in pairs(BOARDS) do
			submitScore(player, board)
		end
	end)
end

return LeaderboardService
