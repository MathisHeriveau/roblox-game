--!strict
--[[
	HudFeedback — what the HUD should celebrate between two PlayerState snapshots: a level up
	(toast + chime + badge pop) and coins going up (coin pill pop). Pure.

	The first snapshot of a session never celebrates (joining is not levelling up), and only
	increases count: a purchase or a rebirth lowers coins silently.

	API: HudFeedback.compare(previous?, current) -> { levelUp: number?, coinsGained: number }
]]

export type Snapshot = {
	level: number,
	coins: number,
}

export type Feedback = {
	-- The new level when it went up, else nil.
	levelUp: number?,
	coinsGained: number,
}

local HudFeedback = {}

function HudFeedback.compare(previous: Snapshot?, current: Snapshot): Feedback
	if previous == nil then
		return { levelUp = nil, coinsGained = 0 }
	end
	return {
		levelUp = if current.level > previous.level then current.level else nil,
		coinsGained = math.max(0, current.coins - previous.coins),
	}
end

return table.freeze(HudFeedback)
