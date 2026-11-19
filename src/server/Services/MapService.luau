--!strict
--[[
	MapService — generates and builds the floating island at boot.

	Generation runs in init() (synchronous, no yields) so terrain, landmarks and spawns exist
	before any character spawns. Exposes the layout for gameplay queries (tile under a position).
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
	local generated = MapLayout.generate(GameConfig.Map)
	layout = generated
	built = MapBuilder.build(generated, Workspace, MapBuilder.terrainWriter(Workspace.Terrain))
	log:info(
		`island seed {generated.seed}: {#generated.tiles} tiles, {#generated.props} props`
			.. ` in {math.floor((os.clock() - started) * 1000)} ms`
	)
end

function MapService.start(_self: any)
	-- The island is static once built.
end

function MapService.getLayout(): MapLayout.Layout
	assert(layout ~= nil, "MapService: island not generated yet")
	return layout
end

function MapService.tileAt(position: Vector3): MapLayout.Tile?
	return MapLayout.tileAt(MapService.getLayout(), position.X, position.Z)
end

function MapService.getMap(): Folder
	assert(built ~= nil, "MapService: island not built yet")
	return built.root
end

return MapService
