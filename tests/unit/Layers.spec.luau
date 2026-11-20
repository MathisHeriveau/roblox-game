--!strict
--[[
	Layers: ScreenGui stacking order.

	Regression: toasts (DisplayOrder 20) were drawn over the shop (15), so "+💰1" collect toasts
	covered the cards the player was trying to buy.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local Layers = require(StarterPlayer.StarterPlayerScripts.Client.UI.Layers)

return function()
	describe("Layers", function()
		it("keeps toasts above the HUD but under the shop modal", function()
			expect(Layers.Hud < Layers.Toasts).to.equal(true)
			expect(Layers.BaseStatus < Layers.Toasts).to.equal(true)
			expect(Layers.Toasts < Layers.Shop).to.equal(true)
		end)
	end)
end
