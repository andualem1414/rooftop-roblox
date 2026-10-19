--!strict
local Test = require("./lib/Test")
local Valley = require("../src/shared/Valley")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Valley", function()
	it("is the same every time", function()
		local a, b = Valley.fills(), Valley.fills()
		expect(#a).toBe(#b)
		expect(#a > 100).toBeTruthy()
	end)
	it("is flat ground by the tower and in the camera's lane", function()
		expect(Valley.height(0, 0)).toBe(0)
		expect(Valley.height(60, 0)).toBe(0)
		expect(Valley.height(0, 300)).toBe(0)
	end)
	it("rises into mountains far out", function()
		local high = 0
		for a = 0, 359, 5 do
			local x, z = math.cos(math.rad(a)) * 760, math.sin(math.rad(a)) * 760
			high = math.max(high, Valley.height(x, z))
		end
		expect(high > 150).toBeTruthy()
	end)
	it("has water in the pond", function()
		expect(Valley.height(Valley.POND.x, Valley.POND.z)).toBe(-0.5)
	end)

	describe("mountain voxels", function()
		local fills = Valley.fills()
		local tiles = Valley.tiles()
		local first, last = 0, 0
		for i, f in fills do
			if Valley.voxelled(f) then
				first = if first == 0 then i else first
				last = i
			end
		end

		-- how the fills up to the last voxelled one leave the voxel centred at (x, y, z), each fill as
		-- Terrain does it (measured in Studio: see Valley.voxels), one by one
		local function filled(x: number, y: number, z: number): (number, string)
			local o, m = 0, "Air"
			for i = 1, last do
				local f = fills[i]
				local v = 0
				if f.op == "ball" then
					local d = math.sqrt((x - f.x) ^ 2 + (y - f.y) ^ 2 + (z - f.z) ^ 2)
					v = 0.5 + (f.sx - d) / 4
				elseif f.op == "block" then
					local c, s = math.cos(f.yaw), math.sin(f.yaw)
					local dx, dz = x - f.x, z - f.z
					local across, along = dx * c - dz * s, dx * s + dz * c
					v = math.min(
						0.5 + (f.sx / 2 - math.abs(across)) / 4,
						0.5 + (f.sy / 2 - math.abs(y - f.y)) / 4,
						0.5 + (f.sz / 2 - math.abs(along)) / 4
					)
				elseif f.op == "replace" and m == f.from and y - 2 >= (f.y0 :: number) and y - 2 < (f.y1 :: number) then
					m = f.mat
				end
				v = math.min(v, 1)
				if v > 0 and v >= o then
					o, m = v, f.mat
				end
			end
			return o, m
		end

		it("stand in for one stretch of fills: the mountains' balls and the replaces", function()
			expect(first > 0).toBeTruthy()
			local balls = 0
			for i = first, last do
				local f = fills[i]
				expect(Valley.voxelled(f)).toBeTruthy()
				balls += if f.op == "ball" then 1 else 0
			end
			expect(balls).toBe(126)
		end)

		it("lie in tiles on the grid, apart, as tall as the mountains", function()
			local seen: { [string]: boolean } = {}
			local high = 0
			for _, t in tiles do
				expect(t.x % (t.nx * 4)).toBe(0)
				expect(t.z % (t.nz * 4)).toBe(0)
				expect(t.y).toBe(Valley.BOTTOM)
				local key = `{t.x},{t.z}`
				expect(seen[key]).toBe(nil)
				seen[key] = true
				expect(t.nx * t.ny * t.nz < 4194304).toBeTruthy()
				high = math.max(high, t.y + t.ny * 4)
			end
			expect(high > 300).toBeTruthy() -- (the snow on the far peaks)
		end)

		it("cover every mountain ball above the bottom", function()
			for i = first, last do
				local f = fills[i]
				if f.op ~= "ball" then
					continue
				end
				for _, d in { { 0, 1, 0 }, { 1, 0, 0 }, { -1, 0.1, 0 }, { 0, 0.3, 1 }, { 0.6, 0.6, -0.5 } } do
					local x, y, z = f.x + d[1] * f.sx, f.y + d[2] * f.sx, f.z + d[3] * f.sx
					if y > Valley.BOTTOM then
						local covered = false
						for _, t in tiles do
							if x >= t.x and x <= t.x + t.nx * 4 and z >= t.z and z <= t.z + t.nz * 4 then
								covered = y <= t.y + t.ny * 4
								break
							end
						end
						expect(covered).toBeTruthy()
					end
				end
			end
		end)

		it("are what the fills would have left there", function()
			local M = setmetatable({}, {
				__index = function(_, k)
					return k
				end,
			}) :: any
			-- a spread of tiles, and the tallest (snow)
			local picked: { Valley.Tile } = {}
			local tallest = tiles[1]
			for i, t in tiles do
				if i % 151 == 1 then
					table.insert(picked, t)
				end
				if t.ny > tallest.ny then
					tallest = t
				end
			end
			table.insert(picked, tallest)
			for _, t in picked do
				local mats, occs = Valley.voxels(t, M)
				for xi = 1, t.nx do
					for yi = 1, t.ny do
						for zi = 1, t.nz do
							local o, m = filled(t.x + xi * 4 - 2, t.y + yi * 4 - 2, t.z + zi * 4 - 2)
							expect(occs[xi][yi][zi]).toBeNear(o)
							expect(mats[xi][yi][zi]).toBe(if o > 0 then m else "Air")
						end
					end
				end
			end
		end)
	end)
end)
