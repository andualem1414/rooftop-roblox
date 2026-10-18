--!strict
-- The game's numbers, in one place. Timings are copied from the original browser game
-- (rooftop/src/config.js, platform.js, combat.js); sizes are in metres and get turned into
-- studs where the world is built (phase 2).

local Config = {}

-- the tower
Config.FLOORS = 20
Config.FLOOR_HEIGHT = 3.2 -- metres
Config.FLOOR_HALF = 12 -- half width: 24 × 24 m floors (the original's 12 × 12, doubled)
Config.SHAFT_HALF = 1.9 -- half size of the platform shaft in the middle

-- the lobby and the race
Config.CLIMBERS = 20 -- every race has this many: real players, bots fill the rest
Config.LOBBY_COUNTDOWN = 45 -- seconds, from the first player in the lobby
Config.LOBBY_FULL_COUNTDOWN = 5 -- seconds left once 20 are waiting
Config.START_FLOORS = { 1, 5 } -- everyone starts spread over these floors (1 = ground floor)
Config.ROOF_OPENS_AFTER = 4 * 60 -- seconds into the race
Config.RACE_LIMIT = 8 * 60 -- nobody out by then: the race ends with no winner
Config.CELEBRATION = 15 -- seconds of fireworks for the winner before everyone goes back

-- platforms
Config.PLATFORM_INTERVAL = 17 -- a new platform launches from the bottom this often
Config.PLATFORM_MOVE = 0.6 -- seconds to travel one floor
Config.PLATFORM_STOP = 3 -- seconds it stops at each floor
Config.PLATFORM_CYCLE = Config.PLATFORM_MOVE + Config.PLATFORM_STOP
Config.PLATFORM_TRIP = Config.FLOORS * Config.PLATFORM_CYCLE -- bottom to the end of the top-floor stop

-- climbers
Config.MAX_HP = 100
Config.REGEN_DELAY = 5 -- seconds without being hit before you heal...
Config.REGEN = 5 -- ...this many hp a second
Config.KNOCKED_OUT_FOR = 3.4 -- seconds down before you come to...
Config.COME_TO_LOWER = { 2, 5 } -- ...this many floors lower
Config.WAKE_PROTECTION = 2 -- seconds nobody can hit you after you come to

return table.freeze(Config)
