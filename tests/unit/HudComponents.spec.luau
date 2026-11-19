--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Components = StarterPlayer.StarterPlayerScripts.Client.UI.Components
local CarryIndicator = require(Components.CarryIndicator)
local CoinPill = require(Components.CoinPill)
local EventBanner = require(Components.EventBanner)
local LevelBadge = require(Components.LevelBadge)
local ShopCard = require(Components.ShopCard)

local function find(root: Instance, name: string): Instance
	return root:FindFirstChild(name, true) :: Instance
end

return function()
	describe("CoinPill", function()
		it("renders compact coins and income", function()
			local pill = CoinPill.new()
			pill.setCoins(12450)
			pill.setIncome(250, 0)
			expect((find(pill.root, "Value") :: TextLabel).Text).to.equal("12.4K")
			expect((find(pill.root, "Income") :: TextLabel).Text).to.equal("+250/s")
			pill.setIncome(0, 0)
			expect((find(pill.root, "Income") :: TextLabel).Text).to.equal("Bring shards to your base!")
			pill.root:Destroy()
		end)
	end)

	describe("LevelBadge", function()
		it("shows level and a clamped XP bar", function()
			local badge = LevelBadge.new()
			badge.setLevel(42, 3280, 7500)
			expect((find(badge.root, "Level") :: TextLabel).Text).to.equal("42")
			expect((find(badge.root, "Fill") :: Frame).Size.X.Scale).to.be.near(3280 / 7500, 1e-6)
			badge.setLevel(1, 999, 10)
			expect((find(badge.root, "Fill") :: Frame).Size.X.Scale).to.equal(1)
			badge.root:Destroy()
		end)
	end)

	describe("CarryIndicator", function()
		it("shows the count and contextual hints", function()
			local carry = CarryIndicator.new()
			carry.setCarry(2, 2)
			expect((find(carry.root, "Count") :: TextLabel).Text).to.equal("✦ 2 / 2")
			expect(string.find((find(carry.root, "Hint") :: TextLabel).Text, "base", 1, true) ~= nil).to.equal(true)
			carry.root:Destroy()
		end)
	end)

	describe("ShopCard", function()
		it("renders a view and disables locked buttons", function()
			local card = ShopCard.new()
			card.render({
				icon = "⚡",
				title = "Speed",
				description = "Run faster: 18 → 20",
				level = "Level 0 / 10",
				buttonText = "💰 50",
				state = "buy",
			})
			expect((find(card.root, "Title") :: TextLabel).Text).to.equal("Speed")
			expect(card.button.Text).to.equal("💰 50")
			expect(card.button.Active).to.equal(true)
			card.render({
				icon = "🌋",
				title = "Lava Fields",
				description = "Unlock Crystal Desert first",
				level = "Zone 3",
				buttonText = "🔒",
				state = "locked",
			})
			expect(card.button.Active).to.equal(false)
			card.root:Destroy()
		end)
	end)

	describe("EventBanner", function()
		it("toggles the comet banner", function()
			local banner = EventBanner.new()
			local comet = find(banner.root, "CometBanner") :: Frame
			expect(comet.Visible).to.equal(false)
			banner.showComet("COMET INCOMING!", "Crash in 0:20 · Lava Fields")
			expect(comet.Visible).to.equal(true)
			banner.hideComet()
			expect(comet.Visible).to.equal(false)
			banner.root:Destroy()
		end)
	end)
end
