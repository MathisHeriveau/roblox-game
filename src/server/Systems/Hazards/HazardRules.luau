--!strict
--[[
	HazardRules — pure decision: which environmental hazard (if any) affects a character.

	API:
	  HazardRules.classify(positionY, tile, voidKillHeight) -> "safe" | "void" | "lava"
	    positionY       character root height (studs)
	    tile            map tile under the character, or nil when over the void
	    voidKillHeight  below this height the character fell off the island (GameConfig.Hazards)

	"void" wins over everything (falling is fatal and must not depend on the tile lookup).
	Non-finite heights are treated as "void": a character at NaN/inf is broken, respawn it.

	Why not Workspace.FallenPartsDestroyHeight: game Scripts lack the capability to write it
	(PluginOrOpenCloud only), so falls are detected by the server instead.
]]

local MapLayout = require(script.Parent.Parent.Map.MapLayout)

export type Hazard = "safe" | "void" | "lava"

-- A character within this many studs above a lava tile's surface stands in the lava.
local LAVA_REACH = 5

local HazardRules = {
	LAVA_REACH = LAVA_REACH,
}

function HazardRules.classify(positionY: number, tile: MapLayout.Tile?, voidKillHeight: number): Hazard
	if positionY ~= positionY or positionY == math.huge or positionY == -math.huge then
		return "void"
	end
	if positionY < voidKillHeight then
		return "void"
	end
	if tile and tile.kind == "lava" and positionY < tile.height + LAVA_REACH then
		return "lava"
	end
	return "safe"
end

return table.freeze(HazardRules)
