--!strict
-- Who bumps into what.
--   Climbers   every character's parts, players and bots (RaceService puts them in it)
--   Tower      the building: platforms pass through its floors
--   Platform   the moving decks: carry climbers and touch nothing else (so nothing can jam the shaft)
--   ShaftGate  an invisible plug in each floor's shaft: stops climbers falling down the shaft, opened
--              while a platform is near (PlatformService)
--   CrateFence always there: keeps crates out of the shaft
--   Crates     loose crates you can shove
--   Bullet     what shots (raycasts) can hit: not the invisible gates
--   Boosting   a climber flying up the shaft on a booster (their client puts its body in it): touches
--              nothing, so nothing in the shaft can snag the flight
--   Debris     what clients throw about for show (brass from a gun, confetti): it lands on floors and
--              decks but never bumps into a climber
--   Barrier    invisible walls round the roof's edge and the lobby's plaza (CollisionGroups.fence): only
--              climbers bump into them, so nobody walks, jumps or falls off, while the camera, shots,
--              platforms, debris and a skydive or a boost (Boosting) pass straight through
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

local GROUPS =
	{ "Climbers", "Tower", "Platform", "ShaftGate", "CrateFence", "Crates", "Bullet", "Boosting", "Debris", "Barrier" }

local function never(a: string, b: string)
	PhysicsService:CollisionGroupSetCollidable(a, b, false)
end

function CollisionGroups.init()
	for _, g in GROUPS do
		if not PhysicsService:IsCollisionGroupRegistered(g) then
			PhysicsService:RegisterCollisionGroup(g)
		end
	end
	never("Platform", "Default")
	never("Platform", "Tower")
	never("Platform", "ShaftGate")
	never("Platform", "CrateFence")
	never("Platform", "Crates")
	never("ShaftGate", "Default")
	never("ShaftGate", "Tower")
	never("ShaftGate", "CrateFence")
	never("ShaftGate", "Crates")
	never("CrateFence", "Default")
	never("CrateFence", "Climbers")
	never("CrateFence", "Tower")
	never("Bullet", "ShaftGate")
	never("Bullet", "CrateFence")
	never("Debris", "Climbers")
	never("Debris", "ShaftGate")
	never("Debris", "CrateFence")
	for _, g in GROUPS do
		never("Boosting", g)
	end
	never("Boosting", "Default")
	-- (raycasts and the camera's casts run as Default unless told otherwise: they never see a barrier)
	for _, g in GROUPS do
		if g ~= "Climbers" then
			never("Barrier", g)
		end
	end
	never("Barrier", "Default")
end

-- invisible walls round a rectangle (x0..x1 by z0..z1, their inner faces on its edges) from y0 up to y1, in
-- the Barrier group: whoever's inside stays inside
function CollisionGroups.fence(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y0: number,
	y1: number
): Model
	local model = Instance.new("Model")
	model.Name = "Barrier"
	local T = 4 -- thick, so nothing slips through
	local function wall(ax0: number, ax1: number, az0: number, az1: number)
		local p = Instance.new("Part")
		p.Name = "Barrier"
		p.Anchored = true
		p.Size = Vector3.new(ax1 - ax0, y1 - y0, az1 - az0)
		p.CFrame = CFrame.new((ax0 + ax1) / 2, (y0 + y1) / 2, (az0 + az1) / 2)
		p.Transparency = 1
		p.CastShadow = false
		p.CanTouch = false
		p.CollisionGroup = "Barrier"
		p.Parent = model
	end
	wall(x0 - T, x1 + T, z1, z1 + T)
	wall(x0 - T, x1 + T, z0 - T, z0)
	wall(x1, x1 + T, z0, z1)
	wall(x0 - T, x0, z0, z1)
	model.Parent = parent
	return model
end

-- put a character (and anything added to it later, like accessories) in the Climbers group
function CollisionGroups.climber(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Climbers"
		end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Climbers"
		end
	end)
end

return CollisionGroups
