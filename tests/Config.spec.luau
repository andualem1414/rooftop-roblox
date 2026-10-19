--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Config", function()
	it("matches the original's platform cadence", function()
		expect(Config.PLATFORM_CYCLE).toBeNear(3.6)
		expect(Config.PLATFORM_TRIP).toBeNear(72)
	end)
	it("has platforms half again as big as the original's, fitting their shaft", function()
		expect(Config.PLATFORM_HALF * 2 / Config.M).toBeNear(3.5 * 1.5)
		expect(Config.PLATFORM_HALF < Config.SHAFT_HALF).toBeTruthy()
		expect(Config.SHAFT_CLEAR > Config.SHAFT_HALF).toBeTruthy()
		-- the walkway round the shaft and the room beyond it still fit on a floor
		expect(Config.SHAFT_CLEAR < Config.FLOOR_HALF / 2).toBeTruthy()
	end)
	it("opens the roof before the race limit", function()
		expect(Config.ROOF_OPENS_AFTER < Config.RACE_LIMIT).toBeTruthy()
	end)
	it("is read-only", function()
		expect(pcall(function()
			(Config :: any).FLOORS = 3
		end)).toBe(false)
	end)
end)
