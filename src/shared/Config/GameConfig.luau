--!strict
--[[
	GameConfig — gameplay tuning shared by server and client.

	Everything under src/shared replicates to every client, so this file is PUBLIC: never put
	secrets, keys or server-only policy here (use src/server/ServerConfig.luau instead).
	Values are frozen so no module can mutate global configuration at runtime.
]]

local GameConfig = {
	Map = table.freeze({
		-- Same seed => identical map on every server (deterministic generation).
		Seed = 20261112,
		-- Tiles per side. Must be odd so a single tile sits exactly at the centre (spawn).
		GridSize = 13,
		-- Tile footprint in studs.
		TileSize = 16,
		-- Highest tile top surface above the spawn plateau, in studs.
		MaxHeight = 12,
		-- Tiles (Chebyshev distance from centre) kept flat and free of collectibles around spawn.
		SpawnClearRadius = 1,
		-- Number of collectibles placed on the map.
		CollectibleCount = 14,
		-- Smoothing passes applied to the raw height noise (higher = gentler hills).
		SmoothingPasses = 2,
	}),

	Collectibles = table.freeze({
		-- Coins granted per pickup. Server-authoritative: clients never send this value.
		Value = 1,
		-- Seconds before a collected item reappears.
		RespawnSeconds = 8,
		-- Studs between the character root and the item. Larger distances are rejected as exploits.
		MaxPickupDistance = 14,
		-- Minimum seconds between two pickups by the same player.
		PlayerCooldownSeconds = 0.15,
	}),

	Ui = table.freeze({
		-- Minimum seconds between two state requests from the HUD (client-side courtesy limit).
		StateRequestIntervalSeconds = 1,
	}),
}

return table.freeze(GameConfig)
