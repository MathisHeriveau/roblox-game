--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Settings = require(StarterPlayer.StarterPlayerScripts.Client.Settings)

return function()
	describe("Settings", function()
		afterEach(function()
			for _, info in Settings.LABELS do
				Settings.set(info.key, true)
			end
		end)

		it("starts with everything on and has a label per key", function()
			for _, info in Settings.LABELS do
				expect(Settings.get(info.key)).to.equal(true)
				expect(#info.label > 0).to.equal(true)
			end
		end)

		it("toggles and notifies only on real changes", function()
			local changes: { string } = {}
			local connection = Settings.changed:connect(function(key)
				table.insert(changes, key)
			end)
			Settings.toggle("sounds")
			expect(Settings.get("sounds")).to.equal(false)
			Settings.set("sounds", false)
			expect(#changes).to.equal(1)
			expect(changes[1]).to.equal("sounds")
			connection:disconnect()
		end)
	end)
end
