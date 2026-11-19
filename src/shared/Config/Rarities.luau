--!strict
--[[
	Rarities — the six shard/Starling rarities of Comet Raiders (colours from the art style sheet).

	`income` is coins per second produced by a Starling of that rarity; `xp` is granted when a shard
	of that rarity is delivered. Ids are stable and persisted: never renumber them.
]]

export type Rarity = {
	id: number,
	key: string,
	name: string,
	color: Color3,
	income: number,
	xp: number,
}

local LIST: { Rarity } = {
	{ id = 1, key = "Common", name = "Common", color = Color3.fromRGB(255, 217, 102), income = 1, xp = 5 },
	{ id = 2, key = "Rare", name = "Rare", color = Color3.fromRGB(0, 180, 255), income = 5, xp = 15 },
	{ id = 3, key = "Epic", name = "Epic", color = Color3.fromRGB(179, 102, 255), income = 25, xp = 40 },
	{ id = 4, key = "Legendary", name = "Legendary", color = Color3.fromRGB(243, 156, 18), income = 120, xp = 120 },
	{ id = 5, key = "Mythic", name = "Mythic", color = Color3.fromRGB(0, 230, 118), income = 600, xp = 400 },
	{ id = 6, key = "Cosmic", name = "Cosmic", color = Color3.fromRGB(255, 107, 255), income = 3000, xp = 1500 },
}

for _, rarity in LIST do
	table.freeze(rarity)
end

local Rarities = {
	list = table.freeze(LIST),
	COUNT = #LIST,
	-- Shiny shards are rarer variants of any rarity: more income and a sparkle effect.
	SHINY_CHANCE = 0.04,
	SHINY_MULTIPLIER = 3,
}

function Rarities.get(id: number): Rarity
	local rarity = LIST[id]
	assert(rarity ~= nil, `Rarities: unknown rarity id {id}`)
	return rarity
end

function Rarities.isValid(id: unknown): boolean
	return type(id) == "number" and LIST[id :: number] ~= nil and math.floor(id :: number) == id
end

return table.freeze(Rarities)
