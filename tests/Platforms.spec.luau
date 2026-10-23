--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Platforms = require("../src/shared/Platforms")

local describe, it, expect = Test.describe, Test.it, Test.expect
local CYCLE, MOVE, FLOORS = Config.PLATFORM_CYCLE, Config.PLATFORM_MOVE, Config.FLOORS

describe("Platforms.state", function()
	it("rises from below the ground floor to floor 0 in MOVE seconds", function()
		local s = Platforms.state(0, false)
		expect(s.active).toBe(true)
		expect(s.level).toBeNear(-1)
		expect(s.stop).toBe(nil)
		local mid = Platforms.state(MOVE / 2, false)
		expect(mid.level).toBeNear(-0.5)
	end)
	it("stops at each floor for STOP seconds", function()
		local s = Platforms.state(3 * CYCLE + MOVE + 1, false)
		expect(s.stop).toBe(3)
		expect(s.level).toBeNear(3)
		expect(s.leaving).toBeNear(Config.PLATFORM_STOP - 1)
	end)
	it("ends at the top floor while the roof is shut", function()
		expect(Platforms.state((FLOORS - 1) * CYCLE + MOVE + 0.1, false).stop).toBe(FLOORS - 1)
		expect(Platforms.state(FLOORS * CYCLE + 0.1, false).active).toBe(false)
	end)
	it("goes on to the roof once it's open", function()
		local s = Platforms.state(FLOORS * CYCLE + MOVE + 0.1, true)
		expect(s.stop).toBe(FLOORS)
		expect(Platforms.state((FLOORS + 1) * CYCLE + 0.1, true).active).toBe(false)
	end)
	it("isn't there before its launch", function()
		expect(Platforms.state(-1, false).active).toBe(false)
	end)
end)

describe("Platforms.nextArrival", function()
	it("is the first stop on the ground floor at the start", function()
		expect(Platforms.nextArrival(0, 0, false)).toBeNear(MOVE)
	end)
	it("is 0 while one is stopped there", function()
		expect(Platforms.nextArrival(5 * CYCLE + MOVE + 1, 5, false)).toBeNear(0)
	end)
	it("starts empty: the first platform has to climb to you", function()
		-- floor 10 (on screen 11) at the start: the first platform reaches it after its climb, not sooner
		expect(Platforms.nextArrival(0, 10, false)).toBeNear(10 * CYCLE + MOVE)
		-- and the next one is an interval behind it
		expect(Platforms.nextArrival(10 * CYCLE + MOVE + Config.PLATFORM_STOP + 0.01, 10, false)).toBeNear(
			Config.PLATFORM_INTERVAL - Config.PLATFORM_STOP - 0.01
		)
	end)
	it("has no platforms launched before the race", function()
		local first, last = Platforms.launchRange(0)
		expect(first).toBe(0)
		expect(last).toBe(0)
		local _, before = Platforms.launchRange(-1)
		expect(before < 0).toBe(true)
	end)
	it("is at most one interval away once the first platform has passed", function()
		for t = 0, 200, 7 do
			for floor = 0, FLOORS - 1 do
				if t > floor * CYCLE + MOVE then
					local a = Platforms.nextArrival(t, floor, false)
					expect(a >= 0 and a <= Config.PLATFORM_INTERVAL).toBeTruthy()
				end
			end
		end
	end)
	it("never comes to the roof while it's shut", function()
		expect(Platforms.nextArrival(10, FLOORS, false)).toBe(math.huge)
	end)
	it("agrees with the platforms' own states", function()
		local t, floor = 100, 7
		local wait = Platforms.nextArrival(t, floor, false)
		local first, last = Platforms.launchRange(t + wait)
		local found = false
		for k = first, last do
			if Platforms.state(Platforms.age(k, t + wait + 0.01), false).stop == floor then
				found = true
			end
		end
		expect(found).toBe(true)
	end)
end)

describe("Platforms.shaftOpen", function()
	it("opens a floor while a platform is stopped there", function()
		local t = 4 * CYCLE + MOVE + 1 -- platform 0 stopped at floor 4
		expect(Platforms.shaftOpen(4, t, false)).toBe(true)
	end)
	it("is shut where no platform is near", function()
		-- platform 0 at floor 4, the first one: nothing above it yet
		local t = 4 * CYCLE + MOVE + 1
		expect(Platforms.shaftOpen(12, t, false)).toBe(false)
		expect(Platforms.shaftOpen(6, t, false)).toBe(false)
	end)
end)
