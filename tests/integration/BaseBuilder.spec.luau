--!strict
--[[
	Integration: BaseLayout -> BaseBuilder, plus the Starling and Shard model builders.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShardVisuals = require(ReplicatedStorage.Shared.Game.ShardVisuals)
local Systems = ServerScriptService.Server.Systems
local BaseBuilder = require(Systems.Base.BaseBuilder)
local BaseLayout = require(Systems.Base.BaseLayout)
local ShardBuilder = require(Systems.Shards.ShardBuilder)
local StarlingBuilder = require(Systems.Base.StarlingBuilder)

return function()
	describe("BaseBuilder.build", function()
		local container: Folder
		local refs: BaseBuilder.PlotRefs

		beforeEach(function()
			container = Instance.new("Folder")
			refs = BaseBuilder.build(BaseLayout.generate(GameConfig.Base)[1], container)
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("builds a plot with pedestals, anchors, pad, sign and spawn", function()
			expect(refs.model.Parent).to.equal(container)
			expect(refs.model:GetAttribute("OwnerUserId")).to.equal(0)
			expect(#refs.pedestals).to.equal(#refs.plot.pedestals)
			expect(#refs.starlingAnchors).to.equal(#refs.pedestals)
			expect(refs.spawn.Neutral).to.equal(true)
			expect(refs.ownerLabel.Text).to.equal("Free Base")
			expect(refs.vaultLabel.Text).to.equal("💰 0")
		end)

		it("floats Starling anchors above their pedestals", function()
			for index, pedestal in refs.pedestals do
				local anchor = refs.starlingAnchors[index]
				expect(anchor.Position.Y > pedestal.CFrame.Position.Y).to.equal(true)
				local flat = (anchor.Position - pedestal.CFrame.Position) * Vector3.new(1, 0, 1)
				expect(flat.Magnitude).to.be.near(0, 1e-3)
			end
		end)

		it("adds raid elements: one disabled Steal prompt per pedestal, a lock console, a shield dome", function()
			expect(#refs.stealPrompts).to.equal(#refs.pedestals)
			for _, prompt in refs.stealPrompts do
				expect(prompt.Enabled).to.equal(false)
				expect(prompt.HoldDuration > 0).to.equal(true)
			end
			expect(refs.lockPrompt.Name).to.equal("LockPrompt")
			expect(refs.dome.Transparency).to.equal(1)
			BaseBuilder.setShield(refs, true)
			expect(refs.dome.Transparency < 1).to.equal(true)
			BaseBuilder.setShield(refs, false)
			expect(refs.dome.Transparency).to.equal(1)
		end)

		it("dims locked pedestals", function()
			BaseBuilder.setUnlockedSlots(refs, 4)
			expect(refs.pedestals[4].Transparency).to.equal(0)
			expect(refs.pedestals[5].Transparency > 0).to.equal(true)
		end)
	end)

	describe("StarlingBuilder.build", function()
		it("builds a tagged, glowing star with rarity extras", function()
			for _, rarity in Rarities.list do
				local model = StarlingBuilder.build(rarity.id, rarity.id == 6, CFrame.new(1, 2, 3))
				expect(model:HasTag(ShardVisuals.STARLING_TAG)).to.equal(true)
				expect(model:GetAttribute("Rarity")).to.equal(rarity.id)
				expect(model.PrimaryPart).to.be.ok()
				if rarity.id ~= 6 then -- Cosmic bodies are pearly white by design
					expect((model.PrimaryPart :: BasePart).Color).to.equal(rarity.color)
				end
				expect(model:FindFirstChild("CrownBand") ~= nil).to.equal(rarity.id == 4)
				expect(model:FindFirstChild("Halo") ~= nil).to.equal(rarity.id == 6)
				-- Every Starling has a real 3D face: eyes (open or ^ ^) and a mouth.
				expect(model:FindFirstChild("Eye") ~= nil or model:FindFirstChild("ClosedEye") ~= nil).to.equal(true)
				expect(model:FindFirstChild("Mouth")).to.be.ok()
				expect(model:FindFirstChild("Blush")).to.be.ok()
				model:Destroy()
			end
		end)
	end)

	describe("ShardBuilder", function()
		it("builds a hidden-able, movable gem with a beacon", function()
			local parts = ShardBuilder.build(3, true, false, Vector3.new(10, 5, -4))
			expect(parts.model:HasTag(ShardVisuals.SHARD_TAG)).to.equal(true)
			expect(parts.crystal:HasTag(ShardVisuals.CRYSTAL_TAG)).to.equal(true)
			expect(parts.crystal.Anchored).to.equal(true)
			expect(parts.crystal.CanCollide).to.equal(false)

			ShardBuilder.setVisible(parts, false)
			for _, gem in parts.gems do
				expect(gem.Transparency).to.equal(1)
			end
			ShardBuilder.setVisible(parts, true)
			expect(parts.crystal.Transparency).to.equal(parts.crystal:GetAttribute("BaseTransparency"))

			-- Every gem part keeps its offset from the crystal when the shard is moved.
			local probe = parts.gems[#parts.gems]
			local before = parts.crystal.CFrame:ToObjectSpace(probe.CFrame)
			ShardBuilder.placeAt(parts, Vector3.new(-20, 3, 7))
			local position = parts.crystal.CFrame.Position
			expect(position.X).to.be.near(-20, 1e-6)
			expect(position.Z).to.be.near(7, 1e-6)
			expect(position.Y > 3).to.equal(true)
			local after = parts.crystal.CFrame:ToObjectSpace(probe.CFrame)
			expect((after.Position - before.Position).Magnitude).to.be.near(0, 1e-4)
			parts.model:Destroy()
		end)

		it("welds every gem part to the crystal and anchors them together", function()
			local parts = ShardBuilder.build(4, false, false, Vector3.zero)
			expect(#parts.gems > 1).to.equal(true)
			for _, gem in parts.gems do
				if gem ~= parts.crystal then
					local weld = gem:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
					expect(weld).to.be.ok()
					expect(weld.Part0).to.equal(parts.crystal)
				end
			end
			ShardBuilder.setAnchored(parts, false)
			for _, gem in parts.gems do
				expect(gem.Anchored).to.equal(false)
				expect(gem.Massless).to.equal(true)
			end
			ShardBuilder.setAnchored(parts, true)
			expect(parts.crystal.Anchored).to.equal(true)
			expect(parts.beacon.Anchored).to.equal(true)
			parts.model:Destroy()
		end)

		it("makes comet cores bigger and burning", function()
			local comet = ShardBuilder.build(5, false, true, Vector3.zero)
			local normal = ShardBuilder.build(5, false, false, Vector3.zero)
			expect(comet.crystal.Size.X > normal.crystal.Size.X).to.equal(true)
			expect(comet.crystal:FindFirstChildOfClass("Fire")).to.be.ok()
			expect(comet.model.Name).to.equal("CometCore")
			comet.model:Destroy()
			normal.model:Destroy()
		end)
	end)
end
