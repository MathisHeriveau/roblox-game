--[[
	Model preview (Lune) — ray-traces the REAL Starling and shard models built by the game
	(StarlingBuilder / ShardBuilder) into build/preview/models.png, so their design can be seen
	and iterated on without Studio. Usage: lune run tools/preview-models.luau (make preview-models)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Canvas = require("./lib/Canvas")
local PartRenderer = require("./lib/PartRenderer")
local PixelFont = require("./lib/PixelFont")
local RobloxRuntime = require("./lib/RobloxRuntime")

local PLACE = "build/preview.rbxl"
for _, dir in { "build", "build/preview" } do
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
end
local built = process.exec("rojo", { "build", "default.project.json", "-o", PLACE })
if not built.ok then
	print(built.stderr)
	process.exit(1)
end

local runtime = RobloxRuntime.fromPlaceFile(PLACE)
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local ReplicatedStorage = runtime.game:GetService("ReplicatedStorage")
local Server = runtime.game:GetService("ServerScriptService").Server
local Rarities = runtime.require(ReplicatedStorage.Shared.Config.Rarities)
local StarlingBuilder = runtime.require(Server.Systems.Base.StarlingBuilder)
local ShardBuilder = runtime.require(Server.Systems.Shards.ShardBuilder)

local TILE_W, TILE_H, LABEL_H = 240, 240, 26
local entries = {}
for _, rarity in Rarities.list do
	table.insert(entries, {
		row = 1,
		label = rarity.name,
		build = function()
			return StarlingBuilder.build(rarity.id, false, CFrame.new())
		end,
	})
end
table.insert(entries, {
	row = 1,
	label = "SHINY EPIC",
	build = function()
		return StarlingBuilder.build(3, true, CFrame.new())
	end,
})
for _, rarity in Rarities.list do
	table.insert(entries, {
		row = 2,
		label = rarity.name,
		shard = true,
		build = function()
			return ShardBuilder.build(rarity.id, false, false, Vector3.zero).model
		end,
	})
end
table.insert(entries, {
	row = 2,
	label = "COMET CORE",
	shard = true,
	build = function()
		return ShardBuilder.build(5, false, true, Vector3.zero).model
	end,
})

local columns = 7
local canvas = Canvas.new(columns * TILE_W, 2 * (TILE_H + LABEL_H) + 50, { 22, 16, 58 })
PixelFont.draw(canvas, "STARLINGS (FRONT 3/4 VIEW) AND STAR SHARDS", 16, 14, 3, { 255, 205, 64 })

local counters = { 0, 0 }
for _, entry in entries do
	counters[entry.row] += 1
	local column = counters[entry.row] - 1
	local x0 = column * TILE_W
	local y0 = 50 + (entry.row - 1) * (TILE_H + LABEL_H)
	-- Soft vignette background per tile.
	Canvas.fillRect(canvas, x0 + 4, y0, x0 + TILE_W - 5, y0 + TILE_H - 1, { 34, 26, 78 })
	local model = entry.build()
	local prims = PartRenderer.collect(model, function(part)
		return part.Name == "Beacon"
	end)
	-- Frame the model: centre of its parts, camera in front (-Z) and slightly above/right.
	local minY, maxY, cx, cy, cz, count = math.huge, -math.huge, 0, 0, 0, 0
	for _, prim in prims do
		cx += prim.px
		cy += prim.py
		cz += prim.pz
		count += 1
		minY = math.min(minY, prim.py - prim.bound)
		maxY = math.max(maxY, prim.py + prim.bound)
	end
	cx, cy, cz = cx / count, cy / count, cz / count
	local distance = math.max(6, (maxY - minY) * 2.3)
	PartRenderer.render(canvas, prims, {
		eye = { cx + distance * 0.28, cy + distance * 0.22, cz - distance },
		target = { cx, cy, cz },
		fov = 36,
	}, x0 + 4, y0, TILE_W - 8, TILE_H)
	local text = string.upper(entry.label)
	PixelFont.draw(canvas, text, x0 + (TILE_W - PixelFont.width(text, 2)) / 2, y0 + TILE_H + 6, 2, { 230, 222, 255 })
end

fs.writeFile("build/preview/models.png", Canvas.encodePng(canvas))
print("wrote build/preview/models.png")
