--!strict
--[[
	BaseLayout — pure geometry of the player bases (plots) around the hub.

	Plots sit on a ring around the island centre, each facing the centre: the entrance (local -Z)
	points at the plaza. Local frame: X = left/right, Z = back (+) / front (-), origin = plot centre.
	Pedestals fill a grid in the back two thirds; the collect pad sits near the entrance.
]]

export type Point = { x: number, z: number }

export type Plot = {
	index: number,
	x: number,
	z: number,
	-- Rotation around Y (radians) that maps local axes to world axes.
	yaw: number,
	size: number,
	pedestals: { Point },
	collectPad: Point,
	spawn: Point,
	sign: Point,
}

export type Config = {
	PlotCount: number,
	PlotRingRadius: number,
	PlotSize: number,
	PedestalColumns: number,
	PedestalRows: number,
}

local BaseLayout = {}

-- Local (lx, lz) -> world (x, z) for a plot. Matches CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0).
function BaseLayout.toWorld(plot: Plot, lx: number, lz: number): (number, number)
	local c, s = math.cos(plot.yaw), math.sin(plot.yaw)
	return plot.x + lx * c + lz * s, plot.z - lx * s + lz * c
end

-- World (x, z) -> local (lx, lz) for a plot (inverse of toWorld).
function BaseLayout.toLocal(plot: Plot, x: number, z: number): (number, number)
	local dx, dz = x - plot.x, z - plot.z
	local c, s = math.cos(plot.yaw), math.sin(plot.yaw)
	return dx * c - dz * s, dx * s + dz * c
end

function BaseLayout.isInside(plot: Plot, x: number, z: number, margin: number?): boolean
	local lx, lz = BaseLayout.toLocal(plot, x, z)
	local half = plot.size / 2 + (margin or 0)
	return math.abs(lx) <= half and math.abs(lz) <= half
end

function BaseLayout.isOnCollectPad(plot: Plot, x: number, z: number, radius: number): boolean
	local px, pz = BaseLayout.toWorld(plot, plot.collectPad.x, plot.collectPad.z)
	local dx, dz = x - px, z - pz
	return dx * dx + dz * dz <= radius * radius
end

function BaseLayout.generate(config: Config): { Plot }
	assert(config.PlotCount >= 1, "BaseLayout: PlotCount must be >= 1")
	local plots: { Plot } = {}
	local size = config.PlotSize
	local half = size / 2

	-- Pedestal grid in local space: columns spread on X, rows towards the back (+Z).
	local pedestals: { Point } = {}
	local columnSpacing = (size - 8) / math.max(1, config.PedestalColumns - 1)
	local rowStart, rowEnd = -half * 0.15, half - 3.5
	local rowSpacing = (rowEnd - rowStart) / math.max(1, config.PedestalRows - 1)
	for row = 0, config.PedestalRows - 1 do
		for column = 0, config.PedestalColumns - 1 do
			table.insert(pedestals, {
				x = -half + 4 + column * columnSpacing,
				z = rowStart + row * rowSpacing,
			})
		end
	end

	for index = 1, config.PlotCount do
		local theta = (index - 1) / config.PlotCount * math.pi * 2
		local x = math.cos(theta) * config.PlotRingRadius
		local z = math.sin(theta) * config.PlotRingRadius
		table.insert(plots, {
			index = index,
			x = x,
			z = z,
			-- Local -Z faces the centre (see header).
			yaw = math.atan2(math.cos(theta), math.sin(theta)),
			size = size,
			pedestals = pedestals,
			collectPad = { x = 0, z = -half + 4 },
			spawn = { x = 0, z = -half * 0.45 },
			sign = { x = 0, z = half - 1 },
		})
	end
	return plots
end

return table.freeze(BaseLayout)
