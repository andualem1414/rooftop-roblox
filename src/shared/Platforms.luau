--!strict
-- When and where the platforms are. Pure timing, the same on the server (which moves them) and the
-- client (which shows "next platform in 5 s"). A port of the original's platform.js.
--
-- Platform k (0, 1, 2…) launches from below the ground floor at race time k × INTERVAL. The shaft is
-- empty when the race starts: the first platform leaves the bottom as the climb begins, so someone high
-- up (a team on floor 5, a boost) waits for it to climb to them, and only then do the others follow
-- every INTERVAL seconds. It takes MOVE seconds to rise one floor and stops STOP
-- seconds at every floor. The top floor is the last stop until the roof opens; after that the roof
-- (level FLOORS) is the last stop. Levels are in floors: level 3 = standing at floor 3.

local Config = require("./Config")

local FLOORS = Config.FLOORS
local INTERVAL = Config.PLATFORM_INTERVAL
local MOVE = Config.PLATFORM_MOVE
local STOP = Config.PLATFORM_STOP
local CYCLE = Config.PLATFORM_CYCLE

local Platforms = {}

export type State = {
	active: boolean,
	level: number, -- where its deck is, in floors (fractional while moving)
	stop: number?, -- the floor it's stopped at, or nil while moving
	leaving: number, -- seconds before it leaves that stop (0 while moving)
}

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

-- the platform's state `age` seconds after its launch
function Platforms.state(age: number, roofOpen: boolean): State
	if age < 0 then
		return { active = false, level = -1, stop = nil, leaving = 0 }
	end
	local n = math.floor(age / CYCLE)
	local r = age - n * CYCLE
	local lastStop = if roofOpen then FLOORS else FLOORS - 1
	if n > lastStop then
		return { active = false, level = lastStop, stop = nil, leaving = 0 }
	end
	if r < MOVE then
		return { active = true, level = n - 1 + ease(r / MOVE), stop = nil, leaving = 0 }
	end
	return { active = true, level = n, stop = n, leaving = CYCLE - r }
end

-- the launch numbers that can be in the shaft at race time t (some may already be done; none before 0)
function Platforms.launchRange(t: number): (number, number)
	local trip = (FLOORS + 1) * CYCLE -- the longest trip: all the way to the roof
	return math.max(0, math.floor((t - trip) / INTERVAL)), math.floor(t / INTERVAL)
end

-- age of platform k at race time t
function Platforms.age(k: number, t: number): number
	return t - k * INTERVAL
end

-- seconds until a platform stops at `floor` (0 if one is there now), from race time t
function Platforms.nextArrival(t: number, floor: number, roofOpen: boolean): number
	if floor >= FLOORS and not roofOpen then
		return math.huge
	end
	local stopStart = floor * CYCLE + MOVE -- age at which a platform reaches this floor
	-- the first launch whose stop here hasn't ended yet (the first platform, early on)
	local k = math.max(0, math.ceil((t - stopStart - STOP) / INTERVAL))
	local arrive = k * INTERVAL + stopStart
	return math.max(0, arrive - t)
end

-- Is the shaft open at this floor? A floor's shaft gate stays shut (nobody falls down the shaft)
-- except while a platform is anywhere between the floor below and the floor above, so riders can
-- pass through and step on and off.
function Platforms.shaftOpen(floor: number, t: number, roofOpen: boolean): boolean
	local first, last = Platforms.launchRange(t)
	for k = first, last do
		local s = Platforms.state(Platforms.age(k, t), roofOpen)
		if s.active and s.level > floor - 1 and s.level < floor + 1 then
			return true
		end
	end
	return false
end

return table.freeze(Platforms)
