--!strict
--[[
	DailyService — the daily reward streak (🎁). One claim per DailyCooldownSeconds; the streak
	grows to DailyStreakLength days (day 7 pays triple) and resets after a missed day. Amounts scale
	with the player's income so the reward stays meaningful at every stage. Rules: Economy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local Guard = require(ReplicatedStorage.Shared.Utils.Guard)
local Server = ServerScriptService.Server
local Notifier = require(Server.Systems.Notifier)
local PlayerDataService = require(Server.Services.PlayerDataService)
local ServerConfig = require(Server.ServerConfig)
local ServerNet = require(Server.Systems.ServerNet)

export type ClaimResult = {
	ok: boolean,
	message: string,
}

local DailyService = {
	name = "DailyService",
}

function DailyService.claim(player: Player): ClaimResult
	local data = PlayerDataService.peek(player)
	if data == nil then
		return { ok = false, message = "Your data is still loading" }
	end
	local now = os.time()
	local ready, wait = Economy.dailyStatus(data.dailyLastClaim, now)
	if not ready then
		return { ok = false, message = `Come back in {Format.duration(wait)}` }
	end
	local day, coins = 0, 0
	local applied = PlayerDataService.update(player, function(draft)
		day, coins = Economy.claimDaily(draft, now)
	end)
	if not applied then
		return { ok = false, message = "Claim failed, please try again" }
	end
	local message = `🎁 Day {day} reward: +💰{Format.compact(coins)}!`
	Notifier.send(player, message, "coins")
	return { ok = true, message = message }
end

function DailyService.init(_self: any)
	ServerNet.onInvoke("ClaimDaily", {
		validate = Guard.tuple(),
		rateLimit = ServerConfig.Network.ClaimDailyRateLimit,
	}, function(player: Player): ClaimResult
		return DailyService.claim(player)
	end)
end

function DailyService.start(_self: any)
	-- Request-driven: nothing to run.
end

return DailyService
