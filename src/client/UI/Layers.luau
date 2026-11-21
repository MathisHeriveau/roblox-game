--!strict
--[[
	Layers — DisplayOrder of every ScreenGui, in one place so the stacking stays intentional:
	HUD < base status < toasts < menu panels = shop modal < title screen. Toasts must never cover a
	modal (only one modal is open at a time: UI/Modal), and the title screen covers everything.
]]

return table.freeze({
	Hud = 0,
	BaseStatus = 2,
	Toasts = 10,
	Panels = 15,
	Shop = 15,
	Title = 30,
})
