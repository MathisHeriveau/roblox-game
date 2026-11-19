--!strict
--[[
	ShardVisuals — visual constants shared by the server (builds shards/Starlings) and the client
	(animates them). Keep both sides in sync through this module only.
]]

local ShardVisuals = {
	SHARD_TAG = "Shard",
	CRYSTAL_TAG = "ShardCrystal",
	STARLING_TAG = "Starling",
	JUMP_PAD_TAG = "JumpPad",
	-- Orientation that balances a cube on one vertex (a gem silhouette).
	TILT = CFrame.Angles(math.rad(45), 0, math.rad(35.264)),
}

return table.freeze(ShardVisuals)
