--!strict
-- The bots that fill a race up to 20 climbers. They want up: they catch every platform they can, crowd
-- the shaft when one is due, ride it (most all the way, some hop off after a few floors), and fight
-- whoever is in the way. Hit one and it hits back. Each has its own temper (aggression, skill, courage),
-- like the original's bots.js. With a gun and ammo they shoot from range; close up they swing the bat.
-- They pick up ammo when low and swords over the bat.
--
-- Bots are Roblox avatars built from HumanoidDescriptions, with Roblox's default animations for the legs
-- and body (the ids are read from the rig's own Animate script and played from the server); their arms
-- are posed on every client like a player's (client/race/Poser).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
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

-- build a handful of avatar rigs once; every bot is a clone of one of them
function Bots.prepare()
	local store = ServerStorage:FindFirstChild("BotTemplates") or Instance.new("Folder")
	store.Name = "BotTemplates"
	store.Parent = ServerStorage
	for _ = 1, 8 do
		local desc = Instance.new("HumanoidDescription")
		local skin, top, pants = pick(SKINS), pick(TOPS), pick(PANTS)
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = top
		desc.LeftLegColor = pants
		desc.RightLegColor = pants
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			model.Parent = store
			table.insert(templates, model)
		else
			warn("[Rooftop] couldn't build a bot rig:", model)
		end
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
		end
	end
	hum.Running:Connect(function(speed: number)
		if hum.FloorMaterial == Enum.Material.Air then
			return
		end
		if speed > 0.75 then
			play(if tracks.run then "run" else "walk")
		else
			play("idle")
		end
	end)
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			play("jump", 0.1)
		elseif new == Enum.HumanoidStateType.Freefall then
			play("fall", 0.2)
		elseif new == Enum.HumanoidStateType.Landed then
			play("idle", 0.1)
		end
	end)
	-- (the arms holding and swinging weapons are posed on every client: client/race/Poser)
	play("idle")
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
		think = rr(0, THINK),
		fireT = 0,
		burst = 0, -- shots left in this burst (full-auto guns)
		swingT = 0,
		guardT = 0,
		wander = nil :: Vector3?,
		wanderT = 0,
		lastPos = Vector3.zero,
		stuck = 0,
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
	model.Parent = folder
	ctx.setup(c, model)
	local root = c.root
	if root then
		root:SetNetworkOwner(nil)
	end
	c.brain.target = nil
	c.brain.rode = 0
	c.brain.lastStop = -1
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
	if not o or o == c or not o.root or o.fighter.dead or o.frozen or o.fighter.invuln > 0 then
		return false
	end
	return o.floor == c.floor
end

local function nearest(c: Climber, within: number): Climber?
	local root = c.root :: BasePart
	local best, bd = nil, within
	for _, o in Climbers.all() do
		if valid(c, o) then
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

local function face(c: Climber, at: Vector3)
	local root, hum = c.root :: BasePart, c.humanoid :: Humanoid
	hum.AutoRotate = false
	local p = root.Position
	root.CFrame = CFrame.lookAt(p, Vector3.new(at.X, p.Y, at.Z))
end

-- the walkway round the shaft, a step back from the edge (where they wait for a platform)
local function stageSpot(c: Climber): Vector3
	local root = c.root :: BasePart
	local p = root.Position
	local r = Config.SHAFT_HALF + rr(0.6, 1.1) * M
	local along = Config.SHAFT_HALF - 0.3 * M
	local y = c.floor * Config.FLOOR_HEIGHT
	if math.abs(p.X) > math.abs(p.Z) then
		return Vector3.new(math.sign(p.X) * r, y, math.clamp(p.Z, -along, along))
	end
	return Vector3.new(math.clamp(p.X, -along, along), y, math.sign(p.Z) * r)
end

local function fight(c: Climber, foe: Climber, goal: Vector3?): Vector3?
	local b, f = c.brain, c.fighter
	local root, froot = c.root :: BasePart, foe.root :: BasePart
	local d = flat(froot.Position - root.Position).Magnitude
	local hasAmmo = f.gun ~= nil and (f.mag > 0 or f.reserve > 0)
	local skip = { c.model :: Model, foe.model :: Model }
	if hasAmmo and d > 3.5 * M then
		Tools.equip(c, "gun")
		local gw = Weapons[f.gun :: string]
		if f.mag <= 0 then
			Combat.startReload(f)
			b.burst = 0
		elseif b.fireT <= 0 and d < gw.range then
			local head = (c.model :: Model):FindFirstChild("Head") :: BasePart?
			local aim = froot.Position + Vector3.new(0, rr(-0.5, 1.5), 0)
			if head and clearShot(head.Position, aim, skip) then
				face(c, aim)
				CombatService.botFire(c, aim, b.skill)
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
	return goal or froot.Position
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
	hum.AutoRotate = true
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

	-- who to fight: whoever hurt us lately comes first; the aggressive ones pick fights
	local foe = if f.hitBy and f.hitAge < 7 then CombatService.climberOf(f.hitBy) else nil
	if foe and valid(c, foe) then
		b.target = foe
	elseif b.target and not valid(c, b.target) then
		b.target = nil
	end
	if not b.target and rng:NextNumber() < b.aggression * 0.02 then
		b.target = nearest(c, 7 * M)
	end
	-- only one can escape: on the top-floor platform with the roof open, clear everyone else off it
	if riding and roofOpen and riding.stop == FLOORS - 1 then
		local root0 = root.Position
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
		end
	end
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
			goal = stageSpot(c)
			mode = "stage"
		end
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
		local close = flat((b.target.root :: BasePart).Position - pos).Magnitude < 8 * M
		if not goal or close or riding then
			goal = fight(c, b.target, if riding then goal else nil)
			mode ..= " + fight " .. b.target.name
		end
	else
		Tools.equip(c, if f.gun and f.mag + f.reserve > 0 then "gun" else "melee")
	end

	-- things worth picking up on the way
	if not goal or not b.target then
		local want = if f.reserve < 12 then Pickups.nearest(c, 30, "ammo") else nil
		want = want or (if f.melee == "bat" then Pickups.nearest(c, 25, "sword") else nil)
		-- a better gun than the one it carries
		local mine = if f.gun then Weapons[f.gun].tier else 0
		want = want
			or Pickups.nearestWhere(c, 30, function(kind: string): boolean
				local w = Weapons[kind]
				return w ~= nil and w.slot == "gun" and w.tier > mine
			end)
		if want then
			if (want.part.Position - pos).Magnitude < 6 then
				Pickups.take(c, want)
			elseif not goal then
				goal = want.part.Position
				mode = "pickup " .. want.kind
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

	-- what it's up to, for debugging (Studio only: in the live game it would be replicated for nothing)
	if STUDIO and c.model and c.model:GetAttribute("BotMode") ~= mode then
		c.model:SetAttribute("BotMode", mode)
	end
	hum:MoveTo(goal :: Vector3)
	-- stuck against cover: hop
	if flat(goal :: Vector3 - pos).Magnitude > 3 and (pos - b.lastPos).Magnitude < 0.4 then
		b.stuck += THINK
		if b.stuck > 0.5 then
			hum.Jump = true
			b.stuck = 0
		end
	else
		b.stuck = 0
	end
	b.lastPos = pos
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
		end
	end)
end

return Bots
