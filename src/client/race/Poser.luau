--!strict
-- Every climber's body, posed on each screen on top of Roblox's own walk / run / jump animations: written
-- into the joints' Transform each frame in PreSimulation, after the animations (create.roblox.com:
-- AnimationConstraint). Offsets go on top of the animation's own pose for the frame, never on top of last
-- frame's: when Roblox skips a far climber's animation for a frame (Animator.EvaluationThrottled) or a joint
-- isn't animated at all, the pose they're added to is the one kept from before (else they'd pile up and the
-- body would twist further every frame).
--
-- Moving
--   running:   the body leans into the run, more as it speeds up, back as it brakes; banks into turns and
--              into a sidestep; the weapon bobs and sways in step
--   strafing:  the camera sets where you face, so you often move another way: the legs turn toward where
--              you go (the chest keeps facing your aim) and, backing off, the run plays in reverse (your own
--              body here, bots on the server: server/race/Bots)
--   turning:   standing, the feet stay put as you turn, then step round to catch up
--   jumping:   the knees tuck in the air and reach for the ground on the way down; a landing sinks into the
--              knees as hard as it hit (a long drop raises dust and a thud); a platform setting off or
--              stopping is felt in the knees too
--   idle:      breathing (harder for a while after a run, and when hurt), a slow shift of weight, a glance at
--              whoever is near, and now and then a fidget with the weapon in hand
-- Guns (held up in both hands and aimed where the climber looks: their Aim pitch)
--   stances:   the pistol out in both hands; the rifle, SMG and shotgun shouldered, the body turned side-on
--              behind them and the other hand as far along the gun as the arm reaches
--   carrying:  running, a gun is carried low (barrel down); it comes up the moment they shoot, aim or get hit
--   aiming:    down the sights, the gun comes up to the eye and the head tilts to it
--   firing:    each gun kicks its own way (springs: a snap and a settle): the pistol flips up, the rifle and
--              SMG push back and climb, the shotgun shoves the whole body back and its pump is racked; the
--              pistol's slide snaps back (client/race/Gunwork has the moving parts)
--   reloading: the gun tips in; the magazine comes out and drops, a fresh one comes from the belt or the
--              chest and goes in with a slap, then the slide or the bolt is worked; the shotgun is fed shells
--              one at a time and pumped
-- Melee (swing timings come from the weapon, shared/Weapons, so the arms land the blow when the server does)
--   a bat:     carried at the shoulder (on it, running), swung from behind the shoulder round through the
--              front and out the other side, then back the other way on the next swing; the hips lead the
--              swing and the body steps into the blow; a blow that lands stops dead for an instant
--   a sword:   carried point-up in front (low, running), diagonal slashes, alternating
--   guard:     the weapon held across the chest, the knees bent; a blow on it jolts it back
-- Hit
--   a bullet:  a flinch by where it hit: the head snaps back, a shoulder twists away, a leg buckles; the
--              side it came from decides which way; a shotgun blast or a melee blow rocks the whole body
--   hurt:      under a third of their health they hunch over and breathe hard
--   thrown:    set down somewhere else at once (thrown off the platform): they stagger, arms out
-- Set pieces
--   a boost:   a crouch, then up on the jets: legs together and straight, toes pointed, arms down and back;
--              a hero's landing on the new floor, one knee and one hand down
--   a skydive: spread out flat on the air, arms and legs wide, fluttering with the speed; swept back in a dive
--   down:      knocked out, the knees go and the body slumps (client/race/Fx fades it away)
--   coming to: a new body starts crouched, gets up groggy and shakes its head
--   the end:   the winner cheers on the roof; everyone else hangs their head
--   the roof:  everyone looks up as it opens
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Motion = require(ReplicatedStorage.Shared.Motion)
local Net = require(ReplicatedStorage.Shared.Net)
local Ik = require(script.Parent.Ik)
local Gunwork = require(script.Parent.Gunwork)
local CameraAim = require(script.Parent.CameraAim)
local Audio = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Audio")) :: any

local player = Players.LocalPlayer

local Poser = {}

type Key = { p: Vector3, d: Vector3, yaw: number, lean: number }
type Swing = { weapon: string, side: number, t0: number }
type Spring = Motion.Spring

type Rig = {
	model: Model,
	hum: Humanoid,
	root: BasePart,
	animator: Animator?,
	right: Ik.Arm,
	left: Ik.Arm,
	legs: { Ik.Leg },
	k: number, -- avatar scale (1 = a default R15 rig)
	waist: Ik.Joint?,
	neck: Ik.Joint?,
	rootJoint: Ik.Joint?,
	a0: { [Ik.Joint]: CFrame }, -- each joint's parent-side frame rotation
	base: { [Ik.Joint]: CFrame }, -- the animation's own pose for the frame (kept while it's throttled)
	wrote: { [Ik.Joint]: CFrame }, -- what we wrote last frame
	throttled: boolean,
	built: number,
	-- where it's going
	lastPos: Vector3?,
	vel: Vector3,
	acc: Vector3,
	lastYaw: number,
	turn: number,
	grounded: boolean,
	airT: number,
	fallVy: number,
	groundVy: number,
	groundPart: BasePart?, -- what they stand on, and how high it was last frame (a platform moves)
	groundY: number,
	gait: number,
	exertion: number,
	breath: number,
	idleT: number,
	-- the body
	legYaw: number,
	backward: boolean,
	stepT: number,
	stepFrom: number,
	lean: number,
	bank: number,
	land: Spring, -- how far the body has sunk into its knees (studs)
	hurtPitch: Spring,
	hurtYaw: Spring,
	hurtRoll: Spring,
	hurtDip: Spring,
	headSnap: Spring,
	stumble: number,
	lookYaw: number,
	lookT: number,
	glanceYaw: number,
	glanceT: number,
	-- in hand
	weapon: string?,
	tool: Tool?,
	near: boolean, -- someone close in front
	groundAcc: number, -- how fast the floor under them is speeding up (a platform)
	drawAt: number,
	armW: number, -- how much the arms are ours (blends in when a weapon is drawn)
	aimW: number, -- a gun: 0 carried low .. 1 up and aimed
	adsW: number, -- down the sights
	readyW: number, -- a melee weapon: 0 carried .. 1 at the ready
	recoil: Spring,
	recoilYaw: number,
	climb: number,
	shotAt: number,
	shotWeapon: string,
	activeAt: number, -- last shot, swing or hit: the weapon stays up a while after
	jolt: Spring, -- the weapon knocked back (a guarded blow, a magazine slapped in)
	swing: Swing?,
	trail: Trail?,
	reloadAt: number?,
	fired: { [number]: boolean }, -- the reload's moments already played
	fidget: string?,
	fidgetAt: number,
	fidgetDue: number,
	-- set pieces
	boostAt: number?,
	heroAt: number?,
	koAt: number?,
	wakeAt: number?,
}

local rigs: { [Model]: Rig } = {}
local ownSwingAt = 0 -- when your own predicted swing started
local POSE_RANGE = 170 -- studs: farther climbers keep their plain animation
local STRIDE = 8.4 -- studs a running climber covers in one full stride (two steps)
local rng = Random.new()

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function key(p: Vector3, d: Vector3, yaw: number?, lean: number?): Key
	return { p = p, d = d.Unit, yaw = yaw or 0, lean = lean or 0 }
end

---------------------------------------------------------------- what they hold, and how

-- hand positions in the upper torso's frame (X right, Y up, Z back; shoulders at about ±0.97, 0.6, 0)
-- and the direction the weapon points. yaw turns the chest (+ = to the left), lean tips it (+ = back).
local MELEE = {
	-- hands stay near the middle of the chest, within reach of short avatar arms (both hands on the
	-- shaft); the chest's twist and the bat turning carry the swing round
	bat = {
		ready = key(v(0.1, 0.35, -0.85), v(0.2, 0.95, 0.25)),
		carry = key(v(0.42, 0.72, -0.32), v(0.12, 0.55, 0.83)), -- on the shoulder
		guard = key(v(0.4, 0.75, -0.85), v(-1, 0.1, 0)),
		[1] = { -- forehand: from over the right shoulder, round through the front, out to the left
			wind = key(v(0.3, 0.55, -0.6), v(0.3, 0.6, 0.75), -0.8, 0.04),
			hit = key(v(0.05, 0.25, -1.05), v(-0.2, 0.05, -1), 0, -0.12),
			finish = key(v(-0.3, 0.4, -0.75), v(-0.95, 0.2, 0.2), 0.85, -0.08),
		},
		[-1] = { -- backhand: from over the left shoulder, back round to the right
			wind = key(v(-0.3, 0.6, -0.6), v(-0.6, 0.55, 0.55), 0.7, 0.04),
			hit = key(v(0.2, 0.25, -1.05), v(0.3, 0.05, -0.95), 0, -0.12),
			finish = key(v(0.55, 0.35, -0.7), v(0.95, 0.2, 0.2), -0.75, -0.08),
		},
		twoHanded = true,
		leftAlong = -0.35, -- the other hand: this far down the shaft from the first
		guardLeftAlong = 0.9, -- guarding: out on the barrel
		trail = Color3.fromRGB(255, 196, 90),
	},
	sword = {
		ready = key(v(0.45, 0.2, -0.9), v(-0.15, 0.6, -0.8)),
		carry = key(v(0.55, -0.15, -0.6), v(0.1, -0.55, -0.83)), -- point down
		guard = key(v(0.4, 0.7, -0.9), v(-0.9, 0.4, 0)),
		[1] = { -- high right down to low left
			wind = key(v(0.75, 0.95, -0.35), v(0.2, 0.85, 0.5), -0.55, 0.06),
			hit = key(v(0.1, 0.15, -1.15), v(-0.55, -0.2, -0.8), 0.1, -0.15),
			finish = key(v(-0.45, -0.2, -0.75), v(-0.75, -0.5, -0.4), 0.65, -0.1),
		},
		[-1] = { -- high left down to low right
			wind = key(v(-0.3, 0.9, -0.55), v(-0.4, 0.8, 0.45), 0.55, 0.06),
			hit = key(v(0.3, 0.15, -1.15), v(0.55, -0.2, -0.8), -0.1, -0.15),
			finish = key(v(0.8, -0.2, -0.5), v(0.8, -0.45, -0.35), -0.6, -0.1),
		},
		twoHanded = false,
		trail = Color3.fromRGB(110, 230, 255),
	},
}

-- How each gun is held, in the frame of a chest square to where they aim. ready: the shooting hand at the
-- grip; ads: down the sights; low: carried running, barrel along lowDir (a long gun across the body).
-- blade, lowBlade: the chest turned side-on behind the gun, aimed and carried (- = to the right: the left
-- shoulder forward, toward the barrel). support: where the other hand goes: nil cups the pistol's grip,
-- else this far along the barrel (studs) and below it, or as far as the arm reaches. (Avatar arms are
-- short: the shooting hand sits near the middle and the chest turns so the other one gets along the gun;
-- tried with the real arm solver on R15 arm lengths.) recoil: the kick (peak 1 at
-- `kick`), how fast it snaps and settles, how far the hand goes back and up, how much the gun flips and the
-- chest rocks; jitter (yaw) and climb for the full-auto guns; mag: where its magazine sits on it.
type Stance = {
	ready: Vector3,
	ads: Vector3,
	low: Vector3,
	lowDir: Vector3,
	blade: number,
	lowBlade: number,
	support: { along: number, down: number }?,
	recoil: {
		kick: number,
		freq: number,
		damping: number,
		back: number,
		up: number,
		flip: number,
		chest: number,
		head: number,
		jitter: number,
		climb: number,
	},
	mag: { along: number, up: number }?,
}
local STANCE: { [string]: Stance } = {
	pistol = {
		ready = v(0.12, 0.6, -1.2),
		ads = v(0.22, 0.92, -1.05),
		low = v(0.25, 0.05, -0.8),
		lowDir = v(-0.1, -0.75, -0.65),
		blade = 0,
		lowBlade = 0,
		support = nil,
		recoil = {
			kick = 1,
			freq = 26,
			damping = 0.42,
			back = 0.26,
			up = 0.2,
			flip = 0.45,
			chest = 0.04,
			head = 0.03,
			jitter = 0.03,
			climb = 0,
		},
		mag = { along = 0.02, up = -0.45 },
	},
	rifle = {
		ready = v(0.12, 0.48, -0.58),
		ads = v(0.15, 0.82, -0.5),
		low = v(0.25, 0.15, -0.45),
		lowDir = v(-0.55, -0.45, -0.7),
		blade = -0.62,
		lowBlade = -0.35,
		support = { along = 1.15, down = 0.22 },
		recoil = {
			kick = 0.55,
			freq = 34,
			damping = 0.6,
			back = 0.24,
			up = 0.05,
			flip = 0.16,
			chest = 0.05,
			head = 0.02,
			jitter = 0.05,
			climb = 0.012,
		},
		mag = { along = 0.95, up = -0.35 },
	},
	smg = {
		ready = v(0.12, 0.42, -0.72),
		ads = v(0.12, 0.78, -0.62),
		low = v(0.25, 0.1, -0.55),
		lowDir = v(-0.45, -0.55, -0.7),
		blade = -0.5,
		lowBlade = -0.3,
		support = { along = 0.75, down = 0.28 },
		recoil = {
			kick = 0.45,
			freq = 38,
			damping = 0.55,
			back = 0.15,
			up = 0.05,
			flip = 0.14,
			chest = 0.025,
			head = 0.015,
			jitter = 0.08,
			climb = 0.008,
		},
		mag = { along = 0.75, up = -0.65 },
	},
	shotgun = {
		ready = v(0.12, 0.55, -0.55),
		ads = v(0.12, 0.82, -0.52),
		low = v(0.25, 0.15, -0.45),
		lowDir = v(-0.55, -0.45, -0.7),
		blade = -0.62,
		lowBlade = -0.35,
		support = { along = 1.35, down = 0.16 },
		recoil = {
			kick = 1.25,
			freq = 16,
			damping = 0.45,
			back = 0.42,
			up = 0.16,
			flip = 0.5,
			chest = 0.16,
			head = 0.1,
			jitter = 0.03,
			climb = 0,
		},
		mag = nil,
	},
}
local PUMP = 0.4 -- studs the shotgun's pump travels
local SLIDE = 0.22 -- studs the pistol's slide snaps back
-- drawing a weapon: a gun comes up from the hip, a bat or sword over the shoulder (DRAW seconds)
local DRAW = 0.32
local HOLSTER = { hand = Vector3.new(0.8, -0.75, 0.05), dir = Vector3.new(0, -1, 0.12).Unit }
local OVER_SHOULDER = { hand = Vector3.new(0.5, 1.15, 0.35), dir = Vector3.new(0.1, 0.45, 0.88).Unit }

-- A reload, by gun, over its reload time (0..1): where the other hand goes (keys: a time and a spot: on
-- the gun, on the body, or back on its hold), the moments things happen (the magazine out, grabbed, in;
-- the slide or bolt worked; a shell picked up and pushed in), and moving parts (a part slid back for a
-- stretch of it).
type Spot = { kind: "hold" | "gun" | "body", p: Vector3 }
type Reload = {
	keys: { { t: number, at: Spot } },
	events: { { t: number, what: string } },
	shifts: { { part: string, from: number, to: number, back: number } },
	roll: number, -- how far the gun tips in (+ toward the face)
	dip: number, -- and down
	pull: Vector3, -- the shooting hand comes in this much
}
local HOLD: Spot = { kind = "hold", p = Vector3.zero }
local function gunSpot(along: number, up: number, side: number?): Spot
	return { kind = "gun", p = v(side or 0, up, along) }
end
local function bodySpot(x: number, y: number, z: number): Spot
	return { kind = "body", p = v(x, y, z) }
end
local BELT = bodySpot(-0.5, -0.5, -0.25)
local VEST = bodySpot(-0.2, 0.15, -0.6)

local function shells(
	first: number,
	count: number,
	span: number
): ({ { t: number, at: Spot } }, { { t: number, what: string } })
	local keys, events = {}, {}
	local each = span / count
	for i = 0, count - 1 do
		local t0 = first + i * each
		table.insert(keys, { t = t0 + each * 0.05, at = BELT })
		table.insert(keys, { t = t0 + each * 0.35, at = BELT })
		table.insert(keys, { t = t0 + each * 0.8, at = gunSpot(0.55, -0.12) })
		table.insert(keys, { t = t0 + each * 0.95, at = gunSpot(0.45, -0.05) })
		table.insert(events, { t = t0 + each * 0.35, what = "shell" })
		table.insert(events, { t = t0 + each * 0.93, what = "load" })
	end
	return keys, events
end

local RELOADS: { [string]: Reload } = {
	pistol = {
		keys = {
			{ t = 0, at = HOLD },
			{ t = 0.1, at = HOLD },
			{ t = 0.3, at = BELT },
			{ t = 0.36, at = BELT },
			{ t = 0.55, at = gunSpot(0.02, -0.6) },
			{ t = 0.62, at = gunSpot(0.02, -0.42) },
			{ t = 0.7, at = gunSpot(0.55, 0.78) },
			{ t = 0.78, at = gunSpot(0.15, 0.78) },
			{ t = 0.9, at = HOLD },
			{ t = 1, at = HOLD },
		},
		events = { { t = 0.12, what = "out" }, { t = 0.36, what = "grab" }, { t = 0.61, what = "in" } },
		shifts = { { part = "Slide", from = 0.7, to = 0.82, back = SLIDE } },
		roll = 0.55,
		dip = 0.1,
		pull = v(-0.08, -0.05, 0.35),
	},
	rifle = {
		keys = {
			{ t = 0, at = HOLD },
			{ t = 0.1, at = gunSpot(0.95, -0.45) },
			{ t = 0.16, at = gunSpot(0.95, -0.7) },
			{ t = 0.36, at = VEST },
			{ t = 0.42, at = VEST },
			{ t = 0.56, at = gunSpot(0.95, -0.6) },
			{ t = 0.62, at = gunSpot(0.95, -0.4) },
			{ t = 0.7, at = gunSpot(0.25, 0.7, 0.25) },
			{ t = 0.78, at = gunSpot(0.0, 0.7, 0.25) },
			{ t = 0.9, at = HOLD },
			{ t = 1, at = HOLD },
		},
		events = { { t = 0.15, what = "out" }, { t = 0.42, what = "grab" }, { t = 0.61, what = "in" } },
		shifts = {},
		roll = 0.45,
		dip = 0.25,
		pull = v(-0.15, -0.05, 0.2),
	},
	smg = {
		keys = {
			{ t = 0, at = HOLD },
			{ t = 0.1, at = gunSpot(0.75, -0.75) },
			{ t = 0.16, at = gunSpot(0.75, -1.0) },
			{ t = 0.36, at = VEST },
			{ t = 0.42, at = VEST },
			{ t = 0.56, at = gunSpot(0.75, -0.95) },
			{ t = 0.62, at = gunSpot(0.75, -0.7) },
			{ t = 0.7, at = gunSpot(0.3, 0.65, 0.22) },
			{ t = 0.78, at = gunSpot(0.05, 0.65, 0.22) },
			{ t = 0.9, at = HOLD },
			{ t = 1, at = HOLD },
		},
		events = { { t = 0.15, what = "out" }, { t = 0.42, what = "grab" }, { t = 0.61, what = "in" } },
		shifts = {},
		roll = 0.45,
		dip = 0.25,
		pull = v(-0.12, -0.05, 0.2),
	},
	shotgun = (function(): Reload
		local keys, events = shells(0.1, 4, 0.74)
		table.insert(keys, 1, { t = 0, at = HOLD })
		table.insert(keys, 2, { t = 0.08, at = HOLD })
		table.insert(keys, { t = 0.88, at = HOLD })
		table.insert(keys, { t = 1, at = HOLD })
		return {
			keys = keys,
			events = events,
			shifts = { { part = "Pump", from = 0.88, to = 1, back = PUMP } },
			roll = -0.55, -- (rolled away: the loading port faces up)
			dip = 0.15,
			pull = v(-0.1, -0.05, 0.2),
		}
	end)(),
}

-- hand turns: a gun's barrel runs along the fingers with its top toward the thumb; a bat or sword sticks
-- out of the fist along the thumb
local function gunHand(dir: Vector3, up: Vector3): CFrame
	return Ik.align(v(0, -1, 0), v(0, 0, -1), dir, up)
end
local function meleeHand(dir: Vector3, fingers: Vector3): CFrame
	return Ik.align(v(0, 0, -1), v(0, -1, 0), dir, fingers)
end
-- the other hand under a long gun's barrel: thumb along it, fingers wrapped round from below
local function supportHand(dir: Vector3, up: Vector3): CFrame
	return Ik.align(v(0, -1, 0), v(0, 0, -1), dir:Cross(up).Unit, dir)
end

-- elbows point down and out
local POLE_R = v(0.8, -1, 0.35)
local POLE_L = v(-0.8, -1, 0.35)

local smooth, bump, follow = Motion.smooth, Motion.bump, Motion.follow
local function ease(x: number): number
	return x * x * (3 - 2 * x)
end
local function wrap(a: number): number
	return math.atan2(math.sin(a), math.cos(a))
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function lerpKey(a: Key, b: Key, t: number): Key
	return {
		p = a.p:Lerp(b.p, t),
		d = a.d:Lerp(b.d, t).Unit,
		yaw = a.yaw + (b.yaw - a.yaw) * t,
		lean = a.lean + (b.lean - a.lean) * t,
	}
end
-- a vector turned about Y (+ = to the left)
local function yawed(p: Vector3, a: number): Vector3
	if a == 0 then
		return p
	end
	return CFrame.Angles(0, a, 0):VectorToWorldSpace(p)
end

-- where a melee swing is at time t (seconds since it started); nil once it's over
local function swingKey(w: Weapons.Weapon, set: any, side: number, t: number): Key?
	local keys = set[side] or set[1]
	local W, S, R = w.windup, w.strike, w.recover
	if t < W then
		local k = t / W
		return lerpKey(set.ready, keys.wind, 1 - (1 - k) * (1 - k))
	elseif t < W + S then
		local u = (t - W) / S
		if u < 0.5 then
			return lerpKey(keys.wind, keys.hit, (u / 0.5) ^ 1.5)
		end
		return lerpKey(keys.hit, keys.finish, ease((u - 0.5) / 0.5))
	elseif t < W + S + R then
		return lerpKey(keys.finish, set.ready, ease((t - W - S) / R))
	end
	return nil
end

---------------------------------------------------------------- the world they move in

local skip: { Instance } = {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true
local race = { phase = "", roofSceneAt = nil :: number?, serverNow = 0 }
local throttleKnown: boolean? = nil -- (Animator.EvaluationThrottled can be read here)

local function isThrottled(a: Animator?): boolean
	if not a then
		return false
	end
	if throttleKnown == nil then
		throttleKnown = pcall(function()
			return (a :: any).EvaluationThrottled
		end)
	end
	return throttleKnown == true and (a :: any).EvaluationThrottled == true
end

-- the climber's look pitch (radians, + = up)
local function aimOf(r: Rig): number
	if r.model == player.Character then
		local look = workspace.CurrentCamera.CFrame.LookVector
		return math.asin(math.clamp(look.Y, -1, 1))
	end
	local a = r.model:GetAttribute("Aim")
	return if type(a) == "number" then a else 0
end

local function aimingDownSights(r: Rig): boolean
	if r.model == player.Character then
		return CameraAim.aiming
	end
	return r.model:GetAttribute("ADS") == true
end

local function dust(at: Vector3, amount: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(196, 186, 176))
	e.LightInfluence = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(6, 11)
	e.SpreadAngle = Vector2.new(90, 5)
	e.Drag = 6
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = a
	e:Emit(math.floor(6 + amount * 10))
	Debris:AddItem(a, 1.2)
end

---------------------------------------------------------------- a rig

local function build(model: Model): Rig?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = model:FindFirstChild("UpperTorso")
	if not hum or not root or not torso then
		return nil
	end
	local right, left = Ik.arm(model, "Right"), Ik.arm(model, "Left")
	if not right or not left then
		return nil
	end
	local function find(part: string, name: string): Ik.Joint?
		local p = model:FindFirstChild(part)
		local j = p and p:FindFirstChild(name)
		if j and (j:IsA("AnimationConstraint") or j:IsA("Motor6D")) then
			return j
		end
		return nil
	end
	local legs = {}
	for _, side in { "Left", "Right" } do
		local leg = Ik.leg(model, side)
		if leg then
			table.insert(legs, leg)
		end
	end
	local look = root.CFrame.LookVector
	local now = os.clock()
	local r: Rig = {
		model = model,
		hum = hum,
		root = root,
		animator = hum:FindFirstChildOfClass("Animator"),
		right = right,
		left = left,
		legs = legs,
		k = math.max(0.5, math.abs(right.S.X) / 0.97),
		waist = find("UpperTorso", "Waist"),
		neck = find("Head", "Neck"),
		rootJoint = find("LowerTorso", "Root"),
		a0 = {},
		base = {},
		wrote = {},
		throttled = false,
		built = now,
		lastPos = nil,
		vel = Vector3.zero,
		acc = Vector3.zero,
		lastYaw = math.atan2(-look.X, -look.Z),
		turn = 0,
		grounded = true,
		airT = 0,
		fallVy = 0,
		groundVy = 0,
		groundPart = nil,
		groundY = 0,
		gait = rng:NextNumber() * math.pi * 2,
		exertion = 0,
		breath = rng:NextNumber() * math.pi * 2,
		idleT = 0,
		legYaw = 0,
		backward = false,
		stepT = 0,
		stepFrom = 0,
		lean = 0,
		bank = 0,
		land = Motion.spring(15, 0.42),
		hurtPitch = Motion.spring(17, 0.4),
		hurtYaw = Motion.spring(15, 0.42),
		hurtRoll = Motion.spring(16, 0.42),
		hurtDip = Motion.spring(14, 0.5),
		headSnap = Motion.spring(20, 0.38),
		stumble = 0,
		lookYaw = 0,
		lookT = rng:NextNumber() * 0.4,
		glanceYaw = 0,
		glanceT = rng:NextNumber() * 5 + 3,
		weapon = nil,
		tool = nil,
		near = false,
		groundAcc = 0,
		drawAt = -math.huge,
		armW = 0,
		aimW = 0.8,
		adsW = 0,
		readyW = 1,
		recoil = Motion.spring(26, 0.42),
		recoilYaw = 0,
		climb = 0,
		shotAt = -math.huge,
		shotWeapon = "pistol",
		activeAt = -math.huge,
		jolt = Motion.spring(22, 0.45),
		swing = nil,
		trail = nil,
		reloadAt = nil,
		fired = {},
		fidget = nil,
		fidgetAt = 0,
		fidgetDue = rng:NextNumber(7, 13),
		boostAt = nil,
		heroAt = nil,
		koAt = nil,
		wakeAt = nil,
	}
	local joints = { right.shoulder, right.elbow, right.wrist, left.shoulder, left.elbow, left.wrist }
	for _, leg in legs do
		table.insert(joints, leg.hip)
		table.insert(joints, leg.knee)
		table.insert(joints, leg.ankle)
	end
	for _, j in joints do
		local a0 = Ik.frames(j)
		r.a0[j] = a0.Rotation
	end
	-- a body just set down comes to (a far one only now in view doesn't)
	local spawned = model:GetAttribute("SpawnedAt")
	if type(spawned) == "number" and workspace:GetServerTimeNow() - spawned < 0.8 then
		r.wakeAt = now
	end
	-- the moments the server marks on the body
	model:GetAttributeChangedSignal("Reloading"):Connect(function()
		if model:GetAttribute("Reloading") == true then
			r.reloadAt = os.clock()
			table.clear(r.fired)
		end
	end)
	model:GetAttributeChangedSignal("Boosting"):Connect(function()
		if model:GetAttribute("Boosting") == true then
			r.boostAt = os.clock()
		elseif r.boostAt then
			r.boostAt = nil
			r.heroAt = os.clock()
		end
	end)
	if model:GetAttribute("Reloading") == true then
		r.reloadAt = now
	end
	return r
end

-- a rotation R meant in the parent's frame, as the joint's Transform (allows for a turned attachment)
local function asTransform(r: Rig, j: Ik.Joint, R: CFrame): CFrame
	local a0 = r.a0[j]
	return if a0 then a0:Inverse() * R * a0 else R
end

-- the animation's pose of a joint this frame: its Transform as the Animator left it, or (when the Animator
-- skipped this frame, or doesn't move this joint at all and it still holds what we wrote) the one before
local function baseOf(r: Rig, j: Ik.Joint): CFrame
	local t: CFrame = j.Transform
	local w = r.wrote[j]
	if w and (r.throttled or t == w) then
		return r.base[j] or t
	end
	r.base[j] = t
	return t
end

local function put(r: Rig, j: Ik.Joint, cf: CFrame)
	j.Transform = cf
	r.wrote[j] = cf
end

-- an offset on top of the animation (a rotation, and a shift, in the parent's frame)
local function add(r: Rig, j: Ik.Joint?, R: CFrame)
	if j then
		put(r, j, asTransform(r, j, R) * baseOf(r, j))
	end
end

local function setArm(r: Rig, arm: Ik.Arm, target: Vector3, hand: CFrame, pole: Vector3, w: number)
	if w <= 0.001 then
		return
	end
	local s, e, wr = Ik.solve(arm, target, hand, pole)
	put(r, arm.shoulder, baseOf(r, arm.shoulder):Lerp(asTransform(r, arm.shoulder, s), w))
	put(r, arm.elbow, baseOf(r, arm.elbow):Lerp(asTransform(r, arm.elbow, e), w))
	put(r, arm.wrist, baseOf(r, arm.wrist):Lerp(asTransform(r, arm.wrist, wr), w))
end

local function toolOf(model: Model): Tool?
	return model:FindFirstChildOfClass("Tool")
end

local function weaponOf(model: Model): (string?, string?)
	local tool = toolOf(model)
	local name = tool and tool:GetAttribute("Weapon")
	if type(name) == "string" and Weapons[name] then
		return name, Weapons[name].slot
	end
	return nil, nil
end

-- the glowing streak behind a bat or sword, on while it strikes
local function trailFor(r: Rig, color: Color3): Trail?
	local tool = toolOf(r.model)
	local handle = tool and tool:FindFirstChild("Handle")
	local a = handle and handle:FindFirstChild("TrailA")
	local b = handle and handle:FindFirstChild("TrailB")
	if not handle or not a or not b then
		return nil
	end
	local t = handle:FindFirstChild("SwingTrail") :: Trail?
	if not t then
		local nt = Instance.new("Trail")
		nt.Name = "SwingTrail"
		nt.Attachment0 = a :: Attachment
		nt.Attachment1 = b :: Attachment
		nt.Lifetime = 0.16
		nt.MinLength = 0.05
		nt.LightEmission = 1
		nt.LightInfluence = 0
		nt.FaceCamera = false
		nt.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		nt.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.6, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		nt.WidthScale = NumberSequence.new(1, 0.3)
		nt.Enabled = false
		nt.Parent = handle
		t = nt
	end
	return t
end

---------------------------------------------------------------- the pose, every frame

-- what the frame's layers add up to, written into the joints at the end
type Body = {
	drop: number, -- the hips sink this far (studs), the knees taking it
	rootYaw: number, -- the legs and hips turned from where they face (+ left)
	rootPitch: number,
	rootRoll: number,
	chestPitch: number, -- (+ back): the body's own lean (a gun held up stays on its aim through it)
	chestKick: number, -- and what knocks it about (a flinch, a stagger, the kick): the gun goes with it
	chestYaw: number, -- the chest turned from where they face, in the world (+ left)
	chestRoll: number,
	headPitch: number, -- where the head looks, in the world (+ up)
	headYaw: number,
	headRoll: number,
	tuck: number, -- knees drawn up (in the air)
	legsTogether: number, -- 0..1: legs straight and together, toes pointed (the jets)
	hero: number, -- 0..1: a hero's landing
	spread: number, -- 0..1: legs spread on the air (the skydive)
	lift: { number }, -- per leg: a step's lift
}

local function sense(r: Rig, dt: number)
	local root, hum = r.root, r.hum
	local pos = root.Position
	-- velocity from where it went (the jets and the skydive move the body by hand, at zero velocity)
	if r.lastPos then
		local moved = (pos - r.lastPos) / math.max(dt, 1e-3)
		if moved.Magnitude > 140 then
			r.stumble = 1 -- set down somewhere else at once: thrown off a platform
		else
			local old = r.vel
			r.vel = r.vel:Lerp(moved, follow(18, dt))
			r.acc = r.acc:Lerp((r.vel - old) / math.max(dt, 1e-3), follow(10, dt))
		end
	end
	r.lastPos = pos
	-- on the ground? (a ray down from the hips; a moving platform counts, at its own speed: measured from
	-- where it went, like the body)
	local reach = root.Size.Y / 2 + hum.HipHeight + 0.9
	groundParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(pos, Vector3.new(0, -reach, 0), groundParams)
	local gvy = 0
	local under = if hit and hit.Instance:IsA("BasePart") then hit.Instance else nil
	if under then
		local y = under.Position.Y
		if under == r.groundPart then
			gvy = math.clamp((y - r.groundY) / math.max(dt, 1e-3), -120, 120)
		end
		r.groundY = y
	end
	r.groundPart = under
	local relVy = r.vel.Y - gvy
	local wasGrounded = r.grounded
	r.grounded = hit ~= nil and relVy < 6
	if not r.grounded then
		r.airT += dt
		r.fallVy = math.min(r.fallVy, relVy)
	else
		if not wasGrounded and r.airT > 0.12 and hum.Health > 0 then
			-- a landing: into the knees as hard as it hit
			local impact = math.max(0, -r.fallVy)
			if impact > 6 then
				Motion.kick(r.land, math.min(impact, 90) * 0.24)
				if impact > 42 then
					dust(pos - Vector3.new(0, reach - 0.9, 0), math.min(1, (impact - 42) / 40))
					Audio.play("land", root, math.clamp(impact / 80, 0.4, 1))
					if r.model == player.Character then
						CameraAim.shake(math.clamp(impact / 120, 0.15, 0.5))
					end
				end
			end
		end
		r.airT = 0
		r.fallVy = 0
	end
	-- (a platform setting off sinks you into your knees; stopping lifts you a little: pose())
	local gAcc = if r.grounded then (gvy - r.groundVy) / math.max(dt, 1e-3) else 0
	r.groundAcc += (gAcc - r.groundAcc) * follow(12, dt)
	r.groundVy = gvy
	-- turning
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local dYaw = wrap(yaw - r.lastYaw)
	r.lastYaw = yaw
	r.turn += (dYaw / math.max(dt, 1e-3) - r.turn) * follow(12, dt)
	-- legs: toward where you go, or standing, the feet stay put as you turn and then step round
	local lv = root.CFrame:VectorToObjectSpace(r.vel)
	local side, fwd = lv.X, -lv.Z
	local flat = math.sqrt(side * side + fwd * fwd)
	if r.grounded and flat > 2.5 then
		local want, backward = Motion.strafe(side, fwd, 1.0)
		local k = smooth(flat, 2.5, 7)
		r.legYaw += (want * k - r.legYaw) * follow(9, dt)
		r.backward = backward and flat > 3
		r.stepT = 0
	elseif r.grounded then
		r.backward = false
		if r.stepT > 0 then
			r.stepT += dt
			local u = math.min(1, r.stepT / 0.26)
			r.legYaw = r.stepFrom * (1 - ease(u)) -- (the step carries them round)
			if u >= 1 then
				r.stepT = 0
			end
		else
			r.legYaw = math.clamp(r.legYaw - dYaw, -1.1, 1.1)
			if math.abs(r.legYaw) > 0.7 then
				r.stepT = 1e-4
				r.stepFrom = r.legYaw
			end
		end
	else
		r.backward = false
		r.legYaw += (0 - r.legYaw) * follow(5, dt)
	end
	-- breathing: a calm rate standing, harder for a while after a run
	r.exertion =
		Motion.approach(r.exertion, math.clamp(flat / Config.WALK_SPEED, 0, 1), if flat > 4 then 0.35 else 0.1, dt)
	-- the stride
	if r.grounded then
		r.gait += flat * dt / STRIDE * math.pi * 2
	end
	if flat > 1 or not r.grounded then
		r.idleT = 0
	else
		r.idleT += dt
	end
	r.stumble = math.max(0, r.stumble - dt * 1.5)
end

-- whom the head turns to: the nearest climber in front, near enough to matter (not your own: your head
-- follows the camera)
local function lookAround(r: Rig, dt: number, others: { Model })
	r.lookT -= dt
	if r.lookT <= 0 then
		r.lookT = 0.35
		local best: BasePart?, bd = nil, 26
		local root = r.root
		for _, m in others do
			if m == r.model then
				continue
			end
			local o = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if o then
				local d = o.Position - root.Position
				local flatD = Vector3.new(d.X, 0, d.Z)
				local dist = flatD.Magnitude
				if dist < bd and dist > 1 and math.abs(d.Y) < 7 and flatD.Unit:Dot(root.CFrame.LookVector) > -0.1 then
					best, bd = o, dist
				end
			end
		end
		local want = 0
		if best then
			local rel = root.CFrame:PointToObjectSpace(best.Position)
			want = math.clamp(math.atan2(-rel.X, -rel.Z), -1.1, 1.1)
		end
		r.near = best ~= nil and bd < 16
		r.glanceYaw = want
	end
	-- nobody about: a glance round now and then
	if r.glanceYaw == 0 then
		r.glanceT -= dt
		if r.glanceT <= 0 then
			r.glanceT = rng:NextNumber(3.5, 7.5)
			r.glanceYaw = rng:NextNumber(-0.7, 0.7)
			r.lookT = 1.3 -- (hold it a moment)
		end
	end
	r.lookYaw += (r.glanceYaw - r.lookYaw) * follow(5, dt)
end

-- the reload's other hand and moments, at u (0..1)
local function reloadHand(
	rl: Reload,
	u: number,
	hold: Vector3,
	g: { hand: Vector3, dir: Vector3, up: Vector3, right: Vector3, k: number }
): Vector3
	local function spot(s: Spot): Vector3
		if s.kind == "hold" then
			return hold
		elseif s.kind == "gun" then
			return g.hand + g.dir * s.p.Z * g.k + g.up * s.p.Y * g.k + g.right * s.p.X * g.k
		end
		return s.p * g.k
	end
	local keys = rl.keys
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if u <= b.t then
			local t = if b.t > a.t then ease(math.clamp((u - a.t) / (b.t - a.t), 0, 1)) else 1
			return spot(a.at):Lerp(spot(b.at), t)
		end
	end
	return hold
end

local function pose(r: Rig, dt: number, now: number, others: { Model })
	local model = r.model
	local hum, root = r.hum, r.root
	local k = r.k
	r.throttled = isThrottled(r.animator)
	local alive = hum.Health > 0
	if not alive and not r.koAt then
		r.koAt = now
		local tool = toolOf(model)
		if tool then
			Gunwork.reset(tool)
		end
	end
	if not r.animator then
		r.animator = hum:FindFirstChildOfClass("Animator") -- (a bot's arrives after its body)
	end
	sense(r, dt)
	local mine = model == player.Character
	if alive then
		lookAround(r, dt, others)
	end

	-- what's in hand
	local wname, slot = weaponOf(model)
	local tool = toolOf(model)
	if wname ~= r.weapon or tool ~= r.tool then
		-- (put away mid-reload, its magazine goes back in)
		local oldTool = r.tool
		if oldTool then
			Gunwork.reset(oldTool)
		end
		r.tool = tool
		r.weapon = wname
		r.armW = 0
		r.trail = nil
		r.drawAt = now
		r.reloadAt = if model:GetAttribute("Reloading") == true then now else nil
		r.fidget = nil
	end
	r.armW = math.min(1, r.armW + dt * 8)

	-- the springs
	local rc = STANCE[r.shotWeapon] and STANCE[r.shotWeapon].recoil or STANCE.pistol.recoil
	r.recoil.freq, r.recoil.damping = rc.freq, rc.damping
	Motion.step(r.recoil, 0, dt)
	Motion.step(r.jolt, 0, dt)
	Motion.step(r.land, math.clamp(r.groundAcc * 0.0012, -0.08, 0.22), dt)
	Motion.step(r.hurtPitch, 0, dt)
	Motion.step(r.hurtYaw, 0, dt)
	Motion.step(r.hurtRoll, 0, dt)
	Motion.step(r.hurtDip, 0, dt)
	Motion.step(r.headSnap, 0, dt)
	r.climb *= math.exp(-dt * 5)

	local flatSpeed = Vector3.new(r.vel.X, 0, r.vel.Z).Magnitude
	local runK = smooth(flatSpeed, 4, 13) * (if r.grounded then 1 else 0)
	local idleK = 1 - smooth(flatSpeed, 0.5, 3)
	local hp = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
	local wounded = if alive then smooth(0.42 - hp, 0, 0.3) else 0
	local pitch = math.clamp(aimOf(r), -1.2, 1.2)
	local lv = root.CFrame:VectorToObjectSpace(r.vel)
	local la = root.CFrame:VectorToObjectSpace(r.acc)

	local b: Body = {
		drop = 0,
		rootYaw = r.legYaw,
		rootPitch = 0,
		rootRoll = 0,
		chestPitch = 0,
		chestKick = 0,
		chestYaw = 0,
		chestRoll = 0,
		headPitch = pitch,
		headYaw = if mine then 0 else r.lookYaw,
		headRoll = 0,
		tuck = 0,
		legsTogether = 0,
		hero = 0,
		spread = 0,
		lift = { 0, 0 },
	}

	-- running: lean into it (more as it picks up, back as it brakes), bank into turns and sidesteps
	local leanWant = math.clamp(-lv.Z / Config.WALK_SPEED, -0.5, 1.3) * 0.13
		+ math.clamp(-la.Z * 0.0035, -0.1, 0.1) * runK
	r.lean += (leanWant - r.lean) * follow(8, dt)
	local bankWant = math.clamp(r.turn * 0.035, -0.22, 0.22) * smooth(flatSpeed, 0, 10)
		- math.clamp(lv.X / Config.WALK_SPEED, -1, 1) * 0.07 * runK
	r.bank += (bankWant - r.bank) * follow(6, dt)
	b.rootRoll += r.bank
	-- breathing, weight shifting from foot to foot, the step's bounce
	local breathRate = 0.26 + 0.6 * r.exertion + 0.35 * wounded
	r.breath += dt * math.pi * 2 * breathRate
	local breathAmp = 0.012 + 0.03 * r.exertion + 0.02 * wounded
	local breathe = math.sin(r.breath)
	b.chestPitch += breathe * breathAmp
	b.rootRoll += math.sin(now * 0.9 + r.built) * 0.022 * idleK
	-- in the air: knees up as they rise, reaching for the floor as they fall
	if not r.grounded and alive then
		local rising = math.clamp(r.vel.Y / 30, -1, 1)
		b.tuck = 0.35 * smooth(r.airT, 0, 0.18) * (0.6 + 0.4 * rising)
		b.chestPitch += -0.06 * smooth(flatSpeed, 4, 14)
	end
	-- a landing (and a platform's jolt) sinks into the knees; a step round lifts a foot
	b.drop += math.max(-0.15, r.land.x)
	if r.stepT > 0 and #r.legs >= 2 then
		local u = math.min(1, r.stepT / 0.26)
		local first = if r.stepFrom > 0 then 1 else 2
		b.lift[first] = bump(u, 0, 0.6) * 0.5
		b.lift[3 - first] = bump(u, 0.4, 1) * 0.4
	end
	-- hurt: hunched, head low
	b.chestPitch -= 0.14 * wounded
	b.headPitch -= 0.12 * wounded

	-- getting hit: the flinch springs
	b.chestKick += r.hurtPitch.x
	b.chestYaw += r.hurtYaw.x
	b.chestRoll += r.hurtRoll.x
	b.rootRoll += r.hurtRoll.x * 0.35
	b.drop += math.max(0, r.hurtDip.x)
	b.headPitch += r.headSnap.x
	-- thrown: a stagger, arms out
	local stagger = r.stumble
	if stagger > 0 then
		b.chestRoll += math.sin(now * 13) * 0.16 * stagger
		b.chestKick += math.sin(now * 9) * 0.08 * stagger
		b.drop += 0.35 * stagger
	end

	-- the race's moments: everyone looks up as the roof opens; at the end the winner cheers, the rest
	-- hang their heads; getting ready, a bounce on the toes
	local cheering, slumped = false, false
	if race.phase == "over" and alive then
		if model:GetAttribute("Escaped") == true then
			cheering = flatSpeed < 3
		else
			slumped = true
			b.headPitch -= 0.4
			b.chestPitch -= 0.15
		end
	elseif race.phase == "ready" then
		b.drop += (1 + math.sin(now * 6.5 + r.built)) * 0.05
	end
	local roofAt = race.roofSceneAt
	if roofAt and race.serverNow - roofAt < Config.ROOF_SCENE then
		local up = bump(race.serverNow - roofAt, 0, Config.ROOF_SCENE)
		b.headPitch += 0.55 * up
		local rel = root.CFrame:PointToObjectSpace(Vector3.new(0, root.Position.Y, 0))
		if rel.Magnitude > 2 then
			b.headYaw = lerp(b.headYaw, math.clamp(math.atan2(-rel.X, -rel.Z), -1, 1), up)
		end
	end

	-- coming to: crouched, then up, groggy
	local wake = 0
	if r.wakeAt then
		local t = now - r.wakeAt
		wake = 1 - smooth(t, 0.1, 1.1)
		b.drop += 1.3 * wake * k
		b.chestPitch -= 0.55 * wake
		b.headPitch -= 0.6 * wake
		b.headYaw += math.sin(t * 16) * 0.3 * bump(t, 0.9, 1.6)
		if t > 1.7 then
			r.wakeAt = nil
		end
	end

	-- knocked out: the knees go, the body slumps, the head lolls
	local ko = 0
	if r.koAt then
		local t = now - r.koAt
		ko = smooth(t, 0, 0.4)
		b.drop += 1.5 * ko * k
		b.chestPitch -= 0.7 * ko
		b.chestRoll += 0.2 * ko
		b.headPitch = lerp(b.headPitch, -0.9, ko)
		b.headRoll += 0.45 * ko
		b.tuck = 0
	end

	-- the jets: a crouch, then up with legs together; a hero's landing at the end
	local boosting = model:GetAttribute("Boosting") == true
	local gliding = model:GetAttribute("Gliding") == true
	if boosting and r.boostAt then
		local t = now - r.boostAt
		b.drop += 0.8 * bump(t, 0, 0.3) * k
		b.legsTogether = smooth(t, 0.15, 0.45)
		b.chestPitch += 0.12 * b.legsTogether + math.sin(now * 9) * 0.02
		b.headPitch = 0.35
		b.rootRoll += math.sin(now * 5.3) * 0.04 + math.clamp(-lv.X * 0.01, -0.25, 0.25)
		b.rootPitch += math.clamp(lv.Z * 0.012, -0.25, 0.25)
		b.rootYaw = 0
	end
	local hero = 0
	if r.heroAt then
		local t = now - r.heroAt
		hero = smooth(t, 0, 0.08) * (1 - smooth(t, 0.55, 0.95))
		b.hero = hero
		b.drop += 1.0 * hero * k
		b.chestPitch -= 0.45 * hero
		b.headPitch = lerp(b.headPitch, -0.25 + 0.6 * smooth(t, 0.3, 0.7), hero)
		b.rootYaw *= 1 - hero
		if t > 1 then
			r.heroAt = nil
		end
	end
	if gliding then
		b.spread = 1
		b.rootYaw = 0
		b.drop = 0
		b.tuck = 0
	end

	-- the arms: what they hold, or the moment's own pose
	local armed = slot ~= nil
	local chestYaw = 0 -- the stance's own turn (the gun's frame follows it)
	local armsPitch = 0
	if gliding then
		-- spread out flat on the air: arms wide, fluttering with the speed; swept back in a dive
		local speed = r.vel.Magnitude
		local flutter = math.sin(now * 23) * 0.05 * smooth(speed, 20, 70)
		local dive = smooth(-r.vel.Y, 25, 50)
		r.armW = math.min(1, r.armW + dt * 4)
		local wide = v(1.75, 0.55 + flutter, -0.25):Lerp(v(1.1, -0.3, 0.6), dive)
		local palm = v(1, 0, 0):Lerp(v(0.3, -0.5, 0.8), dive).Unit
		setArm(r, r.right, wide * k, meleeHand(palm, v(0, -1, 0)), POLE_R, r.armW)
		setArm(
			r,
			r.left,
			v(-wide.X, wide.Y - flutter * 2, wide.Z) * k,
			meleeHand(v(-palm.X, palm.Y, palm.Z), v(0, -1, 0)),
			POLE_L,
			r.armW
		)
		b.headPitch = 0.5 + 0.2 * dive
		armed = true
	elseif boosting then
		-- flying up on the jets: arms down by the sides and back, hands flat, chin up
		r.armW = math.min(1, r.armW + dt * 6)
		local down = v(0, -1, 0.25).Unit
		local wob = math.sin(now * 11) * 0.04
		setArm(r, r.right, v(0.75, -0.55 + wob, 0.45) * k, meleeHand(down, v(0, 0, -1)), POLE_R, r.armW)
		setArm(r, r.left, v(-0.75, -0.55 - wob, 0.45) * k, meleeHand(down, v(0, 0, -1)), POLE_L, r.armW)
		armed = true
	elseif cheering then
		-- the winner: both fists up, pumping
		local pump = math.sin(now * 7)
		local w = math.min(1, r.armW)
		setArm(r, r.right, v(0.85, 2.0 + 0.25 * pump, -0.35) * k, meleeHand(v(0, 1, 0), v(-1, 0, 0)), POLE_R, w)
		setArm(r, r.left, v(-0.85, 2.0 - 0.25 * pump, -0.35) * k, meleeHand(v(0, 1, 0), v(1, 0, 0)), POLE_L, w)
		b.headPitch = 0.35
		b.chestPitch += 0.12
		b.drop += math.max(0, pump) * 0.12
		armed = true
	elseif ko > 0 then
		-- down: the arms hang
		local w = math.min(r.armW, ko)
		setArm(r, r.right, v(0.9, -0.6, -0.15) * k, meleeHand(v(0, -1, 0), v(-1, 0, 0)), POLE_R, w)
		setArm(r, r.left, v(-0.9, -0.6, -0.1) * k, meleeHand(v(0, -1, 0), v(1, 0, 0)), POLE_L, w)
		armed = true
	elseif hero > 0.05 then
		-- a hero's landing: one fist on the floor, the other arm back for balance
		local w = hero
		setArm(r, r.right, v(0.55, -1.9, -0.75) * k, meleeHand(v(0, -1, 0), v(-1, 0, 0)), POLE_R, w)
		setArm(r, r.left, v(-1.1, -0.2, 0.55) * k, meleeHand(v(-0.6, -0.3, 0.7).Unit, v(0, -1, 0)), POLE_L, w)
		armed = true
	elseif slot == "gun" and wname and tool then
		local st = STANCE[wname] or STANCE.pistol
		local reloading = model:GetAttribute("Reloading") == true and r.reloadAt ~= nil
		if not reloading and r.reloadAt then
			r.reloadAt = nil -- (done, or cut short: everything back in the gun)
			Gunwork.reset(tool)
		end
		-- up and aimed: shooting, aiming, hit, or standing; carried low running
		local active = now - r.activeAt < 1.6
		local ads = aimingDownSights(r)
		local wantAim = if ads
				or active
				or reloading
				or r.fidget
			then 1
			elseif runK > 0.4 then (if r.near then 0.7 else 0)
			else 0.85
		if slumped then
			wantAim = 0
		end
		r.aimW = Motion.approach(r.aimW, wantAim, if wantAim > r.aimW then 9 else 3, dt)
		r.adsW += ((if ads and not reloading then 1 else 0) - r.adsW) * follow(12, dt)
		local aimW, adsW = ease(r.aimW), ease(r.adsW)
		-- the stance: side-on behind a long gun, as far as it's up (standing, the feet turn with it)
		chestYaw = lerp(st.lowBlade, st.blade, aimW) * (1 - 0.15 * adsW * aimW)
		b.rootYaw += chestYaw * 0.35 * idleK
		-- the arms take the aim the chest doesn't (the chest's lean and breathing don't tip the gun)
		b.chestPitch += pitch * 0.25 * aimW
		local hand = st.low:Lerp(st.ready, aimW):Lerp(st.ads, adsW * aimW) * k
		local dir = st.lowDir.Unit:Lerp(v(0, 0, -1), aimW).Unit
		local up = v(0, 1, 0)
		-- in step: the gun bobs and sways with the stride, and breathes
		local bob = math.sin(r.gait * 2) * 0.05 * runK * (1 - 0.6 * adsW)
		local sway = math.sin(r.gait) * 0.04 * runK
		hand += v(sway, bob + breathe * breathAmp * 0.8, 0) * k
		hand += v(math.noise(now * 0.6, r.built) * 0.02, math.noise(r.built, now * 0.5) * 0.02, 0) * k * (1 - adsW)
		-- the kick: back and up, the muzzle flipping, a twist of jitter, the climb of full auto
		local kick = r.recoil.x
		local recoilNow = (STANCE[r.shotWeapon] or st).recoil
		hand += v(0, recoilNow.up * kick, recoilNow.back * kick) * k
		local flip = recoilNow.flip * kick + r.climb
		b.chestKick += recoilNow.chest * kick
		b.headPitch += recoilNow.head * kick
		-- a guarded blow or a slapped-in magazine knocks it
		hand += v(0, 0.08 * r.jolt.x, 0.1 * r.jolt.x) * k
		-- the reload: the gun tips in, the shooting hand comes closer
		local rl = RELOADS[wname]
		local tilt = 0
		local u = 0
		if reloading and rl and r.reloadAt then
			u = math.clamp((now - r.reloadAt) / Weapons[wname].reload, 0, 1)
			tilt = smooth(u, 0, 0.12) * (1 - smooth(u, 0.85, 1))
			hand += rl.pull * tilt * k
			flip -= rl.dip * tilt
		end
		-- a fidget: turn the gun over to look at it
		if r.fidget == "inspect" then
			local t = (now - r.fidgetAt) / 1.6
			local f = bump(t, 0, 1)
			hand += v(-0.2, -0.05, 0.45) * f * k
			b.headPitch -= 0.25 * f
			b.headYaw += -0.25 * f
			if t >= 1 then
				r.fidget = nil
			end
		end
		local rot = CFrame.Angles(flip, r.recoilYaw * kick, 0)
		dir = rot:VectorToWorldSpace(dir)
		up = rot:VectorToWorldSpace(up)
		if tilt ~= 0 and rl then
			local roll = CFrame.fromAxisAngle(dir, rl.roll * tilt)
			up = roll:VectorToWorldSpace(up)
		end
		if r.fidget == "inspect" then
			local t = (now - r.fidgetAt) / 1.6
			local roll = CFrame.fromAxisAngle(dir, 1.1 * bump(t, 0, 1))
			up = roll:VectorToWorldSpace(up)
		end
		-- aim pitch, about the shoulder line, as far as the gun is up: what the chest's own lean doesn't
		-- give it (the chest took a quarter of the aim; the running lean, a hunch or a crouch are taken back
		-- out, so the gun stays on target through them)
		armsPitch = pitch * aimW - b.chestPitch + r.lean * 0.6
		local pivot = v(0, 0.6 * k, 0)
		local aimRot = CFrame.Angles(armsPitch, 0, 0)
		hand = pivot + aimRot:VectorToWorldSpace(hand - pivot)
		dir = aimRot:VectorToWorldSpace(dir)
		up = aimRot:VectorToWorldSpace(up)
		-- from the aim's frame into the chest's (turned side-on by the stance)
		hand = yawed(hand, -chestYaw)
		dir = yawed(dir, -chestYaw)
		up = yawed(up, -chestYaw)
		local right = dir:Cross(up).Unit
		-- just drawn: up from the hip
		local draw = 1 - ease(math.clamp((now - r.drawAt) / DRAW, 0, 1))
		if draw > 0 then
			hand = hand:Lerp(HOLSTER.hand * k, draw)
			dir = dir:Lerp(HOLSTER.dir, draw).Unit
			up = up:Lerp(v(0, 0, -1), draw).Unit
		end
		local handRot = gunHand(dir, up)
		setArm(r, r.right, hand, handRot, POLE_R, r.armW)
		-- the other hand: cupping the pistol's grip, or along a long gun's barrel as far as it reaches (the
		-- shotgun's pump racked back after a shot)
		local support: Vector3
		local supportRot: CFrame
		local sp = st.support
		local pump = 0
		if wname == "shotgun" then
			pump = bump(now - r.shotAt, 0.16, 0.6)
			Gunwork.shift(tool, "Pump", PUMP * pump)
		elseif wname == "pistol" then
			local t = now - r.shotAt
			local slide = if t < 0.025 then t / 0.025 elseif t < 0.11 then 1 - (t - 0.025) / 0.085 else 0
			if not reloading then
				Gunwork.shift(tool, "Slide", SLIDE * slide)
			end
		end
		if sp then
			local from = hand - up * sp.down * k
			local a = from - r.left.S
			local along =
				Motion.reachAlong(a.X, a.Y, a.Z, dir.X, dir.Y, dir.Z, Ik.reach(r.left), (sp.along - PUMP * pump) * k)
			support = from + dir * along
			supportRot = supportHand(dir, up)
		else
			support = hand + handRot:VectorToWorldSpace(v(-0.12, 0, 0.1)) * k + v(-0.02, -0.08, 0) * k
			supportRot = gunHand(dir, up)
		end
		-- reloading, the other hand goes about its work
		if reloading and rl then
			local g = { hand = hand, dir = dir, up = up, right = right, k = k }
			support = reloadHand(rl, u, support, g)
			supportRot = supportHand(dir, up)
			for i, e in rl.events do
				if u >= e.t and not r.fired[i] then
					r.fired[i] = true
					if e.what == "out" then
						Gunwork.magOut(tool, true)
					elseif e.what == "grab" then
						Gunwork.hold(tool, "Mag", model:FindFirstChild("LeftHand") :: BasePart?)
					elseif e.what == "in" then
						Gunwork.magIn(tool)
						Motion.kick(r.jolt, 9) -- (slapped home: the gun jumps)
					elseif e.what == "shell" then
						Gunwork.hold(tool, "Shell", model:FindFirstChild("LeftHand") :: BasePart?)
					elseif e.what == "load" then
						Gunwork.hold(tool, "Shell", nil)
						Motion.kick(r.jolt, 4)
					end
				end
			end
			for _, s in rl.shifts do
				Gunwork.shift(tool, s.part, s.back * bump(u, s.from, s.to))
			end
		end
		setArm(r, r.left, support, supportRot, POLE_L, r.armW * (1 - draw))
		-- down the sights: the head tips to the gun
		b.headRoll -= 0.16 * adsW * aimW
		b.headPitch -= 0.06 * adsW * aimW
	elseif slot == "melee" and wname then
		local set = MELEE[wname] or MELEE.bat
		local w = Weapons[wname]
		local guarding = model:GetAttribute("Guard") == true
		local active = now - r.activeAt < 2.5
		local wantReady = if guarding or active or runK < 0.4 or r.near then 1 else 0
		r.readyW = Motion.approach(r.readyW, wantReady, if wantReady > r.readyW then 6 else 2, dt)
		local kk: Key = lerpKey(set.carry, set.ready, ease(r.readyW))
		local striking = false
		local strikeK = 0
		local sw = r.swing
		if sw and sw.weapon == wname then
			local t = now - sw.t0
			local at = swingKey(w, set, sw.side, t)
			if at then
				kk = at
				r.readyW = 1
				striking = t > w.windup * 0.75 and t < w.windup + w.strike + 0.06
				strikeK = bump(t, w.windup * 0.5, w.windup + w.strike + w.recover * 0.5)
			else
				r.swing = nil
			end
		elseif guarding then
			kk = set.guard
		end
		-- a fidget: tap the bat on the other hand, or twirl the sword
		local tap = 0
		if r.fidget and not sw and not guarding then
			local t = (now - r.fidgetAt) / (if r.fidget == "twirl" then 1.1 else 1.5)
			local f = bump(t, 0, 1)
			if r.fidget == "tap" then
				tap = f
				local beat = math.abs(math.sin(t * math.pi * 4))
				kk = lerpKey(kk, key(v(0.2, 0.15, -0.85), v(-0.35, 0.1 + 0.35 * beat, -0.9)), f)
				b.headPitch -= 0.2 * f
			elseif r.fidget == "twirl" then
				local a = t * math.pi * 2
				kk = lerpKey(kk, key(v(0.4, 0.3, -0.9), v(math.sin(a) * 0.7, 0.55 + math.cos(a) * 0.3, -0.6)), f)
			end
			if t >= 1 then
				r.fidget = nil
			end
		end
		chestYaw = kk.yaw
		-- the hips lead the swing round and the body steps into the blow; a guard sits back on its knees
		b.rootYaw += kk.yaw * 0.4
		b.drop += 0.22 * strikeK * k + (if guarding then 0.25 * k else 0)
		b.chestPitch += kk.lean + pitch * 0.2
		b.chestKick -= 0.08 * strikeK
		local hand = kk.p * k
		local dir = kk.d
		-- just drawn: over the shoulder
		local draw = 1 - ease(math.clamp((now - r.drawAt) / DRAW, 0, 1))
		if draw > 0 then
			hand = hand:Lerp(OVER_SHOULDER.hand * k, draw)
			dir = dir:Lerp(OVER_SHOULDER.dir, draw).Unit
			chestYaw += 0.25 * draw
		end
		-- in step: carried, the weapon bobs with the stride
		local bob = math.sin(r.gait * 2) * 0.05 * runK
		hand += v(math.sin(r.gait) * 0.03 * runK, bob + breathe * breathAmp * 0.8, 0) * k
		-- a blow on the guard knocks it back
		hand += v(0, 0.1 * r.jolt.x, 0.18 * r.jolt.x) * k
		-- swing toward where they look, up or down a little
		local aimRot = CFrame.Angles(pitch * 0.35, 0, 0)
		hand = v(0, 0.6 * k, 0) + aimRot:VectorToWorldSpace(hand - v(0, 0.6 * k, 0))
		dir = aimRot:VectorToWorldSpace(dir)
		-- fingers curl round the shaft: across the body
		local fingers = dir:Cross(v(0, 1, 0))
		if fingers.Magnitude < 0.2 then
			fingers = v(-1, 0, 0)
		end
		setArm(r, r.right, hand, meleeHand(dir, -fingers), POLE_R, r.armW)
		if set.twoHanded then
			local along = if kk == set.guard then set.guardLeftAlong else set.leftAlong
			-- carried on the shoulder, the other hand drops to the side; tapping, it's the palm the bat
			-- comes down on
			local leftW = r.armW * (if sw or guarding then 1 else math.max(r.readyW, tap)) * (1 - draw)
			setArm(r, r.left, hand + dir * (if tap > 0 then 1.1 else along) * k, meleeHand(dir, fingers), POLE_L, leftW)
		end
		-- the trail
		if not r.trail then
			r.trail = trailFor(r, set.trail)
		end
		local trail = r.trail
		if trail and trail.Parent then
			trail.Enabled = striking
		end
	elseif stagger > 0.05 then
		-- thrown with nothing in hand: arms out for balance
		local w = stagger
		setArm(
			r,
			r.right,
			v(1.6, 0.5 + math.sin(now * 11) * 0.2, -0.3) * k,
			meleeHand(v(1, 0, 0), v(0, -1, 0)),
			POLE_R,
			w
		)
		setArm(
			r,
			r.left,
			v(-1.6, 0.5 - math.sin(now * 11) * 0.2, -0.3) * k,
			meleeHand(v(-1, 0, 0), v(0, -1, 0)),
			POLE_L,
			w
		)
	end

	-- idle long enough, a fidget
	if r.idleT > r.fidgetDue and not r.fidget and alive and race.phase ~= "over" then
		r.idleT = 0
		r.fidgetDue = rng:NextNumber(7, 13)
		if slot == "gun" and model:GetAttribute("Reloading") ~= true then
			r.fidget = "inspect"
		elseif wname == "bat" then
			r.fidget = "tap"
		elseif wname == "sword" then
			r.fidget = "twirl"
		end
		r.fidgetAt = now
	end
	if r.idleT == 0 and r.fidget and flatSpeed > 1 then
		r.fidget = nil
	end

	---------------------------------------------------------------- write it all into the joints
	-- the hips and legs: turned toward where they go, banked, sunk into the knees
	add(
		r,
		r.rootJoint,
		CFrame.new(0, -b.drop, 0) * CFrame.Angles(0, b.rootYaw, 0) * CFrame.Angles(b.rootPitch, 0, b.rootRoll)
	)
	-- the chest: turned to the stance (from the hips' own turn), leaning; the running lean is the chest's
	-- (a gun holder leans a little less: the gun stays level)
	local chestPitch = b.chestPitch + b.chestKick - r.lean * (if armed then 0.6 else 1)
	local chestWorldYaw = chestYaw + b.chestYaw
	add(r, r.waist, CFrame.Angles(chestPitch, chestWorldYaw - b.rootYaw, b.chestRoll - b.rootRoll * 0.5))
	-- the head: where they look (the chest has taken part of it), turned to whoever's near
	if r.neck then
		local headPitch = (b.headPitch - chestPitch) * (if armed then 0.6 else 0.7)
		local headYaw = math.clamp(b.headYaw - chestWorldYaw, -1.2, 1.2)
		add(r, r.neck, CFrame.Angles(headPitch, headYaw, b.headRoll - b.chestRoll * 0.5))
	end
	-- the legs: the knees take the drop with the feet where they were; tucked in the air; a step's lift;
	-- the jets' straight legs; a hero's landing on one knee; spread on the air
	for i, leg in r.legs do
		local bend = Motion.kneeBend(math.max(0, b.drop), leg.thigh, leg.shin)
		local lift = b.lift[i] or 0
		local isLeft = leg.left
		local hip = bend + b.tuck + lift * 0.6
		local knee = -2 * bend - b.tuck * 1.7 - lift * 1.2
		local ankle = bend + lift * 0.3
		local roll = 0
		if b.hero > 0 then
			-- the right knee to the floor, the left foot planted ahead (for an R15 leg sunk a stud: shin
			-- near upright, foot flat)
			local h = b.hero
			if isLeft then
				hip, knee, ankle = lerp(hip, 1.2, h), lerp(knee, -1.7, h), lerp(ankle, 0.5, h)
			else
				hip, knee, ankle = lerp(hip, 0.15, h), lerp(knee, -1.9, h), lerp(ankle, -0.2, h)
			end
		end
		if b.legsTogether > 0 then
			local t = b.legsTogether
			hip, knee, ankle = lerp(hip, -0.12, t), lerp(knee, -0.08, t), lerp(ankle, -0.6, t)
			roll = (if isLeft then 0.07 else -0.07) * t -- (+ roll swings a leg toward +X: in, for the left)
		end
		if b.spread > 0 then
			local flutter = math.sin(now * 19 + i) * 0.06 * smooth(r.vel.Magnitude, 20, 70)
			hip, knee = lerp(hip, -0.15 + flutter, b.spread), lerp(knee, -0.4, b.spread)
			roll = (if isLeft then -0.3 else 0.3) * b.spread
		end
		local legCF = CFrame.Angles(hip, 0, roll)
		if b.legsTogether > 0 or b.spread > 0 or b.hero > 0 then
			-- (these replace what the legs were doing: running legs in the air look wrong)
			local w = math.max(b.legsTogether, b.spread, b.hero)
			put(r, leg.hip, baseOf(r, leg.hip):Lerp(asTransform(r, leg.hip, legCF), w))
			put(r, leg.knee, baseOf(r, leg.knee):Lerp(asTransform(r, leg.knee, CFrame.Angles(knee, 0, 0)), w))
			put(r, leg.ankle, baseOf(r, leg.ankle):Lerp(asTransform(r, leg.ankle, CFrame.Angles(ankle, 0, 0)), w))
		elseif math.abs(hip) + math.abs(knee) > 1e-3 then
			add(r, leg.hip, legCF)
			add(r, leg.knee, CFrame.Angles(knee, 0, 0))
			add(r, leg.ankle, CFrame.Angles(ankle, 0, 0))
		end
	end
end

-- your own legs run backward as you back off (Roblox's Animate plays the run forward whatever the way)
local function ownGait()
	local char = player.Character
	local r = char and rigs[char]
	local animator = r and r.animator
	if not r or not animator then
		return
	end
	for _, tr in animator:GetPlayingAnimationTracks() do
		local anim = tr.Animation
		local name = anim and anim.Name
		if name == "RunAnim" or name == "WalkAnim" then
			local s = tr.Speed
			if (r.backward and s > 0) or (not r.backward and s < 0) then
				tr:AdjustSpeed(-s)
			end
		end
	end
end

local function rigOf(model: Instance?): Rig?
	if not model or not model:IsA("Model") then
		return nil
	end
	local r = rigs[model]
	if r and r.root.Parent then
		return r
	end
	local nr = build(model)
	if nr then
		rigs[model] = nr
		model.Destroying:Connect(function()
			rigs[model] = nil
		end)
	end
	return nr
end

---------------------------------------------------------------- what happens to them

-- a swing starting on someone (from the server, or predicted for your own)
function Poser.swing(model: Instance?, weapon: string, side: number)
	local r = rigOf(model)
	if r and Weapons[weapon] then
		r.swing = { weapon = weapon, side = if side < 0 then -1 else 1, t0 = os.clock() }
		r.activeAt = os.clock()
		r.fidget = nil
		-- the whoosh, as the blow comes round
		task.delay(Weapons[weapon].windup * 0.6, function()
			Audio.play(weapon, r.root)
		end)
	end
end

-- a shot from someone's gun: the kick (each gun its own), and the gun comes up
function Poser.shot(model: Instance?, weapon: string?)
	local r = rigOf(model)
	if not r then
		return
	end
	local name = if weapon and STANCE[weapon] then weapon else (r.weapon or "pistol")
	local st = STANCE[name] or STANCE.pistol
	local rc = st.recoil
	local now = os.clock()
	r.shotWeapon = name
	r.recoil.freq, r.recoil.damping = rc.freq, rc.damping
	Motion.kick(r.recoil, rc.kick * rc.freq * 1.8) -- (a lightly damped spring peaks near 0.55 v / freq)
	r.recoilYaw = rng:NextNumber(-rc.jitter, rc.jitter) * 2
	r.climb = math.min(r.climb + rc.climb, 0.18)
	r.shotAt = now
	r.activeAt = now
	r.aimW = math.max(r.aimW, 0.7) -- (it snaps up for the shot)
	r.fidget = nil
end

-- Someone was hit at `at` from `from` (positions) for `dmg`: a flinch by where it hit and which way it came
-- (kind: "hit", "head", "block"; weapon: what hit them)
function Poser.hurt(model: Instance?, from: Vector3?, at: Vector3?, dmg: number?, kind: string?, weapon: string?)
	local r = rigOf(model)
	if not r then
		return
	end
	local now = os.clock()
	r.activeAt = now
	r.fidget = nil
	local w = weapon and Weapons[weapon]
	if kind == "block" then
		Motion.kick(r.jolt, 25)
		Motion.kick(r.hurtPitch, 1.5)
		return
	end
	local melee = w ~= nil and w.slot == "melee"
	local m = math.clamp((dmg or 12) / 18, 0.35, 1.8)
		* (if melee then 1.6 else 1)
		* (if weapon == "shotgun" then 1.3 else 1)
	local root = r.root
	-- which way it pushed them, in their own frame (+X right, +Z back)
	local push = v(0, 0, 1)
	if from then
		local d = root.Position - from
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then
			push = root.CFrame:VectorToObjectSpace(d.Unit)
		end
	end
	-- where on them: the head, the body (which side), the legs
	local rel = if at then root.CFrame:PointToObjectSpace(at) else v(0, 0.8, 0)
	local head = model and (model :: Model):FindFirstChild("Head") :: BasePart?
	local headY = if head then root.CFrame:PointToObjectSpace(head.Position).Y - head.Size.Y * 0.5 else 1.6
	if kind == "head" or rel.Y > headY then
		Motion.kick(r.headSnap, 9 * m * push.Z + 2)
		Motion.kick(r.hurtYaw, -rel.X * 3 * m)
		Motion.kick(r.hurtPitch, 3 * m * push.Z)
	elseif rel.Y > -0.4 then
		-- the shoulder it struck goes back, the body rocks with the push
		Motion.kick(r.hurtPitch, 4.5 * m * push.Z)
		Motion.kick(
			r.hurtYaw,
			-math.clamp(rel.X, -1, 1) * 6 * m * math.max(0.3, math.abs(push.Z)) * (if push.Z >= 0 then 1 else -1)
		)
		Motion.kick(r.hurtRoll, -push.X * 4 * m)
	else
		-- a leg: it buckles
		Motion.kick(r.hurtDip, 6 * m)
		Motion.kick(r.hurtRoll, (if rel.X > 0 then -1 else 1) * 3 * m)
		Motion.kick(r.hurtPitch, 1.5 * m * push.Z)
	end
	if melee then
		Motion.kick(r.hurtDip, 2 * m)
	end
	-- the gun jolts off its aim
	Motion.kick(r.jolt, 6 * m)
end

-- a blow of yours landed (melee): it stops dead for an instant, and bounces back off a guard
local function struck(model: Instance?, blocked: boolean)
	local r = rigOf(model)
	local sw = r and r.swing
	if r and sw then
		sw.t0 += if blocked then 0.09 else 0.055
		if blocked then
			Motion.kick(r.jolt, 10)
		end
	end
end

local function everyone(): { Model }
	local out = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			table.insert(out, c)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") then
				table.insert(out, m)
			end
		end
	end
	return out
end

-- your own swing, started the moment you click (the server's SwingFx for it is then skipped)
function Poser.predictSwing(weapon: string, side: number)
	ownSwingAt = os.clock()
	Poser.swing(player.Character, weapon, side)
end

function Poser.init()
	Net.event("SwingFx").OnClientEvent:Connect(function(model: Instance, weapon: string, side: number)
		-- your own swing was already started the moment you clicked
		if model == player.Character and os.clock() - ownSwingAt < 0.35 then
			return
		end
		Poser.swing(model, weapon, side)
	end)
	Net.event("HitFx").OnClientEvent
		:Connect(
			function(at: Vector3, dmg: number, kind: string, victim: Instance?, attacker: Instance?, weapon: string?)
				if typeof(at) ~= "Vector3" then
					return
				end
				local w = if type(weapon) == "string" then Weapons[weapon] else nil
				if victim then
					local from: Vector3? = nil
					if attacker and attacker:IsA("Model") then
						from = attacker:GetPivot().Position
					end
					Poser.hurt(
						victim,
						from,
						at,
						if type(dmg) == "number" then dmg else nil,
						kind,
						if w then weapon else nil
					)
				end
				if attacker and w and w.slot == "melee" then
					struck(attacker, kind == "block")
				end
			end
		)
	local state = ReplicatedStorage:WaitForChild("RaceState")
	local function readRace()
		local phase = state:GetAttribute("Phase")
		race.phase = if type(phase) == "string" then phase else ""
		local at = state:GetAttribute("RoofSceneAt")
		race.roofSceneAt = if type(at) == "number" then at else nil
	end
	state:GetAttributeChangedSignal("Phase"):Connect(readRace)
	state:GetAttributeChangedSignal("RoofSceneAt"):Connect(readRace)
	readRace()
	RunService.PreAnimation:Connect(ownGait)
	RunService.PreSimulation:Connect(function(dt: number)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = os.clock()
		race.serverNow = workspace:GetServerTimeNow()
		local cam = workspace.CurrentCamera.CFrame.Position
		local all = everyone()
		-- (the ground under a climber is anything but climbers and the effects)
		table.clear(skip)
		for _, m in all do
			table.insert(skip, m)
		end
		for _, name in { "Fx", "Pickups", "Ambience", "Skydive" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(skip, f)
			end
		end
		for _, model in all do
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - cam).Magnitude > POSE_RANGE or root.LocalTransparencyModifier >= 1 then
				continue
			end
			local r = rigOf(model)
			if r then
				pose(r, dt, now, all)
			end
		end
	end)
	-- the guns' moving parts follow, once everything has moved for the frame
	RunService.PreRender:Connect(Gunwork.render)
end

return Poser
