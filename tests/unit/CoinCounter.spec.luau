--!strict
local StarterPlayer = game:GetService("StarterPlayer")

-- UI modules live in the client tree; requiring them on the server is fine for pure construction.
local CoinCounter = require(StarterPlayer.StarterPlayerScripts.Client.UI.Components.CoinCounter)

return function()
	describe("CoinCounter.formatNumber", function()
		it("groups thousands", function()
			expect(CoinCounter.formatNumber(0)).to.equal("0")
			expect(CoinCounter.formatNumber(999)).to.equal("999")
			expect(CoinCounter.formatNumber(1000)).to.equal("1,000")
			expect(CoinCounter.formatNumber(1234567)).to.equal("1,234,567")
		end)

		it("never throws or shows garbage on hostile input", function()
			expect(CoinCounter.formatNumber(0 / 0)).to.equal("0")
			expect(CoinCounter.formatNumber(math.huge)).to.equal("0")
			expect(CoinCounter.formatNumber(-5)).to.equal("0")
			expect(CoinCounter.formatNumber(12.9)).to.equal("12")
		end)
	end)

	describe("CoinCounter.new", function()
		it("builds a responsive widget and renders state", function()
			local counter = CoinCounter.new()
			expect(counter.root.ClassName).to.equal("Frame")
			expect(counter.root:FindFirstChildOfClass("UISizeConstraint")).to.be.ok()

			counter.setState(2500, 3)
			local coins = counter.root:FindFirstChild("Coins") :: TextLabel
			local collected = counter.root:FindFirstChild("Collected") :: TextLabel
			expect(coins.Text).to.equal("2,500")
			expect(collected.Text).to.equal("3 pickups")
			counter.root:Destroy()
		end)
	end)
end
