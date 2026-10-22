--!strict
-- The booster: a pad on the walkway beside each floor's shaft opening. Stand on it, pick a boost (1, 3, 5
-- or 10 floors) and you fly up the shaft like a rocket to that floor. Boosts are bought with Robux
-- (Developer Products, one per size); each purchase becomes a boost credit kept with your profile, spent
-- when you boost (so a purchase is never lost if the boost can't happen right then).
-- The rules keep the end of the race earned: never above floor 18, and only while climbing, before the
-- roof opens at 4:00. Floors here are 0-based (floor 0 = "floor 1" on screen).
local Config = require("./Config")

local Booster = {}

Booster.SIZES = { 1, 3, 5, 10 }
Booster.MAX_FLOOR = 17 -- 0-based: floor 18 on screen
Booster.PAD_R = 1.6 * Config.M -- the pad's radius (studs)
Booster.REACH = 3.2 * Config.M -- how near the pad's centre counts as standing on it (the server's check)

-- The Developer Product for each size, from Creator Hub (the experience → Monetization → Developer
-- Products). 0 = not set up: then boosts can't be bought (in Studio the pad hands out free test boosts).
Booster.PRODUCTS = table.freeze({
	[1] = 3721071953,
	[3] = 3721073562,
	[5] = 3721074287,
	[10] = 3721075481,
})

-- the size a product id buys, or nil
function Booster.sizeOf(productId: number): number?
	if productId == 0 then
		return nil
	end
	for size, id in Booster.PRODUCTS do
		if id == productId then
			return size
		end
	end
	return nil
end

function Booster.isSize(size: any): boolean
	return type(size) == "number" and table.find(Booster.SIZES, size) ~= nil
end

-- Can a climber on `floor` boost `size` floors now? The race's phase and time (seconds since the start).
-- Returns false and why not: "size", "floor" (it would pass floor 18), "phase" (not while climbing),
-- "roof" (the roof has opened)
function Booster.canBoost(floor: number, size: number, phase: string, t: number): (boolean, string?)
	if not Booster.isSize(size) then
		return false, "size"
	end
	if phase ~= "climb" then
		return false, if phase == "roof" then "roof" else "phase"
	end
	if t >= Config.ROOF_OPENS_AFTER then
		return false, "roof"
	end
	if floor < 0 or floor + size > Booster.MAX_FLOOR then
		return false, "floor"
	end
	return true, nil
end

-- where a floor's pad is: the walkway's corner beside the shaft (x, y of the floor's surface, z)
function Booster.pad(floor: number): (number, number, number)
	local c = Config.SHAFT_HALF + 0.6 * Config.M
	return c, floor * Config.FLOOR_HEIGHT, c
end

-- how long the flight takes (seconds)
function Booster.flightTime(size: number): number
	return 1.4 + 0.22 * size
end

-- Where the flight is at fraction k (0..1) of its time, from (x0, y0, z0) to a floor: up off the pad, in
-- over the shaft's corner, up the shaft, and out onto the new floor's pad. Returns x, y, z of the body's
-- centre (3 studs above the floor it stands on).
local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
function Booster.flightAt(k: number, x0: number, y0: number, z0: number, toFloor: number): (number, number, number)
	local inner = Config.SHAFT_HALF - 1.4 * Config.M -- over the shaft's corner, clear of the slabs
	local px, py, pz = Booster.pad(toFloor)
	local top = py + 3 + 1.2 * Config.M -- a little above the landing, then down onto it
	if k < 0.15 then
		local u = smooth(k / 0.15)
		return x0 + (inner - x0) * u, y0 + 2.5 * u, z0 + (inner - z0) * u
	elseif k < 0.82 then
		local u = smooth((k - 0.15) / 0.67)
		return inner, y0 + 2.5 + (top - y0 - 2.5) * u, inner
	end
	local u = smooth((k - 0.82) / 0.18)
	return inner + (px - inner) * u, top + (py + 3 - top) * u, inner + (pz - inner) * u
end

return table.freeze(Booster)
