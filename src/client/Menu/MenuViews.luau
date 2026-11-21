--!strict
--[[
	MenuViews — pure view models of the menu panels (🐾 Index, 🎁 Daily, 📊 Stats, 🏆 Leaderboard,
	📅 Events). They turn the server-sent PlayerState (and other replicated facts) into rows the
	panels draw. Display only: the server recomputes every reward.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

type PlayerState = PlayerStateTypes.PlayerState

export type IndexEntry = {
	key: string,
	rarity: number,
	shiny: boolean,
	name: string,
	color: Color3,
	discovered: boolean,
	income: number,
}

export type IndexView = {
	entries: { IndexEntry },
	count: number,
	size: number,
	-- Permanent income bonus earned so far, in percent.
	bonusPercent: number,
}

export type DailyDay = {
	day: number,
	reward: number,
	status: "claimed" | "next" | "upcoming",
}

export type DailyView = {
	days: { DailyDay },
	ready: boolean,
	waitSeconds: number,
	nextDay: number,
}

export type StatRow = {
	icon: string,
	label: string,
	value: string,
}

export type LeaderInput = {
	name: string,
	coins: number,
	level: number,
	rebirths: number,
	isLocal: boolean,
}

export type LeaderRow = LeaderInput & {
	rank: number,
	medal: string,
}

export type EventRow = {
	icon: string,
	title: string,
	detail: string,
	-- Seconds until the event, nil when it is not scheduled (always on / unknown).
	seconds: number?,
	status: string,
}

local MenuViews = {}

-- Row 1: the six rarities, row 2: their shiny variants (two rows of the panel grid).
function MenuViews.index(discovered: { string }): IndexView
	local found: { [string]: boolean } = {}
	for _, key in discovered do
		found[key] = true
	end
	local entries: { IndexEntry } = {}
	local count = 0
	for _, shiny in { false, true } do
		for _, rarity in Rarities.list do
			local key = Economy.indexKey(rarity.id, shiny)
			local isFound = found[key] == true
			if isFound then
				count += 1
			end
			table.insert(entries, {
				key = key,
				rarity = rarity.id,
				shiny = shiny,
				name = if shiny then `Shiny {rarity.name}` else rarity.name,
				color = rarity.color,
				discovered = isFound,
				income = Economy.starlingIncome({ rarity = rarity.id, shiny = shiny }),
			})
		end
	end
	return {
		entries = entries,
		count = count,
		size = Economy.INDEX_SIZE,
		bonusPercent = math.floor(count * GameConfig.Economy.IndexBonusPerEntry * 100 + 0.5),
	}
end

-- `nextClaimAt` is the unix time the next claim opens (0 = now); `now` is the server time.
function MenuViews.daily(nextClaimAt: number, nextDay: number, incomePerSecond: number, now: number): DailyView
	local days: { DailyDay } = {}
	for day = 1, GameConfig.Economy.DailyStreakLength do
		table.insert(days, {
			day = day,
			reward = Economy.dailyReward(day, incomePerSecond),
			status = if day < nextDay then "claimed" elseif day == nextDay then "next" else "upcoming",
		})
	end
	local wait = math.max(0, nextClaimAt - now)
	return {
		days = days,
		ready = nextClaimAt <= 0 or wait <= 0,
		waitSeconds = wait,
		nextDay = nextDay,
	}
end

function MenuViews.stats(state: PlayerState): { StatRow }
	local zone = Zones.get(state.zoneTier)
	return {
		{ icon = "⭐", label = "Level", value = tostring(state.level) },
		{ icon = "💰", label = "Income", value = `+{Format.compact(state.incomePerSecond)}/s` },
		{ icon = "✖️", label = "Income multiplier", value = `x{string.format("%.2f", state.multiplier)}` },
		{ icon = "🐾", label = "Starling Index", value = `{state.indexCount} / {Economy.INDEX_SIZE}` },
		{ icon = "🏠", label = "Starlings at home", value = `{state.starlings} / {state.slots}` },
		{ icon = "🗺️", label = "Best zone", value = zone.name },
		{ icon = "💎", label = "Shards delivered", value = Format.compact(state.shardsDelivered) },
		{ icon = "☄️", label = "Comets caught", value = Format.compact(state.cometsCaught) },
		{ icon = "💥", label = "Bumps landed", value = Format.compact(state.bumpsLanded) },
		{ icon = "🌟", label = "Rebirths", value = tostring(state.rebirths) },
	}
end

local MEDALS = { "🥇", "🥈", "🥉" }

-- Ranks players by rebirths, then level, then coins (rebirths reset coins and levels).
function MenuViews.leaderboard(players: { LeaderInput }): { LeaderRow }
	local sorted = table.clone(players)
	table.sort(sorted, function(a: LeaderInput, b: LeaderInput): boolean
		if a.rebirths ~= b.rebirths then
			return a.rebirths > b.rebirths
		elseif a.level ~= b.level then
			return a.level > b.level
		elseif a.coins ~= b.coins then
			return a.coins > b.coins
		end
		return a.name < b.name
	end)
	local rows: { LeaderRow } = {}
	for index, entry in sorted do
		table.insert(rows, {
			name = entry.name,
			coins = entry.coins,
			level = entry.level,
			rebirths = entry.rebirths,
			isLocal = entry.isLocal,
			rank = index,
			medal = MEDALS[index] or `#{index}`,
		})
	end
	return rows
end

local function countdown(seconds: number?, soonText: string): string
	if seconds == nil then
		return "Soon"
	end
	if seconds <= 0 then
		return soonText
	end
	return `in {Format.duration(seconds)}`
end

-- Live event schedule. Times are seconds from now (nil = unknown).
function MenuViews.events(meteorIn: number?, cometIn: number?, cometZone: string?, daily: DailyView): { EventRow }
	local cometDetail = if cometZone
		then `A giant comet is falling on {cometZone}! Rare shards for the fastest.`
		else "A giant comet crashes somewhere on the island: rare and shiny shards."
	return {
		{
			icon = "☄️",
			title = "Meteor Shower",
			detail = `Star shards rain on the island every {GameConfig.Events.MeteorIntervalSeconds} seconds.`,
			seconds = meteorIn,
			status = countdown(meteorIn, "Now!"),
		},
		{
			icon = "🌠",
			title = "Comet Event",
			detail = cometDetail,
			seconds = cometIn,
			status = countdown(cometIn, "Incoming!"),
		},
		{
			icon = "🎁",
			title = "Daily Gift",
			detail = `Day {daily.nextDay} of {GameConfig.Economy.DailyStreakLength}: come back every day, day 7 pays triple.`,
			seconds = daily.waitSeconds,
			status = if daily.ready then "Ready!" else countdown(daily.waitSeconds, "Ready!"),
		},
		{
			icon = "🏴‍☠️",
			title = "Raids",
			detail = "Always on: steal Starlings from unlocked bases, lock yours to defend it.",
			seconds = nil,
			status = "Live",
		},
	}
end

return table.freeze(MenuViews)
