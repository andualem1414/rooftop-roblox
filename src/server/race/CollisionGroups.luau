--!strict
-- Who bumps into what. Characters (players and bots) stay in the Default group.
--   Tower      the building: platforms pass through its floors
--   Platform   the moving decks: carry climbers, ignore the building
--   ShaftGate  an invisible plug in each floor's shaft: stops climbers falling down the shaft, opened
--              while a platform is near (PlatformService)
--   CrateFence always there: keeps crates out of the shaft
--   Crates     loose crates you can shove
--   Bullet     what shots (raycasts) can hit: not the invisible gates
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

local GROUPS = { "Tower", "Platform", "ShaftGate", "CrateFence", "Crates", "Bullet" }

local function never(a: string, b: string)
	PhysicsService:CollisionGroupSetCollidable(a, b, false)
end

function CollisionGroups.init()
	for _, g in GROUPS do
		if not PhysicsService:IsCollisionGroupRegistered(g) then
			PhysicsService:RegisterCollisionGroup(g)
		end
	end
	never("Platform", "Tower")
	never("Platform", "ShaftGate")
	never("Platform", "CrateFence")
	never("Platform", "Crates")
	never("ShaftGate", "Tower")
	never("ShaftGate", "CrateFence")
	never("ShaftGate", "Crates")
	never("CrateFence", "Default")
	never("CrateFence", "Tower")
	never("Bullet", "ShaftGate")
	never("Bullet", "CrateFence")
end

return CollisionGroups
