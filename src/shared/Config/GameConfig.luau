--!strict
--[[
	GameConfig — Comet Raiders tuning shared by server and client.

	Everything under src/shared replicates to every client, so this file is PUBLIC: never put
	secrets or server-only policy here (use src/server/ServerConfig.luau instead).
	Rarities, zones and upgrades live in their own Config modules.
]]

local GameConfig = {
	Map = table.freeze({
		-- Same seed => identical island on every server (deterministic generation).
		Seed = 20261112,
		-- Never let neighbouring walkable tiles differ by more than this (studs): keeps every
		-- zone reachable on foot from the hub.
		MaxStep = 6,
		-- Rock underside of the floating island: bottom = -(UndersideBase + (radius - d) * UndersideSlope).
		UndersideBase = 10,
		UndersideSlope = 2.4,
		-- Decoration densities (fraction of eligible tiles).
		TreeChance = 0.1,
		CrystalChance = 0.14,
		RockChance = 0.1,
		PillarChance = 0.08,
		FloatingIslands = 12,
	}),

	Base = table.freeze({
		PlotCount = 8,
		-- Distance from the island centre to each plot centre (studs).
		PlotRingRadius = 52,
		-- Square plot side (studs).
		PlotSize = 28,
		-- Pedestals laid out in a grid at the back of each plot (12 = max slots).
		PedestalColumns = 4,
		PedestalRows = 3,
		CollectPadRadius = 4.5,
		IncomeTickSeconds = 1,
	}),

	Economy = table.freeze({
		BaseWalkSpeed = 18,
		SpeedPerLevel = 2,
		BaseCapacity = 1,
		BaseMagnetRadius = 6,
		MagnetPerLevel = 2.5,
		BaseSlots = 4,
		-- Each carried shard slows you down by this fraction, never below MinCarrySpeedFactor.
		CarryPenaltyPerShard = 0.06,
		MinCarrySpeedFactor = 0.7,
		-- A Starling that does not fit is sold for this many seconds of its income.
		SellSeconds = 30,
		RebirthBaseCost = 1000000,
		-- Each rebirth adds this to the permanent income multiplier.
		RebirthBonus = 0.5,
		-- Starlings keep working while you are away, at a reduced rate and for a limited time.
		OfflineRate = 0.25,
		OfflineCapSeconds = 2 * 60 * 60,
		-- XP needed to go from level n to n + 1 = floor(XpBase * n ^ XpExponent).
		XpBase = 40,
		XpExponent = 1.5,
	}),

	Events = table.freeze({
		-- Shards scattered when the server starts so the island is never empty.
		InitialShards = 12,
		MeteorIntervalSeconds = 40,
		MeteorBase = 6,
		MeteorPerPlayer = 2,
		MeteorMax = 18,
		-- Seconds between the meteor launch (VFX) and the shard becoming collectable.
		ImpactDelaySeconds = 1.4,
		ShardLifetimeSeconds = 90,
		MaxActiveShards = 70,
		CometIntervalSeconds = 210,
		CometWarningSeconds = 25,
		CometImpactDelaySeconds = 2.6,
		-- Extra regular shards blasted around a comet crater.
		CometScatter = 6,
	}),

	Carry = table.freeze({
		-- Vertical spacing between stacked shards above the head (studs).
		StackSpacing = 1.9,
		StackOffset = 2.6,
		-- A dropped shard cannot be re-grabbed by its previous carrier for this long.
		DropBlockSeconds = 1.5,
		DroppedLifetimeSeconds = 45,
	}),

	Bump = table.freeze({
		Range = 9,
		CooldownSeconds = 2.5,
		-- A bumped player cannot be bumped again for this long.
		ImmunitySeconds = 3,
		KnockbackForce = 70,
	}),

	Hazards = table.freeze({
		LavaDamagePerSecond = 25,
	}),

	World = table.freeze({
		ClockTime = 19.6,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(88, 74, 140),
		OutdoorAmbient = Color3.fromRGB(150, 128, 205),
		FogColor = Color3.fromRGB(120, 92, 200),
		AtmosphereColor = Color3.fromRGB(199, 170, 255),
		AtmosphereDecay = Color3.fromRGB(106, 80, 190),
		StarCount = 4000,
		FallenPartsDestroyHeight = -110,
	}),
}

return table.freeze(GameConfig)
