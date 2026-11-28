--!strict
--[[
	Art — the style sheet's real artwork (logo, round icons, Play/Shop buttons, coin, Starlings,
	shards), cut out by tools/art/extract-ui-art.py (`make ui-art`) into three atlas images:

	  assets/ui/logo.png            -> Ids.Logo
	  assets/ui/ui-atlas.png        -> Ids.Ui
	  assets/ui/creatures-atlas.png -> Ids.Creatures

	Roblox only shows uploaded images, so the owner uploads those three files (Studio > Asset
	Manager > Import, place saved to Roblox first) and pastes their image ids below. Until then
	`Art.apply` returns false and every component keeps its code-drawn look (text logo, emoji
	icons): the game never shows a broken or empty image.

	API: Art.has(name, ids?), Art.apply(target, name, ids?), Art.aspect(name), Art.label(name, ids?).
	`ids` overrides Art.Ids (tests).
]]

local ArtSprites = require(script.Parent.ArtSprites)

export type Ids = {
	Logo: string,
	Ui: string,
	Creatures: string,
}

local Art = {
	-- Image ids of the uploaded atlases: "123456789" or "rbxassetid://123456789". "" = not uploaded.
	Ids = table.freeze({
		Logo = "",
		Ui = "",
		Creatures = "",
	} :: Ids),
}

local function imageFor(atlas: string, ids: Ids?): string?
	local id = ((ids or Art.Ids) :: any)[atlas]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	if string.match(id, "^rbxassetid://%d+$") then
		return id
	end
	return nil
end

-- True when the sprite exists and its atlas has been uploaded.
function Art.has(name: string, ids: Ids?): boolean
	local sprite = ArtSprites[name]
	return sprite ~= nil and imageFor(sprite.atlas, ids) ~= nil
end

-- Width / height of a sprite (1 if unknown), to size its holder without stretching.
function Art.aspect(name: string): number
	local sprite = ArtSprites[name]
	if sprite == nil or sprite.h == 0 then
		return 1
	end
	return sprite.w / sprite.h
end

-- Shows the sprite on an ImageLabel/ImageButton. Returns false (target untouched) when the art
-- is not available, so the caller keeps its fallback.
function Art.apply(target: ImageLabel | ImageButton, name: string, ids: Ids?): boolean
	local sprite = ArtSprites[name]
	if sprite == nil then
		return false
	end
	local image = imageFor(sprite.atlas, ids)
	if image == nil then
		return false
	end
	local holder = target :: ImageLabel -- same image properties on ImageButton
	holder.Image = image
	holder.ImageRectOffset = Vector2.new(sprite.x, sprite.y)
	holder.ImageRectSize = Vector2.new(sprite.w, sprite.h)
	holder.ScaleType = Enum.ScaleType.Fit
	return true
end

-- A transparent, full-size ImageLabel showing the sprite, or nil when the art is not available.
function Art.label(name: string, ids: Ids?): ImageLabel?
	if not Art.has(name, ids) then
		return nil
	end
	local label = Instance.new("ImageLabel")
	label.Name = "Art"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	Art.apply(label, name, ids)
	return label
end

return table.freeze(Art)
