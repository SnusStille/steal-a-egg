-- EggHeist | Server/Monetization/ShopService.luau
-- Robux monetization: gamepasses + developer products.
-- ALL granting is server-side via ProcessReceipt. Product IDs of 0 mean
-- "not configured" and safely prompt a "coming soon" message.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local GamePassService = game:GetService("GamePassService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EggHeistShared")
local Shop = require(Shared:WaitForChild("Config"):WaitForChild("Shop"))
local Validate = require(Shared:WaitForChild("Utilities"):WaitForChild("Validate"))

local ShopService = {}
ShopService.Name = "ShopService"

local registry = nil
local processedReceipts = {}

function ShopService.Init(_, reg)
	registry = reg
end

function ShopService.RefreshOwnership(player)
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return
	end
	profile.gamepasses = profile.gamepasses or {}
	for passId, pass in pairs(Shop.Gamepasses) do
		if pass.ProductId and pass.ProductId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.ProductId)
			end)
			if ok then
				profile.gamepasses[passId] = owns == true
			end
		else
			profile.gamepasses[passId] = false
		end
	end
	registry.Data.MarkDirty(player)
end

local function findProductByRobloxId(robloxProductId)
	for key, product in pairs(Shop.Products) do
		if product.ProductId == robloxProductId then
			return key, product
		end
	end
	return nil, nil
end

function ShopService.PromptPurchase(player, kind, id)
	kind = Validate.String(kind, 16, nil)
	id = Validate.String(id, 32, nil)
	if kind == "Gamepass" then
		local pass = Shop.Gamepasses[id]
		if not pass then
			return
		end
		if not pass.ProductId or pass.ProductId <= 0 then
			registry.Notify.Send(player, "info", "Coming soon",
				pass.DisplayName .. " is not for sale yet.", 4)
			return
		end
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.ProductId)
		end)
	elseif kind == "Product" then
		local product = Shop.Products[id]
		if not product then
			return
		end
		if not product.ProductId or product.ProductId <= 0 then
			registry.Notify.Send(player, "info", "Coming soon",
				product.DisplayName .. " is not for sale yet.", 4)
			return
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, product.ProductId)
		end)
	end
end

local function grantProduct(player, productKey, product)
	local profile = registry.Data.GetProfile(player)
	if not profile then
		return false
	end
	local grants = product.Grants or {}
	if grants.Gems then
		registry.Economy.AddGems(player, grants.Gems, "purchase")
	end
	if grants.Cash then
		registry.Economy.AddCash(player, grants.Cash, "purchase")
	end
	if grants.Boost then
		local boost = grants.Boost
		registry.Economy.AddBoost(player, boost.Id, boost.Duration, boost)
		registry.Notify.Send(player, "success", "Boost active!",
			(product.DisplayName or productKey) .. " applied!", 5)
		return true
	end
	registry.Notify.Send(player, "success", "Purchase complete!",
		(product.DisplayName or productKey) .. " added to your account!", 5)
	return true
end

function ShopService.Start()
	registry.Net.OnRequest("PromptShop", function(player, kind, id)
		ShopService.PromptPurchase(player, kind, id)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if purchased then
			ShopService.RefreshOwnership(player)
			registry.Notify.Send(player, "success", "Gamepass unlocked!",
				"Thank you for supporting Egg Heist!", 5)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local key = tostring(receipt.PlayerId) .. ":" .. tostring(receipt.PurchaseId)
		if processedReceipts[key] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local productKey, product = findProductByRobloxId(receipt.ProductId)
		if not product then
			return Enum.ProductPurchaseDecision.PurchaseGranted -- unknown; don't retry forever
		end
		local ok = grantProduct(player, productKey, product)
		if ok then
			processedReceipts[key] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				ShopService.RefreshOwnership(player)
			end
		end)
	end)
end

return ShopService
