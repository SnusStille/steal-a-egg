-- EggHeist | Shared/Types.luau
-- Data-model documentation + record constructor helpers.
--
-- The canonical profile/egg/pet shapes are documented below as EmmyLua
-- annotations (understood by Studio and Lua language servers). Runtime code
-- uses the New* constructors so records are always built consistently.
--
--   local Types = require(Shared:WaitForChild("Types"))
--   profile.eggs[#profile.eggs + 1] = Types.NewEggRecord(uid, "Basic")

---@class EggRecord
---@field uid string server-generated unique id
---@field eggId string egg definition id (see Config/Eggs.luau)

---@class PetRecord
---@field uid string server-generated unique id
---@field id string pet definition id (see Config/Pets.luau)
---@field mut string|nil mutation id or nil (see Config/Mutations.luau)
---@field lvl number current level (1..Economy.PetMaxLevel)
---@field xp number xp toward next level

---@class BaseState
---@field plot number claimed plot index, 0 = none
---@field upgrades table<string, number> trackId -> tier
---@field security table<string, number> itemId -> tier
---@field vault number banked cash thieves can steal
---@field decorations string[] owned decoration ids
---@field lockdownUntil number os.time() timestamp
---@field lockdownCooldownUntil number os.time() timestamp

---@class QuestState
---@field id string quest id within its pool
---@field type string progress hook name (see QuestService.AddProgress callers)
---@field target number goal amount
---@field difficulty number 1..3, scales rewards
---@field text string player-facing description
---@field progress number current progress
---@field claimed boolean reward claimed

---@class QuestBlock
---@field dailyDate string day number the dailies were rolled for
---@field dailies QuestState[]
---@field weeklyKey string week number the weeklies were rolled for
---@field weeklies QuestState[]

---@class Profile
---@field version number DataStore schema version
---@field userId number Roblox user id
---@field cash number spendable cash
---@field gems number premium currency
---@field xp number xp toward next level
---@field level number player level
---@field eggs EggRecord[] unhatched eggs
---@field pets PetRecord[] owned pets
---@field equipped string[] equipped pet uids, in slot order
---@field collection table<string, number> "petId:mutation" -> hatch count
---@field base BaseState
---@field quests QuestBlock
---@field daily table lastClaimDay + streak
---@field prestige table count + bonus
---@field settings table<string, boolean>
---@field tutorial table done + step
---@field boosts table[] active temporary boosts
---@field stats table<string, number> lifetime statistics
---@field gamepasses table<string, boolean> owned gamepass flags
---@field lastSeen number os.time() of last save

---@class HatchResultEntry
---@field pet PetRecord the hatched pet
---@field isNew boolean first time in collection
---@field rarity string rarity id

---@class HatchResult
---@field results HatchResultEntry[]
---@field eggId string|nil source egg id (single hatches)
---@field auto boolean|nil hatched via auto-hatch
---@field bulk boolean|nil hatched via hatch-all

local Types = {}

function Types.NewEggRecord(uid, eggId)
	return { uid = uid, eggId = eggId }
end

function Types.NewPetRecord(uid, petId, mutation)
	return { uid = uid, id = petId, mut = mutation, lvl = 1, xp = 0, locked = false }
end

-- "petId:Mutation" key used by collection tracking (server + client must agree).
function Types.CollectionKey(petId, mutation)
	return petId .. ":" .. (mutation or "Normal")
end

return Types
