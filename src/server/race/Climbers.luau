--!strict
-- Everyone in the race, players and bots alike: their character, their fighter state (shared/Combat),
-- and where they are in the tower. Other services look climbers up here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)

export type Climber = {
	id: number,
	name: string,
	kind: "player" | "bot",
	player: Player?,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	fighter: Combat.Fighter,
	floor: number, -- the floor they're on (FLOORS = the roof)
	frozen: boolean, -- getting ready, or the race is over: no moving, no fighting
	knockedAt: number?, -- os.clock() when they went down
	knockouts: number, -- climbers they knocked out this race
	highest: number, -- highest floor reached this race
	brain: any, -- bots only (Bots.luau)
}

local Climbers = {}

local list: { Climber } = {}
local byModel: { [Model]: Climber } = {}
local nextId = 0

function Climbers.add(name: string, kind: "player" | "bot", player: Player?): Climber
	nextId += 1
	local c: Climber = {
		id = nextId,
		name = name,
		kind = kind,
		player = player,
		model = nil,
		humanoid = nil,
		root = nil,
		fighter = Combat.newFighter(if kind == "bot" then Config.BOT_DAMAGE else 1),
		floor = 0,
		frozen = false,
		knockedAt = nil,
		knockouts = 0,
		highest = 0,
		brain = nil,
	}
	c.fighter.hitBy = nil
	table.insert(list, c)
	return c
end

function Climbers.remove(c: Climber)
	local i = table.find(list, c)
	if i then
		table.remove(list, i)
	end
	if c.model then
		byModel[c.model] = nil
	end
end

function Climbers.clear()
	table.clear(list)
	table.clear(byModel)
end

-- attach a (new) character model to a climber
function Climbers.setModel(c: Climber, model: Model)
	if c.model then
		byModel[c.model] = nil
	end
	c.model = model
	c.humanoid = model:FindFirstChildOfClass("Humanoid")
	c.root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	byModel[model] = c
end

function Climbers.all(): { Climber }
	return list
end

function Climbers.forPlayer(player: Player): Climber?
	for _, c in list do
		if c.player == player then
			return c
		end
	end
	return nil
end

-- the climber whose character this part belongs to (an accessory's handle counts too)
function Climbers.fromPart(part: Instance): Climber?
	local node: Instance? = part
	while node and node ~= workspace do
		if node:IsA("Model") and byModel[node :: Model] then
			return byModel[node :: Model]
		end
		node = node.Parent
	end
	return nil
end

-- the height of their feet
function Climbers.feetY(c: Climber): number?
	local root, hum = c.root, c.humanoid
	if not root or not hum then
		return nil
	end
	return root.Position.Y - root.Size.Y / 2 - hum.HipHeight
end

-- refresh positions, floors and how high they're jumping (call every step)
function Climbers.sync()
	for _, c in list do
		local root, hum = c.root, c.humanoid
		local f = c.fighter
		if not root or not hum or not root.Parent then
			continue
		end
		local p = root.Position
		local feet = p.Y - root.Size.Y / 2 - hum.HipHeight
		f.x, f.y, f.z = p.X, feet, p.Z
		local look = root.CFrame.LookVector
		f.heading = math.atan2(look.X, look.Z)
		local floor = math.clamp(math.floor(feet / Config.FLOOR_HEIGHT + 0.3), 0, Config.FLOORS)
		c.floor = floor
		f.lift = math.max(0, feet - floor * Config.FLOOR_HEIGHT)
		if not f.dead and floor > c.highest then
			c.highest = floor
		end
	end
end

return Climbers
