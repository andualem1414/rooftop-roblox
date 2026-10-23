--!strict
-- The winner's skydive, after the original's skydive.js: a pad on the roof, in front of the ROOFTOP sign.
-- The winner steps on it and it flings them up and out over the valley; they spread out and glide down
-- through a trail of glowing rings. Each ring taken lifts them and speeds them up. Four floors above the
-- ground the flight ends. Pure: the flight model and the rings, the same for every client (a shared seed).
--   steering: A / D (or the stick) turns; W dives (faster, dropping fast); S flares (slow, floating, and it
--   turns speed back into height: dive for speed, pull up into a ring)
-- The original's numbers are metres; here they're studs (Config.M per metre).
local Config = require("./Config")
local Valley = require("./Valley")

local M = Config.M
local TOWER_H = Config.FLOORS * Config.FLOOR_HEIGHT

local Skydive = {}

Skydive.PAD = { x = 0, z = 24, r = 0.85 * M * 1.6 } -- on the roof, in front of the sign, facing the valley
Skydive.LAUNCH_UP = 26 * M -- studs/s up off the pad...
Skydive.LAUNCH_OUT = 9 * M -- ...and out over the edge
Skydive.LAUNCH_G = 22 * M -- a floaty arc
Skydive.END_ALT = 4 * Config.FLOOR_HEIGHT -- the flight ends this high above the ground
Skydive.CRUISE = { speed = 14 * M, sink = 5 * M }
Skydive.DIVE = { speed = 27 * M, sink = 12 * M }
Skydive.FLARE = { speed = 10 * M, sink = 2.6 * M }
Skydive.SWOOP = 0.45
Skydive.TURN = 1.35 -- rad/s at full stick
Skydive.RINGS = 12
Skydive.RING_R = 3.6 * M
Skydive.RING_LIFT = 6 * M
Skydive.MAX_TIME = 40 -- seconds: a flight never lasts longer than this

local LIFT_H = Skydive.RING_LIFT / 1.6

export type Ring = { x: number, y: number, z: number, dx: number, dz: number, state: "ahead" | "got" | "missed" }

export type Flyer = {
	x: number,
	y: number,
	z: number,
	vy: number,
	speed: number,
	yaw: number, -- heading: (sin yaw, cos yaw) in x, z
	turn: number,
	pitch: number,
	bank: number,
	boost: number,
	phase: "launch" | "glide" | "done",
	t: number,
	next: number, -- the ring to fly through next (1-based)
	got: number,
	rings: { Ring },
}

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local function damp(k: number, dt: number): number
	return 1 - math.exp(-dt * k)
end

local function ground(x: number, z: number): number
	return math.max(0, Valley.height(x, z))
end

-- where the pad is in the world (on the roof)
function Skydive.padAt(): (number, number, number)
	return Skydive.PAD.x, TOWER_H, Skydive.PAD.z
end

function Skydive.onPad(x: number, z: number): boolean
	local dx, dz = x - Skydive.PAD.x, z - Skydive.PAD.z
	return math.sqrt(dx * dx + dz * dz) < Skydive.PAD.r
end

-- The rings: from where the launch arc tops out, curving out into the valley and down. The height left
-- above the end is shared out over the rings to come, never steeper than a straight glide drops between
-- two rings (the last ring's lift and all) nor gentler than a flare holds, so every one can be reached;
-- where the ground leaves no room for the rest, the trail ends early (it used to push those up out of
-- reach). `seed` makes them the same on every screen.
function Skydive.layRings(x: number, y: number, z: number, yaw: number, seed: number): { Ring }
	-- (a small seeded generator: the same numbers in Roblox and in the tests)
	local st = math.max(1, math.floor(math.abs(seed)) % 2147483646 + 1)
	local function rr(a: number, b: number): number
		st = (st * 16807) % 2147483647
		return a + (b - a) * (st / 2147483647)
	end
	local out: { Ring } = {}
	local a = yaw
	for i = 1, Skydive.RINGS do
		-- swing toward the valley's middle, with a wander so you have to steer (the first is dead ahead)
		local want = math.atan2(-x * 0.006 / M, 1) + math.sin(i * 1.3 + rr(0, 2)) * 0.45
		if i > 1 then
			a += math.clamp(want - a, -0.5, 0.5) * 0.6
		end
		local step = if i == 1 then 22 * M else rr(18, 20) * M
		x += math.sin(a) * step
		z += math.cos(a) * step
		local floor = ground(x, z) + Skydive.END_ALT + 5 * M
		local glide = step * (Skydive.CRUISE.sink / (Skydive.CRUISE.speed + 1.5 * M))
		if i == 1 then
			y -= glide
		else
			local flare = step * (Skydive.FLARE.sink / Skydive.FLARE.speed)
			local share = (y - floor) / (Skydive.RINGS - i + 1)
			y -= math.clamp(share, flare - LIFT_H + 0.6 * M, glide - LIFT_H) + rr(-1, 1) * M
		end
		if y < floor then
			break
		end
		table.insert(out, { x = x, y = y, z = z, dx = math.sin(a), dz = math.cos(a), state = "ahead" })
	end
	return out
end

-- how high a straight glide from (x, y, z), climbing at vy and flying at speed, will be when it reaches
-- (rx, rz) (vy eases to the glide's sink as in Skydive.step)
local function glideTo(x: number, y: number, z: number, vy: number, speed: number, rx: number, rz: number): number
	local t = math.sqrt((rx - x) ^ 2 + (rz - z) ^ 2) / math.max(speed, 1)
	local sink = Skydive.CRUISE.sink
	return y - sink * t + (vy + sink) / 1.6 * (1 - math.exp(-1.6 * t))
end

-- The next ring, and the rest of the trail with it, comes down to where you can still reach it: never
-- above where a straight glide from here meets it (give or take). The trail is laid for taking every ring,
-- and each one lifts you: miss one and nothing climbs back up to the rest (they hung out of reach above
-- you). Rings are never raised: one below you is a dive (W) away. Called as each ring is taken or passed,
-- on every screen (watchers with the flyer's position as they see it).
function Skydive.settle(rings: { Ring }, next: number, x: number, y: number, z: number, vy: number, speed: number)
	local r = rings[next]
	if not r then
		return
	end
	local drop = r.y - (glideTo(x, y, z, vy, speed, r.x, r.z) + 0.4 * Skydive.RING_R)
	if drop <= 0 then
		return
	end
	for i = next, #rings do
		local q = rings[i]
		-- (not under the end height: no lower than the flight goes, or where it already is)
		q.y = math.max(q.y - drop, math.min(q.y, ground(q.x, q.z) + Skydive.END_ALT + 2 * M))
	end
end

-- a new flight off the pad from (x, y, z), out along yaw; the rings come from `seed`
function Skydive.launch(x: number, y: number, z: number, yaw: number, seed: number): Flyer
	local tTop = Skydive.LAUNCH_UP / Skydive.LAUNCH_G
	local tx = x + math.sin(yaw) * Skydive.LAUNCH_OUT * tTop
	local tz = z + math.cos(yaw) * Skydive.LAUNCH_OUT * tTop
	local ty = y + Skydive.LAUNCH_UP * tTop - 0.5 * Skydive.LAUNCH_G * tTop * tTop
	return {
		x = x,
		y = y,
		z = z,
		vy = Skydive.LAUNCH_UP,
		speed = Skydive.LAUNCH_OUT,
		yaw = yaw,
		turn = 0,
		pitch = 0,
		bank = 0,
		boost = 0,
		phase = "launch",
		t = 0,
		next = 1,
		got = 0,
		rings = Skydive.layRings(tx, ty, tz, yaw, seed),
	}
end

-- One step of the flight. steer -1..1 (+ right), pitch -1..1 (+ dive). Returns "ring" when a ring was taken
-- this step, "end" when the flight is over, else nil.
function Skydive.step(f: Flyer, dt: number, steer: number, pitch: number): string?
	if f.phase == "done" then
		return nil
	end
	f.t += dt
	local event: string? = nil
	if f.phase == "launch" then
		-- the pad's throw: up and out, until the arc tops out
		f.vy -= Skydive.LAUNCH_G * dt
		if f.vy <= 2 * M then
			f.phase = "glide"
			Skydive.settle(f.rings, f.next, f.x, f.y, f.z, f.vy, Skydive.CRUISE.speed)
		end
	else
		f.turn += (steer - f.turn) * damp(5, dt)
		f.pitch += (pitch - f.pitch) * damp(3, dt)
		f.yaw -= f.turn * Skydive.TURN * dt
		local p = f.pitch
		local function prof(k: string): number
			local c = (Skydive.CRUISE :: any)[k]
			return if p >= 0 then lerp(c, (Skydive.DIVE :: any)[k], p) else lerp(c, (Skydive.FLARE :: any)[k], -p)
		end
		f.speed += (prof("speed") + f.boost - f.speed) * damp(0.9, dt)
		local swoop = math.max(0, -p) * math.max(0, f.speed - Skydive.FLARE.speed) * Skydive.SWOOP
		f.vy += (-prof("sink") + swoop - f.vy) * damp(1.6, dt)
		f.boost *= math.exp(-dt * 0.5)
		f.bank += (math.clamp(f.turn, -1.2, 1.2) * 0.75 - f.bank) * damp(4, dt)
	end
	f.x += math.sin(f.yaw) * f.speed * dt
	f.z += math.cos(f.yaw) * f.speed * dt
	f.y += f.vy * dt

	-- the tower is solid: slide off its walls
	local W = Config.FLOOR_HALF + 0.8 * M
	if f.y < TOWER_H + M and math.abs(f.x) < W and math.abs(f.z) < W and f.phase ~= "launch" then
		if math.abs(f.x) > math.abs(f.z) then
			f.x = math.sign(f.x) * W
		else
			f.z = math.sign(f.z) * W
		end
		f.speed *= 0.97
	end

	-- the rings: through one (or close by) takes it; flying past one misses it
	local r = f.rings[f.next]
	if r then
		local dx, dy, dz = f.x - r.x, f.y - r.y, f.z - r.z
		if math.sqrt(dx * dx + dy * dy + dz * dz) < Skydive.RING_R + 0.6 * M then
			r.state = "got"
			f.got += 1
			f.next += 1
			f.vy += Skydive.RING_LIFT
			f.boost = math.min(4 * M, f.boost + 2 * M)
			event = "ring"
			Skydive.settle(f.rings, f.next, f.x, f.y, f.z, f.vy, f.speed)
		elseif dx * r.dx + dz * r.dz > 4 * M then
			r.state = "missed"
			f.next += 1
			Skydive.settle(f.rings, f.next, f.x, f.y, f.z, f.vy, f.speed)
		end
	end

	if (f.phase ~= "launch" and f.y - ground(f.x, f.z) < Skydive.END_ALT) or f.t > Skydive.MAX_TIME then
		f.phase = "done"
		event = "end"
	end
	return event
end

return table.freeze(Skydive)
