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

	describe("replace sweeps", function()
		local fills = Valley.fills()
		local function replaces(): { number }
			local out = {}
			for i, f in fills do
				if f.op == "replace" then
					table.insert(out, i)
				end
			end
			return out
		end
		local function inside(b: Valley.Box, x: number, y: number, z: number): boolean
			return x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 and z >= b.z0 and z <= b.z1
		end

		it("stay on the grid, inside one tile and the replace's heights", function()
			for _, i in replaces() do
				local f = fills[i]
				for _, b in Valley.regions(fills, i) do
					for _, v in { b.x0, b.x1, b.y0, b.y1, b.z0, b.z1 } do
						expect(v % 4).toBe(0)
					end
					expect(b.x0 < b.x1 and b.y0 < b.y1 and b.z0 < b.z1).toBeTruthy()
					expect(b.x1 - b.x0 <= Valley.TILE and b.z1 - b.z0 <= Valley.TILE).toBeTruthy()
					expect(b.y1 - b.y0 <= Valley.SLICE).toBeTruthy()
					expect(math.floor(b.x0 / Valley.TILE) == math.ceil(b.x1 / Valley.TILE) - 1).toBeTruthy()
					expect(b.y0 >= (f.y0 :: number) and b.y1 <= (f.y1 :: number)).toBeTruthy()
					expect(b.x0 >= -Valley.EXTENT and b.x1 <= Valley.EXTENT).toBeTruthy()
				end
			end
		end)

		it("cover every ball of the replaced material within the heights", function()
			for _, i in replaces() do
				local f = fills[i]
				local boxes = Valley.regions(fills, i)
				for k = 1, i - 1 do
					local g = fills[k]
					if g.op ~= "ball" or g.mat ~= f.from then
						continue
					end
					-- points through the ball, at the replace's heights
					for _, dx in { -1, -0.5, 0, 0.5, 1 } do
						for _, dy in { -1, -0.5, 0, 0.5, 1 } do
							for _, dz in { -1, -0.5, 0, 0.5, 1 } do
								local x, y, z = g.x + dx * g.sx, g.y + dy * g.sx, g.z + dz * g.sx
								local inBall = (dx * dx + dy * dy + dz * dz) <= 1
								local inSweep = y >= (f.y0 :: number) and y < (f.y1 :: number)
								local inTiles = math.abs(x) < Valley.EXTENT and math.abs(z) < Valley.EXTENT
								if inBall and inSweep and inTiles then
									local covered = false
									for _, b in boxes do
										if inside(b, x, y, z) then
											covered = true
											break
										end
									end
									expect(covered).toBeTruthy()
								end
							end
						end
					end
				end
			end
		end)

		it("skip a replace above every fill of its material (no rock reaches the snow line)", function()
			local skipped = false
			for _, i in replaces() do
				local f = fills[i]
				if f.from == "Rock" and f.mat == "Snow" then
					skipped = #Valley.regions(fills, i) == 0
				end
			end
			expect(skipped).toBeTruthy()
		end)
	end)
end)
