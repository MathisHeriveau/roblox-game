--!strict
--[[
	MapService — generates the procedural map at boot.

	Generation happens in init() (synchronous, no yields) so the map and SpawnLocation exist
	before any character spawns.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Utils.Log)
local MapSystems = ServerScriptService.Server.Systems.Map
local MapBuilder = require(MapSystems.MapBuilder)
local MapLayout = require(MapSystems.MapLayout)

local log = Log.scope("MapService")

local MapService = {
	name = "MapService",
}

local layout: MapLayout.Layout? = nil
local built: MapBuilder.BuildResult? = nil

function MapService.init(_self: any)
	local started = os.clock()
	layout = MapLayout.generate(GameConfig.Map)
	built = MapBuilder.build(layout :: MapLayout.Layout, GameConfig.Map.MaxHeight, Workspace)
	log:info(
		`generated seed {GameConfig.Map.Seed}: {#(layout :: MapLayout.Layout).tiles} tiles, `
			.. `{#(layout :: MapLayout.Layout).collectibles} collectibles in {math.floor((os.clock() - started) * 1000)} ms`
	)
end

function MapService.start(_self: any)
	-- Nothing to run: the map is static once built. Kept explicit (every service has both phases).
end

function MapService.getLayout(): MapLayout.Layout
	assert(layout ~= nil, "MapService: map not generated yet")
	return layout
end

function MapService.getCollectibleParts(): { BasePart }
	assert(built ~= nil, "MapService: map not built yet")
	return built.collectibles
end

return MapService
