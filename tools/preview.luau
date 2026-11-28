--[[
	Island preview (Lune) — renders the procedurally generated world to PNG images so designers
	(and AI agents) can SEE the map without opening Studio.

	Usage: lune run tools/preview.luau            (or `make preview`)
	Output: build/preview/island-top.png   top-down map: zones, relief, lava, props, bases, impacts
	        build/preview/island-iso.png   isometric 3D view of the floating island
	        + a text report (zone stats, walkability, impact distribution)

	It runs the REAL game modules (MapLayout, BaseLayout, SkySchedule...) from a Rojo build, so the
	images always match what the server generates in Roblox.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Canvas = require("./lib/Canvas")
local PixelFont = require("./lib/PixelFont")
local RobloxRuntime = require("./lib/RobloxRuntime")

local OUTPUT_DIR = "build/preview"
local PLACE = "build/preview.rbxl"

if not fs.isDir("build") then
	fs.writeDir("build")
end
if not fs.isDir(OUTPUT_DIR) then
	fs.writeDir(OUTPUT_DIR)
end
local built = process.exec("rojo", { "build", "default.project.json", "-o", PLACE })
if not built.ok then
	print(built.stderr)
	process.exit(1)
end

local runtime = RobloxRuntime.fromPlaceFile(PLACE)
local game = runtime.game
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server

local GameConfig = runtime.require(ReplicatedStorage.Shared.Config.GameConfig)
local Zones = runtime.require(ReplicatedStorage.Shared.Config.Zones)
local Rarities = runtime.require(ReplicatedStorage.Shared.Config.Rarities)
local Prng = runtime.require(ReplicatedStorage.Shared.Utils.Prng)
local MapLayout = runtime.require(Server.Systems.Map.MapLayout)
local MapBuilder = runtime.require(Server.Systems.Map.MapBuilder)
local BaseLayout = runtime.require(Server.Systems.Base.BaseLayout)
local SkySchedule = runtime.require(Server.Systems.Shards.SkySchedule)

local function rgb(color: any): Canvas.Color
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

local layout = MapLayout.generate(GameConfig.Map)
-- The real terrain materials MapBuilder fills (surface cells and the band under them).
local terrainPlans = MapBuilder.terrainPlan(layout)
local materialColors: { [any]: Canvas.Color } = {}
for material, color in MapBuilder.materialColors() do
	materialColors[material] = rgb(color)
end
local CELLS = MapBuilder.SURFACE_DIVISIONS
local decorPlan = MapBuilder.decorPlan(layout)
local plots = BaseLayout.generate(GameConfig.Base)
local impacts = SkySchedule.meteorImpacts(Prng.new(7), layout, 24, function()
	return true
end)
local comet = SkySchedule.cometImpacts(Prng.new(9), layout, GameConfig.Events, function()
	return true
end)

local HUB_COLOR = { 156, 148, 196 }
local LAVA_COLOR = { 255, 92, 24 }
local ROCK_COLOR = { 92, 76, 146 }
local WOOD_COLOR = { 163, 116, 74 }
local PROP_COLORS: { [string]: Canvas.Color } = {
	tree = { 46, 130, 52 },
	crystal = { 190, 120, 255 },
	rock = { 58, 44, 54 },
	pillar = { 205, 190, 255 },
	arch = { 214, 160, 98 },
	volcano = { 120, 60, 50 },
	floatingIsland = { 86, 178, 78 },
}
local PAD_COLORS: { [string]: Canvas.Color } = { up = { 190, 120, 255 }, down = { 80, 220, 255 } }

local function tileColor(tile: any): Canvas.Color
	if tile.tier == 0 then
		return HUB_COLOR
	elseif tile.kind == "lava" then
		return LAVA_COLOR
	end
	return rgb(Zones.get(tile.tier).topColor)
end

-- Height range for shading.
local minHeight, maxHeight = math.huge, -math.huge
for _, tile in layout.tiles do
	minHeight = math.min(minHeight, tile.height)
	maxHeight = math.max(maxHeight, tile.height)
end

local function heightShade(tile: any): number
	-- Hillshade: light from the north-west, plus a gentle brightening with altitude.
	local west = MapLayout.tileAt(layout, tile.x - layout.tileSize, tile.z)
	local north = MapLayout.tileAt(layout, tile.x, tile.z - layout.tileSize)
	local slope = 0
	if west then
		slope += tile.height - west.height
	end
	if north then
		slope += tile.height - north.height
	end
	local altitude = (tile.height - minHeight) / math.max(1, maxHeight - minHeight)
	return math.clamp(0.82 + altitude * 0.25 + slope * 0.035, 0.55, 1.3)
end

--------------------------------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------------------------------

local report = {}
local function line(text: string)
	table.insert(report, text)
	print(text)
end

local maxStep = 0
for _, tile in layout.tiles do
	if tile.kind == "ground" then
		for _, offset in { { 1, 0 }, { 0, 1 } } do
			local neighbour =
				MapLayout.tileAt(layout, tile.x + offset[1] * layout.tileSize, tile.z + offset[2] * layout.tileSize)
			if neighbour and neighbour.kind == "ground" then
				maxStep = math.max(maxStep, math.abs(tile.height - neighbour.height))
			end
		end
	end
end

line(
	`ISLAND SEED {layout.seed}  TILES {#layout.tiles}  RADIUS {layout.radius} TILES ({layout.radius * layout.tileSize} STUDS)`
)
line(`HEIGHT {minHeight} TO {maxHeight}  MAX WALKABLE STEP {maxStep} (LIMIT {GameConfig.Map.MaxStep})`)
for tier = 0, Zones.COUNT do
	local count, lava, low, high = 0, 0, math.huge, -math.huge
	for _, tile in layout.tiles do
		if tile.tier == tier then
			count += 1
			low = math.min(low, tile.height)
			high = math.max(high, tile.height)
			if tile.kind == "lava" then
				lava += 1
			end
		end
	end
	local name = if tier == 0 then Zones.HUB_NAME else Zones.get(tier).name
	local candidates = if tier > 0 then #layout.impactCandidates[tier] else 0
	line(`  {name}: {count} TILES  HEIGHT {low}-{high}  LAVA {lava}  IMPACT SPOTS {candidates}`)
end
local propCounts: { [string]: number } = {}
for _, prop in layout.props do
	propCounts[prop.kind] = (propCounts[prop.kind] or 0) + 1
end
local propLine = {}
for kind, count in propCounts do
	table.insert(propLine, `{kind} {count}`)
end
table.sort(propLine)
line(`PROPS: {table.concat(propLine, ", ")}`)
local perZone = {}
for _, impact in impacts do
	perZone[impact.tile.tier] = (perZone[impact.tile.tier] or 0) + 1
end
line(
	`SAMPLE SHOWER (24): MEADOW {perZone[1] or 0}, DESERT {perZone[2] or 0}, LAVA {perZone[3] or 0}, SKY {perZone[4] or 0}`
)
if #comet > 0 then
	line(
		`SAMPLE COMET: {Zones.get(comet[1].tile.tier).name}, CORE {Rarities.get(comet[1].rarity).name}, +{#comet - 1} SHARDS`
	)
end

--------------------------------------------------------------------------------------------------
-- Top-down map
--------------------------------------------------------------------------------------------------

do
	local scale = 1.25
	local extent = (layout.radius + 7) * layout.tileSize
	local mapSize = math.floor(extent * 2 * scale) + 40
	local legendWidth = 430
	local canvas = Canvas.new(mapSize + legendWidth, mapSize, { 18, 14, 48 })
	local cx, cy = mapSize / 2, mapSize / 2
	local function px(x: number, z: number): (number, number)
		return cx + x * scale, cy + z * scale
	end

	-- Starry background.
	local stars = Prng.new(3)
	for _ = 1, 900 do
		Canvas.set(canvas, stars:nextInteger(0, mapSize - 1), stars:nextInteger(0, mapSize - 1), { 120, 110, 190 })
	end

	local half = layout.tileSize / 2
	local cellSize = layout.tileSize / CELLS
	for _, plan in terrainPlans do
		local tile = plan.tile
		local shade = heightShade(tile)
		for row = 0, CELLS - 1 do
			for column = 0, CELLS - 1 do
				local material = plan.surface[row * CELLS + column + 1]
				local cx0 = tile.x - half + column * cellSize
				local cz0 = tile.z - half + row * cellSize
				local x0, y0 = px(cx0, cz0)
				local x1, y1 = px(cx0 + cellSize, cz0 + cellSize)
				local color = materialColors[material] or tileColor(tile)
				Canvas.fillRect(canvas, x0, y0, math.max(x0, x1 - 1), math.max(y0, y1 - 1), Canvas.shade(color, shade))
			end
		end
	end

	-- Zone borders (warped exactly like Zones.tierAt).
	for tier = 0, Zones.COUNT - 2 do
		local steps = 720
		for step = 0, steps do
			local angle = step / steps * math.pi * 2
			local dirX, dirZ = math.cos(angle), math.sin(angle)
			local radius = Zones.outerRadius(tier)
			if tier > 0 then
				radius -= Zones.warp(dirX, dirZ)
			end
			local x, y = px(dirX * radius * layout.tileSize, dirZ * radius * layout.tileSize)
			Canvas.blend(canvas, x, y, { 255, 255, 255 }, 0.55)
		end
	end

	-- Cosmetic decor (flowers, bushes, pebbles) as small dots.
	for _, item in decorPlan do
		local x, y = px(item.x, item.z)
		Canvas.circle(canvas, x, y, if item.kind == "bush" then 1.6 else 1, rgb(item.color))
	end

	for _, prop in layout.props do
		local x, y = px(prop.x, prop.z)
		local color = PROP_COLORS[prop.kind] or { 255, 255, 255 }
		if prop.kind == "floatingIsland" then
			Canvas.circle(canvas, x, y, 8 * prop.scale * scale, Canvas.shade(ROCK_COLOR, 0.9))
			Canvas.circle(canvas, x, y, 6 * prop.scale * scale, color)
		elseif prop.kind == "volcano" then
			Canvas.circle(canvas, x, y, 20 * scale, Canvas.shade(color, 0.8))
			Canvas.circle(canvas, x, y, 13 * scale, color)
			Canvas.circle(canvas, x, y, 6 * scale, LAVA_COLOR)
		elseif prop.kind == "arch" then
			local ax, az = math.cos(prop.yaw) * 7, math.sin(prop.yaw) * 7
			local x0, y0 = px(prop.x - ax, prop.z - az)
			local x1, y1 = px(prop.x + ax, prop.z + az)
			Canvas.line(canvas, x0, y0, x1, y1, color)
			Canvas.circle(canvas, x0, y0, 3, color)
			Canvas.circle(canvas, x1, y1, 3, color)
		else
			Canvas.circle(canvas, x, y, 3.2 * prop.scale, Canvas.shade(color, 0.6))
			Canvas.circle(canvas, x, y, 2.4 * prop.scale, color)
		end
	end

	-- Jump pads and their flight paths (dashed).
	for _, pad in layout.jumpPads do
		local color = PAD_COLORS[pad.kind]
		local x0, y0 = px(pad.position.x, pad.position.z)
		local x1, y1 = px(pad.target.x, pad.target.z)
		local steps = 24
		for step = 0, steps - 1, 2 do
			local t0, t1 = step / steps, (step + 1) / steps
			Canvas.line(
				canvas,
				x0 + (x1 - x0) * t0,
				y0 + (y1 - y0) * t0,
				x0 + (x1 - x0) * t1,
				y0 + (y1 - y0) * t1,
				color
			)
		end
		Canvas.circle(canvas, x0, y0, 5, Canvas.shade(color, 0.6))
		Canvas.circle(canvas, x0, y0, 3.5, color)
	end

	-- Bases.
	for _, plot in plots do
		local halfSize = plot.size / 2
		local corners = {}
		for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local wx, wz = BaseLayout.toWorld(plot, corner[1] * halfSize, corner[2] * halfSize)
			local x, y = px(wx, wz)
			table.insert(corners, { x, y })
		end
		Canvas.fillPolygon(canvas, corners, WOOD_COLOR)
		for _, pedestal in plot.pedestals do
			local wx, wz = BaseLayout.toWorld(plot, pedestal.x, pedestal.z)
			local x, y = px(wx, wz)
			Canvas.circle(canvas, x, y, 2, { 0, 180, 255 })
		end
		local padX, padZ = BaseLayout.toWorld(plot, plot.collectPad.x, plot.collectPad.z)
		local x, y = px(padX, padZ)
		Canvas.circle(canvas, x, y, 3.5, { 64, 222, 120 })
		local labelX, labelY = px(plot.x, plot.z)
		PixelFont.draw(canvas, tostring(plot.index), labelX - 5, labelY - 7, 2, { 40, 24, 16 })
	end

	-- Monument + plaza spawn.
	Canvas.circle(canvas, cx, cy, 9 * scale, { 92, 76, 146 })
	Canvas.circle(canvas, cx, cy, 4 * scale, { 255, 205, 64 })
	local sx, sy = px(0, 22)
	Canvas.circle(canvas, sx, sy, 4, { 150, 132, 240 })

	-- Sample meteor shower + comet.
	for _, impact in impacts do
		local x, y = px(impact.tile.x, impact.tile.z)
		local color = rgb(Rarities.get(impact.rarity).color)
		Canvas.fillPolygon(canvas, { { x, y - 6 }, { x + 5, y }, { x, y + 6 }, { x - 5, y } }, Canvas.shade(color, 0.5))
		Canvas.fillPolygon(canvas, { { x, y - 4 }, { x + 3, y }, { x, y + 4 }, { x - 3, y } }, color)
	end
	for index, impact in comet do
		local x, y = px(impact.tile.x, impact.tile.z)
		local color = rgb(Rarities.get(impact.rarity).color)
		if index == 1 then
			Canvas.ring(canvas, x, y, 22, { 255, 84, 96 })
			Canvas.ring(canvas, x, y, 23, { 255, 84, 96 })
			Canvas.circle(canvas, x, y, 7, color)
		else
			Canvas.circle(canvas, x, y, 4, color)
		end
	end

	-- Legend.
	local lx = mapSize + 20
	Canvas.fillRect(canvas, mapSize, 0, mapSize + legendWidth - 1, mapSize - 1, { 30, 22, 70 })
	PixelFont.draw(canvas, "COMET RAIDERS", lx, 24, 4, { 255, 205, 64 })
	PixelFont.draw(canvas, `ISLAND PREVIEW - SEED {layout.seed}`, lx, 64, 2, { 206, 196, 246 })
	local y = 104
	local function legendRow(color: Canvas.Color, text: string)
		Canvas.fillRect(canvas, lx, y, lx + 22, y + 14, color)
		PixelFont.draw(canvas, text, lx + 32, y + 1, 2, { 255, 255, 255 })
		y += 24
	end
	legendRow(HUB_COLOR, Zones.HUB_NAME .. " (BASES)")
	for _, zone in Zones.list do
		legendRow(rgb(zone.topColor), `{zone.tier}. {zone.name}`)
	end
	legendRow(LAVA_COLOR, "LAVA (DAMAGE)")
	legendRow(WOOD_COLOR, "PLAYER BASE")
	legendRow(PAD_COLORS.up, "JUMP PAD TO ISLAND")
	legendRow(PAD_COLORS.down, "RETURN PAD")
	y += 10
	PixelFont.draw(canvas, "SHARD RARITIES", lx, y, 2, { 255, 205, 64 })
	y += 22
	for _, rarity in Rarities.list do
		legendRow(rgb(rarity.color), rarity.name)
	end
	y += 10
	PixelFont.draw(canvas, "RED RING = COMET CRATER", lx, y, 2, { 255, 84, 96 })
	y += 30
	for index = 1, #report do
		if y > mapSize - 20 then
			break
		end
		local text = string.sub(report[index], 1, 34)
		PixelFont.draw(canvas, text, lx, y, 1, { 206, 196, 246 })
		y += 12
	end

	fs.writeFile(`{OUTPUT_DIR}/island-top.png`, Canvas.encodePng(canvas))
end

--------------------------------------------------------------------------------------------------
-- Isometric view
--------------------------------------------------------------------------------------------------

do
	local s = 0.95
	local extent = (layout.radius + 7) * layout.tileSize
	local width = math.floor(extent * 2 * 0.866 * s * 1.02) + 60
	local height = math.floor(extent * s + 150 * s + 200)
	local canvas = Canvas.new(width, height, { 26, 27, 143 })
	-- Night-sky gradient.
	for row = 0, height - 1 do
		local t = row / height
		Canvas.fillRect(canvas, 0, row, width - 1, row, Canvas.mix({ 22, 18, 92 }, { 150, 96, 210 }, t * t))
	end
	local stars = Prng.new(5)
	for _ = 1, 700 do
		Canvas.set(canvas, stars:nextInteger(0, width - 1), stars:nextInteger(0, height // 2), { 230, 225, 255 })
	end

	local ox, oy = width / 2, height * 0.42
	local function project(x: number, y: number, z: number): { number }
		return { ox + (x - z) * 0.866 * s, oy + (x + z) * 0.5 * s - y * s }
	end

	local function box(
		x0: number,
		x1: number,
		z0: number,
		z1: number,
		yb: number,
		yt: number,
		top: Canvas.Color,
		side: Canvas.Color
	)
		Canvas.fillPolygon(canvas, {
			project(x1, yt, z0),
			project(x1, yt, z1),
			project(x1, yb, z1),
			project(x1, yb, z0),
		}, Canvas.shade(side, 0.78))
		Canvas.fillPolygon(canvas, {
			project(x0, yt, z1),
			project(x1, yt, z1),
			project(x1, yb, z1),
			project(x0, yb, z1),
		}, Canvas.shade(side, 0.6))
		Canvas.fillPolygon(canvas, {
			project(x0, yt, z0),
			project(x1, yt, z0),
			project(x1, yt, z1),
			project(x0, yt, z1),
		}, top)
	end

	type Drawable = { depth: number, draw: () -> () }
	local drawables: { Drawable } = {}
	local half = layout.tileSize / 2

	local cellSize = layout.tileSize / CELLS
	for _, plan in terrainPlans do
		local tile = plan.tile
		table.insert(drawables, {
			depth = tile.x + tile.z,
			draw = function()
				local shade = heightShade(tile)
				local band = materialColors[plan.band] or ROCK_COLOR
				-- Rock column, the band (earth / sandstone) that shows on cliffs, then the cells.
				box(
					tile.x - half,
					tile.x + half,
					tile.z - half,
					tile.z + half,
					tile.bottom,
					tile.height - 8,
					ROCK_COLOR,
					ROCK_COLOR
				)
				box(
					tile.x - half,
					tile.x + half,
					tile.z - half,
					tile.z + half,
					tile.height - 8,
					tile.height - 4,
					band,
					band
				)
				for row = 0, CELLS - 1 do
					for column = 0, CELLS - 1 do
						local material = plan.surface[row * CELLS + column + 1]
						local color = Canvas.shade(materialColors[material] or tileColor(tile), shade)
						local cx0 = tile.x - half + column * cellSize
						local cz0 = tile.z - half + row * cellSize
						box(
							cx0,
							cx0 + cellSize,
							cz0,
							cz0 + cellSize,
							tile.height - 4,
							tile.height,
							color,
							Canvas.shade(color, 0.85)
						)
					end
				end
			end,
		})
	end

	for _, item in decorPlan do
		local d = item
		table.insert(drawables, {
			depth = d.x + d.z + 0.5,
			draw = function()
				local color = rgb(d.color)
				local r = (if d.kind == "bush" then 1.3 elseif d.kind == "pebble" then 0.8 else 0.5) * d.scale
				local h = (if d.kind == "flower" then 1.9 elseif d.kind == "pebble" then 0.8 else 1.8) * d.scale
				box(d.x - r, d.x + r, d.z - r, d.z + r, d.y, d.y + h, color, Canvas.shade(color, 0.8))
			end,
		})
	end

	for _, prop in layout.props do
		local p = prop
		table.insert(drawables, {
			depth = p.x + p.z + half + 1,
			draw = function()
				local k = p.scale
				if p.kind == "tree" then
					box(p.x - 1, p.x + 1, p.z - 1, p.z + 1, p.y, p.y + 8 * k, { 116, 78, 50 }, { 116, 78, 50 })
					box(
						p.x - 4 * k,
						p.x + 4 * k,
						p.z - 4 * k,
						p.z + 4 * k,
						p.y + 7 * k,
						p.y + 13 * k,
						{ 86, 190, 86 },
						{ 60, 150, 64 }
					)
				elseif p.kind == "crystal" then
					box(p.x - k, p.x + k, p.z - k, p.z + k, p.y, p.y + 8 * k, { 220, 170, 255 }, { 170, 100, 255 })
				elseif p.kind == "rock" then
					box(
						p.x - 2.5 * k,
						p.x + 2.5 * k,
						p.z - 2 * k,
						p.z + 2 * k,
						p.y,
						p.y + 4 * k,
						{ 80, 64, 74 },
						{ 58, 44, 54 }
					)
				elseif p.kind == "pillar" then
					box(
						p.x - 1.3 * k,
						p.x + 1.3 * k,
						p.z - 1.3 * k,
						p.z + 1.3 * k,
						p.y,
						p.y + 12 * k,
						{ 225, 215, 255 },
						{ 190, 172, 255 }
					)
				elseif p.kind == "volcano" then
					box(p.x - 22, p.x + 22, p.z - 22, p.z + 22, p.y, p.y + 10, { 110, 64, 58 }, { 80, 50, 50 })
					box(p.x - 14, p.x + 14, p.z - 14, p.z + 14, p.y + 10, p.y + 22, { 120, 70, 62 }, { 86, 54, 52 })
					box(p.x - 7, p.x + 7, p.z - 7, p.z + 7, p.y + 22, p.y + 30, LAVA_COLOR, { 96, 58, 54 })
				elseif p.kind == "arch" then
					local ax, az = math.cos(p.yaw) * 7, math.sin(p.yaw) * 7
					box(
						p.x - ax - 2,
						p.x - ax + 2,
						p.z - az - 2,
						p.z - az + 2,
						p.y,
						p.y + 16,
						{ 230, 180, 120 },
						{ 200, 150, 92 }
					)
					box(
						p.x + ax - 2,
						p.x + ax + 2,
						p.z + az - 2,
						p.z + az + 2,
						p.y,
						p.y + 16,
						{ 230, 180, 120 },
						{ 200, 150, 92 }
					)
					box(
						math.min(p.x - ax, p.x + ax) - 2,
						math.max(p.x - ax, p.x + ax) + 2,
						math.min(p.z - az, p.z + az) - 2,
						math.max(p.z - az, p.z + az) + 2,
						p.y + 16,
						p.y + 19,
						{ 236, 190, 132 },
						{ 200, 150, 92 }
					)
				elseif p.kind == "floatingIsland" then
					box(
						p.x - 6 * k,
						p.x + 6 * k,
						p.z - 6 * k,
						p.z + 6 * k,
						p.y - 14 * k,
						p.y - 2 * k,
						ROCK_COLOR,
						ROCK_COLOR
					)
					box(
						p.x - 8 * k,
						p.x + 8 * k,
						p.z - 8 * k,
						p.z + 8 * k,
						p.y - 2 * k,
						p.y + 1 * k,
						{ 96, 190, 88 },
						{ 70, 150, 64 }
					)
				end
			end,
		})
	end

	for _, plot in plots do
		local pl = plot
		table.insert(drawables, {
			depth = pl.x + pl.z + 1,
			draw = function()
				local corners = {}
				for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
					local wx, wz = BaseLayout.toWorld(pl, corner[1] * pl.size / 2, corner[2] * pl.size / 2)
					table.insert(corners, project(wx, 1, wz))
				end
				Canvas.fillPolygon(canvas, corners, WOOD_COLOR)
				for _, pedestal in pl.pedestals do
					local wx, wz = BaseLayout.toWorld(pl, pedestal.x, pedestal.z)
					box(wx - 1.6, wx + 1.6, wz - 1.6, wz + 1.6, 1, 2.6, { 0, 190, 255 }, { 226, 224, 240 })
				end
			end,
		})
	end

	-- Monument.
	table.insert(drawables, {
		depth = 2,
		draw = function()
			box(-8, 8, -8, 8, 0, 3, { 120, 104, 180 }, ROCK_COLOR)
			box(-1.5, 1.5, -1.5, 1.5, 3, 15, { 240, 236, 255 }, { 200, 196, 220 })
			box(-3, 3, -3, 3, 16, 22, { 255, 220, 90 }, { 255, 180, 30 })
		end,
	})

	for _, pad in layout.jumpPads do
		local jumpPad = pad
		table.insert(drawables, {
			depth = jumpPad.position.x + jumpPad.position.z + half + 3,
			draw = function()
				local color = PAD_COLORS[jumpPad.kind]
				local p = jumpPad.position
				box(p.x - 4, p.x + 4, p.z - 4, p.z + 4, p.y, p.y + 1, color, Canvas.shade(color, 0.7))
				-- Ballistic arc (what the player will actually fly).
				local previous = project(p.x, p.y, p.z)
				for step = 1, 30 do
					local t = jumpPad.flightTime * step / 30
					local v = jumpPad.velocity
					local point =
						project(p.x + v.x * t, p.y + v.y * t - 0.5 * GameConfig.Map.Gravity * t * t, p.z + v.z * t)
					Canvas.line(canvas, previous[1], previous[2], point[1], point[2], color, 0.75)
					previous = point
				end
			end,
		})
	end

	for _, impact in impacts do
		local tile, color = impact.tile, rgb(Rarities.get(impact.rarity).color)
		table.insert(drawables, {
			depth = tile.x + tile.z + half + 2,
			draw = function()
				local base = project(tile.x, tile.height, tile.z)
				local top = project(tile.x, tile.height + 60, tile.z)
				Canvas.line(canvas, base[1], base[2], top[1], top[2], color, 0.55)
				box(
					tile.x - 1.5,
					tile.x + 1.5,
					tile.z - 1.5,
					tile.z + 1.5,
					tile.height + 1,
					tile.height + 4,
					color,
					Canvas.shade(color, 0.8)
				)
			end,
		})
	end

	table.sort(drawables, function(a, b)
		return a.depth < b.depth
	end)
	for _, drawable in drawables do
		drawable.draw()
	end

	PixelFont.draw(canvas, "COMET RAIDERS - ISOMETRIC PREVIEW", 20, 20, 3, { 255, 205, 64 })
	fs.writeFile(`{OUTPUT_DIR}/island-iso.png`, Canvas.encodePng(canvas))
end

fs.writeFile(`{OUTPUT_DIR}/report.txt`, table.concat(report, "\n") .. "\n")
print(`\nwrote {OUTPUT_DIR}/island-top.png, island-iso.png, report.txt`)
