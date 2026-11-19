--!strict
--[[
	SkyEventService — the heartbeat of Comet Raiders: meteor showers and comets.

	  - At boot a handful of shards are scattered so the island is never empty.
	  - Every MeteorIntervalSeconds a shower drops shards across the zones (more players = more).
	  - Every CometIntervalSeconds a comet is announced CometWarningSeconds ahead (banner + target
	    marker for everyone), then crashes and leaves a rare comet core plus scattered shards.

	Timings are replicated as Workspace attributes (NextMeteorAt / NextCometAt, in server time) so
	clients show countdowns without extra traffic. Visual effects are cosmetic WorldEvents.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local Prng = require(ReplicatedStorage.Shared.Utils.Prng)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Server = ServerScriptService.Server
local MapService = require(Server.Services.MapService)
local Notifier = require(Server.Systems.Notifier)
local ServerNet = require(Server.Systems.ServerNet)
local ShardService = require(Server.Services.ShardService)
local SkySchedule = require(Server.Systems.Shards.SkySchedule)

local events = GameConfig.Events
local log = Log.scope("SkyEventService")

local SkyEventService = {
	name = "SkyEventService",
}

-- Runtime randomness differs per server (the island layout itself stays seeded).
local rng = Prng.new(os.time() + math.floor(os.clock() * 1000))

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function tilePosition(impact: SkySchedule.Impact): Vector3
	return Vector3.new(impact.tile.x, impact.tile.height, impact.tile.z)
end

local function launchMeteors(count: number, delay: number)
	local impacts = SkySchedule.meteorImpacts(rng, MapService.getLayout(), count, ShardService.isTileFree)
	local payload = {}
	for _, impact in impacts do
		if ShardService.spawnAt(impact.tile, impact.rarity, impact.shiny, false, delay) then
			table.insert(payload, { position = tilePosition(impact), rarity = impact.rarity })
		end
	end
	if delay > 0 and #payload > 0 then
		ServerNet.fireAllClients("WorldEvent", { kind = "meteors", impacts = payload, impactAt = serverNow() + delay })
	end
end

function SkyEventService.init(_self: any)
	-- Everything happens in start(): shards need the running ShardService loop.
end

function SkyEventService.start(_self: any)
	launchMeteors(events.InitialShards, 0)

	local nextMeteor = serverNow() + 20
	local nextComet = serverNow() + events.CometIntervalSeconds
	Workspace:SetAttribute("NextMeteorAt", nextMeteor)
	Workspace:SetAttribute("NextCometAt", nextComet)

	local pendingComet: { SkySchedule.Impact }? = nil
	local warned = false

	while true do
		task.wait(0.5)
		local now = serverNow()

		if now >= nextMeteor then
			local count = SkySchedule.meteorCount(#Players:GetPlayers(), events)
			launchMeteors(count, events.ImpactDelaySeconds)
			nextMeteor = now + events.MeteorIntervalSeconds
			Workspace:SetAttribute("NextMeteorAt", nextMeteor)
		end

		if not warned and now >= nextComet - events.CometWarningSeconds then
			warned = true
			local impacts = SkySchedule.cometImpacts(rng, MapService.getLayout(), events, ShardService.isTileFree)
			if #impacts > 0 then
				pendingComet = impacts
				local core = impacts[1]
				local zone = Zones.get(math.max(1, core.tile.tier))
				ServerNet.fireAllClients("WorldEvent", {
					kind = "cometWarning",
					position = tilePosition(core),
					impactAt = nextComet,
					zoneName = zone.name,
					rarity = core.rarity,
				})
				Notifier.broadcast(`☄️ A comet is heading for {zone.name}!`, "warning")
				Workspace:SetAttribute("CometZone", zone.name)
			else
				log:warn("no free tile for the comet")
			end
		end

		if now >= nextComet then
			local impacts = pendingComet
			if impacts then
				for _, impact in impacts do
					ShardService.spawnAt(impact.tile, impact.rarity, impact.shiny, impact.isComet, 0.1)
				end
				ServerNet.fireAllClients("WorldEvent", { kind = "cometImpact", position = tilePosition(impacts[1]) })
			end
			pendingComet = nil
			warned = false
			nextComet = now + events.CometIntervalSeconds
			Workspace:SetAttribute("NextCometAt", nextComet)
			Workspace:SetAttribute("CometZone", nil)
		end
	end
end

return SkyEventService
