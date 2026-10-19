--!strict
-- The arithmetic of a body in motion, for the poses every client draws on every climber
-- (client/race/Poser). Pure numbers, so the tests can pin them.
--   springs:    a value pulled toward a target that overshoots a little and settles, like a body does
--               (recoil, flinches, landings)
--   strafing:   which way to turn the legs, and whether to run backward, for a body that faces one way and
--               moves another (the camera sets where you face)
--   knees:      how far to bend the hips, knees and ankles to lower the body without moving the feet
--   reaching:   how far along a gun the other hand can get (short avatar arms)
-- Angles are radians.

local Motion = {}

export type Spring = { x: number, v: number, freq: number, damping: number }

-- freq: how quickly it moves (radians a second); damping: 1 settles without overshoot, less rings on
function Motion.spring(freq: number, damping: number): Spring
	return { x = 0, v = 0, freq = freq, damping = damping }
end

-- move a spring toward `target` over dt (in short steps: a long frame doesn't blow it up)
function Motion.step(s: Spring, target: number, dt: number)
	local left = math.min(dt, 0.1)
	while left > 0 do
		local h = math.min(left, 1 / 120)
		left -= h
		local w = s.freq
		local a = -w * w * (s.x - target) - 2 * s.damping * w * s.v
		s.v += a * h
		s.x += s.v * h
	end
end

-- a knock: the spring is set moving at this speed (and moves itself back)
function Motion.kick(s: Spring, speed: number)
	s.v += speed
end

-- Moving at (side, forward) (studs/s in the body's own frame, + right, + ahead), how far to turn the legs
-- (+ to the left, at most `limit`) so they run along the way you go, and whether to run them backward
-- (backing off: the legs face the way you face, mirrored, and the run plays in reverse)
function Motion.strafe(side: number, forward: number, limit: number): (number, boolean)
	if side * side + forward * forward < 1e-6 then
		return 0, false
	end
	local a = math.atan2(side, forward) -- 0 ahead, + to the right
	local backward = math.abs(a) > math.pi / 2 + 0.15
	if backward then
		a -= math.pi * (if a > 0 then 1 else -1)
	end
	return -math.clamp(a, -limit, limit), backward
end

-- the bend that lowers the hips by `drop` with the feet where they are: hip +a, knee -2a, ankle +a
-- (thigh and shin lengths in studs)
function Motion.kneeBend(drop: number, thigh: number, shin: number): number
	local legs = thigh + shin
	if drop <= 0 or legs <= 0 then
		return 0
	end
	return math.acos(math.clamp(1 - drop / legs, -1, 1))
end

-- How far along a line (from point a, along unit direction d) a hand at the end of an arm `reach` long from
-- a shoulder at the origin can grip, at most `want`: the far end it can reach, or the nearest point on the
-- line if it can't reach the line at all. (a is relative to the shoulder.)
function Motion.reachAlong(
	ax: number,
	ay: number,
	az: number,
	dx: number,
	dy: number,
	dz: number,
	reach: number,
	want: number
): number
	local ad = ax * dx + ay * dy + az * dz
	local aa = ax * ax + ay * ay + az * az
	local disc = ad * ad - aa + reach * reach
	local t = if disc >= 0 then -ad + math.sqrt(disc) else -ad
	return math.clamp(t, 0, want)
end

-- a smooth 0 -> 1 between a and b
function Motion.smooth(x: number, a: number, b: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- up and back down: 0 at a, 1 halfway, 0 at b (smooth)
function Motion.bump(x: number, a: number, b: number): number
	if x <= a or x >= b then
		return 0
	end
	return math.sin(math.pi * (x - a) / (b - a)) ^ 2
end

-- move `x` toward `to` at `rate` a second
function Motion.approach(x: number, to: number, rate: number, dt: number): number
	if x < to then
		return math.min(to, x + rate * dt)
	end
	return math.max(to, x - rate * dt)
end

-- the share of the way to go in dt for a smooth follow at `rate` (1/s), frame-rate independent
function Motion.follow(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

return table.freeze(Motion)
