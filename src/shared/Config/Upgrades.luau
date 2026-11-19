--!strict
--[[
	Upgrades — permanent (until rebirth) player upgrades sold in the shop.

	Cost of the next level = floor(baseCost * growth ^ currentLevel). Effects are computed by
	Shared/Game/Economy so the client shop and the server agree on every number.
	Ids are persisted: never rename them.
]]

export type UpgradeId = "speed" | "carry" | "magnet" | "slots"

export type Upgrade = {
	id: UpgradeId,
	name: string,
	icon: string,
	description: string,
	maxLevel: number,
	baseCost: number,
	growth: number,
}

local LIST: { Upgrade } = {
	{
		id = "speed",
		name = "Speed",
		icon = "⚡",
		description = "Run faster across the island",
		maxLevel = 10,
		baseCost = 50,
		growth = 1.75,
	},
	{
		id = "carry",
		name = "Backpack",
		icon = "🎒",
		description = "Carry more shards at once",
		maxLevel = 5,
		baseCost = 120,
		growth = 2.4,
	},
	{
		id = "magnet",
		name = "Magnet",
		icon = "🧲",
		description = "Grab shards from further away",
		maxLevel = 8,
		baseCost = 80,
		growth = 1.9,
	},
	{
		id = "slots",
		name = "Pedestals",
		icon = "🏛️",
		description = "Host more Starlings in your base",
		maxLevel = 8,
		baseCost = 200,
		growth = 2.2,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in LIST do
	table.freeze(upgrade)
	byId[upgrade.id] = upgrade
end

local IDS: { UpgradeId } = { "speed", "carry", "magnet", "slots" }

local Upgrades = {
	list = table.freeze(LIST),
	IDS = table.freeze(IDS),
}

function Upgrades.get(id: string): Upgrade?
	return byId[id]
end

return table.freeze(Upgrades)
