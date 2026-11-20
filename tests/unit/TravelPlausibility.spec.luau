--!strict
--[[
	The anti-teleport delivery check (ShardRules.deliveryPlausible) must accept the fastest
	legitimate trips of the generated world. Jump pads fly ~60 studs/s, three times walking speed:
	a shard grabbed next to a sky island's return pad and carried home must still count.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Systems = ServerScriptService.Server.Systems
local BaseLayout = require(Systems.Base.BaseLayout)
local MapLayout = require(Systems.Map.MapLayout)
local ShardRules = require(Systems.Shards.ShardRules)

local function flat(x1: number, z1: number, x2: number, z2: number): number
	return math.sqrt((x1 - x2) ^ 2 + (z1 - z2) ^ 2)
end

return function()
	describe("delivery plausibility over the real world", function()
		it("accepts a shard carried home through a sky island's return pad", function()
			local layout = MapLayout.generate(GameConfig.Map)
			local plots = BaseLayout.generate(GameConfig.Base)
			local maxSpeed = Economy.walkSpeed(0)
			-- Fastest real run: base speed slowed by one carried shard.
			local runSpeed = maxSpeed * Economy.carrySpeedFactor(1)
			local magnet = GameConfig.Economy.BaseMagnetRadius
			local checked = 0
			for _, pad in layout.jumpPads do
				if pad.kind == "down" then
					for _, plot in plots do
						-- Delivery triggers on entering the plot (1 stud margin, BaseService.isInOwnPlot).
						local toPlot = flat(pad.target.x, pad.target.z, plot.x, plot.z)
						local run = math.max(0, toPlot - (plot.size / 2 + 1))
						local elapsed = pad.flightTime + run / runSpeed
						-- Shard grabbed by the magnet on the far side of the pad: longest distance.
						local deliveredAt = toPlot - run
						local ux, uz = (plot.x - pad.target.x) / toPlot, (plot.z - pad.target.z) / toPlot
						local dx, dz =
							pad.target.x + ux * (toPlot - deliveredAt), pad.target.z + uz * (toPlot - deliveredAt)
						local distance = flat(pad.position.x, pad.position.z, dx, dz) + magnet
						expect(ShardRules.deliveryPlausible(distance, elapsed, maxSpeed)).to.equal(true)
						checked += 1
					end
				end
			end
			expect(checked > 0).to.equal(true)
		end)
	end)
end
