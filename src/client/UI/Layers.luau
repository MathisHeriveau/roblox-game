--!strict
--[[
	Layers — DisplayOrder of every ScreenGui, in one place so the stacking stays intentional:
	HUD < base status < toasts < shop modal. Toasts must never cover the shop.
]]

return table.freeze({
	Hud = 0,
	BaseStatus = 2,
	Toasts = 10,
	Shop = 15,
})
