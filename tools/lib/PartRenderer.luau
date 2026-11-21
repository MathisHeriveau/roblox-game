--[[
	PartRenderer — tiny CPU ray tracer for Roblox part assemblies (Ball / Block / Cylinder), so
	tooling can SEE models built by game code (Starlings, shards...) without Studio.

	Lighting: ambient + key light (Lambert) + Blinn-Phong highlight; Neon parts are emissive.
	Transparent parts (Transparency >= 0.5) are blended over what is behind them; parts with
	Transparency >= 0.95 are skipped. Other part types are approximated by their bounding box.
]]

local Canvas = require("./Canvas")

export type Prim = {
	kind: string,
	-- Rotation matrix rows (world = R * local + p).
	r: { number },
	px: number,
	py: number,
	pz: number,
	hx: number,
	hy: number,
	hz: number,
	radius: number,
	bound: number,
	color: Canvas.Color,
	emissive: boolean,
	alpha: number,
}

export type Camera = {
	eye: { number },
	target: { number },
	fov: number,
}

local PartRenderer = {}

local EPSILON = 1e-4

function PartRenderer.collect(root: any, exclude: ((any) -> boolean)?): { Prim }
	local prims: { Prim } = {}
	local parts = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(parts, root)
	end
	for _, part in parts do
		if part:IsA("BasePart") and part.Transparency < 0.95 and not (exclude and exclude(part)) then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
			local size = part.Size
			local kind = "Block"
			if part:IsA("Part") then
				kind = part.Shape.Name
			end
			local c = part.Color
			table.insert(prims, {
				kind = kind,
				r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				px = x,
				py = y,
				pz = z,
				hx = size.X / 2,
				hy = size.Y / 2,
				hz = size.Z / 2,
				radius = if kind == "Ball"
					then math.min(size.X, size.Y, size.Z) / 2
					elseif kind == "Cylinder" then math.min(size.Y, size.Z) / 2
					else 0,
				bound = math.sqrt(size.X ^ 2 + size.Y ^ 2 + size.Z ^ 2) / 2,
				color = { c.R * 255, c.G * 255, c.B * 255 },
				emissive = part.Material.Name == "Neon",
				alpha = 1 - part.Transparency,
			})
		end
	end
	return prims
end

-- Returns t, local normal (nx, ny, nz) or nil.
local function intersect(prim: Prim, ox: number, oy: number, oz: number, dx: number, dy: number, dz: number)
	local kind = prim.kind
	if kind == "Ball" then
		local radius = prim.radius
		local b = ox * dx + oy * dy + oz * dz
		local c = ox * ox + oy * oy + oz * oz - radius * radius
		local disc = b * b - c
		if disc < 0 then
			return nil
		end
		local root = math.sqrt(disc)
		local t = -b - root
		if t < EPSILON then
			t = -b + root
			if t < EPSILON then
				return nil
			end
		end
		return t, (ox + t * dx) / radius, (oy + t * dy) / radius, (oz + t * dz) / radius
	elseif kind == "Cylinder" then
		local radius, h = prim.radius, prim.hx
		local best, nx, ny, nz = math.huge, 0, 0, 0
		local a = dy * dy + dz * dz
		if a > 1e-12 then
			local b = oy * dy + oz * dz
			local c = oy * oy + oz * oz - radius * radius
			local disc = b * b - a * c
			if disc >= 0 then
				local root = math.sqrt(disc)
				for _, t in { (-b - root) / a, (-b + root) / a } do
					if t > EPSILON and t < best and math.abs(ox + t * dx) <= h then
						best, nx, ny, nz = t, 0, (oy + t * dy) / radius, (oz + t * dz) / radius
						break
					end
				end
			end
		end
		if math.abs(dx) > 1e-12 then
			for _, side in { -1, 1 } do
				local t = (side * h - ox) / dx
				if t > EPSILON and t < best then
					local y, z = oy + t * dy, oz + t * dz
					if y * y + z * z <= radius * radius then
						best, nx, ny, nz = t, side, 0, 0
					end
				end
			end
		end
		if best == math.huge then
			return nil
		end
		return best, nx, ny, nz
	end
	-- Block (slab method).
	local tmin, tmax = -math.huge, math.huge
	local axis, sign = 0, 0
	local o = { ox, oy, oz }
	local d = { dx, dy, dz }
	local halves = { prim.hx, prim.hy, prim.hz }
	for i = 1, 3 do
		if math.abs(d[i]) < 1e-12 then
			if math.abs(o[i]) > halves[i] then
				return nil
			end
		else
			local t1 = (-halves[i] - o[i]) / d[i]
			local t2 = (halves[i] - o[i]) / d[i]
			local near, far = math.min(t1, t2), math.max(t1, t2)
			if near > tmin then
				tmin, axis, sign = near, i, if d[i] > 0 then -1 else 1
			end
			tmax = math.min(tmax, far)
			if tmin > tmax then
				return nil
			end
		end
	end
	local t = tmin
	if t < EPSILON then
		return nil -- camera inside the block: ignore
	end
	local normal = { 0, 0, 0 }
	normal[axis] = sign
	return t, normal[1], normal[2], normal[3]
end

local LIGHT = { -0.45, 0.75, -0.5 }
do
	local length = math.sqrt(LIGHT[1] ^ 2 + LIGHT[2] ^ 2 + LIGHT[3] ^ 2)
	LIGHT = { LIGHT[1] / length, LIGHT[2] / length, LIGHT[3] / length }
end

local function shade(prim: Prim, nx: number, ny: number, nz: number, vx: number, vy: number, vz: number): Canvas.Color
	local color = prim.color
	local facing = math.max(0, nx * vx + ny * vy + nz * vz)
	if prim.emissive then
		local glow = 1.05 + 0.25 * (1 - facing)
		return {
			math.min(255, color[1] * glow + 30),
			math.min(255, color[2] * glow + 30),
			math.min(255, color[3] * glow + 30),
		}
	end
	local lambert = math.max(0, nx * LIGHT[1] + ny * LIGHT[2] + nz * LIGHT[3])
	local hx, hy, hz = LIGHT[1] + vx, LIGHT[2] + vy, LIGHT[3] + vz
	local hl = math.sqrt(hx * hx + hy * hy + hz * hz)
	local specular = math.max(0, (nx * hx + ny * hy + nz * hz) / hl) ^ 28
	local rim = (1 - facing) ^ 3 * 0.35
	local k = 0.38 + 0.72 * lambert + rim
	return {
		math.min(255, color[1] * k + 255 * specular * 0.55),
		math.min(255, color[2] * k + 255 * specular * 0.55),
		math.min(255, color[3] * k + 255 * specular * 0.55),
	}
end

-- Renders `prims` seen from `camera` into the rectangle (x0, y0, width, height) of `canvas`.
function PartRenderer.render(
	canvas: Canvas.Canvas,
	prims: { Prim },
	camera: Camera,
	x0: number,
	y0: number,
	width: number,
	height: number
)
	local ex, ey, ez = camera.eye[1], camera.eye[2], camera.eye[3]
	local fx, fy, fz = camera.target[1] - ex, camera.target[2] - ey, camera.target[3] - ez
	local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
	fx, fy, fz = fx / fl, fy / fl, fz / fl
	-- right = forward x up(0,1,0); up = right x forward
	local rx, ry, rz = -fz, 0, fx
	local rl = math.sqrt(rx * rx + rz * rz)
	rx, rz = rx / rl, rz / rl
	local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
	local tanHalf = math.tan(math.rad(camera.fov) / 2)
	local aspect = width / height

	for py = 0, height - 1 do
		for px = 0, width - 1 do
			local sx = (2 * (px + 0.5) / width - 1) * tanHalf * aspect
			local sy = (1 - 2 * (py + 0.5) / height) * tanHalf
			local dx, dy, dz = fx + rx * sx + ux * sy, fy + ry * sx + uy * sy, fz + rz * sx + uz * sy
			local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
			dx, dy, dz = dx / dl, dy / dl, dz / dl

			local nearestOpaque, opaqueColor = math.huge, nil
			local glassT, glassColor, glassAlpha = math.huge, nil, 0
			for _, prim in prims do
				-- Bounding-sphere rejection.
				local cx, cy, cz = prim.px - ex, prim.py - ey, prim.pz - ez
				local tca = cx * dx + cy * dy + cz * dz
				local d2 = cx * cx + cy * cy + cz * cz - tca * tca
				if d2 <= prim.bound * prim.bound and tca + prim.bound > 0 then
					local r = prim.r
					-- Ray into local space: local = R^T (world - p).
					local wx, wy, wz = ex - prim.px, ey - prim.py, ez - prim.pz
					local lox = r[1] * wx + r[4] * wy + r[7] * wz
					local loy = r[2] * wx + r[5] * wy + r[8] * wz
					local loz = r[3] * wx + r[6] * wy + r[9] * wz
					local ldx = r[1] * dx + r[4] * dy + r[7] * dz
					local ldy = r[2] * dx + r[5] * dy + r[8] * dz
					local ldz = r[3] * dx + r[6] * dy + r[9] * dz
					local t, nx, ny, nz = intersect(prim, lox, loy, loz, ldx, ldy, ldz)
					if t then
						local opaque = prim.alpha >= 0.5
						if (opaque and t < nearestOpaque) or (not opaque and t < glassT) then
							-- Normal back to world: n = R * nl.
							local wnx = r[1] * nx + r[2] * ny + r[3] * nz
							local wny = r[4] * nx + r[5] * ny + r[6] * nz
							local wnz = r[7] * nx + r[8] * ny + r[9] * nz
							local color = shade(prim, wnx, wny, wnz, -dx, -dy, -dz)
							if opaque then
								nearestOpaque, opaqueColor = t, color
							else
								glassT, glassColor, glassAlpha = t, color, prim.alpha
							end
						end
					end
				end
			end
			if opaqueColor then
				Canvas.set(canvas, x0 + px, y0 + py, opaqueColor)
			end
			if glassColor and glassT < nearestOpaque then
				Canvas.blend(canvas, x0 + px, y0 + py, glassColor, math.max(glassAlpha, 0.35))
			end
		end
	end
end

return PartRenderer
