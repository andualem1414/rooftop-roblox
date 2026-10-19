--!strict
-- Every climber's arms, torso and head, posed on each screen on top of Roblox's own walk / run / jump
-- animations (which still move the legs and body). Written into the joints' Transform each frame in
-- PreSimulation, after the animations, so it layers over them (create.roblox.com: AnimationConstraint).
--   a gun:   held up in both hands and aimed where the climber looks (their Aim pitch), kicking back on
--            every shot; tilted in for a reload
--   a bat:   carried up at the shoulder, swung from behind the shoulder round through the front and out
--            the other side, then back the other way on the next swing (forehand / backhand)
--   a sword: carried point-up in front, diagonal slashes, alternating
--   guard:   the weapon held across the chest
--   always:  the head and chest follow the aim; a flinch when hit; a lean into the run and a bank into
--            turns
-- Swing timings come from the weapon (shared/Weapons), so the arms land the blow when the server does.
-- A glowing trail follows the weapon through the strike.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local Ik = require(script.Parent.Ik)
local Audio = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Audio")) :: any

local player = Players.LocalPlayer

local Poser = {}

type Key = { p: Vector3, d: Vector3, yaw: number, lean: number }
type Swing = { weapon: string, side: number, t0: number }

type Rig = {
	model: Model,
	hum: Humanoid,
	root: BasePart,
	right: Ik.Arm,
	left: Ik.Arm,
	k: number, -- avatar scale (1 = a default R15 rig)
	waist: Ik.Joint?,
	neck: Ik.Joint?,
	rootJoint: Ik.Joint?,
	a0: { [Ik.Joint]: CFrame }, -- each joint's parent-side frame rotation
	-- state
	swing: Swing?,
	recoil: number,
	hurt: number,
	hurtSide: number,
	lean: number,
	bank: number,
	lastYaw: number,
	armW: number, -- how much the arms are ours (blends in when a weapon is drawn)
	weapon: string?,
	trail: Trail?,
}

local rigs: { [Model]: Rig } = {}
local ownSwingAt = 0 -- when your own predicted swing started
local POSE_RANGE = 170 -- studs: farther climbers keep their plain animation

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function key(p: Vector3, d: Vector3, yaw: number?, lean: number?): Key
	return { p = p, d = d.Unit, yaw = yaw or 0, lean = lean or 0 }
end

-- hand positions in the upper torso's frame (X right, Y up, Z back; shoulders at about ±0.97, 0.6, 0)
-- and the direction the weapon points. yaw turns the chest (+ = to the left), lean tips it (+ = back).
local MELEE = {
	-- hands stay near the middle of the chest, within reach of short avatar arms (both hands on the
	-- shaft); the chest's twist and the bat turning carry the swing round
	bat = {
		ready = key(v(0.1, 0.35, -0.85), v(0.2, 0.95, 0.25)),
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

-- a gun: where the shooting hand holds it (in front of the middle of the chest), aimed straight ahead
local GUN = {
	hand = v(0.12, 0.6, -1.2),
	reload = key(v(0.1, 0.3, -0.9), v(-0.35, 0.7, -0.6)),
}

-- elbows point down and out
local POLE_R = v(0.8, -1, 0.35)
local POLE_L = v(-0.8, -1, 0.35)

-- hand orientations: a gun's barrel runs along the fingers with its top toward the thumb; a bat or
-- sword sticks out of the fist along the thumb
local function gunHand(dir: Vector3, up: Vector3): CFrame
	return Ik.align(v(0, -1, 0), v(0, 0, -1), dir, up)
end
local function meleeHand(dir: Vector3, fingers: Vector3): CFrame
	return Ik.align(v(0, 0, -1), v(0, -1, 0), dir, fingers)
end

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end
local function lerpKey(a: Key, b: Key, t: number): Key
	return {
		p = a.p:Lerp(b.p, t),
		d = a.d:Lerp(b.d, t).Unit,
		yaw = a.yaw + (b.yaw - a.yaw) * t,
		lean = a.lean + (b.lean - a.lean) * t,
	}
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

-- the climber's look pitch (radians, + = up)
local function aimOf(r: Rig): number
	if r.model == player.Character then
		local look = workspace.CurrentCamera.CFrame.LookVector
		return math.asin(math.clamp(look.Y, -1, 1))
	end
	local a = r.model:GetAttribute("Aim")
	return if type(a) == "number" then a else 0
end

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
	local r: Rig = {
		model = model,
		hum = hum,
		root = root,
		right = right,
		left = left,
		k = math.max(0.5, math.abs(right.S.X) / 0.97),
		waist = find("UpperTorso", "Waist"),
		neck = find("Head", "Neck"),
		rootJoint = find("LowerTorso", "Root"),
		a0 = {},
		swing = nil,
		recoil = 0,
		hurt = 0,
		hurtSide = 1,
		lean = 0,
		bank = 0,
		lastYaw = 0,
		armW = 0,
		weapon = nil,
		trail = nil,
	}
	for _, j in { right.shoulder, right.elbow, right.wrist, left.shoulder, left.elbow, left.wrist } do
		local a0 = Ik.frames(j)
		r.a0[j] = a0.Rotation
	end
	return r
end

-- a rotation R meant in the parent's frame, as the joint's Transform (allows for a turned attachment)
local function asTransform(r: Rig, j: Ik.Joint, R: CFrame): CFrame
	local a0 = r.a0[j]
	return if a0 then a0:Inverse() * R * a0 else R
end

local function setArm(r: Rig, arm: Ik.Arm, target: Vector3, hand: CFrame, pole: Vector3, w: number)
	local s, e, wr = Ik.solve(arm, target, hand, pole)
	arm.shoulder.Transform = arm.shoulder.Transform:Lerp(asTransform(r, arm.shoulder, s), w)
	arm.elbow.Transform = arm.elbow.Transform:Lerp(asTransform(r, arm.elbow, e), w)
	arm.wrist.Transform = arm.wrist.Transform:Lerp(asTransform(r, arm.wrist, wr), w)
end

local function weaponOf(model: Model): (string?, string?)
	local tool = model:FindFirstChildOfClass("Tool")
	local name = tool and tool:GetAttribute("Weapon")
	if type(name) == "string" and Weapons[name] then
		return name, Weapons[name].slot
	end
	return nil, nil
end

-- the glowing streak behind a bat or sword, on while it strikes
local function trailFor(r: Rig, color: Color3): Trail?
	local tool = r.model:FindFirstChildOfClass("Tool")
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

local function pose(r: Rig, dt: number)
	local model = r.model
	local hum, root = r.hum, r.root
	if hum.Health <= 0 then
		return -- knocked out: let them fall
	end
	local now = os.clock()
	local k = r.k
	local wname, slot = weaponOf(model)
	if wname ~= r.weapon then
		r.weapon = wname
		r.armW = 0
		r.trail = nil
	end
	r.armW = math.min(1, r.armW + dt * 8)
	r.recoil *= math.exp(-dt * 13)
	r.hurt *= math.exp(-dt * 7)

	-- the body: lean into the run, bank into turns
	local vel = root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = math.atan2(math.sin(yaw - r.lastYaw), math.cos(yaw - r.lastYaw)) / math.max(dt, 1e-3)
	r.lastYaw = yaw
	r.lean += (math.clamp(speed / 16, 0, 1.3) * 0.13 - r.lean) * math.min(1, dt * 8)
	r.bank += (math.clamp(turn * 0.035, -0.22, 0.22) * math.min(1, speed / 10) - r.bank) * math.min(1, dt * 6)

	local pitch = math.clamp(aimOf(r), -1.2, 1.2)
	local chestYaw, chestLean = 0, 0
	local armed = slot ~= nil

	if slot == "gun" then
		local reloading = model:GetAttribute("Reloading") == true
		-- the arms take most of the aim, the chest a little
		local armsPitch = pitch * 0.75
		chestLean = pitch * 0.25
		local hand, dir, up
		if reloading then
			local kk = GUN.reload
			hand, dir, up = kk.p * k, kk.d, v(0, 1, 0)
		else
			hand = GUN.hand * k
			dir = v(0, 0, -1)
			up = v(0, 1, 0)
		end
		-- recoil: the gun kicks up and back
		local rc = r.recoil
		hand += v(0, 0.12, 0.3) * rc * k
		local kick = CFrame.Angles(0.4 * rc, 0, 0)
		dir = kick:VectorToWorldSpace(dir)
		up = kick:VectorToWorldSpace(up)
		-- aim pitch, about the shoulder line
		local pivot = v(0, 0.6 * k, 0)
		local aimRot = CFrame.Angles(armsPitch, 0, 0)
		hand = pivot + aimRot:VectorToWorldSpace(hand - pivot)
		dir = aimRot:VectorToWorldSpace(dir)
		up = aimRot:VectorToWorldSpace(up)
		local handRot = gunHand(dir, up)
		setArm(r, r.right, hand, handRot, POLE_R, r.armW)
		-- the other hand cups the grip from below and to the left
		local support = hand + handRot:VectorToWorldSpace(v(-0.12, 0, 0.1)) * k + v(-0.02, -0.08, 0) * k
		if reloading then
			support = hand + v(-0.12, -0.3, 0.05) * k
		end
		setArm(r, r.left, support, gunHand(dir, up), POLE_L, r.armW)
	elseif slot == "melee" and wname then
		local set = MELEE[wname] or MELEE.bat
		local w = Weapons[wname]
		local kk: Key = set.ready
		local striking = false
		local sw = r.swing
		if sw and sw.weapon == wname then
			local at = swingKey(w, set, sw.side, now - sw.t0)
			if at then
				kk = at
				local t = now - sw.t0
				striking = t > w.windup * 0.75 and t < w.windup + w.strike + 0.06
			else
				r.swing = nil
			end
		elseif model:GetAttribute("Guard") == true then
			kk = set.guard
		end
		chestYaw, chestLean = kk.yaw, kk.lean + pitch * 0.2
		local hand = kk.p * k
		local dir = kk.d
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
			setArm(r, r.left, hand + dir * along * k, meleeHand(dir, fingers), POLE_L, r.armW)
		end
		-- the trail
		if not r.trail then
			r.trail = trailFor(r, set.trail)
		end
		local trail = r.trail
		if trail and trail.Parent then
			trail.Enabled = striking
		end
	end

	-- hurt: a jolt back (or forward, hit from behind)
	chestLean += r.hurt * 0.35 * r.hurtSide

	if r.waist then
		local add = CFrame.Angles(chestLean - r.lean * (if armed then 0.6 else 1), chestYaw, 0)
		r.waist.Transform = add * r.waist.Transform
	end
	if r.neck then
		-- the head follows the aim (the chest has taken part of it)
		local headPitch = (if armed then pitch * 0.45 else pitch * 0.6) + r.hurt * 0.25 * r.hurtSide
		r.neck.Transform = CFrame.Angles(headPitch, -chestYaw * 0.6, 0) * r.neck.Transform
	end
	if r.rootJoint then
		r.rootJoint.Transform = CFrame.Angles(0, 0, r.bank) * r.rootJoint.Transform
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

-- a swing starting on someone (from the server, or predicted for your own)
function Poser.swing(model: Instance?, weapon: string, side: number)
	local r = rigOf(model)
	if r and Weapons[weapon] then
		r.swing = { weapon = weapon, side = if side < 0 then -1 else 1, t0 = os.clock() }
		-- the whoosh, as the blow comes round
		task.delay(Weapons[weapon].windup * 0.6, function()
			Audio.play(weapon, r.root)
		end)
	end
end

-- a shot from someone's gun: the kick
function Poser.shot(model: Instance?)
	local r = rigOf(model)
	if r then
		r.recoil = 1
	end
end

-- someone was hit from `from` (a position)
function Poser.hurt(model: Instance?, from: Vector3?)
	local r = rigOf(model)
	if not r then
		return
	end
	r.hurt = 1
	if from then
		local toward = (from - r.root.Position)
		r.hurtSide = if toward:Dot(r.root.CFrame.LookVector) >= 0 then 1 else -1
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
		:Connect(function(_at: Vector3, _dmg: number, kind: string, victim: Instance?, attacker: Instance?)
			if kind ~= "block" and victim then
				local from: Vector3? = nil
				if attacker and attacker:IsA("Model") then
					from = attacker:GetPivot().Position
				end
				Poser.hurt(victim, from)
			end
		end)
	RunService.PreSimulation:Connect(function(dt: number)
		local cam = workspace.CurrentCamera.CFrame.Position
		for _, model in everyone() do
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - cam).Magnitude > POSE_RANGE or root.LocalTransparencyModifier >= 1 then
				continue
			end
			local r = rigOf(model)
			if r then
				pose(r, dt)
			end
		end
	end)
end

return Poser
