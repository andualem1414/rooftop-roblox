--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local FairClimb = require("../src/shared/FairClimb")

local describe, it, expect = Test.describe, Test.it, Test.expect

local FH = Config.FLOOR_HEIGHT
local TICK = 0.1 -- FairPlay looks ten times a second

-- a climber the rule watches, fed one look at a time: feet (their height), on (a platform under them),
-- boosting; it counts every "back" (and puts them back where they last were fair, as FairPlay does)
local function climber(feet: number)
	local now = 0
	local s = FairClimb.start(feet, now)
	local last = feet
	local self = { backs = 0, state = s }
	local function topOf(deck: any): number?
		return if deck.parked then nil else deck.top
	end
	function self.look(f: number, on: any?, boosting: boolean?): string
		now += TICK
		local v = FairClimb.step(s, { feet = f, now = now, on = on, boosting = boosting == true, topOf = topOf })
		if v == "back" then
			self.backs += 1
			FairClimb.putBack(s, last, now)
		else
			last = f
		end
		return v
	end
	function self.wait(seconds: number, f: number, on: any?)
		for _ = 1, math.floor(seconds / TICK + 0.5) do
			self.look(f, on)
		end
	end
	return self
end

-- a platform's deck rising a floor (0.6 s, eased as the real ones are), the rider on it all the way
local function rideUp(c: any, deck: { top: number }, floors: number, lag: number?)
	for _ = 1, floors do
		local from = deck.top
		for i = 1, 6 do
			local u = i / 6
			deck.top = from + FH * u * u * (3 - 2 * u)
			-- (a lagging body reads lower than the deck, and off it while it moves)
			if lag then
				c.look(deck.top - lag, nil)
			else
				c.look(deck.top, deck)
			end
		end
		c.wait(3, deck.top, deck) -- the stop
	end
end

describe("FairClimb", function()
	it("leaves someone standing, walking and jumping about their floor alone", function()
		local c = climber(3 * FH)
		c.wait(5, 3 * FH)
		for _ = 1, 20 do
			c.look(3 * FH + 2)
			c.look(3 * FH + 3.9) -- a jump's top
			c.look(3 * FH + 2)
			c.look(3 * FH)
		end
		c.wait(1, 3 * FH + 7.5) -- on the tallest furniture
		expect(c.backs).toBe(0)
	end)

	it("never mistakes standing up from a crouch, a hard landing or a lagging body for a climb", function()
		local c = climber(6 * FH)
		for _ = 1, 100 do
			-- standing up: the hips go up before the body does, so the feet read 1.6 low for a moment
			c.look(6 * FH - 1.6)
			c.look(6 * FH)
			c.look(6 * FH)
		end
		for _ = 1, 20 do
			c.look(6 * FH - 2.8) -- a landing, a hitch
			c.look(6 * FH - 2.8)
			c.look(6 * FH)
		end
		expect(c.backs).toBe(0)
		expect(c.state.level).toBe(6)
	end)

	it("puts back someone teleported or flown up the tower, and leaves them free once they're back", function()
		local c = climber(4 * FH)
		c.wait(1, 4 * FH)
		expect(c.look(5 * FH)).toBe("back")
		expect(c.look(14 * FH)).toBe("back")
		-- back on their own floor: nothing more
		c.wait(3, 4 * FH)
		for i = 1, 20 do
			c.look(4 * FH + (i % 2) * 3)
		end
		expect(c.backs).toBe(2)
	end)

	it("puts back someone flying up a floor at a time, every time", function()
		local c = climber(2 * FH)
		for f = 3, 10 do
			c.look(f * FH)
		end
		expect(c.backs).toBe(8)
		expect(c.state.level).toBe(2)
	end)

	it("lets a platform carry its riders up floor after floor", function()
		local c = climber(1 * FH)
		local deck = { top = 1 * FH }
		c.wait(3, deck.top, deck) -- stepped on at its stop
		rideUp(c, deck, 6)
		expect(c.backs).toBe(0)
		expect(c.state.level).toBe(7)
		-- off at the stop, and about the new floor
		c.wait(3, 7 * FH)
		expect(c.backs).toBe(0)
	end)

	it("lets a lagging rider ride (seen low and off the deck while it moves)", function()
		local c = climber(1 * FH)
		local deck = { top = 1 * FH }
		c.wait(3, deck.top, deck)
		rideUp(c, deck, 5, 2.5)
		expect(c.backs).toBe(0)
		expect(c.state.level).toBe(6)
	end)

	it("lets someone jump onto a platform as it goes by, and ride it", function()
		local c = climber(3 * FH)
		c.wait(1, 3 * FH)
		local deck = { top = 3 * FH + 2 }
		c.look(deck.top, deck) -- (jumped on, between floors)
		deck.top = 4 * FH
		c.wait(3, deck.top, deck)
		rideUp(c, deck, 2)
		expect(c.backs).toBe(0)
		expect(c.state.level).toBe(6)
	end)

	it("puts back someone who turns up on a platform far above them", function()
		local c = climber(2 * FH)
		c.wait(1, 2 * FH)
		local deck = { top = 12 * FH }
		expect(c.look(deck.top, deck)).toBe("back")
		c.wait(1, 2 * FH)
		expect(c.state.level).toBe(2)
	end)

	it("doesn't let a rider go higher than their platform", function()
		local c = climber(1 * FH)
		local deck = { top = 1 * FH }
		c.wait(3, deck.top, deck)
		rideUp(c, deck, 1)
		expect(c.look(9 * FH, deck)).toBe("back")
	end)

	it("follows a fall down the shaft, and holds them to the floor they fell to", function()
		local c = climber(9 * FH)
		c.wait(1, 9 * FH)
		for i = 1, 8 do
			c.look(9 * FH - i * 2.4) -- falling
		end
		c.wait(1, 7 * FH) -- landed two floors down
		expect(c.backs).toBe(0)
		expect(c.state.level).toBe(7)
		expect(c.look(8 * FH)).toBe("back") -- (and not back up without a platform)
	end)

	it("lets a boost fly someone up, and land", function()
		local c = climber(4 * FH)
		c.wait(1, 4 * FH)
		for i = 1, 20 do
			c.look(4 * FH + i * 2.4, nil, true) -- five floors in two seconds
		end
		c.wait(0.5, 9 * FH) -- landed (the jets off)
		c.wait(3, 9 * FH)
		expect(c.backs).toBe(0)
		expect(c.state.level).toBe(9)
	end)

	it("forgets a ride a while after getting off it", function()
		local c = climber(1 * FH)
		local deck = { top = 1 * FH }
		c.wait(3, deck.top, deck)
		rideUp(c, deck, 1)
		c.wait(3, 2 * FH) -- off, walking about
		deck.top = 6 * FH -- (it went on up)
		expect(c.look(6 * FH, deck)).toBe("back")
	end)
end)
