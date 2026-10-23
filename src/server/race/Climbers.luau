--!strict
-- Everyone in the race, players and bots alike: their character, their fighter state (shared/Combat),
-- their team (shared/Teams) and where they are in the tower. Other services look climbers up here.
-- Clients see the team on the character and the player (a Team attribute; players are on Roblox's teams
-- too) and read everyone's state from the roster (Climbers.publish).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)

export type Climber = {
	id: number,
	name: string,
	kind: "player" | "bot",
	player: Player?,
	team: number, -- 1..TEAMS (0 until the race puts them on one)
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	fighter: Combat.Fighter,
	floor: number, -- the floor they're on (FLOORS = the roof)
	frozen: boolean, -- getting ready, or the race is over: no moving, no fighting
	knockedAt: number?, -- os.clock() when they went down
	out: boolean, -- knocked out after the roof opened: out of the race for good (no coming to)
	escaped: boolean, -- rode up through the roof
	knockouts: number, -- climbers they knocked out this race
	highest: number, -- highest floor reached this race
	brain: any, -- bots only (Bots.luau)
}

local Climbers = {}

local list: { Climber } = {}
local byModel: { [Model]: Climber } = {}
local nextId = 0
local roster: Folder? = nil

function Climbers.add(name: string, kind: "player" | "bot", player: Player?): Climber
	nextId += 1
	local c: Climber = {
		id = nextId,
		name = name,
		kind = kind,
		player = player,
		team = 0,
		model = nil,
		humanoid = nil,
		root = nil,
		fighter = Combat.newFighter(if kind == "bot" then Config.BOT_DAMAGE else 1),
		floor = 0,
		frozen = false,
		knockedAt = nil,
		out = false,
		escaped = false,
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
	if roster then
		roster:ClearAllChildren()
	end
end

-- put a climber on a team (their character and player carry it as the Team attribute)
function Climbers.setTeam(c: Climber, team: number)
	c.team = team
	c.fighter.team = team
	if c.model then
		c.model:SetAttribute("Team", team)
	end
	if c.player then
		c.player:SetAttribute("Team", team)
	end
end

-- on the same team (never yourself)
function Climbers.allies(a: Climber, b: Climber): boolean
	return a ~= b and a.team ~= 0 and a.team == b.team
end

-- let go of a climber's body (it's being taken away: out of the race)
function Climbers.dropModel(c: Climber)
	if c.model then
		byModel[c.model] = nil
	end
	c.model, c.humanoid, c.root = nil, nil, nil
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
	model:SetAttribute("Team", c.team)
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

local function set(i: Instance, name: string, value: any)
	if i:GetAttribute(name) ~= value then
		i:SetAttribute(name, value)
	end
end

-- The roster every client reads (the folder given here, RaceState.Roster): one Configuration per
-- climber, named by their id, with Name, Team, UserId (0 for a bot), Floor and State ("up", "down",
-- "out", "escaped"; "gone" once they've left the race: a bot out of it, a player who quit), and a Body
-- ObjectValue pointing at their character. Call every so often.
function Climbers.publish(folder: Folder?)
	if folder then
		roster = folder
	end
	local into = roster
	if not into then
		return
	end
	local here: { [string]: boolean } = {}
	for _, c in list do
		local key = tostring(c.id)
		here[key] = true
		local entry = into:FindFirstChild(key)
		if not entry then
			entry = Instance.new("Configuration")
			entry.Name = key
			local body = Instance.new("ObjectValue")
			body.Name = "Body"
			body.Parent = entry
			set(entry, "Name", c.name)
			set(entry, "UserId", if c.player then c.player.UserId else 0)
			entry.Parent = into
		end
		local e = entry :: Instance
		set(e, "Team", c.team)
		set(e, "Floor", c.floor)
		set(e, "State", if c.escaped then "escaped" elseif c.out then "out" elseif c.fighter.dead then "down" else "up")
		local body = e:FindFirstChild("Body") :: ObjectValue?
		if body and body.Value ~= c.model then
			body.Value = c.model
		end
	end
	for _, e in into:GetChildren() do
		if not here[e.Name] then
			set(e, "State", "gone")
			local body = e:FindFirstChild("Body") :: ObjectValue?
			if body then
				body.Value = nil
			end
		end
	end
end

return Climbers
