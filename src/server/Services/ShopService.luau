--!strict
--[[
	ShopService — purchases (upgrades, zone unlocks, rebirth). Clients only send *what* they want;
	prices, eligibility and effects come from Shared/Game/Economy on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Guard = require(ReplicatedStorage.Shared.Utils.Guard)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Server = ServerScriptService.Server
local Notifier = require(Server.Systems.Notifier)
local PlayerDataService = require(Server.Services.PlayerDataService)
local ServerConfig = require(Server.ServerConfig)
local ServerNet = require(Server.Systems.ServerNet)

export type PurchaseResult = {
	ok: boolean,
	message: string,
}

local ShopService = {
	name = "ShopService",
}

local function successMessage(kind: string, id: string?, levels: { [string]: number }, rebirths: number): string
	if kind == "upgrade" and id then
		local upgrade = Upgrades.get(id) :: Upgrades.Upgrade
		return `{upgrade.icon} {upgrade.name} upgraded to level {levels[id]}!`
	elseif kind == "zone" and id then
		local zone = Zones.byKey(id) :: Zones.Zone
		return `{zone.icon} {zone.name} unlocked!`
	end
	return `🌟 Rebirth #{rebirths}! Permanent bonus: +{math.floor(Economy.multiplier(rebirths) * 100 - 100)}% income`
end

function ShopService.purchase(player: Player, kind: string, id: string?): PurchaseResult
	local data = PlayerDataService.get(player)
	if data == nil then
		return { ok = false, message = "Your data is still loading" }
	end
	local ok, reason = Economy.canPurchase(data, kind, id)
	if not ok then
		return { ok = false, message = reason or "Not available" }
	end
	local applied = PlayerDataService.update(player, function(draft)
		Economy.applyPurchase(draft, kind, id)
	end)
	if not applied then
		return { ok = false, message = "Purchase failed, please try again" }
	end
	local after = PlayerDataService.peek(player)
	local message = if after then successMessage(kind, id, after.upgrades :: any, after.rebirths) else "Done!"
	Notifier.send(player, message, "success")
	return { ok = true, message = message }
end

function ShopService.init(_self: any)
	ServerNet.onInvoke("RequestPurchase", {
		validate = Guard.tuple(
			Guard.oneOf({ "upgrade", "zone", "rebirth" }),
			Guard.optional(Guard.string({ maxLength = 16, pattern = "^%a+$" }))
		),
		rateLimit = ServerConfig.Network.RequestPurchaseRateLimit,
	}, function(player: Player, kind: string, id: string?): PurchaseResult
		return ShopService.purchase(player, kind, id)
	end)
end

function ShopService.start(_self: any)
	-- Request-driven: nothing to run.
end

return ShopService
