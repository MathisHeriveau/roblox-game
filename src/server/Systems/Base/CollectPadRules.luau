--!strict
--[[
	CollectPadRules — when the collect pad banks the vault. Pure.

	The vault is banked once per visit: on the tick its owner steps onto the pad. Standing there
	does nothing more, so a visit gives exactly one "+💰" toast; income earned meanwhile waits for
	the next visit. The caller remembers, per player, whether they were on the pad last tick.

	API:
	  CollectPadRules.shouldBank(wasOnPad, isOnPad, vault) -> boolean
]]

local CollectPadRules = {}

function CollectPadRules.shouldBank(wasOnPad: boolean, isOnPad: boolean, vault: number): boolean
	-- `vault == vault` rejects NaN; finite and positive only (never bank corrupt values).
	local bankable = vault == vault and vault > 0 and vault < math.huge
	return isOnPad and not wasOnPad and bankable
end

return table.freeze(CollectPadRules)
