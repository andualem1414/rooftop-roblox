--!strict
-- The valley round the tower, as a recipe: a list of terrain fills, always the same (its own seeded random
-- numbers), plus the ground's height anywhere. Every client builds the terrain from it while its loading
-- screen is up (building it locally takes a second or two; sending a server's terrain to each client takes
-- far longer), and the server places the trees and the title on the hill by the height alone.
--   the valley floor: grass, its top at y = 0
--   gentle rises in the forest (not on the pond, the track or the camera's lane up the valley)
--   mountains: a near ring with a gap toward +Z (down the valley), a higher ring behind; snow on the tops
--   a pond off to the left of the track; the track itself; nothing under the tower (the shaft's pit)
-- Pure data (numbers and material names), so the tests can check it.

local Config = require("./Config")

local Valley = {}

export type Fill = {
	op: "block" | "ball" | "cylinder" | "replace",
	x: number,
	y: number,
	z: number,
	sx: number, -- block size / cylinder height / ball radius in sx
	sy: number,
	sz: number,
	yaw: number, -- blocks: turned about Y
	mat: string, -- a terrain material's name ("Air" carves)
	from: string?, -- replace: this material...
	y0: number?, -- ...between these heights
	y1: number?,
}

Valley.POND = { x = -250, z = 230, r = 80 }
local SURFACE_SHIFT = -2.3 -- see the valley floor in fills()
Valley.SEED = 20261018

-- a small deterministic random generator (Park-Miller), the same everywhere
local function generator(seed: number): (number, number) -> number
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function(a: number, b: number): number
		s = (s * 16807) % 2147483647
		return a + (b - a) * (s / 2147483647)
	end
end

-- the camera's lane up the valley, in front of the tower (kept clear of trees and rises)
function Valley.inCameraLane(x: number, z: number): boolean
	local F = Config.FLOOR_HALF
	return z > F and math.abs(x) < 70 + (z - F) * 0.28
end

local function nearPond(x: number, z: number, pad: number): boolean
	local p = Valley.POND
	return math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2) < p.r + pad
end

local function ball(x: number, y: number, z: number, r: number, mat: string): Fill
	return { op = "ball", x = x, y = y, z = z, sx = r, sy = r, sz = r, yaw = 0, mat = mat }
end
local function block(
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	yaw: number,
	mat: string
): Fill
	return { op = "block", x = x, y = y, z = z, sx = sx, sy = sy, sz = sz, yaw = yaw, mat = mat }
end
local function cylinder(x: number, y: number, z: number, h: number, r: number, mat: string): Fill
	return { op = "cylinder", x = x, y = y, z = z, sx = h, sy = r, sz = r, yaw = 0, mat = mat }
end
local function replace(y0: number, y1: number, from: string, to: string): Fill
	return {
		op = "replace",
		x = 0,
		y = 0,
		z = 0,
		sx = 0,
		sy = 0,
		sz = 0,
		yaw = 0,
		mat = to,
		from = from,
		y0 = y0,
		y1 = y1,
	}
end

local cached: { Fill }? = nil

-- every fill, in order
function Valley.fills(): { Fill }
	if cached then
		return cached
	end
	local rr = generator(Valley.SEED)
	local F = Config.FLOOR_HALF
	local out: { Fill } = {}
	local function add(f: Fill)
		table.insert(out, f)
	end

	-- (smooth terrain draws a block's top surface 2 studs above the block itself: measured in Studio. The
	-- floor's block tops out at -2.3, so the grass lies at -0.3, just under the concrete at the tower's foot)
	add(block(0, SURFACE_SHIFT - 8, 0, 2800, 16, 2800, 0, "Grass"))
	-- bare ground (no grass blades) under the concrete at the tower's foot and its walkway, with a trodden
	-- margin: the blades would poke up through the slabs (server/common/World builds those)
	local apron = F + 18 + 3
	add(block(0, SURFACE_SHIFT - 8, 0, 2 * apron, 16, 2 * apron, 0, "Ground"))
	add(block(0, SURFACE_SHIFT - 8, F + 18 + 30, 30, 16, 62, 0, "Ground"))
	for _ = 1, 40 do
		local a, r = rr(0, math.pi * 2), rr(260, 560)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local radius = rr(60, 130)
		if not nearPond(x, z, radius + 10) and not Valley.inCameraLane(x, z) then
			add(ball(x, -radius * 0.78, z, radius, "LeafyGrass"))
		end
	end
	local function gap(a: number): number
		local d = math.atan2(math.sin(a - math.pi / 2), math.cos(a - math.pi / 2))
		return math.exp(-(d / 0.42) ^ 2)
	end
	for i = 1, 80 do
		local a = i / 80 * math.pi * 2 + rr(-0.03, 0.03)
		local radius = rr(140, 250) * (1 - 0.6 * gap(a))
		local r = rr(640, 860) + gap(a) * 120
		add(ball(math.cos(a) * r, -radius * 0.3 + rr(0, 30), math.sin(a) * r, radius, "Rock"))
	end
	for i = 1, 46 do
		local a = i / 46 * math.pi * 2 + rr(-0.05, 0.05)
		local radius = rr(260, 380) * (1 - 0.35 * gap(a))
		local r = rr(1000, 1200)
		add(ball(math.cos(a) * r, -radius * 0.2, math.sin(a) * r, radius, "Slate"))
	end
	add(replace(220, 800, "Rock", "Snow"))
	add(replace(300, 800, "Slate", "Snow"))
	add(replace(-40, 36, "Rock", "LeafyGrass"))

	-- the pond
	local p = Valley.POND
	add(cylinder(p.x, 30, p.z, 86, p.r, "Air"))
	add(cylinder(p.x, -12, p.z, 4, p.r + 2, "Mud"))
	add(cylinder(p.x, -5, p.z, 9, p.r - 2, "Water"))

	-- the track: from the walkway out along the valley, bending a little
	local walkEnd = F + 18 + 60
	local prevX, prevZ = 0, walkEnd
	for k = 1, 24 do
		local z = walkEnd + k * 40
		local x = math.sin(k * 0.35) * 18 * math.min(1, k / 4)
		local dx, dz = x - prevX, z - prevZ
		local len = math.sqrt(dx * dx + dz * dz)
		add(
			block((x + prevX) / 2, SURFACE_SHIFT - 0.8, (z + prevZ) / 2, 20, 2, len + 6, math.atan2(-dx, -dz), "Ground")
		)
		prevX, prevZ = x, z
	end

	-- nothing under the tower: the shaft's pit goes down into the ground
	add(block(0, -14, 0, 2 * F, 28, 2 * F, 0, "Air"))
	cached = out
	return out
end

-- The mountains, voxel by voxel. FillBall writes every voxel of its ball, and the mountains' balls are big,
-- overlap about four times round the rings and lie mostly under the floor: they were most of the build.
-- So the client writes the mountains' footprint in tiles instead (Terrain:WriteVoxels), each voxel as the
-- recipe's fills up to its last replace would have left it, from BOTTOM up only (below that is under the
-- floor, out of sight). The mountains' balls and the replaces are made here (Valley.voxelled), every other
-- fill by itself. How a fill writes the terrain, measured in Studio:
--   a shape's occupancy of a voxel is 0.5 + s / 4, kept between 0 and 1, s the distance from the voxel's
--   centre in to the shape's surface (negative outside)
--   a fill sets a voxel's occupancy and material where its own occupancy is above 0 and at least the
--   voxel's, and leaves it otherwise (so a run of balls of one material leaves what one fill of their
--   union, the highest of their occupancies, would)
--   a replace changes the material of the voxels whose cells lie between its heights
Valley.BOTTOM = -20
Valley.TILE = 64 -- a tile's size in x, in studs (twice that in z)
local VOXELLED: { [string]: boolean } = { Rock = true, Slate = true }

export type Tile = { x: number, y: number, z: number, nx: number, ny: number, nz: number } -- its corner, voxels

function Valley.voxelled(f: Fill): boolean
	return f.op == "replace" or (f.op == "ball" and VOXELLED[f.mat] == true)
end

-- how far a ball's centre is from a tile's columns in x and z (0 if it is over them)
local function off(f: Fill, x0: number, z0: number, x1: number, z1: number): number
	local dx = math.max(x0 - f.x, 0, f.x - x1)
	local dz = math.max(z0 - f.z, 0, f.z - z1)
	return math.sqrt(dx * dx + dz * dz)
end

local tilesCached: { Tile }? = nil

-- the tiles over the mountains' footprint, each as high as a mountain's ball over it reaches
function Valley.tiles(): { Tile }
	if tilesCached then
		return tilesCached
	end
	local balls: { Fill } = {}
	local reach = 0
	for _, f in Valley.fills() do
		if f.op == "ball" and VOXELLED[f.mat] then
			table.insert(balls, f)
			reach = math.max(reach, math.abs(f.x) + f.sx + 2, math.abs(f.z) + f.sx + 2)
		end
	end
	local W, D = Valley.TILE, 2 * Valley.TILE
	local out: { Tile } = {}
	for x = -math.ceil(reach / W) * W, reach, W do
		for z = -math.ceil(reach / D) * D, reach, D do
			local top = -math.huge
			for _, b in balls do
				local d, r = off(b, x, z, x + W, z + D), b.sx + 2
				if d < r then
					top = math.max(top, b.y + math.sqrt(r * r - d * d))
				end
			end
			if top > Valley.BOTTOM then
				local ny = math.ceil((top - Valley.BOTTOM) / 4)
				table.insert(out, { x = x, y = Valley.BOTTOM, z = z, nx = W // 4, ny = ny, nz = D // 4 })
			end
		end
	end
	tilesCached = out
	return out
end

-- A tile's voxels as Terrain:WriteVoxels takes them: materials[x][y][z] (M[name], M maps a material's name
-- to what the caller wants: Enum.Material in Roblox) and occupancies[x][y][z].
function Valley.voxels(tile: Tile, M: { [string]: any }): ({ { { any } } }, { { { number } } })
	local fills = Valley.fills()
	local x0, y0, z0, nx, ny, nz = tile.x, tile.y, tile.z, tile.nx, tile.ny, tile.nz
	local x1, y1, z1 = x0 + nx * 4, y0 + ny * 4, z0 + nz * 4

	-- the fills that reach this tile, up to the last one made here, as steps: blocks (not turned) and runs of
	-- balls of one material; then the replaces
	local last = 0
	for i, f in fills do
		if Valley.voxelled(f) then
			last = i
		end
	end
	local stepMat: { string } = {}
	local stepBlock: { Fill | false } = {}
	local stepBalls: { { Fill } } = {}
	local replaces: { Fill } = {}
	local run = ""
	for i = 1, last do
		local f = fills[i]
		if f.op == "replace" then
			table.insert(replaces, f)
			run = ""
		elseif f.op == "ball" then
			if off(f, x0, z0, x1, z1) < f.sx + 2 and f.y - f.sx - 2 < y1 and f.y + f.sx + 2 > y0 then
				if run ~= f.mat then
					table.insert(stepMat, f.mat)
					table.insert(stepBlock, false)
					table.insert(stepBalls, {})
					run = f.mat
				end
				table.insert(stepBalls[#stepBalls], f)
			elseif run ~= f.mat then
				run = "" -- (a run of balls that misses this tile at first is still one run after)
			end
		else
			run = ""
			local h = if f.op == "block" then math.sqrt(f.sx * f.sx + f.sz * f.sz) / 2 + 2 else f.sy + 2
			local hy = (if f.op == "block" then f.sy else f.sx) / 2 + 2
			local reaches = f.x - h < x1 and f.x + h > x0 and f.z - h < z1 and f.z + h > z0
			if reaches and f.y - hy < y1 and f.y + hy > y0 then
				assert(f.op == "block" and f.yaw == 0 and f.mat ~= "Air", "a fill under the mountains: " .. f.op)
				table.insert(stepMat, f.mat)
				table.insert(stepBlock, f)
				table.insert(stepBalls, {})
			end
		end
	end
	local steps = #stepMat

	-- each material, after the replaces, by row
	local final: { [string]: { any } } = {}
	local function finals(name: string)
		if final[name] then
			return
		end
		local rows = table.create(ny)
		for yi = 1, ny do
			local cell = y0 + (yi - 1) * 4
			local m = name
			for _, r in replaces do
				if m == r.from and cell >= (r.y0 :: number) and cell < (r.y1 :: number) then
					m = r.mat
				end
			end
			rows[yi] = M[m]
		end
		final[name] = rows
	end
	finals("Air")
	for _, m in stepMat do
		finals(m)
	end

	-- Rows (along z) that are all one thing share one table: all air, or all full of one material.
	local airMats, zeros = table.create(nz, M.Air), table.create(nz, 0)
	local ones = table.create(nz, 1)
	local fullRows: { [any]: { any } } = {}

	-- per column (zi) and step (s), at [(zi - 1) * steps + s]: where the step is surely full (k0..k1), where
	-- it may be (m0..m1), a block's occupancy across, and the balls over the column (at bo + 1 .. bo + bn in
	-- by, br, bd: centre heights, radii, squared distances across)
	local cells = nz * steps
	local k0, k1, m0, m1 =
		table.create(cells, 0), table.create(cells, 0), table.create(cells, 0), table.create(cells, 0)
	local fxz, bo, bn = table.create(cells, 0), table.create(cells, 0), table.create(cells, 0)
	local by: { number }, br: { number }, bd: { number } = {}, {}, {}
	local tops = table.create(nz, 0) -- nothing in the column reaches this high
	-- over the whole row of columns, per step: k0's highest and k1's lowest (surely full in every column
	-- between), k0's lowest and k1's highest, m0's lowest and m1's highest (full in some column between)
	local K0, K1, k0lo, k1hi =
		table.create(steps, 0), table.create(steps, 0), table.create(steps, 0), table.create(steps, 0)
	local M0, M1 = table.create(steps, 0), table.create(steps, 0)
	local INF = math.huge
	local first = y0 + 2

	local mats: { { { any } } } = table.create(nx)
	local occs: { { { number } } } = table.create(nx)
	for xi = 1, nx do
		local xc = x0 + xi * 4 - 2
		for s = 1, steps do
			K0[s], K1[s], k0lo[s], k1hi[s], M0[s], M1[s] = -INF, INF, INF, -INF, INF, -INF
		end
		local topAll = -INF
		local p = 0
		for zi = 1, nz do
			local zc = z0 + zi * 4 - 2
			local top = -INF
			local base = (zi - 1) * steps
			for s = 1, steps do
				local c = base + s
				local b = stepBlock[s]
				local a0, a1, b0, b1
				if b then
					local fx = math.clamp(0.5 + (b.sx / 2 - math.abs(xc - b.x)) / 4, 0, 1)
					local fz = math.clamp(0.5 + (b.sz / 2 - math.abs(zc - b.z)) / 4, 0, 1)
					local f = math.min(fx, fz)
					fxz[c] = f
					local hy = b.sy / 2
					if f >= 1 then
						a0, a1 = b.y - hy + 2, b.y + hy - 2
					else
						a0, a1 = INF, -INF
					end
					b0, b1 = a0, a1
					if f > 0 then
						top = math.max(top, b.y + hy + 2)
					end
				else
					bo[c] = p
					local solid, lo, hi = -INF, INF, -INF
					for _, f in stepBalls[s] do
						local dx, dz = xc - f.x, zc - f.z
						local d2 = dx * dx + dz * dz
						local r = f.sx
						if d2 < (r + 2) * (r + 2) then
							p += 1
							by[p], br[p], bd[p] = f.y, r, d2
							top = math.max(top, f.y + math.sqrt((r + 2) * (r + 2) - d2))
							if d2 <= (r - 2) * (r - 2) then
								local a = math.sqrt((r - 2) * (r - 2) - d2)
								lo, hi = math.min(lo, f.y - a), math.max(hi, f.y + a)
								if f.y - a <= first then
									solid = math.max(solid, f.y + a)
								end
							end
						end
					end
					bn[c] = p - bo[c]
					a0, a1, b0, b1 = -INF, solid, lo, hi
				end
				k0[c], k1[c], m0[c], m1[c] = a0, a1, b0, b1
				K0[s], K1[s] = math.max(K0[s], a0), math.min(K1[s], a1)
				k0lo[s], k1hi[s] = math.min(k0lo[s], a0), math.max(k1hi[s], a1)
				M0[s], M1[s] = math.min(M0[s], b0), math.max(M1[s], b1)
			end
			tops[zi] = top
			topAll = math.max(topAll, top)
		end

		local mx, ox = table.create(ny), table.create(ny)
		mats[xi], occs[xi] = mx, ox
		for yi = 1, ny do
			local yc = first + (yi - 1) * 4
			-- the whole row at once? the last step surely full in every column, before any that may be full
			-- in some; or nothing at all
			local whole = 0
			if yc >= topAll then
				whole = -1
			else
				for s = steps, 1, -1 do
					if yc >= K0[s] and yc <= K1[s] then
						whole = s
						break
					elseif (yc >= k0lo[s] and yc <= k1hi[s]) or (yc >= M0[s] and yc <= M1[s]) then
						break
					end
				end
			end
			if whole == -1 then
				mx[yi], ox[yi] = airMats, zeros
				continue
			elseif whole > 0 then
				local mat = final[stepMat[whole]][yi]
				local row = fullRows[mat]
				if not row then
					row = table.create(nz, mat)
					fullRows[mat] = row
				end
				mx[yi], ox[yi] = row, ones
				continue
			end

			local mrow, orow = table.create(nz), table.create(nz)
			mx[yi], ox[yi] = mrow, orow
			for zi = 1, nz do
				local o, m = 0, "Air"
				if yc < tops[zi] then
					-- the last step surely full here wins; one that may be full here means working it out
					local base = (zi - 1) * steps
					local known = 0
					for s = steps, 1, -1 do
						local c = base + s
						if yc >= k0[c] and yc <= k1[c] then
							known = s
							break
						elseif yc >= m0[c] and yc <= m1[c] then
							break
						end
					end
					if known > 0 then
						o, m = 1, stepMat[known]
					else
						for s = 1, steps do
							local c = base + s
							local v = 0
							local b = stepBlock[s]
							if b then
								v = math.min(fxz[c], 0.5 + (b.sy / 2 - math.abs(yc - b.y)) / 4)
							else
								for j = bo[c] + 1, bo[c] + bn[c] do
									local dy = yc - by[j]
									local e = 0.5 + (br[j] - math.sqrt(bd[j] + dy * dy)) / 4
									if e > v then
										v = e
									end
								end
							end
							if v > 1 then
								v = 1
							end
							if v > 0 and v >= o then
								o, m = v, stepMat[s]
							end
						end
					end
				end
				mrow[zi] = final[m][yi]
				orow[zi] = o
			end
		end
	end
	return mats, occs
end

-- the ground's height at (x, z): the valley floor, the rises and mountains on it, the pond's water
function Valley.height(x: number, z: number): number
	if nearPond(x, z, 0) then
		return -0.5
	end
	local h = 0
	for _, f in Valley.fills() do
		if f.op == "ball" then
			local d2 = (x - f.x) ^ 2 + (z - f.z) ^ 2
			local r2 = f.sx * f.sx
			if d2 < r2 then
				h = math.max(h, f.y + math.sqrt(r2 - d2))
			end
		end
	end
	return h
end

return Valley
