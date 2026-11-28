--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local UI = StarterPlayer.StarterPlayerScripts.Client.UI
local Art = require(UI.Art)
local ArtSprites = require(UI.ArtSprites)

local UPLOADED: Art.Ids = { Logo = "111", Ui = "rbxassetid://222", Creatures = "333" }

return function()
	describe("ArtSprites", function()
		it("has every sprite the UI needs, inside a 1024 px atlas", function()
			local needed = { "logo", "play", "shop", "coin", "plus" }
			for _, icon in { "settings", "stats", "gifts", "index", "top", "events" } do
				table.insert(needed, `icon-{icon}`)
			end
			for rarity = 1, 6 do
				table.insert(needed, `starling-{rarity}`)
				table.insert(needed, `shard-{rarity}`)
			end
			for _, name in needed do
				local sprite = ArtSprites[name]
				assert(sprite, `missing sprite {name}`)
				expect(sprite.w > 0 and sprite.h > 0).to.equal(true)
				expect(sprite.x + sprite.w <= 1024 and sprite.y + sprite.h <= 1024).to.equal(true)
			end
		end)
	end)

	describe("Art", function()
		it("falls back while the atlases are not uploaded", function()
			expect(Art.has("logo", { Logo = "", Ui = "", Creatures = "" })).to.equal(false)
			local label = Instance.new("ImageLabel")
			expect(Art.apply(label, "logo", { Logo = "", Ui = "", Creatures = "" })).to.equal(false)
			expect(Art.label("coin", { Logo = "", Ui = "", Creatures = "" })).to.equal(nil)
		end)

		it("shows the sprite's rectangle of its atlas once uploaded", function()
			local label = Instance.new("ImageLabel")
			expect(Art.apply(label, "icon-gifts", UPLOADED)).to.equal(true)
			local sprite = ArtSprites["icon-gifts"]
			expect(label.Image).to.equal("rbxassetid://222")
			expect(label.ImageRectOffset).to.equal(Vector2.new(sprite.x, sprite.y))
			expect(label.ImageRectSize).to.equal(Vector2.new(sprite.w, sprite.h))
			expect(Art.has("starling-6", UPLOADED)).to.equal(true)
			local logo = Art.label("logo", UPLOADED) :: ImageLabel
			expect(logo.Image).to.equal("rbxassetid://111")
		end)

		it("rejects unknown sprites and malformed ids", function()
			expect(Art.has("dragon", UPLOADED)).to.equal(false)
			expect(Art.has("logo", { Logo = "https://evil.example/x.png", Ui = "", Creatures = "" })).to.equal(false)
			expect(Art.aspect("dragon")).to.equal(1)
			expect(Art.aspect("play") > 2).to.equal(true)
		end)
	end)
end
