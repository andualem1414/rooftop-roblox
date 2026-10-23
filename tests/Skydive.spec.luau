--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Skydive = require("../src/shared/Skydive")

local describe, it, expect = Test.describe, Test.it, Test.expect

local TOWER_H = Config.FLOORS * Config.FLOOR_HEIGHT

-- fly a whole flight with a steering rule; returns the flyer and how long it took
local function fly(seed: number, rule: (Skydive.Flyer) -> (number, number))
	local x, y, z = Skydive.padAt()
	local f = Skydive.launch(x, y, z, 0, seed)
	local t = 0
	while f.phase ~= "done" and t < 60 do
		local steer, pitch = rule(f)
		Skydive.step(f, 1 / 60, steer, pitch)
		t += 1 / 60
	end
	return f, t
end

-- steer for the next ring like a player would
local function chase(f: Skydive.Flyer): (number, number)
	local r = f.rings[f.next]
	if not r then
		return 0, 0
	end
	local want = math.atan2(r.x - f.x, r.z - f.z)
	local d = math.atan2(math.sin(want - f.yaw), math.cos(want - f.yaw))
	local steer = math.clamp(-d * 3, -1, 1)
	local pitch = math.clamp((f.y - r.y) / (8 * Config.M), -1, 1)
	return steer, pitch
end

describe("Skydive", function()
	it("puts the pad on the roof, in front of the sign", function()
		local x, y, z = Skydive.padAt()
		expect(y).toBe(TOWER_H)
		expect(z > 0 and z < Config.FLOOR_HALF).toBe(true)
		expect(Skydive.onPad(x, z)).toBe(true)
		expect(Skydive.onPad(x + 20, z)).toBe(false)
	end)
	it("lays the same rings on every screen for the same seed", function()
		local a = Skydive.layRings(0, 250, 40, 0, 7)
		local b = Skydive.layRings(0, 250, 40, 0, 7)
		expect(#a).toBe(Skydive.RINGS)
		for i = 1, #a do
			expect(a[i].x).toBe(b[i].x)
			expect(a[i].y).toBe(b[i].y)
		end
	end)
	it("lays the rings out over the valley and downhill, above the end height", function()
		local f = Skydive.launch(0, TOWER_H, 24, 0, 3)
		for _, r in f.rings do
			expect(r.z > Config.FLOOR_HALF).toBe(true)
			expect(r.y > Skydive.END_ALT).toBe(true)
		end
		expect(f.rings[#f.rings].y < f.rings[1].y).toBe(true)
	end)
	it("arcs up off the pad, then glides down and ends four floors up", function()
		local f, t = fly(5, function()
			return 0, 0
		end)
		expect(f.phase).toBe("done")
		expect(t > 5 and t < Skydive.MAX_TIME).toBe(true)
		expect(f.y < TOWER_H).toBe(true)
	end)
	it("takes rings when you steer for them, and they lift you", function()
		local f = fly(11, chase)
		expect(f.got >= 6).toBe(true)
	end)
	it("lays every ring where a flyer steering for it can reach it (the last ones were out of reach)", function()
		for seed = 1, 60 do
			local f = fly(seed, chase)
			expect(#f.rings).toBe(Skydive.RINGS)
			expect(f.got).toBe(#f.rings)
		end
	end)
	it("gets nearly every ring just steering, never diving or flaring", function()
		for seed = 1, 60 do
			local f = fly(seed, function(f: Skydive.Flyer): (number, number)
				return (chase(f)), 0
			end)
			expect(f.got >= Skydive.RINGS - 2).toBe(true)
		end
	end)
	it("brings the rest of the trail within reach after a missed ring", function()
		for seed = 1, 60 do
			local f = fly(seed, function(f: Skydive.Flyer): (number, number)
				local r = f.rings[f.next]
				if f.next == 3 and r then
					-- well wide of ring 3, and no lift from it
					local wx, wz = r.x + r.dz * 5 * Skydive.RING_R, r.z - r.dx * 5 * Skydive.RING_R
					local want = math.atan2(wx - f.x, wz - f.z)
					return math.clamp(-math.atan2(math.sin(want - f.yaw), math.cos(want - f.yaw)) * 3, -1, 1), 0
				end
				return chase(f)
			end)
			expect(f.rings[3].state).toBe("missed")
			-- (the turn back in can cost the next one or two, sideways; never the rest)
			expect(f.got >= Skydive.RINGS - 3).toBe(true)
		end
	end)
	it("only ever brings rings down", function()
		local x, y, z = Skydive.padAt()
		local f = Skydive.launch(x, y, z, 0, 9)
		local before = {}
		for i, r in f.rings do
			before[i] = r.y
		end
		Skydive.settle(f.rings, 4, f.rings[3].x, f.rings[3].y + 50, f.rings[3].z, 0, Skydive.CRUISE.speed)
		Skydive.settle(f.rings, 4, f.rings[3].x, f.rings[3].y - 8 * Config.M, f.rings[3].z, 0, Skydive.CRUISE.speed)
		for i, r in f.rings do
			expect(r.y <= before[i]).toBe(true)
		end
		expect(f.rings[4].y < before[4]).toBe(true)
		expect(f.rings[2].y).toBe(before[2])
	end)
	it("never flies through the tower", function()
		local x, y, z = Skydive.padAt()
		local f = Skydive.launch(x, y, z, math.pi, 1) -- launched the wrong way, back over the roof
		for _ = 1, 600 do
			Skydive.step(f, 1 / 60, 0, 1)
			if f.y < TOWER_H then
				local inside = math.abs(f.x) < Config.FLOOR_HALF and math.abs(f.z) < Config.FLOOR_HALF
				expect(inside).toBe(false)
			end
			if f.phase == "done" then
				break
			end
		end
	end)
end)
