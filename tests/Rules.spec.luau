--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Rules", function()
	it("spreads 20 climbers over floors 1-5, four each", function()
		local count = {}
		for i = 1, 20 do
			local f = Rules.startFloor(i, 20)
			count[f] = (count[f] or 0) + 1
		end
		for f = 0, 4 do
			expect(count[f]).toBe(4)
		end
	end)
	it("comes to 2-5 floors lower, never below the ground floor", function()
		expect(Rules.comeToFloor(10, function(a, _b)
			return a
		end)).toBe(8)
		expect(Rules.comeToFloor(10, function(_a, b)
			return b
		end)).toBe(5)
		expect(Rules.comeToFloor(1, function(_a, b)
			return b
		end)).toBe(0)
		-- knocked out on the roof: counts from the top floor
		expect(Rules.comeToFloor(Config.FLOORS, function(a, _b)
			return a
		end)).toBe(Config.FLOORS - 3)
	end)
	it("platform loot is a gun, a sword or ammo, evenly", function()
		expect(Rules.platformLoot(function()
			return 0.1
		end)).toBe("gun")
		expect(Rules.platformLoot(function()
			return 0.5
		end)).toBe("sword")
		expect(Rules.platformLoot(function()
			return 0.9
		end)).toBe("ammo")
	end)
	it("only one can escape", function()
		expect(Rules.escape(1)).toBe("escape")
		expect(Rules.escape(2)).toBe("throw")
		expect(Rules.escape(0)).toBe("empty")
	end)
	it("phases: ready, climb, roof (from 4:00), over (winner or 8:00)", function()
		expect(Rules.phase(-1, false)).toBe("ready")
		expect(Rules.phase(10, false)).toBe("climb")
		expect(Rules.phase(Config.ROOF_OPENS_AFTER, false)).toBe("roof")
		expect(Rules.phase(Config.RACE_LIMIT, false)).toBe("over")
		expect(Rules.phase(100, true)).toBe("over")
	end)
	it("bots fill the race to 20", function()
		expect(Rules.botsFor(1)).toBe(19)
		expect(Rules.botsFor(20)).toBe(0)
		expect(Rules.botsFor(25)).toBe(0)
	end)
	it("formats the clock", function()
		expect(Rules.clock(240)).toBe("4:00")
		expect(Rules.clock(61.2)).toBe("1:02")
		expect(Rules.clock(-3)).toBe("0:00")
	end)
end)
