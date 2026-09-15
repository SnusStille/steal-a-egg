-- EggHeist | Server/Social/TradeService.luau
-- Safe player-to-player trading: pets + eggs + cash offers.
--
-- Flow: Request -> Accept -> Offer -> Lock (both) -> Confirm (both, after
-- a review delay) -> Execute. EVERYTHING is re-validated server-side at
-- execute time: ownership, balances, caps. Nothing from the client is
-- trusted. Cancel at any point; sessions expire; leaving cancels.
--
-- Anti-scam minimums: level gate, 3 s review delay after both lock,
-- full offer display on both sides, server-validated inventories.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local ConfigFolder = Shared:WaitForChild("Config")
local Settings = require(ConfigFolder:WaitForChild("Settings"))
local Economy = require(ConfigFolder:WaitForChild("Economy"))
local Types = require(Shared:WaitForChild("Types"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local TradeService = {}
TradeService.Name = "TradeService"

local registry = nil
local pending = {} -- [targetUserId] = { fromUserId, expiresAt }
local sessions = {} -- [sessionId] = session
local busy = {} -- [userId] = sessionId (or true while a request is outbound)
local nextSessionId = 0

function TradeService.Init(_, reg)
	registry = reg
end

local function tradingOn()
	return Settings.Features and Settings.Features.Trading == true
end

local function tradingCfg()
	return Settings.Trading or {}
end

local function profileOf(player)
	return registry.Data.GetProfile(player)
end

local function playerOf(userId)
	return Players:GetPlayerByUserId(userId)
end

local function otherOf(session, userId)
	if session.a == userId then
		return session.b
	end
	return session.a
end

-- Builds the client-safe offer summary for one side.
local function summarizeOffer(profile, offer)
	local summary = { pets = {}, eggs = {}, cash = offer.cash }
	for _, uid in ipairs(offer.pets) do
		local pet = registry.Pet.FindPet(profile, uid)
		if pet then
			summary.pets[#summary.pets + 1] = {
				uid = uid, id = pet.id, mut = pet.mut,
				lvl = pet.lvl or 1,
			}
		end
	end
	for _, uid in ipairs(offer.eggs) do
		local egg = registry.Egg.FindEgg(profile, uid)
		if egg then
			summary.eggs[#summary.eggs + 1] = { uid = uid, eggId = egg.eggId }
		end
	end
	return summary
end

local function pushUpdate(session)
	local playerA = playerOf(session.a)
	local playerB = playerOf(session.b)
	if not playerA or not playerB then
		return
	end
	local profileA = profileOf(playerA)
	local profileB = profileOf(playerB)
	if not profileA or not profileB then
		return
	end
	local base = {
		phase = session.phase,
		sessionId = session.id,
		expiresAt = session.expiresAt,
		confirmAt = session.confirmAt,
		lockedA = session.locked[session.a] == true,
		lockedB = session.locked[session.b] == true,
		offerA = summarizeOffer(profileA, session.offers[session.a]),
		offerB = summarizeOffer(profileB, session.offers[session.b]),
	}
	registry.Net.Fire(playerA, "TradeUpdate", {
		phase = base.phase, sessionId = base.sessionId,
		expiresAt = base.expiresAt, confirmAt = base.confirmAt,
		partner = playerB.DisplayName, partnerLevel = profileB.level or 1,
		mine = base.offerA, theirs = base.offerB,
		mineLocked = base.lockedA, theirsLocked = base.lockedB,
	})
	registry.Net.Fire(playerB, "TradeUpdate", {
		phase = base.phase, sessionId = base.sessionId,
		expiresAt = base.expiresAt, confirmAt = base.confirmAt,
		partner = playerA.DisplayName, partnerLevel = profileA.level or 1,
		mine = base.offerB, theirs = base.offerA,
		mineLocked = base.lockedB, theirsLocked = base.lockedA,
	})
end

local function closeSession(session, reason)
	sessions[session.id] = nil
	busy[session.a] = nil
	busy[session.b] = nil
	local playerA = playerOf(session.a)
	local playerB = playerOf(session.b)
	if playerA then
		registry.Net.Fire(playerA, "TradeUpdate", { phase = "Closed", reason = reason })
	end
	if playerB then
		registry.Net.Fire(playerB, "TradeUpdate", { phase = "Closed", reason = reason })
	end
end

local function sessionOf(player)
	local id = busy[player.UserId]
	if type(id) == "number" then
		return sessions[id]
	end
	return nil
end

--------------------------------------------------------------------------------
-- Request / accept
--------------------------------------------------------------------------------

function TradeService.RequestTrade(player, targetUserId)
	if not tradingOn() then
		return
	end
	targetUserId = tonumber(targetUserId)
	if not targetUserId or targetUserId == player.UserId then
		return
	end
	local target = playerOf(targetUserId)
	if not target then
		return
	end
	if busy[player.UserId] or busy[targetUserId] then
		registry.Notify.Send(player, "warning", "Busy",
			"One of you is already trading.", 3)
		return
	end
	local minLevel = tradingCfg().MinLevel or 5
	local profile = profileOf(player)
	local targetProfile = profileOf(target)
	if not profile or not targetProfile then
		return
	end
	if (profile.level or 1) < minLevel or (targetProfile.level or 1) < minLevel then
		registry.Notify.Send(player, "warning", "Level locked",
			"Both traders need level " .. tostring(minLevel) .. "+.", 4)
		return
	end
	pending[targetUserId] = {
		fromUserId = player.UserId,
		expiresAt = os.time() + (tradingCfg().RequestExpiry or 30),
	}
	busy[player.UserId] = true
	registry.Notify.Send(player, "info", "Request sent",
		"Trade request sent to " .. target.DisplayName .. ".", 3)
	registry.Net.Fire(target, "TradeUpdate", {
		phase = "Request",
		from = player.DisplayName,
		fromLevel = profile.level or 1,
		expiresAt = pending[targetUserId].expiresAt,
	})
	registry.Notify.Send(target, "info", "Trade request",
		player.DisplayName .. " wants to trade with you!", 5)
end

function TradeService.AcceptTrade(player)
	if not tradingOn() then
		return
	end
	local request = pending[player.UserId]
	pending[player.UserId] = nil
	if not request or request.expiresAt < os.time() then
		registry.Notify.Send(player, "warning", "Expired",
			"That trade request expired.", 3)
		return
	end
	local partner = playerOf(request.fromUserId)
	if not partner then
		return
	end
	if busy[player.UserId] or busy[partner.UserId] ~= true then
		busy[partner.UserId] = nil
		return
	end
	nextSessionId = nextSessionId + 1
	local session = {
		id = nextSessionId,
		a = partner.UserId,
		b = player.UserId,
		phase = "Offer",
		offers = {
			[partner.UserId] = { pets = {}, eggs = {}, cash = 0 },
			[player.UserId] = { pets = {}, eggs = {}, cash = 0 },
		},
		locked = {},
		confirmAt = 0,
		confirmed = {},
		expiresAt = os.time() + (tradingCfg().SessionExpiry or 180),
	}
	sessions[session.id] = session
	busy[partner.UserId] = session.id
	busy[player.UserId] = session.id
	pushUpdate(session)
end

function TradeService.DeclineTrade(player)
	local request = pending[player.UserId]
	pending[player.UserId] = nil
	if not request then
		return
	end
	busy[request.fromUserId] = nil
	local partner = playerOf(request.fromUserId)
	if partner then
		registry.Notify.Send(partner, "info", "Declined",
			player.DisplayName .. " declined your trade.", 3)
		registry.Net.Fire(partner, "TradeUpdate", { phase = "Closed", reason = "declined" })
	end
	registry.Net.Fire(player, "TradeUpdate", { phase = "Closed", reason = "declined" })
end

--------------------------------------------------------------------------------
-- Offers
--------------------------------------------------------------------------------

local function offerOf(session, userId)
	return session.offers[userId]
end

local function unlockBoth(session)
	session.locked[session.a] = nil
	session.locked[session.b] = nil
	session.confirmed[session.a] = nil
	session.confirmed[session.b] = nil
	session.confirmAt = 0
	if session.phase == "Confirm" then
		session.phase = "Offer"
	end
end

function TradeService.OfferAdd(player, kind, ref, amount)
	local session = sessionOf(player)
	if not session or session.phase ~= "Offer" then
		return
	end
	if session.locked[player.UserId] then
		return -- locked side cannot edit (unlock by cancel... see OfferRemove guard)
	end
	kind = Validate.String(kind, 8, nil)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local offer = offerOf(session, player.UserId)
	if kind == "pet" then
		local uid = Validate.Uid(ref)
		if not uid then
			return
		end
		local pet = registry.Pet.FindPet(profile, uid)
		if not pet then
			return
		end
		if registry.Pet.IsEquipped(profile, uid) then
			registry.Notify.Send(player, "warning", "Equipped",
				"Unequip this pet before trading it.", 3)
			return
		end
		for _, existing in ipairs(offer.pets) do
			if existing == uid then
				return
			end
		end
		if #offer.pets >= 6 then
			return
		end
		offer.pets[#offer.pets + 1] = uid
	elseif kind == "egg" then
		local uid = Validate.Uid(ref)
		if not uid then
			return
		end
		local egg = registry.Egg.FindEgg(profile, uid)
		if not egg then
			return
		end
		for _, existing in ipairs(offer.eggs) do
			if existing == uid then
				return
			end
		end
		if #offer.eggs >= 6 then
			return
		end
		offer.eggs[#offer.eggs + 1] = uid
	elseif kind == "cash" then
		amount = math.floor(tonumber(amount) or 0)
		if amount <= 0 or amount > Economy.MaxCash then
			return
		end
		if (profile.cash or 0) < amount then
			registry.Notify.Send(player, "warning", "Not enough cash",
				"You don't have that much cash.", 3)
			return
		end
		offer.cash = amount
	else
		return
	end
	unlockBoth(session)
	pushUpdate(session)
end

function TradeService.OfferRemove(player, kind, ref)
	local session = sessionOf(player)
	if not session or session.phase ~= "Offer" then
		return
	end
	if session.locked[player.UserId] then
		return
	end
	kind = Validate.String(kind, 8, nil)
	local offer = offerOf(session, player.UserId)
	if kind == "pet" or kind == "egg" then
		local uid = Validate.Uid(ref)
		if not uid then
			return
		end
		local list = kind == "pet" and offer.pets or offer.eggs
		for i, existing in ipairs(list) do
			if existing == uid then
				table.remove(list, i)
				break
			end
		end
	elseif kind == "cash" then
		offer.cash = 0
	else
		return
	end
	unlockBoth(session)
	pushUpdate(session)
end

function TradeService.Lock(player)
	local session = sessionOf(player)
	if not session or session.phase ~= "Offer" then
		return
	end
	session.locked[player.UserId] = true
	if session.locked[session.a] and session.locked[session.b] then
		session.phase = "Confirm"
		session.confirmAt = os.time() + (tradingCfg().ConfirmDelay or 3)
	end
	pushUpdate(session)
end

--------------------------------------------------------------------------------
-- Execute (full re-validation)
--------------------------------------------------------------------------------

local function petCap(profile)
	return Economy.MaxPetsStored + (profile.base.upgrades.EggSlots or 0) * 2
end

local function validateSide(session, giverId)
	local giver = playerOf(giverId)
	local receiver = playerOf(otherOf(session, giverId))
	if not giver or not receiver then
		return false, "Player left"
	end
	local giverProfile = profileOf(giver)
	local receiverProfile = profileOf(receiver)
	if not giverProfile or not receiverProfile then
		return false, "No profile"
	end
	local offer = session.offers[giverId]
	-- pets: owned, not equipped, receiver has room
	for _, uid in ipairs(offer.pets) do
		local pet = registry.Pet.FindPet(giverProfile, uid)
		if not pet then
			return false, "Pet no longer available"
		end
		if registry.Pet.IsEquipped(giverProfile, uid) then
			return false, "Offered pet is equipped"
		end
	end
	if #receiverProfile.pets + #offer.pets > petCap(receiverProfile) then
		return false, receiver.DisplayName .. "'s pet storage is full"
	end
	-- eggs: owned, receiver has room
	for _, uid in ipairs(offer.eggs) do
		if not registry.Egg.FindEgg(giverProfile, uid) then
			return false, "Egg no longer available"
		end
	end
	if #receiverProfile.eggs + #offer.eggs > 200 then
		return false, receiver.DisplayName .. "'s egg storage is full"
	end
	-- cash: balance covers offer
	if (giverProfile.cash or 0) < (offer.cash or 0) then
		return false, giver.DisplayName .. " lacks the offered cash"
	end
	return true, nil
end

local function movePet(giverProfile, receiver, petUid)
	local pet, index = registry.Pet.FindPet(giverProfile, petUid)
	if not pet or not index then
		return false
	end
	table.remove(giverProfile.pets, index)
	local copy = {
		uid = registry.Data.GenerateUid(receiver),
		id = pet.id,
		mut = pet.mut,
		lvl = pet.lvl or 1,
		xp = pet.xp or 0,
	}
	local receiverProfile = profileOf(receiver)
	receiverProfile.pets[#receiverProfile.pets + 1] = copy
	receiverProfile.collection = receiverProfile.collection or {}
	receiverProfile.collection[Types.CollectionKey(pet.id, pet.mut)] = true
	return true
end

local function moveEgg(giverProfile, receiver, eggUid)
	for index, egg in ipairs(giverProfile.eggs) do
		if egg.uid == eggUid then
			table.remove(giverProfile.eggs, index)
			return registry.Egg.GiftEgg(receiver, egg.eggId, "trade")
		end
	end
	return false
end

local function execute(session)
	-- validate both sides BEFORE moving anything (atomic-ish: pets/eggs/cash)
	local okA, errA = validateSide(session, session.a)
	local okB, errB = validateSide(session, session.b)
	if not okA or not okB then
		local reason = errA or errB or "Validation failed"
		local playerA = playerOf(session.a)
		local playerB = playerOf(session.b)
		if playerA then
			registry.Notify.Send(playerA, "error", "Trade failed", reason, 5)
		end
		if playerB then
			registry.Notify.Send(playerB, "error", "Trade failed", reason, 5)
		end
		closeSession(session, "failed")
		return
	end
	local playerA = playerOf(session.a)
	local playerB = playerOf(session.b)
	local profileA = profileOf(playerA)
	local profileB = profileOf(playerB)
	local offerA = session.offers[session.a]
	local offerB = session.offers[session.b]

	for _, uid in ipairs(offerA.pets) do
		movePet(profileA, playerB, uid)
	end
	for _, uid in ipairs(offerA.eggs) do
		moveEgg(profileA, playerB, uid)
	end
	for _, uid in ipairs(offerB.pets) do
		movePet(profileB, playerA, uid)
	end
	for _, uid in ipairs(offerB.eggs) do
		moveEgg(profileB, playerA, uid)
	end
	if (offerA.cash or 0) > 0 then
		registry.Economy.SpendCash(playerA, offerA.cash)
		registry.Economy.AddCash(playerB, offerA.cash, "trade")
	end
	if (offerB.cash or 0) > 0 then
		registry.Economy.SpendCash(playerB, offerB.cash)
		registry.Economy.AddCash(playerA, offerB.cash, "trade")
	end

	profileA.stats.tradesCompleted = (profileA.stats.tradesCompleted or 0) + 1
	profileB.stats.tradesCompleted = (profileB.stats.tradesCompleted or 0) + 1
	registry.Data.MarkDirty(playerA)
	registry.Data.MarkDirty(playerB)
	registry.Pet.RebuildFollowers(playerA)
	registry.Pet.RebuildFollowers(playerB)
	registry.Quest.AddProgress(playerA, "CompleteTrades", 1)
	registry.Quest.AddProgress(playerB, "CompleteTrades", 1)
	if registry.Achievement then
		registry.Achievement.Check(playerA, "TradeComplete")
		registry.Achievement.Check(playerB, "TradeComplete")
	end
	registry.Notify.Send(playerA, "success", "Trade complete!",
		"You traded with " .. playerB.DisplayName .. ".", 5)
	registry.Notify.Send(playerB, "success", "Trade complete!",
		"You traded with " .. playerA.DisplayName .. ".", 5)
	closeSession(session, "completed")
end

function TradeService.Confirm(player)
	local session = sessionOf(player)
	if not session or session.phase ~= "Confirm" then
		return
	end
	if os.time() < (session.confirmAt or 0) then
		registry.Notify.Send(player, "warning", "Review first",
			"Check the offers before confirming!", 2)
		return
	end
	session.confirmed[player.UserId] = true
	if session.confirmed[session.a] and session.confirmed[session.b] then
		execute(session)
	else
		pushUpdate(session)
	end
end

function TradeService.Cancel(player)
	local session = sessionOf(player)
	if session then
		local other = playerOf(otherOf(session, player.UserId))
		if other then
			registry.Notify.Send(other, "info", "Trade cancelled",
				player.DisplayName .. " cancelled the trade.", 3)
		end
		closeSession(session, "cancelled")
		return
	end
	-- cancel an outbound request
	for targetId, request in pairs(pending) do
		if request.fromUserId == player.UserId then
			pending[targetId] = nil
			busy[player.UserId] = nil
			local target = playerOf(targetId)
			if target then
				registry.Net.Fire(target, "TradeUpdate", { phase = "Closed", reason = "cancelled" })
			end
		end
	end
end

function TradeService.HandlePlayerLeaving(player)
	pending[player.UserId] = nil
	for targetId, request in pairs(pending) do
		if request.fromUserId == player.UserId then
			pending[targetId] = nil
		end
	end
	local session = sessionOf(player)
	if session then
		local other = playerOf(otherOf(session, player.UserId))
		if other then
			registry.Notify.Send(other, "info", "Trade cancelled",
				player.DisplayName .. " left.", 3)
		end
		closeSession(session, "left")
	end
	busy[player.UserId] = nil
end

function TradeService.Start()
	registry.Net.OnRequest("TradeRequest", function(player, targetUserId)
		TradeService.RequestTrade(player, targetUserId)
	end)
	registry.Net.OnRequest("TradeAccept", function(player)
		TradeService.AcceptTrade(player)
	end)
	registry.Net.OnRequest("TradeDecline", function(player)
		TradeService.DeclineTrade(player)
	end)
	registry.Net.OnRequest("TradeOfferAdd", function(player, kind, ref, amount)
		TradeService.OfferAdd(player, kind, ref, amount)
	end)
	registry.Net.OnRequest("TradeOfferRemove", function(player, kind, ref)
		TradeService.OfferRemove(player, kind, ref)
	end)
	registry.Net.OnRequest("TradeLock", function(player)
		TradeService.Lock(player)
	end)
	registry.Net.OnRequest("TradeConfirm", function(player)
		TradeService.Confirm(player)
	end)
	registry.Net.OnRequest("TradeCancel", function(player)
		TradeService.Cancel(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		TradeService.HandlePlayerLeaving(player)
	end)

	-- expiry sweeper
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for targetId, request in pairs(pending) do
				if request.expiresAt < now then
					pending[targetId] = nil
					busy[request.fromUserId] = nil
					local target = playerOf(targetId)
					if target then
						registry.Net.Fire(target, "TradeUpdate", { phase = "Closed", reason = "expired" })
					end
				end
			end
			for _, session in pairs(sessions) do
				if session.expiresAt < now then
					closeSession(session, "expired")
				end
			end
		end
	end)
end

return TradeService
