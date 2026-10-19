--!strict
-- The race's rules: where you start, where you come to, what platforms carry, who escapes, and what
-- phase the race is in. Pure functions; `rand(a, b)` is a random integer a..b (inclusive) and
-- `roll()` a random number 0..1, passed in so the tests can pin them.

local Config = require("./Config")

local Rules = {}

-- the floor the i-th climber starts on: spread evenly over START_FLOORS (the caller shuffles who is i)
function Rules.startFloor(i: number): number
	local lo, hi = Config.START_FLOORS[1], Config.START_FLOORS[2]
	local span = hi - lo + 1
	return lo + ((i - 1) % span)
end

-- knocked out on `floor`: you come to 2–5 floors lower (never below the ground floor)
function Rules.comeToFloor(floor: number, rand: (number, number) -> number): number
	local drop = rand(Config.COME_TO_LOWER[1], Config.COME_TO_LOWER[2])
	return math.max(0, math.min(floor, Config.FLOORS - 1) - drop)
end

-- What a platform carries up the shaft: a gun, a sword or an ammo box, evenly.
export type Loot = "gun" | "sword" | "ammo"
function Rules.platformLoot(roll: () -> number): Loot
	local r = roll()
	if r < 1 / 3 then
		return "gun"
	elseif r < 2 / 3 then
		return "sword"
	end
	return "ammo"
end

-- The gun found on a platform or a floor: everyone already carries a pistol, so it's one of the others
-- (the rifle and the SMG a little more often than the shotgun)
local FOUND_GUNS = { { "rifle", 0.36 }, { "smg", 0.36 }, { "shotgun", 0.28 } }
function Rules.foundGun(roll: () -> number): string
	local r = roll()
	for _, g in FOUND_GUNS do
		if r < g[2] then
			return g[1]
		end
		r -= g[2]
	end
	return FOUND_GUNS[#FOUND_GUNS][1]
end

-- A weapon lying on a floor at the start: a sword or a found gun
function Rules.floorWeapon(roll: () -> number): string
	if roll() < 0.4 then
		return "sword"
	end
	return Rules.foundGun(roll)
end

-- A platform about to rise through the roof: only one can escape.
--   "escape": exactly one rider, up they go
--   "throw": more than one, it throws them all off ("Only one can escape")
--   "empty": nobody on it
export type Escape = "escape" | "throw" | "empty"
function Rules.escape(riders: number): Escape
	if riders == 1 then
		return "escape"
	elseif riders > 1 then
		return "throw"
	end
	return "empty"
end

-- the race's phase at race time t (seconds since the start; negative while getting ready)
export type Phase = "ready" | "climb" | "roof" | "over"
function Rules.phase(t: number, finished: boolean): Phase
	if finished or t >= Config.RACE_LIMIT then
		return "over"
	elseif t < 0 then
		return "ready"
	elseif t < Config.ROOF_OPENS_AFTER then
		return "climb"
	end
	return "roof"
end

-- how many bots fill a race with this many players
function Rules.botsFor(players: number): number
	return math.max(0, Config.CLIMBERS - players)
end

-- m:ss for the HUD
function Rules.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return table.freeze(Rules)
