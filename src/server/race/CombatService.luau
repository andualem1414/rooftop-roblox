--!strict
-- Fighting, on the server. Clients only say what they want (swing toward here, shoot along this camera
-- ray, guard, reload); the server decides what happens:
--   swings: the timing is the server's (shared/Combat), and who gets hit is worked out from the server's
--           own positions when the blow lands
--   shots:  checked for rate and ammo; the camera ray must start near your head; the bullet then goes
--           from YOUR gun (or head) toward where that ray points, with the server's own spread, and hits
--           the first thing in its way: no shooting through walls, no hitting from out of range
-- Health lives in the fighter state and is mirrored onto the Humanoid; 0 hp is a knock-out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Climbers = require(script.Parent.Climbers)
local Tools = require(script.Parent.Tools)

type Climber = Climbers.Climber
type Fighter = Combat.Fighter

export type Hooks = {
	onKnockedOut: (c: Climber, by: Climber?) -> (),
}

local CombatService = {}

local hooks: Hooks
local rng = Random.new()
local owner: { [Fighter]: Climber } = {}
local MAX_CAMERA_DISTANCE = 40 -- how far a shot's camera ray may start from your head (zoomed-out camera)
local CHEST = 1.5 * Config.M -- melee line of sight is checked at chest height (low cover doesn't block it)

local KnockEvent = Net.event("Knock")
local ShotFx = Net.event("ShotFx")
local SwingFx = Net.event("SwingFx")
local HitFx = Net.event("HitFx")
local Feed = Net.event("Feed")

local function rand(): number
	return rng:NextNumber()
end

local function climberOf(f: Fighter): Climber?
	return owner[f]
end
CombatService.climberOf = climberOf

-- raycast params that skip every climber (for walls between two of them) or one shooter
local function params(skip: { Instance }): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = skip
	p.CollisionGroup = "Bullet"
	p.IgnoreWater = true
	return p
end

local function allModels(): { Instance }
	local out = {}
	for _, c in Climbers.all() do
		if c.model then
			table.insert(out, c.model)
		end
	end
	return out
end

-- something tall (a half wall, an outer wall) between two fighters
local function losBlocked(a: Fighter, b: Fighter): boolean
	local from = Vector3.new(a.x, a.y + CHEST, a.z)
	local to = Vector3.new(b.x, b.y + CHEST, b.z)
	local hit = workspace:Raycast(from, to - from, params(allModels()))
	return hit ~= nil and hit.Instance.CollisionGroup ~= "Crates"
end

local function headOf(c: Climber): BasePart?
	local model = c.model
	local head = model and model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- push a climber along (vx, vz): their own client moves a player's body, the server a bot's
local function knock(c: Climber, v: Vector3)
	if c.kind == "player" and c.player then
		KnockEvent:FireClient(c.player, v)
	elseif c.root then
		c.root.AssemblyLinearVelocity += v
	end
end

function CombatService.knockOut(c: Climber, by: Climber?, why: string?)
	local f = c.fighter
	if c.knockedAt then
		return
	end
	if RunService:IsStudio() and not by then
		print(`[Rooftop] {c.name} went down ({why or "?"}) at {c.root and c.root.Position}`)
	end
	f.dead = true
	f.hp = 0
	f.atk = nil
	f.blocking = false
	c.knockedAt = os.clock()
	if c.humanoid then
		c.humanoid.Health = 0
	end
	if by and by ~= c then
		by.knockouts += 1
		Feed:FireAllClients(`{by.name} knocked out {c.name}`, "ko")
	else
		Feed:FireAllClients(`{c.name} went down`, "ko")
	end
	hooks.onKnockedOut(c, by)
end

local function landed(att: Climber, vic: Climber, r: Combat.HitResult, nx: number, nz: number, at: Vector3)
	local hum = vic.humanoid
	if hum and not vic.fighter.dead then
		hum.Health = vic.fighter.hp
	end
	knock(vic, Vector3.new(nx * r.knock, if r.blocked then 0 else 6, nz * r.knock))
	local kind = if r.blocked then "block" elseif r.headshot then "head" else "hit"
	HitFx:FireAllClients(at, r.dmg, kind, vic.model, att.model)
	if r.killed then
		CombatService.knockOut(vic, att)
	end
end

local function others(): { Fighter }
	local out = {}
	for _, c in Climbers.all() do
		if c.model and not c.frozen then
			table.insert(out, c.fighter)
		end
	end
	return out
end

local function landMelee(c: Climber, a: Combat.Attack)
	for _, h in Combat.findVictims(c.fighter, a, others(), losBlocked) do
		local vic = climberOf(h.v)
		if not vic then
			continue
		end
		local r = Combat.applyHit(c.fighter, a.w, h.v, h.nx, h.nz)
		local at = Vector3.new(h.v.x, h.v.y + CHEST, h.v.z)
		landed(c, vic, r, h.nx, h.nz, at)
	end
end

-- every screen plays the swing on this climber's arms (client Poser), in step with the server's clock
local function swingAnim(c: Climber, a: Combat.Attack)
	if c.model then
		SwingFx:FireAllClients(c.model, a.w.name, a.side)
	end
end

-- the closest climber in front within reach: a swing near someone snaps to them
local function snapHeading(c: Climber, yaw: number): number
	local f = c.fighter
	local w = Combat.weapon(f)
	if not w then
		return yaw
	end
	local hx, hz = math.sin(yaw), math.cos(yaw)
	local best, bd = yaw, w.reach + Config.BODY_R + 2
	for _, o in Climbers.all() do
		local g = o.fighter
		if o == c or g.dead or o.frozen or math.abs(g.y - f.y) > Config.SAME_LEVEL then
			continue
		end
		local dx, dz = g.x - f.x, g.z - f.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < bd and d > 1e-3 and (dx * hx + dz * hz) / d > math.cos(math.rad(70)) then
			best, bd = math.atan2(dx, dz), d
		end
	end
	return best
end

function CombatService.swing(c: Climber, yaw: number): boolean
	local f = c.fighter
	if c.frozen or f.equipped ~= "melee" then
		return false
	end
	local a = Combat.startAttack(f, snapHeading(c, yaw))
	if a then
		swingAnim(c, a)
	end
	return a ~= nil
end

-- fire the gun in hand toward a point; err scales the spread (1 = the weapon's own)
local function fire(c: Climber, aimPoint: Vector3, err: number)
	local f = c.fighter
	local w = Combat.weapon(f)
	local head = headOf(c)
	if not w or w.slot ~= "gun" or not head or not c.model then
		return
	end
	local skip = params({ c.model })
	local start = head.Position
	local muzzle = Tools.muzzle(c)
	-- the barrel can poke through a wall you stand against: then the shot starts from your head
	if muzzle and not workspace:Raycast(start, muzzle - start, skip) then
		start = muzzle
	end
	local toAim = aimPoint - start
	if toAim.Magnitude < 0.1 then
		return
	end
	local base = CFrame.lookAt(Vector3.zero, toAim.Unit)
	local struck: { [Climber]: boolean } = {}
	for _ = 1, math.max(1, w.pellets) do
		local yaw, pitch = Combat.spread(w, err, rand)
		local dir = (base * CFrame.Angles(pitch, yaw, 0)).LookVector
		local hit = workspace:Raycast(start, dir * w.range, skip)
		local stop = if hit then hit.Position else start + dir * w.range
		local vic = if hit then Climbers.fromPart(hit.Instance) else nil
		ShotFx:FireAllClients(c.model, start, stop, if vic then "body" elseif hit then "wall" else "none", w.name)
		if not vic or vic == c or vic.frozen or vic.fighter.dead or vic.fighter.invuln > 0 or struck[vic] then
			continue
		end
		struck[vic] = w.pellets <= 1 -- (shotguns: every pellet counts)
		local vh = headOf(vic)
		local headshot = vh ~= nil and hit ~= nil and hit.Position.Y > vh.Position.Y - vh.Size.Y / 2
		local d = Vector3.new(vic.fighter.x - f.x, 0, vic.fighter.z - f.z)
		local n = if d.Magnitude > 1e-3 then d.Unit else Vector3.new(dir.X, 0, dir.Z).Unit
		local r = Combat.applyHit(f, w, vic.fighter, n.X, n.Z, headshot)
		landed(c, vic, r, n.X, n.Z, stop)
	end
end

-- start a shot if the gun is ready (a shot that arrives a hair early, from network jitter, still counts)
local function startShot(c: Climber, dir: Vector3): boolean
	local f = c.fighter
	local a = f.atk
	if a and a.w.slot == "gun" and a.t >= a.total - 0.06 then
		f.atk = nil
		f.cool = 0
	end
	return Combat.startAttack(f, math.atan2(dir.X, dir.Z)) ~= nil
end

-- a player's shot: the camera ray tells where they aim; the server finds that point and fires at it
local function onShoot(player: Player, origin: unknown, dir: unknown, aiming: unknown)
	local c = Climbers.forPlayer(player)
	if not c or c.frozen or typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then
		return
	end
	local o, d = origin :: Vector3, dir :: Vector3
	if d.Magnitude < 0.5 or d.Magnitude > 1.5 or o ~= o or d ~= d then
		return
	end
	d = d.Unit
	local f = c.fighter
	local head = headOf(c)
	if f.dead or f.equipped ~= "gun" or not head or not c.model then
		return
	end
	if (o - head.Position).Magnitude > MAX_CAMERA_DISTANCE then
		return
	end
	local w = Combat.weapon(f)
	if not w or not startShot(c, d) then
		return
	end
	-- where the camera ray points (skipping yourself); not behind you, not past the gun's range
	local hit = workspace:Raycast(o, d * (w.range + MAX_CAMERA_DISTANCE), params({ c.model }))
	local p = if hit then hit.Position else o + d * (w.range + MAX_CAMERA_DISTANCE)
	if (p - head.Position):Dot(d) < 0 then
		p = head.Position + d * w.range
	end
	fire(c, p, if aiming == true then 0.15 else 1)
	Tools.publish(c)
end

-- a bot's shot at a point; skill 0..1 steadies its aim
function CombatService.botFire(c: Climber, at: Vector3, skill: number): boolean
	if c.frozen or c.fighter.equipped ~= "gun" or c.fighter.dead then
		return false
	end
	local root = c.root
	if not root or not startShot(c, at - root.Position) then
		return false
	end
	local head = headOf(c)
	if head and c.model then
		local d = at - head.Position
		c.model:SetAttribute("Aim", math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude))
	end
	fire(c, at, 1.75 - skill)
	return true
end

-- what CombatService knows about whose fighter is whose
function CombatService.register(c: Climber)
	owner[c.fighter] = c
end

function CombatService.unregister(c: Climber)
	owner[c.fighter] = nil
end

local publishT = 0
local function step(dt: number)
	Climbers.sync()
	publishT += dt
	local publish = publishT > 0.1
	if publish then
		publishT = 0
	end
	for _, c in Climbers.all() do
		local f, hum, root = c.fighter, c.humanoid, c.root
		if not hum or not root or not c.model then
			continue
		end
		f.equipped = Tools.inHand(c)
		if c.frozen then
			f.atk = nil
			f.blocking = false
		end
		local blow = Combat.tick(f, dt)
		if blow then
			landMelee(c, blow)
		end
		if not f.dead then
			if hum.Health ~= f.hp then
				hum.Health = f.hp
			end
			hum.WalkSpeed = if c.frozen then 0 else Config.WALK_SPEED * Combat.moveScale(f)
			hum.JumpHeight = if c.frozen then 0 else Config.JUMP_HEIGHT
			-- fell out of the tower (or down the pit)
			if root.Position.Y < -2 * Config.FLOOR_HEIGHT - 10 then
				CombatService.knockOut(c, nil, "fell out")
			end
		end
		local model = c.model
		if model then
			if model:GetAttribute("Guard") ~= f.blocking then
				model:SetAttribute("Guard", f.blocking)
			end
			local reloading = f.reloadT > 0
			if model:GetAttribute("Reloading") ~= reloading then
				model:SetAttribute("Reloading", reloading)
			end
		end
		if publish then
			Tools.publish(c)
		end
	end
end

function CombatService.init(h: Hooks)
	hooks = h
	Net.event("Swing").OnServerEvent:Connect(function(player: Player, yaw: unknown)
		local c = Climbers.forPlayer(player)
		if c and type(yaw) == "number" and yaw == yaw and math.abs(yaw) < 100 then
			CombatService.swing(c, yaw)
		end
	end)
	Net.event("Shoot").OnServerEvent:Connect(onShoot)
	Net.unreliable("Look").OnServerEvent:Connect(function(player: Player, pitch: unknown)
		local c = Climbers.forPlayer(player)
		if c and c.model and type(pitch) == "number" and pitch == pitch then
			c.model:SetAttribute("Aim", math.clamp(pitch, -1.3, 1.3))
		end
	end)
	Net.event("Guard").OnServerEvent:Connect(function(player: Player, on: unknown)
		local c = Climbers.forPlayer(player)
		if c then
			c.fighter.blocking = on == true and not c.frozen and Combat.canBlock(c.fighter)
		end
	end)
	Net.event("Reload").OnServerEvent:Connect(function(player: Player)
		local c = Climbers.forPlayer(player)
		if c and not c.frozen then
			Combat.startReload(c.fighter)
			Tools.publish(c)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return CombatService
