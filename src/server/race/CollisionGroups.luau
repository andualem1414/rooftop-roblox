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
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

local GROUPS = { "Climbers", "Tower", "Platform", "ShaftGate", "CrateFence", "Crates", "Bullet" }

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
