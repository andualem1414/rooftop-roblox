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
end)
