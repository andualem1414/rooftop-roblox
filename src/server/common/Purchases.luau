--!strict
-- Robux purchases (both places answer them: Roblox may hand a purchase to whichever server the buyer is in,
-- and again later if it wasn't confirmed). Each boost bought becomes a boost credit in the buyer's profile
-- (shared/Booster, server/common/ProfileStore), counted once however often Roblox reports it, and only
-- confirmed to Roblox once it's saved. Then onCredit runs (the race spends it on the boost the player
-- asked for).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Booster = require(ReplicatedStorage.Shared.Booster)
local ProfileStore = require(script.Parent.ProfileStore)

local Purchases = {}

function Purchases.init(onCredit: ((Player, number) -> ())?)
	MarketplaceService.ProcessReceipt = function(info: { [string]: any }): Enum.ProductPurchaseDecision
		local size = Booster.sizeOf(info.ProductId)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not size or not player then
			-- (not ours, or they've left: Roblox offers it again when they're back)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, fresh = ProfileStore.grantPurchase(player, tostring(info.PurchaseId), size)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if fresh and onCredit then
			task.spawn(onCredit, player, size)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

-- open Roblox's purchase dialog for a boost (false if that size isn't on sale)
function Purchases.promptBoost(player: Player, size: number): boolean
	local id = Booster.PRODUCTS[size]
	if not id or id == 0 then
		return false
	end
	MarketplaceService:PromptProductPurchase(player, id)
	return true
end

return Purchases
