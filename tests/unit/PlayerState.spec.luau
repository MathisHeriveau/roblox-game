--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)

local function valid(): { [string]: any }
	return {
		coins = 1,
		vault = 0,
		incomePerSecond = 2,
		xp = 3,
		level = 1,
		levelProgress = 3,
		levelGoal = 40,
		rebirths = 0,
		multiplier = 1,
		rebirthCost = 1000000,
		zoneTier = 1,
		upgrades = { speed = 0, carry = 0, magnet = 0, slots = 0 },
		carrying = 0,
		capacity = 1,
		starlings = 0,
		slots = 4,
		shardsDelivered = 0,
		bumpsLanded = 0,
		cometsCaught = 0,
	}
end

return function()
	describe("PlayerStateTypes.isPlayerState", function()
		it("accepts a complete snapshot", function()
			expect(PlayerStateTypes.isPlayerState(valid())).to.equal(true)
		end)

		it("rejects malformed payloads", function()
			expect(PlayerStateTypes.isPlayerState(nil)).to.equal(false)
			expect(PlayerStateTypes.isPlayerState("state")).to.equal(false)
			local missing = valid()
			missing.coins = nil
			expect(PlayerStateTypes.isPlayerState(missing)).to.equal(false)
			local nan = valid()
			nan.level = 0 / 0
			expect(PlayerStateTypes.isPlayerState(nan)).to.equal(false)
			local noUpgrades = valid()
			noUpgrades.upgrades = 5
			expect(PlayerStateTypes.isPlayerState(noUpgrades)).to.equal(false)
		end)
	end)
end
