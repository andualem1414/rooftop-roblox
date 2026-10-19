--!strict
-- The game's numbers, in one place. Timings are copied from the original browser game
-- (rooftop/src/config.js, platform.js, combat.js). Sizes are written in metres, the original's unit,
-- and stored in studs: M is studs per metre, set so a Roblox avatar (~5.5 studs) is a 1.8 m climber.

local M = 3
-- the platform deck's half size in metres: the original's 3.5 m deck, made half again as big (5.25 m), with
-- the shaft round it a hand's width wider
local DECK_HALF = 1.75 * 1.5

local Config = {}

Config.M = M

-- the tower (floor 0 is the ground floor; players see it as floor 1)
Config.FLOORS = 20
Config.FLOOR_HEIGHT = 3.2 * M -- from one floor's surface to the next
Config.FLOOR_HALF = 12 * M -- half width: 24 × 24 m floors (the original's 12 × 12, doubled)
Config.SLAB = 0.35 * M -- floor slab thickness
Config.WALL = 0.3 * M -- outer wall thickness
Config.SHAFT_HALF = (DECK_HALF + 0.15) * M -- half size of the platform shaft in the middle
Config.SHAFT_CLEAR = (DECK_HALF + 0.15 + 1.2) * M -- no cover within this of the centre: a walkway round the shaft
Config.LOW_COVER = 0.95 * M -- crates and barriers: low enough to jump over
Config.HALF_WALL = 2.1 * M -- half walls: too high to jump

-- the lobby and the race
Config.CLIMBERS = 20 -- every race has this many: real players, bots fill the rest
Config.LOBBY_COUNTDOWN = 45 -- seconds, from the first player in the lobby
Config.LOBBY_FULL_COUNTDOWN = 5 -- seconds left once 20 are waiting
Config.GROUP_WAIT = 20 -- seconds a race server waits for the rest of its group before it starts
Config.TELEPORT_TRIES = 4 -- a teleport that fails is tried again this many times
Config.START_FLOORS = { 0, 4 } -- everyone starts spread over these floors (floors 1–5)
Config.GET_READY = 10 -- seconds frozen in place before the race starts (the intro flies in meanwhile)
Config.ROOF_SCENE = 5.8 -- seconds everyone stops to watch the roof open (the last 3.2 behind a title card
-- while the lighting builds back round each player: client/race/Cinematic)
Config.ROOF_OPENS_AFTER = 4 * 60 -- seconds into the race
Config.RACE_LIMIT = 8 * 60 -- nobody out by then: the race ends with no winner
Config.CELEBRATION = 15 -- seconds of fireworks for the winner before everyone goes back

-- platforms
Config.PLATFORM_INTERVAL = 17 -- a new platform launches from the bottom this often
Config.PLATFORM_MOVE = 0.6 -- seconds to travel one floor
Config.PLATFORM_STOP = 3 -- seconds it stops at each floor
Config.PLATFORM_CYCLE = Config.PLATFORM_MOVE + Config.PLATFORM_STOP
Config.PLATFORM_TRIP = Config.FLOORS * Config.PLATFORM_CYCLE -- bottom to the end of the top-floor stop
Config.PLATFORM_HALF = DECK_HALF * M -- half size of the deck
Config.PLATFORM_THICK = 0.4 * M

-- climbers
Config.MAX_HP = 100
Config.REGEN_DELAY = 5 -- seconds without being hit before you heal...
Config.REGEN = 5 -- ...this many hp a second
Config.KNOCKED_OUT_FOR = 3.4 -- seconds down before you come to...
Config.COME_TO_LOWER = { 2, 5 } -- ...this many floors lower
Config.WAKE_PROTECTION = 2 -- seconds nobody can hit you after you come to
Config.BODY_R = 0.35 * M -- a climber's radius, for melee reach
Config.SAME_LEVEL = 0.8 * M -- melee only reaches someone within this height of you
Config.WALK_SPEED = 16 -- studs/s (Roblox's default, ~5.3 m/s; the original ran at 4.5)
Config.JUMP_HEIGHT = 1.3 * M -- feet clear any crate or barrier
Config.HEADSHOT = 1.5 -- gun damage times this on the head
Config.BOT_DAMAGE = 0.8 -- bots' blows land a little softer than players'

-- pickups
Config.FLOOR_AMMO = { 1, 2 } -- ammo boxes on each floor
Config.AMMO_RESPAWN = 60 -- seconds after one is taken
Config.FLOOR_WEAPON_CHANCE = 0.55 -- a weapon lies on about half the floors at the start
Config.DROP_LIFE = 50 -- seconds a dropped weapon lies there

return table.freeze(Config)
