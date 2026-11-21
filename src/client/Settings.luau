--!strict
--[[
	Settings — local, per-session player preferences (⚙️ panel). Effects and sounds read these
	flags; `changed` fires with the key that changed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Utils.Signal)

export type Key = "sounds" | "effects" | "guide"

local Settings = {
	changed = Signal.new() :: Signal.Signal<Key>,
	LABELS = table.freeze({
		{ key = "sounds" :: Key, label = "Sound effects" },
		{ key = "effects" :: Key, label = "Flashes, shockwaves & camera shake" },
		{ key = "guide" :: Key, label = "Golden guide beam to your base" },
	}),
}

local values: { [Key]: boolean } = {
	sounds = true,
	effects = true,
	guide = true,
}

function Settings.get(key: Key): boolean
	return values[key]
end

function Settings.set(key: Key, value: boolean)
	if values[key] ~= value then
		values[key] = value
		Settings.changed:fire(key)
	end
end

function Settings.toggle(key: Key)
	Settings.set(key, not values[key])
end

return Settings
