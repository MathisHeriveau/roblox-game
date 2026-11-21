--!strict
--[[
	Modal: one modal window at a time (shop and menu panels share a DisplayOrder).
]]

local StarterPlayer = game:GetService("StarterPlayer")

local Modal = require(StarterPlayer.StarterPlayerScripts.Client.UI.Modal)

return function()
	describe("Modal", function()
		afterEach(function()
			Modal.closeAll()
		end)

		it("closes the previous modal when another one opens", function()
			local closed: { string } = {}
			Modal.opened("Shop", function()
				table.insert(closed, "Shop")
			end)
			Modal.opened("Index", function()
				table.insert(closed, "Index")
			end)
			expect(#closed).to.equal(1)
			expect(closed[1]).to.equal("Shop")
			expect(Modal.current()).to.equal("Index")
		end)

		it("does not close a modal that re-opens itself", function()
			local closes = 0
			local function close()
				closes += 1
			end
			Modal.opened("Shop", close)
			Modal.opened("Shop", close)
			expect(closes).to.equal(0)
		end)

		it("forgets a modal once it reports closed, and ignores stale reports", function()
			Modal.opened("Stats", function() end)
			Modal.closed("Shop")
			expect(Modal.current()).to.equal("Stats")
			Modal.closed("Stats")
			expect(Modal.current()).to.equal(nil)
		end)
	end)
end
