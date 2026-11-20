--!strict
--[[
	ZoneAnnouncer — decides when the zone banner appears and what it says. Pure: no Instances.

	A banner is announced only when the character *walks* into another zone. The zone a character
	spawns in is never announced — call `reset()` on every CharacterAdded, otherwise a respawn at
	the base (Comet Plaza) after dying elsewhere looks like a zone change.

	API:
	  local announcer = ZoneAnnouncer.new()
	  announcer:observe(tier?) -> tier to announce, or nil   (tier from Zones.tierAt; nil = off-world)
	  announcer:reset()                                      new character: next zone is silent
	  ZoneAnnouncer.describe(tier, unlockedTier?) -> { title, subtitle, color }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Parent.UI.Theme)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

export type Text = {
	title: string,
	subtitle: string,
	color: Color3,
}

local ZoneAnnouncer = {}
ZoneAnnouncer.__index = ZoneAnnouncer

export type ZoneAnnouncer = typeof(setmetatable(
	{} :: {
		-- Zone the current character is in; nil until its first observation.
		_current: number?,
	},
	ZoneAnnouncer
))

function ZoneAnnouncer.new(): ZoneAnnouncer
	return setmetatable({ _current = nil :: number? }, ZoneAnnouncer)
end

function ZoneAnnouncer.observe(self: ZoneAnnouncer, tier: number?): number?
	if tier == nil or tier == self._current then
		-- Off-world (falling, flying past the edge) keeps the last zone: no flicker on return.
		return nil
	end
	local previous = self._current
	self._current = tier
	return if previous == nil then nil else tier
end

function ZoneAnnouncer.reset(self: ZoneAnnouncer)
	self._current = nil
end

-- Banner texts. `unlockedTier` is the player's highest unlocked zone (nil = not known yet).
function ZoneAnnouncer.describe(tier: number, unlockedTier: number?): Text
	if tier == 0 then
		return {
			title = `🏠 {string.upper(Zones.HUB_NAME)}`,
			subtitle = "Home: deliver shards to hatch Starlings",
			color = Theme.Color.Gold,
		}
	end
	local zone = Zones.get(tier)
	local locked = unlockedTier ~= nil and tier > unlockedTier
	return {
		title = `{zone.icon} {string.upper(zone.name)}`,
		subtitle = if locked then "🔒 Locked: unlock it in the shop" else `Shards drop here · zone {tier}`,
		color = zone.color,
	}
end

return ZoneAnnouncer
