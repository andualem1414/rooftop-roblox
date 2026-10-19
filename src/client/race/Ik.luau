--!strict
-- A small two-bone arm solver for R15 rigs (shoulder -> elbow -> wrist -> hand), used by the Poser.
-- Give it where the hand should grip (in the upper torso's frame) and how the hand should turn; it
-- returns the rotations for the shoulder, elbow and wrist joints, using the avatar's own arm lengths
-- (read from its rig attachments, so scaled avatars work too).
--
-- R15 axes: X right, Y up, Z back. An arm hangs along -Y; the elbow bends about its X axis (positive
-- folds the forearm forward). On the hand, -Y runs along the fingers (the forearm's direction) and -Z
-- points where the thumb does.

local Ik = {}

export type Joint = any -- AnimationConstraint (new avatar joints) or Motor6D

export type Arm = {
	shoulder: Joint,
	elbow: Joint,
	wrist: Joint,
	S: Vector3, -- the shoulder joint, in the upper torso's frame
	U: Vector3, -- shoulder -> elbow at rest
	L: Vector3, -- elbow -> wrist at rest
	G: Vector3, -- wrist -> grip point, in the hand's frame
}

-- the parent-side and child-side frames of a joint
local function frames(j: Joint): (CFrame, CFrame)
	if j:IsA("AnimationConstraint") then
		return j.Attachment0.CFrame, j.Attachment1.CFrame
	end
	return j.C0, j.C1
end
Ik.frames = frames

-- the shortest rotation turning unit vector a onto unit vector b
function Ik.fromTo(a: Vector3, b: Vector3): CFrame
	local d = math.clamp(a:Dot(b), -1, 1)
	if d > 0.99999 then
		return CFrame.identity
	end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-6 then
		axis = a:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-6 then
			axis = a:Cross(Vector3.yAxis)
		end
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

-- an orthonormal frame whose X is along a and whose Y is as close to b as it can be
local function basis(a: Vector3, b: Vector3): CFrame
	local x = a.Unit
	local y = b - x * b:Dot(x)
	if y.Magnitude < 1e-4 then
		local other = if math.abs(x.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		y = other - x * other:Dot(x)
	end
	y = y.Unit
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

-- the rotation taking local axis p onto direction P, with local axis s turned as close to S as possible
function Ik.align(p: Vector3, s: Vector3, P: Vector3, S: Vector3): CFrame
	return basis(P, S) * basis(p, s):Inverse()
end

-- read an arm's measurements from a character ("Right" or "Left"); nil if it isn't an R15 rig
function Ik.arm(model: Model, side: string): Arm?
	local upper = model:FindFirstChild(side .. "UpperArm")
	local lower = model:FindFirstChild(side .. "LowerArm")
	local hand = model:FindFirstChild(side .. "Hand")
	if not upper or not lower or not hand then
		return nil
	end
	local function joint(part: Instance, name: string): Joint?
		local j = part:FindFirstChild(name)
		if j and (j:IsA("AnimationConstraint") or j:IsA("Motor6D")) then
			return j
		end
		return nil
	end
	local shoulder = joint(upper, side .. "Shoulder")
	local elbow = joint(lower, side .. "Elbow")
	local wrist = joint(hand, side .. "Wrist")
	local grip = hand:FindFirstChild(side .. "GripAttachment")
	if not shoulder or not elbow or not wrist then
		return nil
	end
	local s0, s1 = frames(shoulder)
	local e0, e1 = frames(elbow)
	local w0, w1 = frames(wrist)
	local gp = if grip and grip:IsA("Attachment") then grip.Position else Vector3.new(0, -0.16, 0)
	return {
		shoulder = shoulder,
		elbow = elbow,
		wrist = wrist,
		S = s0.Position,
		U = e0.Position - s1.Position,
		L = w0.Position - e1.Position,
		G = gp - w1.Position,
	}
end

-- an arm's reach from the shoulder to the grip point, a little short of straight (what Ik.solve can get to)
function Ik.reach(arm: Arm): number
	return (arm.U.Magnitude + arm.L.Magnitude) * 0.97 + arm.G.Magnitude * 0.5
end

export type Leg = {
	left: boolean,
	hip: Joint,
	knee: Joint,
	ankle: Joint,
	thigh: number, -- hip -> knee (studs)
	shin: number, -- knee -> ankle
}

-- read a leg from a character ("Right" or "Left"); nil if it isn't an R15 rig. Legs bend about X like the
-- elbow: + swings the thigh forward (the hip), - folds the shin back (the knee).
function Ik.leg(model: Model, side: string): Leg?
	local upper = model:FindFirstChild(side .. "UpperLeg")
	local lower = model:FindFirstChild(side .. "LowerLeg")
	local foot = model:FindFirstChild(side .. "Foot")
	if not upper or not lower or not foot then
		return nil
	end
	local function joint(part: Instance, name: string): Joint?
		local j = part:FindFirstChild(name)
		if j and (j:IsA("AnimationConstraint") or j:IsA("Motor6D")) then
			return j
		end
		return nil
	end
	local hip = joint(upper, side .. "Hip")
	local knee = joint(lower, side .. "Knee")
	local ankle = joint(foot, side .. "Ankle")
	if not hip or not knee or not ankle then
		return nil
	end
	local _, h1 = frames(hip)
	local k0, k1 = frames(knee)
	local a0 = frames(ankle)
	return {
		left = side == "Left",
		hip = hip,
		knee = knee,
		ankle = ankle,
		thigh = (k0.Position - h1.Position).Magnitude,
		shin = (a0.Position - k1.Position).Magnitude,
	}
end

-- Solve one arm: the grip point at `target` (upper torso frame), the hand turned to `hand` (a rotation
-- in the upper torso frame), the elbow pointing toward `pole`. Returns the three joint rotations.
function Ik.solve(arm: Arm, target: Vector3, hand: CFrame, pole: Vector3): (CFrame, CFrame, CFrame)
	local wristAt = target - hand:VectorToWorldSpace(arm.G)
	local P = wristAt - arm.S
	local a, b = arm.U.Magnitude, arm.L.Magnitude
	local d = math.clamp(P.Magnitude, math.abs(a - b) + 0.02, a + b - 0.01)
	-- the elbow bend (about X, 0..2.9) that makes shoulder -> wrist exactly d long:
	-- |U + Rx(bend) L|² = d²  is  A cos(bend) + B sin(bend) = E, solved outright (it runs for every arm
	-- every frame; a bisection did the same to within 0.0001 rad, with 28 allocations an arm)
	local U, L = arm.U, arm.L
	local A = U.Y * L.Y + U.Z * L.Z
	local B = U.Z * L.Y - U.Y * L.Z
	local R = math.sqrt(A * A + B * B)
	local E = (d * d - U:Dot(U) - L:Dot(L)) / 2 - U.X * L.X
	local bend = if R > 1e-9 then math.clamp(math.atan2(B, A) + math.acos(math.clamp(E / R, -1, 1)), 0, 2.9) else 0
	local elbowRot = CFrame.Angles(bend, 0, 0)
	local v = arm.U + elbowRot:VectorToWorldSpace(arm.L)
	local dir = if P.Magnitude > 1e-4 then P.Unit else Vector3.new(0, -1, 0)
	local r1 = Ik.fromTo(v.Unit, dir)
	-- turn the arm about the shoulder -> wrist line so the elbow points toward the pole
	local e = r1:VectorToWorldSpace(arm.U)
	local ep = e - dir * e:Dot(dir)
	local pp = pole - dir * pole:Dot(dir)
	local twist = 0
	if ep.Magnitude > 1e-4 and pp.Magnitude > 1e-4 then
		twist = math.atan2(ep:Cross(pp):Dot(dir), ep:Dot(pp))
	end
	local shoulderRot = CFrame.fromAxisAngle(dir, twist) * r1
	local wristRot = (shoulderRot * elbowRot):Inverse() * hand.Rotation
	return shoulderRot, elbowRot, wristRot
end

return Ik
