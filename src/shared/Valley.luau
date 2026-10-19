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

-- Where a replace fill can change anything: the boxes it has to sweep, each within one of the tiles the
-- terrain is swept in (a region can only be so big) and a multiple of 4 studs. The material it replaces
-- can only be inside the fills that made it (padded for the terrain's soft edges), so the rest of the
-- valley is skipped: the result is the same, only quicker (a sweep of the whole valley took seconds).
-- A replace above every fill of its material sweeps nothing.
export type Box = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number }
Valley.TILE = 400 -- a sweep's tile, across
Valley.SLICE = 200 -- ...and up
Valley.EXTENT = 1600 -- the tiles cover -EXTENT .. EXTENT in x and z
local PAD = 8

local function grid(v: number, up: boolean): number
	return if up then math.ceil(v / 4) * 4 else math.floor(v / 4) * 4
end

function Valley.regions(fills: { Fill }, index: number): { Box }
	-- what each material could cover, fill by fill, up to this one
	local made: { [string]: { Box } } = {}
	local function add(mat: string, b: Box)
		local list = made[mat]
		if not list then
			list = {}
			made[mat] = list
		end
		table.insert(list, b)
	end
	for i = 1, index - 1 do
		local f = fills[i]
		local hx, hy, hz
		if f.op == "ball" then
			hx, hy, hz = f.sx, f.sx, f.sx
		elseif f.op == "block" then
			local r = math.sqrt(f.sx * f.sx + f.sz * f.sz) / 2 -- (turned about Y)
			hx, hy, hz = r, f.sy / 2, r
		elseif f.op == "cylinder" then
			hx, hy, hz = f.sy, f.sx / 2, f.sz
		end
		if hx and f.mat ~= "Air" then
			add(f.mat, {
				x0 = f.x - hx - PAD,
				x1 = f.x + hx + PAD,
				y0 = f.y - hy - PAD,
				y1 = f.y + hy + PAD,
				z0 = f.z - hz - PAD,
				z1 = f.z + hz + PAD,
			})
		elseif f.op == "replace" and f.from and f.y0 and f.y1 then
			for _, b in made[f.from] or {} do
				if b.y1 > f.y0 and b.y0 < f.y1 then
					add(f.mat, {
						x0 = b.x0,
						x1 = b.x1,
						y0 = math.max(b.y0, f.y0),
						y1 = math.min(b.y1, f.y1),
						z0 = b.z0,
						z1 = b.z1,
					})
				end
			end
		end
	end

	local f = fills[index]
	local out: { Box } = {}
	if f.op ~= "replace" or not f.from or not f.y0 or not f.y1 then
		return out
	end
	local sources = made[f.from] or {}
	local T, S, E = Valley.TILE, Valley.SLICE, Valley.EXTENT
	for x = -E, E - T, T do
		for z = -E, E - T, T do
			for y = f.y0, f.y1 - 1, S do
				local tile = { x0 = x, x1 = x + T, y0 = y, y1 = math.min(y + S, f.y1), z0 = z, z1 = z + T }
				-- the part of this tile any source reaches
				local box: Box? = nil
				for _, b in sources do
					local x0, x1 = math.max(tile.x0, b.x0), math.min(tile.x1, b.x1)
					local y0, y1 = math.max(tile.y0, b.y0), math.min(tile.y1, b.y1)
					local z0, z1 = math.max(tile.z0, b.z0), math.min(tile.z1, b.z1)
					if x0 < x1 and y0 < y1 and z0 < z1 then
						if box then
							box.x0, box.x1 = math.min(box.x0, x0), math.max(box.x1, x1)
							box.y0, box.y1 = math.min(box.y0, y0), math.max(box.y1, y1)
							box.z0, box.z1 = math.min(box.z0, z0), math.max(box.z1, z1)
						else
							box = { x0 = x0, x1 = x1, y0 = y0, y1 = y1, z0 = z0, z1 = z1 }
						end
					end
				end
				if box then
					-- on the 4-stud grid, and still inside the tile (whose corners are on it)
					box.x0, box.x1 = math.max(tile.x0, grid(box.x0, false)), math.min(tile.x1, grid(box.x1, true))
					box.y0, box.y1 = math.max(tile.y0, grid(box.y0, false)), math.min(tile.y1, grid(box.y1, true))
					box.z0, box.z1 = math.max(tile.z0, grid(box.z0, false)), math.min(tile.z1, grid(box.z1, true))
					table.insert(out, box)
				end
			end
		end
	end
	return out
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
