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

	add(block(0, -8, 0, 2800, 16, 2800, 0, "Grass"))
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
		add(block((x + prevX) / 2, -0.8, (z + prevZ) / 2, 20, 2, len + 6, math.atan2(-dx, -dz), "Ground"))
		prevX, prevZ = x, z
	end

	-- nothing under the tower: the shaft's pit goes down into the ground
	add(block(0, -14, 0, 2 * F, 28, 2 * F, 0, "Air"))
	cached = out
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
