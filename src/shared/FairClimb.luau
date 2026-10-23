--!strict
-- The rule that keeps the climb honest, pure (server/race/FairPlay feeds it what it sees of each player
-- ten times a second; tests/FairClimb.spec pins it): the only ways up the tower are a platform and a
-- boost, so a player only goes up a floor riding a platform they got onto fair and square, or boosting
-- (or just after either: a stop, a landing). Anything else is "back": put them back where they last were
-- fair. Going down is always fine.
--
-- With room to spare, so nothing a real climber does ever looks like cheating:
--   up a floor:   their feet up at the next floor's surface (no furniture is anywhere near that tall)
--   down a floor: their feet well under their own floor's surface, and staying there a moment. A body's
--                 feet read low for a moment all the time (standing up from a crouch: the server lifts
--                 the hips before the body rises; a hard landing; a body that lags): that's no fall, and
--                 coming back up from it is no climb. (Counting those dips as falls once put a player
--                 back every tenth of a second, for good, wherever they stood up from a crouch.)
--   a ride:       a platform they stepped or dropped onto from where they were (not one they turned up
--                 on far above): it may carry them any number of floors, and no higher than it goes
local Config = require("./Config")

local FairClimb = {}

local FH = Config.FLOOR_HEIGHT
local FLOORS = Config.FLOORS
FairClimb.GRACE = 1.5 -- seconds a ride or a boost still counts after it
local UP = 1 -- studs under the next floor's surface that count as being up on it
local DOWN = 3 -- studs under their own floor's surface that count as having dropped below it...
local DOWN_FOR = 0.4 -- ...once they've stayed down there this long
local RISE = 26 -- studs a second a platform can lift you (its fastest), plus...
local SLACK = 6 -- ...a jump and a little lag: how far up anyone gets from where they were, fair
local ABOVE_DECK = 6 -- studs over its deck a rider can be (a jump on it)

export type State = {
	level: number, -- the floor they're on, fair and square
	feet: number, -- the height of their feet when last fair...
	at: number, -- ...and when
	lowSince: number?, -- under their floor since (a fall, once it lasts)
	deck: any, -- the platform they got onto fair (nil: none)...
	rodeAt: number, -- ...when they were last on it
	boostAt: number, -- when they were last boosting
}

-- what's seen of them now: feet (the height of their feet), now (seconds), on (the platform they're
-- standing on, if any), boosting, and topOf(platform): how high a platform's deck is now (nil: gone)
export type Seen = {
	feet: number,
	now: number,
	on: any,
	boosting: boolean,
	topOf: (any) -> number?,
}

function FairClimb.levelOf(feet: number): number
	return math.clamp(math.floor(feet / FH + 0.3), 0, FLOORS)
end

-- a body set down here, fair (a race's start, coming to)
function FairClimb.start(feet: number, now: number): State
	return {
		level = FairClimb.levelOf(feet),
		feet = feet,
		at = now,
		lowSince = nil,
		deck = nil,
		rodeAt = -math.huge,
		boostAt = -math.huge,
	}
end

-- how it stands now: "ok", or "back" (put them back where they last were fair, then FairClimb.putBack)
function FairClimb.step(s: State, seen: Seen): "ok" | "back"
	local feet, now = seen.feet, seen.now
	-- a platform under them: one they got onto from where they were (stepped on at a stop, jumped on as
	-- it went by, dropped onto down the shaft) is their ride; one they turned up on far above isn't
	if seen.on ~= nil then
		if seen.on ~= s.deck and feet - s.feet <= (now - s.at) * RISE + SLACK then
			s.deck = seen.on
		end
		if seen.on == s.deck then
			s.rodeAt = now
		end
	end
	if seen.boosting then
		s.boostAt = now
	end
	if feet >= (s.level + 1) * FH - UP then
		-- up on a floor above theirs: on their ride (no higher than it goes), or boosting
		local top = if s.deck ~= nil then seen.topOf(s.deck) else nil
		local riding = top ~= nil and now - s.rodeAt < FairClimb.GRACE and feet <= top + ABOVE_DECK
		if not riding and now - s.boostAt >= FairClimb.GRACE then
			return "back"
		end
		s.level = FairClimb.levelOf(feet)
		s.lowSince = nil
	elseif feet <= s.level * FH - DOWN then
		-- under their floor: a fall, once it lasts
		local since = s.lowSince or now
		s.lowSince = since
		if now - since >= DOWN_FOR then
			s.level = FairClimb.levelOf(feet)
			s.lowSince = nil
		end
	else
		s.lowSince = nil
	end
	if s.deck ~= nil and now - s.rodeAt >= FairClimb.GRACE then
		s.deck = nil
	end
	s.feet = feet
	s.at = now
	return "ok"
end

-- they've been put back: their feet are here now (where they last were fair)
function FairClimb.putBack(s: State, feet: number, now: number)
	s.feet = feet
	s.at = now
	s.lowSince = nil
end

return table.freeze(FairClimb)
