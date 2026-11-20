--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Components = StarterPlayer.StarterPlayerScripts.Client.UI.Components
local CarryIndicator = require(Components.CarryIndicator)
local CoinPill = require(Components.CoinPill)
local EventBanner = require(Components.EventBanner)
local LevelBadge = require(Components.LevelBadge)
local ShopCard = require(Components.ShopCard)
local ZoneBanner = require(Components.ZoneBanner)

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
			carry.setCarry(0, 2, 5)
			expect((find(carry.root, "Count") :: TextLabel).Text).to.equal("⭐ STOLEN!")
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
			expect(banner.comet.Name).to.equal("CometBanner")
			expect(banner.comet.Visible).to.equal(false)
			banner.showComet("COMET INCOMING!", "Crash in 0:20 · Lava Fields")
			expect(banner.comet.Visible).to.equal(true)
			banner.hideComet()
			expect(banner.comet.Visible).to.equal(false)
			banner.setCountdowns("☄️ Meteor shower in 0:12", "")
			expect((find(banner.countdowns, "Meteor") :: TextLabel).Text).to.equal("☄️ Meteor shower in 0:12")
			banner.countdowns:Destroy()
			banner.comet:Destroy()
		end)
	end)

	describe("ZoneBanner", function()
		local function luminance(color: Color3): number
			return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
		end

		it("shows the zone name and a light subtitle with a dark outline (readable anywhere)", function()
			local banner = ZoneBanner.new()
			expect(banner.root.Visible).to.equal(false)
			banner.show("🌿 STARTING MEADOW", "Shards drop here · zone 1", Color3.fromRGB(76, 175, 80))
			expect(banner.root.Visible).to.equal(true)
			local title = find(banner.root, "Title") :: TextLabel
			local subtitle = find(banner.root, "Subtitle") :: TextLabel
			expect(title.Text).to.equal("🌿 STARTING MEADOW")
			expect(subtitle.Text).to.equal("Shards drop here · zone 1")
			expect(luminance(subtitle.TextColor3) > 0.8).to.equal(true)
			local outline = subtitle:FindFirstChildOfClass("UIStroke") :: UIStroke
			expect(luminance(outline.Color) < 0.2).to.equal(true)
			-- Sits on its own panel: readable over the bright sky and the dark base sign alike.
			expect(banner.root.BackgroundTransparency < 0.5).to.equal(true)
			banner.root:Destroy()
		end)

		it("fades text, outlines and panel together, then hides", function()
			local banner = ZoneBanner.new()
			banner.show("☁️ FLOATING SKY ISLANDS", "Shards drop here · zone 4", Color3.new(0.5, 0.4, 0.9))
			banner.setFade(1)
			expect(banner.root.Visible).to.equal(false)
			for _, descendant in banner.root:GetDescendants() do
				if descendant:IsA("TextLabel") then
					expect(descendant.TextTransparency).to.be.near(1, 1e-3)
				elseif descendant:IsA("UIStroke") then
					-- A stroke left opaque on faded text is the "dark on dark" ghost text.
					expect(descendant.Transparency).to.be.near(1, 1e-3)
				end
			end
			expect(banner.root.BackgroundTransparency).to.be.near(1, 1e-3)
			banner.show("🏜️ CRYSTAL DESERT", "Shards drop here · zone 2", Color3.new(1, 0.8, 0.4))
			expect(banner.root.Visible).to.equal(true)
			expect((find(banner.root, "Subtitle") :: TextLabel).TextTransparency).to.equal(0)
			banner.root:Destroy()
		end)
	end)
end
