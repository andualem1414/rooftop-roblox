--!strict
-- The roof hatch's two doors opening. Each first sinks into the roof slab, then slides away sideways
-- inside it, so an open door is hidden in the slab (lying on the roof's surface, the two flickered through
-- each other). The server puts the doors where they end up (server/common/Tower); every client draws the
-- slide itself (client/race/Ambience), since a tween on the server reaches clients in steps.
local Config = require("./Config")

local H = Config.SHAFT_HALF

local Hatch = {}

Hatch.OPEN_TIME = 1.6
Hatch.THICK = 0.6 -- a door's thickness
local SINK = (Config.SLAB - Hatch.THICK) / 2 + 0.01 -- down to the middle of the slab
local SINK_PART = 0.2 -- of the time

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

-- where a door is (from where it sits closed) at p (0 shut .. 1 open); side: -1 the left door, 1 the right
function Hatch.offset(side: number, p: number): CFrame
	local sink = ease(math.clamp(p / SINK_PART, 0, 1))
	local slide = ease(math.clamp((p - SINK_PART) / (1 - SINK_PART), 0, 1))
	return CFrame.new(side * (H + 0.3) * slide, -SINK * sink, 0)
end

return Hatch
