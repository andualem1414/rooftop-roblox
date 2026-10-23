--!strict
-- Getting a body out of anywhere it has got stuck: wedged in a gap between furniture, boxed in by something
-- it was knocked over, inside a piece it was set down too close to. There's no reset button (a knock-out is
-- the only way down), so being stuck would be for good: whoever moves the body (a player's own client:
-- client/race/Unstick; the server for a bot: server/race/Bots) asks here once it has tried to move for a
-- while and got nowhere.
--   trapped:   the body is inside something solid, or there's no way out in any of eight directions, along
--              the floor or a step up (what a climber walks or hops onto)
--   freeSpot:  the nearest spot round it, on the same floor, with room for a body and floor under it, away
--              from the shaft and the outer walls
-- (It looks at the world, unlike the rest of shared/: both the client and the server need it.)
local Config = require("./Config")

local Unstuck = {}

local SHAFT = Config.SHAFT_HALF + 1.5 -- nobody's set down over the shaft
local INNER = Config.FLOOR_HALF - Config.WALL - 1.2 -- nor in an outer wall
local RINGS = { 1.5, 2.5, 3.5, 5, 6.5, 8, 10, 12.5 }
local TURNS = 16

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.CollisionGroup = "Climbers"
overlap.RespectCanCollide = true
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.CollisionGroup = "Climbers"
ray.RespectCanCollide = true

-- the height of a body's feet
local function feetOf(root: BasePart, hum: Humanoid): number
	return root.Position.Y - root.Size.Y / 2 - hum.HipHeight
end

-- is there room for a body standing with its feet at (x, y, z)? (a little slimmer than a body: touching a
-- wall isn't being in it)
local function room(x: number, y: number, z: number, slim: number?): boolean
	local w = 1.6 - (slim or 0)
	return #workspace:GetPartBoundsInBox(CFrame.new(x, y + 2.7, z), Vector3.new(w, 4.4 - (slim or 0), w), overlap) == 0
end

-- the floor under (x, z), looked for from `top` down to `bottom` (nil: none there)
local function ground(x: number, z: number, top: number, bottom: number): number?
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, bottom - top, 0), ray)
	return if hit then hit.Position.Y else nil
end

local function inside(x: number, z: number): boolean
	return math.abs(x) < INNER and math.abs(z) < INNER and (math.abs(x) > SHAFT or math.abs(z) > SHAFT)
end

-- skip: what doesn't count as being in the way (the body itself, everyone else's, effects, pickups)
function Unstuck.trapped(root: BasePart, hum: Humanoid, skip: { Instance }): boolean
	overlap.FilterDescendantsInstances = skip
	ray.FilterDescendantsInstances = skip
	local p = root.Position
	local feet = feetOf(root, hum)
	-- inside something
	if not room(p.X, feet + 0.3, p.Z, 0.5) then
		return true
	end
	-- a way out: room for a body a stride away (along the floor or a step up), and half way there
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local dx, dz = math.cos(a), math.sin(a)
		for _, up in { 0, 1.3 } do
			local y = feet + up
			if room(p.X + dx * 1.2, y + 0.1, p.Z + dz * 1.2) and room(p.X + dx * 2.4, y + 0.1, p.Z + dz * 2.4) then
				return false
			end
		end
	end
	return true
end

-- the nearest spot to stand on the same floor (as the root's CFrame for it, facing the same way), or nil
function Unstuck.freeSpot(root: BasePart, hum: Humanoid, skip: { Instance }): CFrame?
	overlap.FilterDescendantsInstances = skip
	ray.FilterDescendantsInstances = skip
	local p = root.Position
	local feet = feetOf(root, hum)
	local lift = root.Position.Y - feet -- (the root over the feet)
	local turn = root.CFrame - root.Position
	for _, r in RINGS do
		for k = 0, TURNS - 1 do
			local a = (k + (r * 0.37) % 1) / TURNS * math.pi * 2
			local x, z = p.X + math.cos(a) * r, p.Z + math.sin(a) * r
			if inside(x, z) then
				local g = ground(x, z, feet + 3.5, feet - 2.5)
				if g and room(x, g + 0.1, z) then
					return CFrame.new(x, g + lift + 0.1, z) * turn
				end
			end
		end
	end
	return nil
end

return Unstuck
