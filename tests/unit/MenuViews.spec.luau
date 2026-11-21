--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MenuViews = require(StarterPlayer.StarterPlayerScripts.Client.Menu.MenuViews)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local function state(): any
	return {
		coins = 1500,
		vault = 0,
		incomePerSecond = 42,
		xp = 300,
		level = 7,
		levelProgress = 10,
		levelGoal = 100,
		rebirths = 2,
		multiplier = 1.54,
		rebirthCost = 1000000,
		zoneTier = 2,
		upgrades = { speed = 0, carry = 0, magnet = 0, slots = 0 },
		carrying = 0,
		capacity = 1,
		carryingStarling = 0,
		starlings = 3,
		slots = 4,
		shardsDelivered = 1234,
		bumpsLanded = 5,
		cometsCaught = 2,
		discovered = { "r1", "r2" },
		indexCount = 2,
		dailyNextClaimAt = 0,
		dailyNextDay = 1,
	}
end

return function()
	describe("MenuViews.index", function()
		it("lists every rarity, then every shiny variant", function()
			local view = MenuViews.index({})
			expect(#view.entries).to.equal(Economy.INDEX_SIZE)
			expect(view.entries[1].key).to.equal("r1")
			expect(view.entries[Rarities.COUNT].key).to.equal(`r{Rarities.COUNT}`)
			expect(view.entries[Rarities.COUNT + 1].key).to.equal("r1s")
			expect(view.entries[Rarities.COUNT + 1].name).to.equal("Shiny Common")
			expect(view.count).to.equal(0)
		end)

		it("marks discovered entries, counts them and shows the income bonus", function()
			local view = MenuViews.index({ "r2", "r6s", "bogus" })
			expect(view.count).to.equal(2)
			expect(view.entries[2].discovered).to.equal(true)
			expect(view.entries[1].discovered).to.equal(false)
			expect(view.entries[12].discovered).to.equal(true)
			expect(view.bonusPercent).to.equal(math.floor(2 * GameConfig.Economy.IndexBonusPerEntry * 100 + 0.5))
		end)
	end)

	describe("MenuViews.daily", function()
		local NOW = 1800000000

		it("shows claimed, next and upcoming days with their rewards", function()
			local view = MenuViews.daily(0, 3, 10, NOW)
			expect(#view.days).to.equal(GameConfig.Economy.DailyStreakLength)
			expect(view.days[1].status).to.equal("claimed")
			expect(view.days[3].status).to.equal("next")
			expect(view.days[4].status).to.equal("upcoming")
			expect(view.days[3].reward).to.equal(Economy.dailyReward(3, 10))
			expect(view.ready).to.equal(true)
		end)

		it("counts down to the next claim", function()
			local view = MenuViews.daily(NOW + 90, 2, 0, NOW)
			expect(view.ready).to.equal(false)
			expect(view.waitSeconds).to.equal(90)
			view = MenuViews.daily(NOW - 5, 2, 0, NOW)
			expect(view.ready).to.equal(true)
			expect(view.waitSeconds).to.equal(0)
		end)
	end)

	describe("MenuViews.stats", function()
		it("formats the lifetime progression rows", function()
			local rows = MenuViews.stats(state())
			local byLabel: { [string]: string } = {}
			for _, row in rows do
				byLabel[row.label] = row.value
			end
			expect(byLabel["Level"]).to.equal("7")
			expect(byLabel["Income"]).to.equal("+42/s")
			expect(byLabel["Income multiplier"]).to.equal("x1.54")
			expect(byLabel["Starling Index"]).to.equal(`2 / {Economy.INDEX_SIZE}`)
			expect(byLabel["Starlings at home"]).to.equal("3 / 4")
			expect(byLabel["Shards delivered"]).to.equal("1.23K")
			expect(byLabel["Rebirths"]).to.equal("2")
		end)
	end)

	describe("MenuViews.leaderboard", function()
		it("ranks by rebirths, then level, then coins, with medals", function()
			local rows = MenuViews.leaderboard({
				{ name = "Rich", coins = 9000000, level = 30, rebirths = 0, isLocal = false },
				{ name = "Reborn", coins = 10, level = 2, rebirths = 1, isLocal = true },
				{ name = "Leveled", coins = 5, level = 31, rebirths = 0, isLocal = false },
				{ name = "Newbie", coins = 0, level = 1, rebirths = 0, isLocal = false },
			})
			expect(rows[1].name).to.equal("Reborn")
			expect(rows[1].medal).to.equal("🥇")
			expect(rows[1].isLocal).to.equal(true)
			expect(rows[2].name).to.equal("Leveled")
			expect(rows[3].name).to.equal("Rich")
			expect(rows[4].medal).to.equal("#4")
		end)

		it("does not reorder its input", function()
			local input = {
				{ name = "B", coins = 0, level = 1, rebirths = 0, isLocal = false },
				{ name = "A", coins = 0, level = 1, rebirths = 0, isLocal = false },
			}
			local rows = MenuViews.leaderboard(input)
			expect(rows[1].name).to.equal("A")
			expect(input[1].name).to.equal("B")
		end)
	end)

	describe("MenuViews.events", function()
		it("lists live countdowns and the always-on raids", function()
			local daily = MenuViews.daily(0, 1, 0, 0)
			local rows = MenuViews.events(12, 0, "Lava Fields", daily)
			expect(#rows).to.equal(4)
			expect(rows[1].status).to.equal("in 0:12")
			expect(rows[2].status).to.equal("Incoming!")
			expect(string.find(rows[2].detail, "Lava Fields", 1, true) ~= nil).to.equal(true)
			expect(rows[3].status).to.equal("Ready!")
			expect(rows[4].status).to.equal("Live")
		end)

		it("copes with unknown schedules", function()
			local daily = MenuViews.daily(100, 2, 0, 0)
			local rows = MenuViews.events(nil, nil, nil, daily)
			expect(rows[1].status).to.equal("Soon")
			expect(rows[3].status).to.equal("in 1:40")
		end)
	end)
end
