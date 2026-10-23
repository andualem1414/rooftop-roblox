--!strict
-- The bots that fill a race up to 20 climbers. They want up: they catch every platform they can, crowd
-- the shaft when one is due, ride it (most all the way, some hop off after a few floors), and fight
-- whoever is in the way. Hit one and it hits back. Each has its own temper (aggression, courage, skill),
-- like the original's bots.js.
--
-- How they move (every frame, `steer`): toward the spot their thinking chose, the way a person runs: up to
-- speed over a few strides, round a curve rather than a snap (a running turn swings at most TURN_RATE),
-- planting and pushing off to reverse, easing off as they arrive, stepping round anyone in the way. With
-- nothing going on they walk (and stop at the end for a look round); anything that matters, they run.
-- They walk straight where the way is open and take a path (PathfindingService) round walls and furniture
-- where it isn't; stuck anyway, they hop or sidestep, and give up on a spot they can't reach; wedged or
-- boxed in for good (shared/Unstuck), they're set down on open floor nearby. They turn smoothly to face
-- whoever they're fighting (an AlignOrientation, not a snap of the body).
--
-- How they fight:
--   who:     whoever hit them; a teammate's attacker (they back each other up); someone they hear shooting
--            nearby and then see; now and then the nearest enemy in sight (all the time on the top floor
--            waiting for the roof, and whoever's next to them crowding the shaft), for a while, and never
--            someone two others are already on. Never a teammate: they shoot past (through) their own team.
--   guns:    each gun has a range it likes (a shotgun up close, the rifle far back): they close in or back
--            off to it, and strafe in bursts (one way, then the other, now and then planting their feet to
--            shoot straighter); they only fire with a clear line to the body (so crouching behind a sofa
--            hides you; they come round it instead), react before their first shot, miss by a skill-based
--            error that settles as they keep firing (shared/Combat botAimError), and aim where a moving
--            target was a moment ago (botLag)
--   cover:   reloading, or hurt, they go behind the nearest furniture that hides them from their foe
--            (Tower.covers) and crouch there; they stand up to shoot again (crouched, a gun won't fire)
--   melee:   up to them, a swing, a step back out of reach, and in again; the skilled ones read a swing
--            coming and guard it or step out of it
--   scared:  badly hurt (under their courage), they break off and run for cover away from the threat
-- With teammates on the floor they keep loosely together. Bots never boost.
--
-- Bots are Roblox avatars built from HumanoidDescriptions, with Roblox's default animations for the legs
-- and body (the ids are read from the rig's own Animate script and played from the server; the walk or
-- the run by pace, kept in step with the body); their arms are posed on every client like a player's
-- (client/race/Poser).
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
local Unstuck = require(ReplicatedStorage.Shared.Unstuck)
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
local FH = Config.FLOOR_HEIGHT
local THINK = 0.25
local STUDIO = RunService:IsStudio()
local PATH = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 }
-- moving like a person (steer)
local TURN_RATE = 9 -- radians a second a running bot's heading swings (a U-turn on the run takes ~1/3 s)
local ACCEL = 6 -- how fast it gets up to pace (of full speed, per second)
local DECEL = 9 -- and down again
local SLOW_FROM = 5 -- studs from the end of a walk it starts easing off
local WALK_PACE = { 0.42, 0.58 } -- of full speed, strolling about with nothing going on
local SEPARATE = 3 -- studs: it steps round anyone closer than this
-- fighting
local PREFER = { pistol = 26, rifle = 34, smg = 18, shotgun = 9 } -- studs: where each gun does its work
local HEAR = 70 -- studs: a shot this close on its floor turns its head
local COVER_WITHIN = 30 -- studs: how far it'll go for cover
local INNER = Config.FLOOR_HALF - Config.WALL - 2

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
	-- a stroll is a walk, anything quicker a run
	local function moving(speed: number)
		if speed > 10.5 or (speed > 0.75 and not tracks.walk) then
			play(if tracks.run then "run" else "walk", 0.25)
		elseif speed > 0.75 then
			play("walk", 0.25)
		else
			play("idle", 0.3)
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

-- The walk or run cycle keeps pace with the body (it played at one speed whatever the pace), and runs
-- backward while the bot backs off from someone it's fighting (it faces them; every client turns its legs
-- to match: client/race/Poser). Only sent on a real change: the server's track speeds replicate.
local function gait(c: Climber)
	local b, root = c.brain, c.root
	local tracks = b and b.tracks
	if not tracks or not root then
		return
	end
	local tr, nominal = nil, Config.WALK_SPEED
	if tracks.run and tracks.run.IsPlaying then
		tr = tracks.run
	elseif tracks.walk and tracks.walk.IsPlaying then
		tr, nominal = tracks.walk, Config.WALK_SPEED / 2
	end
	if not tr then
		return
	end
	local v = root.AssemblyLinearVelocity
	local flatV = Vector3.new(v.X, 0, v.Z)
	local speed = flatV.Magnitude
	local backward = speed > 2 and flatV.Unit:Dot(root.CFrame.LookVector) < -0.35
	local rate = math.clamp(speed / nominal, 0.4, 1.4) * (if backward then -1 else 1)
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
		backT = 0, -- stepping back out of reach after a swing
		strafe = 1, -- which way it's sidestepping in a gunfight (+1 / -1; 0: feet planted)
		strafeT = 0,
		heard = nil :: { who: Climber, at: Vector3, t: number }?, -- a shot it heard
		cover = nil :: { spot: Vector3, from: Climber, t: number }?, -- going behind (or crouched at) cover
		wander = nil :: Vector3?,
		wanderT = 0,
		walkPace = 1,
		pause = 0, -- standing a moment at the end of a stroll
		glanceT = rr(1, 4),
		lastPos = Vector3.zero,
		stuck = 0,
		stuckN = 0, -- sidesteps lately without getting anywhere
		wedgedT = 0, -- seconds trying to move and getting nowhere (shared/Unstuck, past a few)
		detour = nil :: Vector3?, -- sidestepping that way
		detourT = 0,
		stage = nil :: Vector3?, -- its place by the shaft while a platform is due
		nav = nil :: any, -- the path it's following: { goal, at, points, i, failed }
		path = nil :: Path?,
		computing = false,
		skip = {} :: { [Instance]: number }, -- pickups it couldn't reach (until when)
		faceAt = Vector3.zero,
		faceT = 0, -- facing faceAt (not where it walks) while > 0
		align = nil :: AlignOrientation?,
		-- where its feet take it (steer, every frame)
		step = nil :: Vector3?, -- the spot it walks to right now
		through = false, -- a waypoint on the way (no easing off there)
		arrive = 1.2, -- studs: close enough
		pace = 1, -- of full speed
		move = Vector3.zero, -- the way it's moving now, eased (Humanoid:Move)
		sep = Vector3.zero, -- the nudge off anyone close
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
		align.Responsiveness = 22
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
	b.cover = nil
	b.heard = nil
	b.wander = nil
	b.pause = 0
	b.step = nil
	b.move = Vector3.zero
	b.sep = Vector3.zero
	b.stuckN = 0
	b.wedgedT = 0
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

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.CollisionGroup = "Bullet"
local function clearShot(from: Vector3, to: Vector3, skip: { Instance }): boolean
	losParams.FilterDescendantsInstances = skip
	return workspace:Raycast(from, to - from, losParams) == nil
end

-- every climber's body (sight lines look past bodies: they're what's being looked at)
local function bodies(): { Instance }
	local out = {}
	for _, o in Climbers.all() do
		if o.model then
			table.insert(out, o.model)
		end
	end
	return out
end

local function eyes(c: Climber): Vector3
	local head = c.model and c.model:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else (c.root :: BasePart).Position + Vector3.new(0, 1.5, 0)
end

-- can it see them (head to head, past everyone's bodies)?
local function sees(c: Climber, o: Climber, skip: { Instance }?): boolean
	return clearShot(eyes(c), eyes(o), skip or bodies())
end

-- the nearest one worth fighting (not already mobbed by two others) that it can see
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
	-- (someone right next to it it knows about anyway)
	if best and bd > 2.5 * M and not sees(c, best) then
		return nil
	end
	return best
end

-- face that way for a moment (it turns smoothly: the Heartbeat in Bots.init); a glance turns slower
local function face(c: Climber, at: Vector3, seconds: number?, slow: boolean?)
	local b = c.brain
	b.faceAt = at
	b.faceT = seconds or 0.6
	local align = b.align :: AlignOrientation?
	if align then
		align.Responsiveness = if slow then 7 else 22
	end
end

local function onFloor(x: number, z: number): boolean
	local clear = Config.SHAFT_CLEAR - 0.5 * M
	return math.abs(x) < INNER and math.abs(z) < INNER and (math.abs(x) > clear or math.abs(z) > clear)
end

-- the walkway round the shaft, a step back from the edge (where they wait for a platform), spread out
-- along the side nearest them
local function stageSpot(c: Climber): Vector3
	local root = c.root :: BasePart
	local p = root.Position
	local r = Config.SHAFT_HALF + rr(0.6, 1.1) * M
	local along = Config.SHAFT_HALF - 0.3 * M
	local y = c.floor * FH
	if math.abs(p.X) > math.abs(p.Z) then
		return Vector3.new(math.sign(p.X) * r, y, math.clamp(p.Z + rr(-1, 1) * M, -along, along))
	end
	return Vector3.new(math.clamp(p.X + rr(-1, 1) * M, -along, along), y, math.sign(p.Z) * r)
end

-- somewhere to stroll to: near a teammate on this floor if there is one (they keep loosely together),
-- else anywhere on the floor or by the shaft
local function strollSpot(c: Climber): Vector3
	local mates = {}
	for _, o in Climbers.all() do
		if o ~= c and o.root and not o.fighter.dead and o.floor == c.floor and Climbers.allies(c, o) then
			table.insert(mates, o)
		end
	end
	if #mates > 0 and rng:NextNumber() < 0.6 then
		local o = pick(mates)
		local base = (o.root :: BasePart).Position
		for _ = 1, 6 do
			local a = rr(0, math.pi * 2)
			local r = rr(5, 12)
			local x, z = base.X + math.cos(a) * r, base.Z + math.sin(a) * r
			if onFloor(x, z) then
				return Vector3.new(x, c.floor * FH, z)
			end
		end
	end
	return if rng:NextNumber() < 0.55 then ctx.tower.randomSpot(c.floor) else stageSpot(c)
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
		if not b.path then
			b.path = PathfindingService:CreatePath(PATH)
		end
		local path = b.path :: Path
		task.spawn(function()
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

-- the nudge off anyone closer than SEPARATE (a person steps round someone, not through them)
local function separation(c: Climber): Vector3
	local root = c.root :: BasePart
	local push = Vector3.zero
	for _, o in Climbers.all() do
		if o ~= c and o.root and not o.fighter.dead and o.floor == c.floor then
			local away = flat(root.Position - o.root.Position)
			local d = away.Magnitude
			if d < SEPARATE and d > 0.01 then
				push += away.Unit * (SEPARATE - d) / SEPARATE * 0.6
			end
		end
	end
	return push
end

-- turn v toward `to` (both flat and unit) by at most `angle` radians
local function turnToward(v: Vector3, to: Vector3, angle: number): Vector3
	local sign = if v:Cross(to).Y >= 0 then 1 else -1
	return CFrame.Angles(0, sign * angle, 0):VectorToWorldSpace(v)
end

-- Every frame: walk toward the spot think() chose, the way a person does (see the top)
local function steer(c: Climber, dt: number)
	local b, hum, root = c.brain, c.humanoid, c.root
	if not hum or not root then
		return
	end
	if c.frozen or c.fighter.dead then
		if b.move.Magnitude > 0 then
			b.move = Vector3.zero
			hum:Move(Vector3.zero)
		end
		return
	end
	local pos = root.Position
	-- (along a path: on to the next waypoint the moment it reaches one, not at the next think)
	local nav = b.nav
	if b.through and nav and b.step then
		local points = nav.points
		if nav.i < #points and flat(points[nav.i].Position - pos).Magnitude < 2 then
			nav.i += 1
			b.step = points[nav.i].Position
			b.through = nav.i < #points
		end
	end
	local want = Vector3.zero
	local step = b.step
	if step then
		local to = flat(step - pos)
		local d = to.Magnitude
		if d > b.arrive then
			local ease = if b.through then 1 else math.clamp((d - b.arrive) / SLOW_FROM + 0.35, 0.35, 1)
			want = to.Unit * ease * b.pace
		end
	end
	want += b.sep
	if want.Magnitude > 1 then
		want = want.Unit
	end
	local cur = b.move
	local wm, cm = want.Magnitude, cur.Magnitude
	local new: Vector3
	if wm < 0.05 then
		new = if cm > 0.05 then cur.Unit * math.max(0, cm - dt * DECEL) else Vector3.zero
	elseif cm < 0.1 then
		new = want.Unit * math.min(wm, math.max(cm, 0.15) + dt * ACCEL)
	else
		local cu, wu = cur.Unit, want.Unit
		local dot = cu:Dot(wu)
		if dot < -0.2 then
			-- the other way: plant and push off (a run doesn't swing round through a half circle)
			local m = cm - dt * DECEL * 1.4
			new = if m > 0.12 then cu * m else wu * 0.12
		else
			local angle = math.acos(math.clamp(dot, -1, 1))
			-- (slow, it turns on the spot; running, it swings round)
			local most = TURN_RATE * dt * (if cm < 0.5 then 2.5 else 1)
			local dir = if angle <= most then wu else turnToward(cu, wu, most)
			new = dir * (cm + math.clamp(wm - cm, -dt * DECEL, dt * ACCEL))
		end
	end
	b.move = new
	hum:Move(new)
end

---------------------------------------------------------------- fighting

local coverParams = RaycastParams.new()
coverParams.FilterType = Enum.RaycastFilterType.Exclude
coverParams.CollisionGroup = "Bullet"

-- A spot behind something solid from `from` (a foe's eyes), near the bot: beside one of the floor's
-- pieces of furniture (Tower.covers), on its far side from the foe, where a crouched body is out of
-- their sight; nil if there's none close by.
local function findCover(c: Climber, from: Vector3): Vector3?
	local pos = (c.root :: BasePart).Position
	local y = c.floor * FH
	local best, bestScore = nil, math.huge
	coverParams.FilterDescendantsInstances = bodies()
	local mine = flat(pos - from).Magnitude
	for _, r in ctx.tower.covers[c.floor] or {} do
		local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
		local d = flat(Vector3.new(cx, 0, cz) - pos).Magnitude
		if d > COVER_WITHIN then
			continue
		end
		local away = flat(Vector3.new(cx, 0, cz) - from)
		if away.Magnitude < 0.1 then
			continue
		end
		away = away.Unit
		-- (from the piece's middle out past its edge, that way, and a step more)
		local hx, hz = (r.x1 - r.x0) / 2, (r.z1 - r.z0) / 2
		local edge = math.min(
			if math.abs(away.X) > 1e-3 then hx / math.abs(away.X) else math.huge,
			if math.abs(away.Z) > 1e-3 then hz / math.abs(away.Z) else math.huge
		)
		local x, z = cx + away.X * (edge + 1.8), cz + away.Z * (edge + 1.8)
		if not onFloor(x, z) then
			continue
		end
		local spot = Vector3.new(x, y, z)
		local chest = spot + Vector3.new(0, 2.6, 0)
		if workspace:Raycast(from, chest - from, coverParams) then
			-- near is better; one that takes it toward the foe much worse
			local score = d + (if flat(spot - from).Magnitude < mine * 0.6 then 25 else 0)
			if score < bestScore then
				best, bestScore = spot, score
			end
		end
	end
	return best
end

-- crouch, or stand (the server lowers the body: CombatService; a gun won't fire till it stands)
local function crouch(c: Climber, on: boolean)
	local f = c.fighter
	if on and c.humanoid and c.humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	f.crouch = on and not f.dead and not c.frozen
end

-- go behind cover from this foe (and crouch there); false if there's nowhere
local function takeCover(c: Climber, foe: Climber, seconds: number): boolean
	local spot = findCover(c, eyes(foe))
	if not spot then
		return false
	end
	c.brain.cover = { spot = spot, from = foe, t = seconds }
	return true
end

-- a gunfight: keep to the gun's range, strafe in bursts, shoot when there's a clear line. Returns where to go.
local function gunfight(c: Climber, foe: Climber, keep: Vector3?, skip: { Instance }): Vector3?
	local b, f = c.brain, c.fighter
	local root, froot = c.root :: BasePart, foe.root :: BasePart
	local d = flat(froot.Position - root.Position).Magnitude
	local gw = Weapons[f.gun :: string]
	if f.mag <= 0 then
		-- empty: reload, from behind something if there's anything near
		Combat.startReload(f)
		b.burst = 0
		if not keep and not b.cover and f.reloadT > 0.6 then
			takeCover(c, foe, f.reloadT + rr(0.2, 0.6))
		end
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
		if clear and f.crouch then
			-- up from cover to shoot (it fires once it's standing)
			crouch(c, false)
			b.fireT = math.max(b.fireT, 0.25)
		elseif clear and b.fireT <= 0 and not f.crouch then
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
	if keep then
		return keep
	end
	-- out of sight: go round to where it can see them
	if not b.sighted then
		b.pace = 1
		return froot.Position
	end
	-- in sight: to the gun's range (in or out), sidestepping in bursts, now and then planting its feet
	local want = PREFER[gw.name] or 24
	local toward = flat(froot.Position - root.Position)
	toward = if toward.Magnitude > 0.01 then toward.Unit else Vector3.xAxis
	local side = toward:Cross(Vector3.yAxis)
	b.strafeT -= THINK
	if b.strafeT <= 0 then
		local r = rng:NextNumber()
		if b.strafe ~= 0 and r < 0.45 then
			b.strafe = -b.strafe -- the other way
		elseif r < 0.65 + b.skill * 0.15 then
			b.strafe = if b.strafe ~= 0 then b.strafe elseif rng:NextNumber() < 0.5 then 1 else -1
		else
			b.strafe = 0 -- feet planted: a steadier shot (the clumsier ones do it more)
		end
		b.strafeT = if b.strafe == 0 then rr(0.4, 0.9) else rr(0.5, 1.5)
	end
	-- (shot at just now: a quick hop now and then throws the aim off)
	if f.hitAge < 0.4 and rng:NextNumber() < 0.05 + b.skill * 0.08 then
		(c.humanoid :: Humanoid).Jump = true
	end
	-- (reloading in the open: it backs off while it does)
	local range = 0
	if f.reloadT > 0 or d < want * 0.6 then
		range = -1
	elseif d > want * 1.3 then
		range = 1
	end
	b.pace = if b.strafe == 0 and range == 0 then 0 else 0.85
	return root.Position + toward * range * 6 + side * b.strafe * 5
end

-- up close with the bat or the sword: in, a swing, a step back out of reach, in again
local function meleeFight(c: Climber, foe: Climber, keep: Vector3?): Vector3?
	local b, f = c.brain, c.fighter
	local root, froot = c.root :: BasePart, foe.root :: BasePart
	local d = flat(froot.Position - root.Position).Magnitude
	Tools.equip(c, "melee")
	crouch(c, false)
	local w = Combat.weapon(f)
	if w and w.slot == "melee" and d < w.reach + Config.BODY_R and b.swingT <= 0 then
		face(c, froot.Position)
		local dir = froot.Position - root.Position
		if CombatService.swing(c, math.atan2(dir.X, dir.Z)) then
			b.swingT = rr(0.1, 0.5) * (1.3 - b.skill)
			-- (and out of their reach while it recovers, now and then)
			if rng:NextNumber() < 0.35 + b.skill * 0.35 then
				b.backT = w.windup + w.strike + w.recover * rr(0.6, 1)
			end
		end
	end
	-- read a swing coming and guard it, or step out of it (the skilled ones)
	local fa = foe.fighter.atk
	if fa and fa.w.slot == "melee" and fa.t < fa.w.windup and d < fa.w.reach + 3 then
		if Combat.canBlock(f) and rng:NextNumber() < b.skill * 0.4 then
			f.blocking = true
			b.guardT = 0.5
		elseif rng:NextNumber() < b.skill * 0.25 then
			b.backT = math.max(b.backT, 0.35)
		end
	end
	if keep then
		return keep
	end
	b.pace = 1
	local reach = if w and w.slot == "melee" then w.reach else 1.5 * M
	local away = flat(root.Position - froot.Position)
	if away.Magnitude < 0.01 then
		return froot.Position
	end
	face(c, froot.Position)
	if b.backT > 0 then
		return froot.Position + away.Unit * (reach + 3) + away.Unit:Cross(Vector3.yAxis) * (c.id % 3 - 1) * 2
	end
	return froot.Position + away.Unit * math.min(reach * 0.6, d)
end

local function fight(c: Climber, foe: Climber, keep: Vector3?): Vector3?
	local f = c.fighter
	local root, froot = c.root :: BasePart, foe.root :: BasePart
	local d = flat(froot.Position - root.Position).Magnitude
	local hasAmmo = f.gun ~= nil and (f.mag > 0 or f.reserve > 0)
	local skip = { c.model :: Model, foe.model :: Model }
	for _, o in Climbers.all() do
		if o.model and Climbers.allies(c, o) then
			table.insert(skip, o.model) -- (its bullets fly through teammates)
		end
	end
	-- a gun unless it's out of rounds, or it's a pistol (or empty) with them right on top of it
	local close = d < 1.8 * M or (d < 3.5 * M and f.mag <= 0)
	if hasAmmo and not (close and f.gun ~= "shotgun" and (f.gun == "pistol" or f.mag <= 0)) then
		Tools.equip(c, "gun")
		return gunfight(c, foe, keep, skip)
	end
	return meleeFight(c, foe, keep)
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
	-- a teammate under attack nearby: go for whoever's hurting them
	local root = c.root :: BasePart
	for _, o in Climbers.all() do
		if o ~= c and o.root and Climbers.allies(c, o) and o.floor == c.floor and o.fighter.hitAge < 2.5 then
			local by = o.fighter.hitBy and CombatService.climberOf(o.fighter.hitBy)
			if
				by
				and valid(c, by)
				and flat(o.root.Position - root.Position).Magnitude < 45
				and rng:NextNumber() < 0.35 + b.aggression * 0.5
			then
				b.target = by
				b.fightT = rr(5, 9)
				return
			end
		end
	end
	-- a shot it heard: once it sees the shooter, it's on them (the bold ones, anyway)
	local heard = b.heard
	if heard and heard.t > 0 and valid(c, heard.who) then
		if sees(c, heard.who) and rng:NextNumber() < 0.3 + b.aggression * 0.6 then
			b.target = heard.who
			b.fightT = rr(5, 9)
			b.heard = nil
			return
		end
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
		b.step = nil
		crouch(c, false)
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
	local foe = b.target
	-- badly hurt: break off and get out of its sight (unless riding)
	local scared = f.hp / f.maxHp < b.courage and not riding
	b.pace = 1
	b.arrive = 1.2

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
			b.arrive = 0.8
		end
	else
		local s = PlatformService.stoppedAt(c.floor)
		if s and c.floor < FLOORS then
			local spot = s.deck.Position + b.spot
			if s.leaving > flat(spot - pos).Magnitude / Config.WALK_SPEED + 0.3 then
				goal = spot
				mode = "board"
				b.arrive = 0.8
			end
		end
		if not goal and Platforms.nextArrival(t, c.floor, roofOpen) < 4 then
			-- (its own place by the shaft, kept while it waits: a new one each think had it shuffling about)
			if not b.stage or math.abs(b.stage.Y - c.floor * FH) > 1 then
				b.stage = stageSpot(c)
			end
			goal = b.stage
			mode = "stage"
			b.arrive = 1.5
		end
	end
	if mode ~= "stage" then
		b.stage = nil
	end
	local boarding = mode == "board" or mode == "ride" or mode == "hop off"
	local rushing = mode == "board" -- (it's leaving: flat out onto the deck, no easing off)
	if boarding then
		b.cover = nil
		b.nav = nil -- (straight there: no path round the floor)
		crouch(c, false)
	end

	-- behind cover: crouched there until the gun's reloaded (or it's healed a while), unless they come at it
	local cover = b.cover
	if cover and not boarding then
		cover.t -= THINK
		local threat = cover.from
		local near = threat.root and flat(threat.root.Position - pos).Magnitude < 2.5 * M
		-- (they've come round it, and it has rounds: no use hiding)
		local seen = valid(c, threat) and f.reloadT <= 0 and f.mag > 0 and sees(threat, c)
		if cover.t <= 0 or not valid(c, threat) or near or seen then
			b.cover = nil
			crouch(c, false)
		else
			goal = cover.spot
			b.arrive = 0.9
			mode = "cover"
			if flat(cover.spot - pos).Magnitude < 1.6 then
				crouch(c, true)
				face(c, eyes(threat), 0.4, true)
			end
		end
	end

	if b.cover then
		-- (reloading or healing behind it)
		if f.mag <= 0 then
			Combat.startReload(f)
		end
	elseif scared and foe then
		-- out of its sight, else just away from it
		if not takeCover(c, foe, rr(4, 7)) then
			if not b.wander or b.wanderT <= 0 then
				local away = flat(pos - (foe.root :: BasePart).Position)
				away = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
				local x = math.clamp(pos.X + away.X * 24, -INNER, INNER)
				local z = math.clamp(pos.Z + away.Z * 24, -INNER, INNER)
				b.wander = Vector3.new(x, c.floor * FH, z)
				b.wanderT = 3
			end
			goal = b.wander
			mode = "flee"
		end
		b.target = nil
	elseif foe then
		-- boarding or riding it keeps going and fights on the way; anywhere else it goes after them
		goal = fight(c, foe, if boarding then goal else nil)
		mode ..= " + fight " .. foe.name
		-- hurt and holding a gun: it falls back behind something to get its breath (health comes back)
		if
			not boarding
			and not b.cover
			and f.hp < f.maxHp * 0.45
			and f.hitAge > 1
			and f.gun
			and rng:NextNumber() < 0.15 * (1.2 - b.aggression)
		then
			takeCover(c, foe, rr(3, 6))
		end
	else
		Tools.equip(c, if f.gun and f.mag + f.reserve > 0 then "gun" else "melee")
		if f.crouch and not b.cover then
			crouch(c, false)
		end
		-- reload when it's quiet
		if f.gun and f.mag < Weapons[f.gun].mag * 0.5 then
			Combat.startReload(f)
		end
	end

	-- things worth picking up on the way
	local want: Pickups.Pickup? = nil
	if not foe and not b.cover then
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
				b.arrive = 2
			else
				want = nil
			end
		end
	end

	-- a shot it heard (and nobody to fight yet): it turns to look
	local heard = b.heard
	if heard then
		heard.t -= THINK
		if heard.t <= 0 then
			b.heard = nil
		elseif not foe and not boarding then
			face(c, heard.at, 0.5, true)
		end
	end

	local strolling = false
	if not goal then
		-- a stroll: somewhere to go, a moment's stop at the end of it, and off again
		if b.wander and flat(b.wander - pos).Magnitude < 2.5 and b.pause <= 0 and b.wanderT > 0 then
			b.pause = rr(0.6, 2.8)
			b.wanderT = 0
		end
		if b.pause > 0 then
			b.pause -= THINK
			b.glanceT -= THINK
			if b.glanceT <= 0 then
				b.glanceT = rr(1.2, 3)
				local a = rr(0, math.pi * 2)
				face(c, pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 10, rr(0.6, 1.2), true)
			end
			goal = nil
			mode = "look round"
		else
			if not b.wander or b.wanderT <= 0 then
				b.wander = strollSpot(c)
				b.wanderT = rr(5, 9)
				b.walkPace = rr(WALK_PACE[1], WALK_PACE[2])
			end
			goal = b.wander
			strolling = true
		end
	end
	if strolling or mode == "stage" then
		b.pace = if strolling then b.walkPace else 0.8
	end
	if mode == "stage" and b.stage and flat(b.stage - pos).Magnitude < 2 then
		-- waiting at the shaft: watching for it
		face(c, Vector3.new(0, pos.Y, 0), 0.4, true)
	end

	-- can't get there: give it up (a new spot to stroll to, the pickup left alone for a while)
	local function giveUp()
		if want then
			b.skip[want.part] = t + 15
		end
		if mode == "wander" or mode == "flee" then
			b.wanderT = 0
		end
		if mode == "cover" then
			b.cover = nil
			crouch(c, false)
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

	if not goal then
		b.step = nil
		b.through = false
		b.sep = separation(c)
		b.lastPos = pos
		return
	end
	local target = goal :: Vector3
	if not foe and not boarding then
		target = spread(c, target)
	end

	-- on its way: straight onto a platform, round things on the floor
	local step = target
	b.through = false
	if b.detour and b.detourT > 0 then
		step = pos + b.detour
		b.pace = 1
	elseif not boarding then
		local skip: { Instance } = { folder }
		for _, o in Climbers.all() do
			if o.model and o.kind ~= "bot" then
				table.insert(skip, o.model)
			end
		end
		step = route(c, target, skip)
		b.through = flat(step - target).Magnitude > 1
		if unreachable(c, target) then
			giveUp()
		end
	end
	b.step = step
	if rushing then
		b.through = true
	end
	-- (on a deck everyone's close: no shuffling round each other there)
	b.sep = if boarding then Vector3.zero else separation(c)

	-- stuck against something: hop it, then sidestep for a moment; still stuck, give the spot up
	local trying = b.move.Magnitude > 0.3 and flat(target - pos).Magnitude > 3
	if trying and (pos - b.lastPos).Magnitude < 0.4 * b.pace then
		-- (wedged somewhere it can't get out of, however it tries: set down on open floor nearby)
		b.wedgedT += THINK
		if b.wedgedT >= 2.5 and not riding then
			b.wedgedT = 0
			local skip = bodies()
			for _, name in { "Fx", "Pickups", "Platforms" } do
				local held = workspace:FindFirstChild(name)
				if held then
					table.insert(skip, held)
				end
			end
			local cf = Unstuck.trapped(root, hum, skip) and Unstuck.freeSpot(root, hum, skip)
			if cf and c.model then
				c.model:PivotTo(cf)
				root.AssemblyLinearVelocity = Vector3.zero
				b.nav = nil
				b.stuckN = 0
			end
		end
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
		b.wedgedT = 0
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

-- someone fired: the bots on that floor within earshot turn to it (and may go for the shooter: pickTarget)
local function heardShot(shooter: Climber, from: Vector3)
	for _, c in Climbers.all() do
		local b = c.brain
		if
			c.kind == "bot"
			and b
			and c ~= shooter
			and c.root
			and c.floor == shooter.floor
			and not Climbers.allies(c, shooter)
			and b.target == nil
			and (c.root.Position - from).Magnitude < HEAR
		then
			b.heard = { who = shooter, at = from, t = rr(1.2, 2.2) }
		end
	end
end

function Bots.init(context: Context)
	ctx = context
	Bots.clear()
	CombatService.onShot = heardShot
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
			b.backT -= dt
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
			steer(c, dt)
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
