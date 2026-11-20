--!strict
--[[
	CometTracker — what the comet banner says, from the server's warning until a few seconds after
	the crash. Pure: times are server times passed in by the caller.

	The impact event does not end the comet: the banner switches to "grab the core!" and lingers
	LINGER_SECONDS (the target marker with it) so players find the core.

	API:
	  local tracker = CometTracker.new()
	  tracker:warn(impactAt, zoneName)   new comet announced (replaces any previous one)
	  tracker:impact(now)                the comet crashed (server event)
	  tracker:status(now) -> { title, subtitle }?   nil = no comet to show (and it is forgotten)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Game.Format)

local LINGER_SECONDS = 4

export type Status = {
	title: string,
	subtitle: string,
}

local CometTracker = {
	LINGER_SECONDS = LINGER_SECONDS,
}
CometTracker.__index = CometTracker

export type CometTracker = typeof(setmetatable(
	{} :: {
		_impactAt: number?,
		_zoneName: string,
		_crashed: boolean,
	},
	CometTracker
))

function CometTracker.new(): CometTracker
	return setmetatable({ _impactAt = nil :: number?, _zoneName = "", _crashed = false }, CometTracker)
end

function CometTracker.warn(self: CometTracker, impactAt: number, zoneName: string)
	self._impactAt = impactAt
	self._zoneName = zoneName
	self._crashed = false
end

function CometTracker.impact(self: CometTracker, now: number)
	local impactAt = self._impactAt
	if impactAt == nil then
		return
	end
	self._crashed = true
	self._impactAt = math.min(impactAt, now)
end

function CometTracker.status(self: CometTracker, now: number): Status?
	local impactAt = self._impactAt
	if impactAt == nil then
		return nil
	end
	local remaining = impactAt - now
	if remaining < -LINGER_SECONDS then
		self._impactAt = nil
		return nil
	end
	if remaining > 0 and not self._crashed then
		return {
			title = "COMET INCOMING!",
			subtitle = `Crash in {Format.duration(remaining)} · {self._zoneName}`,
		}
	end
	return {
		title = "COMET CRASHED!",
		subtitle = `Crashed in {self._zoneName}: grab the core!`,
	}
end

return CometTracker
