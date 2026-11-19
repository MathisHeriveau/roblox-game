--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseLayout = require(ServerScriptService.Server.Systems.Base.BaseLayout)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

return function()
	local plots = BaseLayout.generate(GameConfig.Base)

	describe("BaseLayout", function()
		it("creates one plot per configured slot, all inside the hub", function()
			expect(#plots).to.equal(GameConfig.Base.PlotCount)
			local hubEdge = Zones.HUB_RADIUS * Zones.TILE_SIZE
			for _, plot in plots do
				local farthest = math.sqrt(plot.x ^ 2 + plot.z ^ 2) + plot.size / math.sqrt(2)
				expect(farthest <= hubEdge).to.equal(true)
			end
		end)

		it("never overlaps two plots", function()
			for i, a in plots do
				for j, b in plots do
					if i < j then
						local distance = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
						expect(distance >= a.size).to.equal(true)
					end
				end
			end
		end)

		it("has enough pedestals for the maximum number of Starlings", function()
			expect(#plots[1].pedestals).to.equal(Economy.MAX_SLOTS)
		end)

		it("round-trips local <-> world coordinates", function()
			for _, plot in plots do
				local x, z = BaseLayout.toWorld(plot, 3, -7)
				local lx, lz = BaseLayout.toLocal(plot, x, z)
				expect(lx).to.be.near(3, 1e-6)
				expect(lz).to.be.near(-7, 1e-6)
			end
		end)

		it("faces every entrance towards the island centre", function()
			for _, plot in plots do
				local frontX, frontZ = BaseLayout.toWorld(plot, 0, -plot.size / 2)
				local backX, backZ = BaseLayout.toWorld(plot, 0, plot.size / 2)
				local front = math.sqrt(frontX ^ 2 + frontZ ^ 2)
				local back = math.sqrt(backX ^ 2 + backZ ^ 2)
				expect(front < back).to.equal(true)
			end
		end)

		it("detects positions inside a plot and on its collect pad", function()
			local plot = plots[1]
			expect(BaseLayout.isInside(plot, plot.x, plot.z)).to.equal(true)
			expect(BaseLayout.isInside(plot, plot.x + plot.size, plot.z)).to.equal(false)
			local padX, padZ = BaseLayout.toWorld(plot, plot.collectPad.x, plot.collectPad.z)
			expect(BaseLayout.isOnCollectPad(plot, padX + 1, padZ, 3)).to.equal(true)
			expect(BaseLayout.isOnCollectPad(plot, plot.x, plot.z + plot.size / 2, 3)).to.equal(false)
			for _, pedestal in plot.pedestals do
				expect(math.abs(pedestal.x) < plot.size / 2 and math.abs(pedestal.z) < plot.size / 2).to.equal(true)
			end
		end)
	end)
end
