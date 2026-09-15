-- EggHeist | Shared/Remotes.lua
-- SINGLE SOURCE OF TRUTH for all RemoteEvents / RemoteFunctions.
-- Server NetService creates these at runtime; client fetches via WaitForChild.
--
-- Convention:
--   "C2S_<Name>"  client -> server requests (validated + rate-limited)
--   "S2C_<Name>"  server -> client pushes
--   "Fn_<Name>"   RemoteFunctions (client -> server, use sparingly)

local Remotes = {}

Remotes.FolderName = "EggHeistRemotes"

-- Client -> Server
Remotes.C2S = {
	"BuyEgg",        -- (eggId)
	"HatchEgg",      -- (eggUid)
	"HatchAll",      -- ()
	"EquipPet",      -- (petUid)
	"UnequipPet",    -- (petUid)
	"DeletePet",     -- (petUid) (sells for 50% value)
	"SellPet",       -- (petUid)
	"ClaimBase",     -- ()
	"BuyUpgrade",    -- (trackId)
	"BuySecurity",   -- (itemId)
	"ToggleLockdown",-- ()
	"CollectVault",  -- ()
	"GrabLoot",      -- ()  (heist grab; server validates position/channel)
	"ClaimQuest",    -- (questId)
	"ClaimDaily",    -- ()
	"Prestige",      -- ()
	"BuyDecoration", -- (decorId)
	"UpdateSetting", -- (key, value)
	"CompleteTutorialStep", -- (stepId)
	"PromptShop",    -- (kind, id)  kind: "Gamepass"|"Product"
	"Admin",         -- (command, ...)  (admins only, server re-checks)
}

-- Server -> Client
Remotes.S2C = {
	"DataSync",      -- (dataTable) full or partial profile push
	"Notify",        -- (kind, title, message, duration)
	"HatchResult",   -- (resultTable) {pets = {...}, eggId}
	"HeistUpdate",   -- (stateTable) carrying/alarm/extraction state
	"EventUpdate",   -- (eventTable) active event + time left
	"QuestUpdate",   -- (questsTable)
	"Leaderboard",   -- (boardName, entries)
	"Fx",            -- (fxName, ...) lightweight effect triggers
	"ServerTime",    -- (unixTime) clock sync for daily/weekly logic
}

-- RemoteFunctions (client invokes, server answers)
Remotes.Fn = {
	"GetData",       -- () -> profile snapshot
	"GetLeaderboard",-- (boardName) -> entries
}

-- Rate limits: max requests per second per player per endpoint (server-side)
Remotes.RateLimits = {
	BuyEgg = 6,
	HatchEgg = 8,
	HatchAll = 2,
	EquipPet = 10,
	UnequipPet = 10,
	DeletePet = 4,
	SellPet = 4,
	BuyUpgrade = 4,
	BuySecurity = 4,
	ToggleLockdown = 1,
	CollectVault = 4,
	GrabLoot = 3,
	ClaimQuest = 4,
	ClaimDaily = 2,
	Prestige = 1,
	BuyDecoration = 4,
	UpdateSetting = 10,
	CompleteTutorialStep = 4,
	PromptShop = 3,
	Admin = 5,
}

return Remotes
