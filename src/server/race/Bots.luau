--!strict
-- The bots that fill a race up to 20 climbers. They want up: they catch every platform they can, crowd
-- the shaft when one is due, ride it (most all the way, some hop off after a few floors), and fight
-- whoever is in the way. Hit one and it hits back. Each has its own temper (aggression, skill, courage),
-- like the original's bots.js. With a gun and ammo they shoot from range; close up they swing the bat.
-- They pick up ammo when low and swords over the bat.
-- They shoot like people, not aimbots: a moment to react when someone comes into view, shots that go
-- wide (less so the longer they keep at the same target, more on the move: shared/Combat botAimError),
-- and aimed where a moving target was a moment ago. Nobody behind cover gets shot at: they only fire with
-- a clear line to the body (so crouching behind a sofa hides you; they come round it instead).
--
-- Who they fight is the original's: whoever hit them, else now and then the nearest one (all the time on
-- the top floor waiting for the roof, and whoever's next to them crowding the shaft), for a while, and
-- never someone two others are already on. Never a teammate: they shoot past (through) their own team.
-- They walk straight where the way is open and take a path (PathfindingService) round walls and
-- furniture where it isn't; stuck anyway, they hop or sidestep, and give up on a spot they can't reach.
-- They turn smoothly to face whoever they're fighting (an AlignOrientation, not a snap of the body).
--
-- Bots are Roblox avatars built from HumanoidDescriptions, with Roblox's default animations for the legs
-- and body (the ids are read from the rig's own Animate script and played from the server); their arms
-- are posed on every client like a player's (client/race/Poser).
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Looks = require(ReplicatedStorage.Shared.Looks)
local LookService = require(script.Parent.Parent.Common.LookService)
local Platforms = require(ReplicatedStorage.Shared.Platforms)
local Climbers = require(script.Parent.Climbers)
local Tools = require(script.Parent.Tools)
local Pickups = require(script.Parent.Pickups)
local PlatformService = require(script.Parent.PlatformService)
local CombatService = require(script.Parent.CombatService)
local Tower = require(script.Parent.Parent.Common.Tower)

type Climber = Climbers.Climber

export type Context = {
	tower: Tower.Tower,
	time: () -> number, -- race time
	roofOpen: () -> boolean,
	setup: (c: Climber, model: Model) -> (), -- shared character setup (RaceService)
}

local NAMES = {
	"Vasko",
	"Ilse",
	"Tomas",
	"Rook",
	"Mara",
	"Edda",
	"Pell",
	"Juno",
	"Kasim",
	"Oren",
	"Bex",
	"Doyle",
	"Nadia",
	"Lev",
	"Ines",
	"Hugo",
	"Sana",
	"Ivo",
	"Wren",
}

-- muted outfits: skin, top, trousers
local SKINS = {
	Color3.fromRGB(240, 203, 169),
	Color3.fromRGB(209, 160, 122),
	Color3.fromRGB(176, 126, 91),
	Color3.fromRGB(138, 91, 64),
	Color3.fromRGB(95, 62, 44),
}
local TOPS = {
	Color3.fromRGB(52, 64, 90),
	Color3.fromRGB(74, 85, 69),
	Color3.fromRGB(138, 78, 60),
	Color3.fromRGB(111, 122, 89),
	Color3.fromRGB(90, 95, 104),
	Color3.fromRGB(62, 101, 98),
	Color3.fromRGB(138, 58, 46),
	Color3.fromRGB(189, 184, 170),
	Color3.fromRGB(109, 47, 51),
}
local PANTS = {
	Color3.fromRGB(37, 39, 45),
	Color3.fromRGB(61, 75, 102),
	Color3.fromRGB(54, 49, 43),
	Color3.fromRGB(42, 45, 38),
	Color3.fromRGB(74, 66, 52),
}

local M = Config.M
local FLOORS = Config.FLOORS
local THINK = 0.25
local STUDIO = RunService:IsStudio()
local PATH = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 }

local Bots = {}

local ctx: Context
local rng = Random.new()
local templates: { Model } = {}
local folder: Folder

local function rr(a: number, b: number): number
	return a + (b - a) * rng:NextNumber()
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- build a handful of avatar rigs once, all at once (each is a trip to Roblox's avatar service); every
-- bot is a clone of one of them
function Bots.prepare()
	local store = ServerStorage:FindFirstChild("BotTemplates") or Instance.new("Folder")
	store.Name = "BotTemplates"
	store.Parent = ServerStorage
	local left = 8
	for _ = 1, left do
		local desc = Instance.new("HumanoidDescription")
		local skin, top, pants = pick(SKINS), pick(TOPS), pick(PANTS)
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = top
		desc.LeftLegColor = pants
		desc.RightLegColor = pants
		task.spawn(function()
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
			end)
			if ok and model then
				model.Parent = store
				table.insert(templates, model)
			else
				warn("[Rooftop] couldn't build a bot rig:", model)
			end
			left -= 1
		end)
	end
	while left > 0 do
		task.wait()
	end
end

-- the default animations, from the rig's own Animate script
local function loadAnims(c: Climber, model: Model)
	local hum = c.humanoid :: Humanoid
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local tracks: { [string]: AnimationTrack } = {}
	local animate = model:FindFirstChild("Animate")
	if animate then
		for _, v in animate:GetChildren() do
			local anim = v:FindFirstChildOfClass("Animation")
			if v:IsA("StringValue") and anim and not tracks[v.Name] then
				tracks[v.Name] = (animator :: Animator):LoadAnimation(anim)
			end
		end
		animate:Destroy() -- (a LocalScript; it never runs on a server-owned rig)
	end
	local function play(name: string, fade: number?)
		for n, tr in tracks do
			if
				n ~= name
				and (n == "idle" or n == "run" or n == "walk" or n == "fall" or n == "jump")
				and tr.IsPlaying
			then
				tr:Stop(fade or 0.2)
			end
		end
		local tr = tracks[name]
		if tr and not tr.IsPlaying then
			tr:Play(fade or 0.2)
			c.brain.gaitRate = 1 -- (a track starts at its own speed: gait() sets the pace again)
		end
	end
	local function moving(speed: number)
		if speed > 0.75 then
			play(if tracks.run then "run" else "walk")
		else
			play("idle")
		end
	end
	hum.Running:Connect(function(speed: number)
		if hum.FloorMaterial ~= Enum.Material.Air then
			moving(speed)
		end
	end)
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			play("jump", 0.1)
		elseif new == Enum.HumanoidStateType.Freefall then
			play("fall", 0.2)
		elseif new == Enum.HumanoidStateType.Landed then
			-- (still running as it lands: Running needn't fire again)
			local v = c.root and c.root.AssemblyLinearVelocity or Vector3.zero
			moving(Vector3.new(v.X, 0, v.Z).Magnitude)
		end
	end)
	-- (the arms holding and swinging weapons are posed on every client: client/race/Poser)
	play("idle")
	c.brain.tracks = tracks
	c.brain.gaitRate = 1
end

-- The run cycle keeps pace with the body (it played at one speed whatever the pace), and runs backward
-- while the bot backs off from someone it's fighting (it faces them; every client turns its legs to match:
-- client/race/Poser). Only sent on a real change: the server's track speeds replicate.
local function gait(c: Climber)
	local b, root = c.brain, c.root
	local tracks = b and b.tracks
	if not tracks or not root then
		return
	end
	local tr = tracks.run or tracks.walk
	if not tr or not tr.IsPlaying then
		return
	end
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	local backward = speed > 2 and flat.Unit:Dot(root.CFrame.LookVector) < -0.35
	local rate = math.clamp(speed / Config.WALK_SPEED, 0.35, 1.4) * (if backward then -1 else 1)
	if math.abs(rate - b.gaitRate) > 0.08 then
		b.gaitRate = rate
		tr:AdjustSpeed(rate)
	end
end

-- a new bot climber (no body yet)
function Bots.create(i: number): Climber
	local c = Climbers.add(NAMES[(i - 1) % #NAMES + 1], "bot", nil)
	c.brain = {
		aggression = rr(0.1, 1),
		courage = rr(0.12, 0.38),
		skill = rr(0.25, 0.95),
		ambition = if rng:NextNumber() < 0.72 then math.huge else rng:NextInteger(2, 8),
		rode = 0,
		lastStop = -1,
		spot = Vector3.new(rr(-0.6, 0.6) * Config.PLATFORM_HALF, 0, rr(-0.6, 0.6) * Config.PLATFORM_HALF),
		target = nil :: Climber?,
		fightT = 0, -- how much longer it keeps at a fight it picked
		think = rr(0, THINK),
		fireT = 0,
		burst = 0, -- shots left in this burst (full-auto guns)
		focus = 0, -- 0..1: how settled its aim is on the one it's shooting at
		focusOn = nil :: Climber?,
		sighted = false, -- it had a clear shot at them last time it looked
		swingT = 0,
		guardT = 0,
		wander = nil :: Vector3?,
		wanderT = 0,
		lastPos = Vector3.zero,
		stuck = 0,
		stuckN = 0, -- sidesteps lately without getting anywhere
		detour = nil :: Vector3?, -- sidestepping that way
		detourT = 0,
		stage = nil :: Vector3?, -- its place by the shaft while a platform is due
		nav = nil :: any, -- the path it's following: { goal, at, points, i, failed }
		computing = false,
		skip = {} :: { [Instance]: number }, -- pickups it couldn't reach (until when)
		faceAt = Vector3.zero,
		faceT = 0, -- facing faceAt (not where it walks) while > 0
		align = nil :: AlignOrientation?,
	}
	return c
end

-- give a bot a body on a floor (a fresh race, or coming to after a knock-out)
function Bots.spawn(c: Climber, floor: number)
	if #templates == 0 then
		return
	end
	if c.model then
		c.model:Destroy()
	end
	local model = (templates[(c.id % #templates) + 1]):Clone()
	model.Name = c.name
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = c.name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	Tools.stash(model)
	local spot = ctx.tower.randomSpot(floor)
	model:PivotTo(CFrame.new(spot) * CFrame.Angles(0, rr(0, math.pi * 2), 0))
	-- each bot wears one of the looks (the same one every time)
	LookService.apply(model, Looks.forBot(c.id).id)
	model.Parent = folder
	ctx.setup(c, model)
	local b = c.brain
	local root = c.root
	if root then
		root:SetNetworkOwner(nil)
		-- turns it to face whoever it's fighting (switched on while it does: the Heartbeat in Bots.init)
		local att = root:FindFirstChild("RootAttachment") :: Attachment?
		if not att then
			att = Instance.new("Attachment");
			(att :: Attachment).Parent = root
		end
		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = att
		align.Responsiveness = 25
		align.MaxTorque = math.huge
		align.Enabled = false
		align.Parent = root
		b.align = align
	end
	b.target = nil
	b.fightT = 0
	b.rode = 0
	b.lastStop = -1
	b.nav = nil
	b.stage = nil
	b.detour = nil
	b.faceT = 0
	loadAnims(c, model)
	Tools.equip(c, "gun")
end

function Bots.clear()
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function valid(c: Climber, o: Climber?): boolean
	if not o or o == c or not o.root or o.fighter.dead or o.frozen or o.fighter.invuln > 0 or Climbers.allies(c, o) then
		return false
	end
	return o.floor == c.floor
end

-- how many bots are after this one
local function hunters(o: Climber): number
	local n = 0
	for _, h in Climbers.all() do
		if h.brain and h.brain.target == o then
			n += 1
		end
	end
	return n
end

-- the nearest one worth fighting (not already mobbed by two others)
local function nearest(c: Climber, within: number, keep: ((o: Climber) -> boolean)?): Climber?
	local root = c.root :: BasePart
	local best, bd = nil, within
	for _, o in Climbers.all() do
		if valid(c, o) and (not keep or keep(o)) and hunters(o) < 2 then
			local d = (flat((o.root :: BasePart).Position - root.Position)).Magnitude
			if d < bd then
				best, bd = o, d
			end
		end
	end
	return best
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.CollisionGroup = "Bullet"
local function clearShot(from: Vector3, to: Vector3, skip: { Instance }): boolean
	losParams.FilterDescendantsInstances = skip
	return workspace:Raycast(from, to - from, losParams) == nil
end

-- face that way for a moment (it turns smoothly: the Heartbeat in Bots.init)
local function face(c: Climber, at: Vector3)
	c.brain.faceAt = at
	c.brain.faceT = 0.6
end

-- the walkway round the shaft, a step back from the edge (where they wait for a platform), spread out
-- along the side nearest them
local function stageSpot(c: Climber): Vector3
	local root = c.root :: BasePart
	local p = root.Position
	local r = Config.SHAFT_HALF + rr(0.6, 1.1) * M
	local along = Config.SHAFT_HALF - 0.3 * M
	local y = c.floor * Config.FLOOR_HEIGHT
	if math.abs(p.X) > math.abs(p.Z) then
		return Vector3.new(math.sign(p.X) * r, y, math.clamp(p.Z + rr(-1, 1) * M, -along, along))
	end
	return Vector3.new(math.clamp(p.X + rr(-1, 1) * M, -along, along), y, math.sign(p.Z) * r)
end

---------------------------------------------------------------- getting about

local wayParams = RaycastParams.new()
wayParams.FilterType = Enum.RaycastFilterType.Exclude
wayParams.CollisionGroup = "Climbers"
wayParams.RespectCanCollide = true

-- is the way there open (nothing a climber would walk into, at waist height)? (cast from a step back: a
-- shape cast doesn't see what it starts inside, such as the wall a bot is pressed against)
local function openWay(from: Vector3, to: Vector3, skip: { Instance }): boolean
	local dir = flat(to - from)
	if dir.Magnitude < 1 then
		return true
	end
	wayParams.FilterDescendantsInstances = skip
	local back = dir.Unit * 1.2
	return workspace:Spherecast(from - back, 0.9, dir + back, wayParams) == nil
end

-- the next spot to walk to on the way to a goal: the goal itself when the way is open, else the next
-- waypoint of a path round whatever's in the way (worked out in the background, again when the goal
-- moves or every few seconds)
local function route(c: Climber, goal: Vector3, skip: { Instance }): Vector3
	local b, root, hum = c.brain, c.root :: BasePart, c.humanoid :: Humanoid
	local pos = root.Position
	-- (stuck lately: the way only looked open, so take a path)
	if b.stuckN < 1 and openWay(pos, goal, skip) then
		b.nav = nil
		return goal
	end
	local nav = b.nav
	if (not nav or flat(nav.goal - goal).Magnitude > 4 or os.clock() - nav.at > 3) and not b.computing then
		b.computing = true
		local from = pos
		task.spawn(function()
			local path = PathfindingService:CreatePath(PATH)
			local ok = pcall(function()
				path:ComputeAsync(from, goal)
			end)
			b.computing = false
			local good = ok and path.Status == Enum.PathStatus.Success
			b.nav = {
				goal = goal,
				at = os.clock(),
				points = if good then path:GetWaypoints() else {},
				i = 2,
				failed = not good,
			}
		end)
	end
	nav = b.nav
	if not nav or #nav.points < 2 or flat(nav.goal - goal).Magnitude > 6 then
		return goal
	end
	local points = nav.points
	while nav.i < #points and flat(points[nav.i].Position - pos).Magnitude < 2.5 do
		nav.i += 1
	end
	-- a later waypoint in plain sight: cut the corner
	while nav.i < #points and openWay(pos, points[nav.i + 1].Position, skip) do
		nav.i += 1
	end
	local wp = points[math.min(nav.i, #points)]
	if wp.Action == Enum.PathWaypointAction.Jump and flat(wp.Position - pos).Magnitude < 5 then
		hum.Jump = true
	end
	return wp.Position
end

-- the path to this goal can't be found (it's inside something, or walled off)
local function unreachable(c: Climber, goal: Vector3): boolean
	local nav = c.brain.nav
	return nav ~= nil and nav.failed and flat(nav.goal - goal).Magnitude < 4
end

-- not right on top of the others where it's going (they bunched up on the same spot)
local function spread(c: Climber, goal: Vector3): Vector3
	local root = c.root :: BasePart
	if flat(goal - root.Position).Magnitude > 6 then
		return goal
	end
	local push = Vector3.zero
	for _, o in Climbers.all() do
		if o ~= c and o.root and o.floor == c.floor then
			local away = flat(goal - o.root.Position)
			local d = away.Magnitude
			if d < 3.5 and d > 0.01 then
				push += away.Unit * (3.5 - d)
			end
		end
	end
	return goal + push
end

---------------------------------------------------------------- fighting

local function fight(c: Climber, foe: Climber, goal: Vector3?): Vector3?
	local b, f = c.brain, c.fighter
	local root, froot = c.root :: BasePart, foe.root :: BasePart
	local d = flat(froot.Position - root.Position).Magnitude
	local hasAmmo = f.gun ~= nil and (f.mag > 0 or f.reserve > 0)
	local skip = { c.model :: Model, foe.model :: Model }
	for _, o in Climbers.all() do
		if o.model and Climbers.allies(c, o) then
			table.insert(skip, o.model) -- (its bullets fly through teammates)
		end
	end
	if hasAmmo and d > 3.5 * M then
		Tools.equip(c, "gun")
		local gw = Weapons[f.gun :: string]
		if f.mag <= 0 then
			Combat.startReload(f)
			b.burst = 0
		elseif d < gw.range then
			if b.focusOn ~= foe then
				-- someone new: it takes a moment to react and line up
				b.focusOn = foe
				b.focus = 0
				b.sighted = false
			end
			local head = (c.model :: Model):FindFirstChild("Head") :: BasePart?
			-- a point on the body (lower on someone crouched: their body is lower)
			local aim = froot.Position + Vector3.new(0, rr(-0.4, 1.3), 0)
			local clear = head ~= nil and clearShot(head.Position, aim, skip)
			if clear and not b.sighted then
				-- just came into view (or out from behind cover): react first
				b.fireT = math.max(b.fireT, rr(0.3, 0.7) * (1.3 - b.skill * 0.5))
				b.focus *= 0.4
			end
			b.sighted = clear
			if clear then
				face(c, aim)
			end
			if clear and b.fireT <= 0 then
				-- where they were a moment ago (as it sees them move across its sights)
				local rel = froot.AssemblyLinearVelocity - root.AssemblyLinearVelocity
				local seen = aim - rel * Combat.botLag(b.skill) * rr(0.6, 1.3)
				local moving = flat(root.AssemblyLinearVelocity).Magnitude > 4
				CombatService.botFire(c, seen, Combat.botAimError(b.skill, b.focus, moving))
				b.focus = math.min(1, b.focus + 0.2)
				local interval = gw.windup + gw.strike + gw.recover
				if gw.auto then
					-- full auto: bursts of a few rounds, then a pause to steady the aim
					if b.burst <= 0 then
						b.burst = rng:NextInteger(3, 4 + math.floor(b.skill * 6))
					end
					b.burst -= 1
					b.fireT = if b.burst > 0 then interval else rr(0.3, 0.8) * (1.3 - b.skill * 0.5)
				else
					b.fireT = math.max(interval, rr(0.35, 0.9) * (1.3 - b.skill * 0.5))
				end
			end
		end
		if goal then
			return goal
		end
		-- close in to where the gun does its work (a shotgun wants them near), else circle them a little
		if d > math.min(12 * M, gw.range * 0.6) then
			return froot.Position
		end
		local side = flat(root.Position - froot.Position).Unit:Cross(Vector3.yAxis)
		return root.Position + side * (if c.id % 2 == 0 then 6 else -6)
	end
	Tools.equip(c, "melee")
	local w = Combat.weapon(f)
	if w and w.slot == "melee" and d < w.reach + Config.BODY_R and b.swingT <= 0 then
		face(c, froot.Position)
		local dir = froot.Position - root.Position
		if CombatService.swing(c, math.atan2(dir.X, dir.Z)) then
			b.swingT = rr(0.1, 0.5) * (1.3 - b.skill)
		end
	end
	-- read a swing coming and guard it (the skilled ones)
	local fa = foe.fighter.atk
	if
		fa
		and fa.w.slot == "melee"
		and fa.t < fa.w.windup
		and Combat.canBlock(f)
		and rng:NextNumber() < b.skill * 0.4
	then
		f.blocking = true
		b.guardT = 0.5
	end
	if goal then
		return goal
	end
	-- up to them, not into them (walking into someone shoves them about)
	local reach = if w and w.slot == "melee" then w.reach else 1.5 * M
	local away = flat(root.Position - froot.Position)
	if away.Magnitude < 0.01 then
		return froot.Position
	end
	face(c, froot.Position)
	return froot.Position + away.Unit * math.min(reach * 0.6, d)
end

---------------------------------------------------------------- thinking

-- who to fight
local function pickTarget(c: Climber, riding: any, t: number, roofOpen: boolean)
	local b, f = c.brain, c.fighter
	-- whoever hurt us lately comes first, and keeps us at it for a while
	local foe = if f.hitBy and f.hitAge < 7 then CombatService.climberOf(f.hitBy) else nil
	if foe and valid(c, foe) then
		if b.target ~= foe then
			b.fightT = rr(6, 10)
		end
		b.target = foe
	elseif b.target and (not valid(c, b.target) or b.fightT <= 0) then
		b.target = nil
	end
	-- only one team can escape: on the top-floor platform with the roof open, clear the other teams off it
	if riding and roofOpen and riding.stop == FLOORS - 1 then
		local root0 = (c.root :: BasePart).Position
		local best, bd = nil, math.huge
		for _, o in PlatformService.riders(riding) do
			if o ~= c and o.root and valid(c, o) then
				local d = (o.root.Position - root0).Magnitude
				if d < bd then
					best, bd = o, d
				end
			end
		end
		if best then
			b.target = best
			b.fightT = 3
		end
	end
	if b.target then
		return
	end
	-- pick a fight (the original's odds, per think): a platform is small, so anyone on it is competition;
	-- the top floor, waiting for the roof, makes everyone restless; crowding the shaft for a platform
	-- means shoving whoever's next to you
	local gun = f.gun ~= nil and f.mag + f.reserve > 0
	local sight = if gun then 1.6 else 1
	local top = c.floor == FLOORS - 1 and not roofOpen
	local chance, range, keep = 0.07, 7 * M * sight, nil
	if riding then
		chance, range = 0.25, 2.6 * M
		keep = function(o: Climber): boolean
			return PlatformService.slotOf(o) == riding
		end
	elseif top then
		chance, range = 0.4, 10 * M * sight
	elseif Platforms.nextArrival(t, c.floor, roofOpen) < 6 then
		chance, range = 0.45, 2.5 * M
	end
	if rng:NextNumber() < b.aggression * chance then
		local o = nearest(c, range, keep)
		if o then
			b.target = o
			b.fightT = rr(5, 10)
		end
	end
end

local function think(c: Climber)
	local b, f = c.brain, c.fighter
	local hum, root = c.humanoid, c.root
	if not hum or not root or f.dead then
		return
	end
	if c.frozen then
		hum:Move(Vector3.zero)
		return
	end
	local t, roofOpen = ctx.time(), ctx.roofOpen()
	local pos = root.Position
	local riding = PlatformService.slotOf(c)
	if riding and riding.stop and riding.stop ~= b.lastStop then
		b.lastStop = riding.stop
		b.rode += 1
	elseif not riding then
		b.rode = 0
		b.lastStop = -1
	end
	pickTarget(c, riding, t, roofOpen)
	-- badly hurt: run for it (unless riding)
	local scared = f.hp / f.maxHp < b.courage and not riding

	local goal: Vector3? = nil
	local mode = "wander"
	if riding then
		mode = "ride"
		if riding.stop and b.rode >= b.ambition and riding.stop < FLOORS - 1 then
			goal = ctx.tower.ringSpot(riding.stop) -- hop off and roam
			b.ambition = math.huge
			mode = "hop off"
		else
			goal = riding.deck.Position + b.spot
		end
	else
		local s = PlatformService.stoppedAt(c.floor)
		if s and c.floor < FLOORS then
			local spot = s.deck.Position + b.spot
			if s.leaving > flat(spot - pos).Magnitude / Config.WALK_SPEED + 0.3 then
				goal = spot
				mode = "board"
			end
		end
		if not goal and Platforms.nextArrival(t, c.floor, roofOpen) < 4 then
			-- (its own place by the shaft, kept while it waits: a new one each think had it shuffling about)
			if not b.stage or math.abs(b.stage.Y - c.floor * Config.FLOOR_HEIGHT) > 1 then
				b.stage = stageSpot(c)
			end
			goal = b.stage
			mode = "stage"
		end
	end
	if mode ~= "stage" then
		b.stage = nil
	end

	if scared then
		b.target = nil
		if not b.wander or b.wanderT <= 0 then
			b.wander = ctx.tower.randomSpot(c.floor)
			b.wanderT = 4
		end
		goal = b.wander
		mode = "flee"
	elseif b.target then
		-- boarding or riding it keeps going and fights on the way; anywhere else it goes after them
		local keep = mode == "board" or mode == "ride" or mode == "hop off"
		goal = fight(c, b.target, if keep then goal else nil)
		mode ..= " + fight " .. b.target.name
	else
		Tools.equip(c, if f.gun and f.mag + f.reserve > 0 then "gun" else "melee")
	end

	-- things worth picking up on the way
	local want: Pickups.Pickup? = nil
	if not goal or not b.target then
		local function reachable(pk: Pickups.Pickup?): Pickups.Pickup?
			return if pk and (b.skip[pk.part] or 0) < t then pk else nil
		end
		want = if f.reserve < 12 then reachable(Pickups.nearest(c, 30, "ammo")) else nil
		want = want or (if f.melee == "bat" then reachable(Pickups.nearest(c, 25, "sword")) else nil)
		-- a better gun than the one it carries
		local mine = if f.gun then Weapons[f.gun].tier else 0
		want = want
			or reachable(Pickups.nearestWhere(c, 30, function(kind: string): boolean
				local w = Weapons[kind]
				return w ~= nil and w.slot == "gun" and w.tier > mine
			end))
		if want then
			if (want.part.Position - pos).Magnitude < 6 then
				Pickups.take(c, want)
				want = nil
			elseif not goal then
				goal = want.part.Position
				mode = "pickup " .. want.kind
			else
				want = nil
			end
		end
	end

	if not goal then
		if not b.wander or b.wanderT <= 0 or flat(b.wander - pos).Magnitude < 3 then
			b.wander = if rng:NextNumber() < 0.5 then ctx.tower.randomSpot(c.floor) else stageSpot(c)
			b.wanderT = rr(3, 7)
		end
		goal = b.wander
	end
	local target = goal :: Vector3
	if not b.target then
		target = spread(c, target)
	end

	-- can't get there: give it up (a new spot to wander to, the pickup left alone for a while)
	local function giveUp()
		if want then
			b.skip[want.part] = t + 15
		end
		if mode == "wander" or mode == "flee" then
			b.wanderT = 0
		end
		if b.target and not (f.hitBy and f.hitAge < 7) then
			b.target = nil
		end
		b.nav = nil
		b.stuckN = 0
	end

	-- what it's up to, for debugging (Studio only: in the live game it would be replicated for nothing)
	if STUDIO and c.model and c.model:GetAttribute("BotMode") ~= mode then
		c.model:SetAttribute("BotMode", mode)
	end

	-- on its way: straight onto a platform, round things on the floor
	local onDeck = mode == "board" or mode == "ride" or mode == "hop off"
	local step = target
	if b.detour and b.detourT > 0 then
		step = pos + b.detour
	elseif not onDeck then
		local skip: { Instance } = { folder }
		for _, o in Climbers.all() do
			if o.model and o.kind ~= "bot" then
				table.insert(skip, o.model)
			end
		end
		step = route(c, target, skip)
		if unreachable(c, target) then
			giveUp()
		end
	end
	hum:MoveTo(step)

	-- stuck against something: hop it, then sidestep for a moment; still stuck, give the spot up
	if flat(target - pos).Magnitude > 3 and (pos - b.lastPos).Magnitude < 0.4 then
		b.stuck += THINK
		if b.stuck > 0.5 then
			b.stuck = 0
			b.stuckN += 1
			if b.stuckN % 2 == 1 then
				hum.Jump = true
			else
				local ahead = flat(target - pos)
				ahead = if ahead.Magnitude > 0.01 then ahead.Unit else Vector3.xAxis
				local side = ahead:Cross(Vector3.yAxis) * (if rng:NextNumber() < 0.5 then 1 else -1)
				b.detour = (side + ahead * 0.3).Unit * 8
				b.detourT = rr(0.5, 0.9)
				b.nav = nil
			end
			if b.stuckN >= 5 then
				giveUp()
			end
		end
	else
		b.stuck = 0
		b.stuckN = math.max(0, b.stuckN - THINK / 2)
	end
	b.lastPos = pos
end

-- turning to face whoever it's fighting (smoothly: an AlignOrientation), else turning where it walks
local function turn(c: Climber, dt: number)
	local b, hum, root = c.brain, c.humanoid, c.root
	local align = b.align :: AlignOrientation?
	if not hum or not root or not align or align.Parent == nil then
		return
	end
	b.faceT -= dt
	local on = b.faceT > 0 and not c.fighter.dead and not c.frozen
	if on then
		local dir = flat(b.faceAt - root.Position)
		if dir.Magnitude > 0.1 then
			align.CFrame = CFrame.lookAt(Vector3.zero, dir)
		end
	end
	if align.Enabled ~= on then
		align.Enabled = on
		hum.AutoRotate = not on
	end
end

function Bots.init(context: Context)
	ctx = context
	Bots.clear()
	RunService.Heartbeat:Connect(function(dt: number)
		for _, c in Climbers.all() do
			local b = c.brain
			if c.kind ~= "bot" or not b then
				continue
			end
			b.fireT -= dt
			b.swingT -= dt
			b.wanderT -= dt
			b.fightT -= dt
			b.detourT -= dt
			if b.guardT > 0 then
				b.guardT -= dt
				if b.guardT <= 0 then
					c.fighter.blocking = false
				end
			end
			b.think -= dt
			if b.think <= 0 then
				b.think = THINK
				think(c)
			end
			turn(c, dt)
			b.gaitT = (b.gaitT or 0) - dt
			if b.gaitT <= 0 then
				b.gaitT = 0.1
				gait(c)
			end
		end
	end)
end

return Bots
