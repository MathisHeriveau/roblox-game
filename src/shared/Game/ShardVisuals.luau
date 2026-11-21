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
	-- Resting orientation of a shard crystal: square prism turned 45° so two facets face you.
	TILT = CFrame.Angles(0, math.rad(45), 0),
}

return table.freeze(ShardVisuals)
