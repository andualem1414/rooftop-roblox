--!strict
-- Fighting for everyone, players and bots alike: health, attacks, blocks, guns and ammo. Pure logic
-- (a port of the original's combat.js): the server owns the fighters and feeds in positions; nothing
-- here touches Roblox instances, so it runs in the tests too.
--
-- Headings are yaw angles in radians, measured so that (sin h, cos h) is the direction in x, z.

local Config = require("./Config")
local Weapons = require("./Weapons")

type Weapon = Weapons.Weapon

local COMBO_WINDOW = 0.45 -- attack again this soon after one ends and the next swing comes the other way

export type Attack = {
	w: Weapon,
	t: number,
	heading: number,
	side: number,
	struck: boolean,
	total: number,
}

export type Fighter = {
	hp: number,
	maxHp: number,
	dead: boolean,
	atk: Attack?,
	cool: number,
	stagger: number,
	blocking: boolean,
	sinceHurt: number,
	invuln: number,
	combo: number,
	comboT: number,
	dmgScale: number,
	-- where they are (filled in by the server every step)
	x: number,
	y: number,
	z: number,
	heading: number,
	lift: number, -- feet above the floor (jumping over a low swing)
	-- what they carry: one melee weapon and one gun; `equipped` is which one is in hand
	melee: string,
	gun: string?,
	equipped: "melee" | "gun" | "none",
	mag: number,
	reserve: number,
	reloadT: number,
	-- who hit them last, and how long ago (for knock-out credit)
	hitBy: any,
	hitAge: number,
}

export type Hit = {
	v: Fighter,
	d: number,
	nx: number,
	nz: number,
}

export type HitResult = {
	dmg: number,
	knock: number,
	blocked: boolean,
	broke: boolean,
	killed: boolean,
	headshot: boolean,
}

local Combat = {}

function Combat.newFighter(dmgScale: number?): Fighter
	return {
		hp = Config.MAX_HP,
		maxHp = Config.MAX_HP,
		dead = false,
		atk = nil,
		cool = 0,
		stagger = 0,
		blocking = false,
		sinceHurt = math.huge,
		invuln = 0,
		combo = 0,
		comboT = 0,
		dmgScale = dmgScale or 1,
		x = 0,
		y = 0,
		z = 0,
		heading = 0,
		lift = 0,
		melee = "bat",
		gun = nil,
		equipped = "none",
		mag = 0,
		reserve = 0,
		reloadT = 0,
		hitBy = nil,
		hitAge = math.huge,
	}
end

-- the start-of-race (and come-to) loadout: bat + pistol, full and with spare rounds
function Combat.loadout(f: Fighter)
	f.melee = "bat"
	Combat.giveGun(f, "pistol")
end

-- a gun you pick up comes loaded, with its usual spare rounds
function Combat.giveGun(f: Fighter, name: string)
	local w = Weapons[name]
	f.gun = name
	f.mag = w.mag
	f.reserve = w.reserve
	f.reloadT = 0
end

-- an ammo box: two magazines' worth for the gun you carry (none if you have no gun, or your spare
-- rounds are already full: then the box stays where it is for someone else)
function Combat.addAmmo(f: Fighter): boolean
	if not f.gun then
		return false
	end
	local w = Weapons[f.gun]
	local cap = w.mag * 8
	if f.reserve >= cap then
		return false
	end
	f.reserve = math.min(f.reserve + w.mag * 2, cap)
	return true
end

function Combat.revive(f: Fighter)
	f.hp = f.maxHp
	f.dead = false
	f.atk = nil
	f.cool = 0
	f.stagger = 0
	f.blocking = false
	f.sinceHurt = math.huge
	f.hitBy = nil
	f.hitAge = math.huge
	f.invuln = Config.WAKE_PROTECTION
	f.reloadT = 0
	Combat.loadout(f)
end

-- the weapon in hand, if any
function Combat.weapon(f: Fighter): Weapon?
	if f.equipped == "melee" then
		return Weapons[f.melee]
	elseif f.equipped == "gun" and f.gun then
		return Weapons[f.gun]
	end
	return nil
end

function Combat.canAttack(f: Fighter): boolean
	return not f.dead and f.atk == nil and f.stagger <= 0 and f.cool <= 0 and f.reloadT <= 0
end

function Combat.canBlock(f: Fighter): boolean
	return not f.dead and f.atk == nil and f.stagger <= 0 and f.equipped == "melee"
end

-- start reloading. Returns true if it started
function Combat.startReload(f: Fighter): boolean
	if not f.gun or f.dead or f.reloadT > 0 or f.atk then
		return false
	end
	local w = Weapons[f.gun]
	if f.mag >= w.mag or f.reserve <= 0 then
		return false
	end
	f.reloadT = w.reload
	return true
end

-- Start an attack toward `heading` with the weapon in hand (fixed from here on: step out of the way and
-- it misses). Returns the attack, or nil and why not: "busy", "unarmed", "empty" (it starts reloading).
function Combat.startAttack(f: Fighter, heading: number): (Attack?, string?)
	local w = Combat.weapon(f)
	if not w then
		return nil, "unarmed"
	end
	if not Combat.canAttack(f) then
		return nil, "busy"
	end
	if w.slot == "gun" then
		if f.mag <= 0 then
			Combat.startReload(f)
			return nil, "empty"
		end
		f.mag -= 1
	end
	f.combo = if f.comboT > 0 then f.combo + 1 else 0
	f.blocking = false
	local a: Attack = {
		w = w,
		t = 0,
		heading = heading,
		side = if f.combo % 2 == 1 then -1 else 1,
		struck = false,
		total = w.windup + w.strike + w.recover,
	}
	f.atk = a
	return a, nil
end

-- how much of your running speed you keep right now (slow while winding up, recovering, blocking)
function Combat.moveScale(f: Fighter): number
	local w = Combat.weapon(f)
	local k = if w then w.move else 1
	local a = f.atk
	if a then
		k *= if a.t < a.w.windup then 0.5 else 0.6
	end
	if f.blocking then
		k *= 0.5
	end
	return k
end

-- advance one fighter's timers by dt. Returns the melee attack whose blow lands now, or nil.
function Combat.tick(f: Fighter, dt: number): Attack?
	f.cool = math.max(0, f.cool - dt)
	f.stagger = math.max(0, f.stagger - dt)
	f.invuln = math.max(0, f.invuln - dt)
	f.comboT -= dt
	f.sinceHurt += dt
	f.hitAge += dt
	if f.reloadT > 0 then
		f.reloadT -= dt
		if f.reloadT <= 0 then
			f.reloadT = 0
			if f.gun then
				local w = Weapons[f.gun]
				local take = math.min(w.mag - f.mag, f.reserve)
				f.mag += take
				f.reserve -= take
			end
		end
	end
	if f.dead then
		return nil
	end
	if f.sinceHurt > Config.REGEN_DELAY and f.hp < f.maxHp then
		f.hp = math.min(f.maxHp, f.hp + Config.REGEN * dt)
	end
	if f.stagger > 0 then
		f.blocking = false
	end
	local a = f.atk
	if not a then
		return nil
	end
	a.t += dt
	local blow = nil
	if not a.struck and a.t >= a.w.windup + a.w.strike * 0.4 then
		a.struck = true
		if a.w.slot == "melee" then
			blow = a
		end
	end
	if a.t >= a.total then
		f.atk = nil
		f.cool = 0.04
		f.comboT = COMBO_WINDOW
	end
	return blow
end

-- Who a melee blow catches: in reach, in the arc, on the same level, not behind a wall.
-- losBlocked(a, b) is true if something tall stands between them.
function Combat.findVictims(
	att: Fighter,
	a: Attack,
	others: { Fighter },
	losBlocked: (Fighter, Fighter) -> boolean
): { Hit }
	local w = a.w
	local hx, hz = math.sin(a.heading), math.cos(a.heading)
	local out: { Hit } = {}
	for _, v in others do
		if v == att or v.dead or v.invuln > 0 then
			continue
		end
		if math.abs(v.y - att.y) > Config.SAME_LEVEL then
			continue
		end
		local dx, dz = v.x - att.x, v.z - att.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d > w.reach + Config.BODY_R then
			continue
		end
		local nx, nz = hx, hz
		if d > 1e-3 then
			nx, nz = dx / d, dz / d
		end
		-- up close the arc is forgiving: someone pressed against you is hard to miss
		local close = 0.8 * Config.M
		local half = math.min(math.pi, math.rad(w.arc) / 2 + (if d < close then 0.6 else 0.12))
		if nx * hx + nz * hz < math.cos(half) then
			continue
		end
		-- a low sweep goes under your feet if you jump it
		if (w.style == "slash" or w.style == "swing") and v.lift > 0.7 * Config.M then
			continue
		end
		if losBlocked(att, v) then
			continue
		end
		table.insert(out, { v = v, d = d, nx = nx, nz = nz })
	end
	table.sort(out, function(p, q)
		return p.d < q.d
	end)
	if w.cleave or #out <= 1 then
		return out
	end
	return { out[1] }
end

-- Land a blow (melee or bullet) on one victim; (nx, nz) is the direction from the attacker to them.
-- Knockback is left to the caller: push the victim along (nx, nz) at result.knock studs/s.
-- scale: several pellets landing together count as one blow this many times as hard (a shotgun)
function Combat.applyHit(
	att: Fighter,
	w: Weapon,
	v: Fighter,
	nx: number,
	nz: number,
	headshot: boolean?,
	scale: number?
): HitResult
	local dmg = w.damage * att.dmgScale * (scale or 1)
	if w.slot == "gun" and headshot then
		dmg *= Config.HEADSHOT
	end
	-- a block only covers what's in front of you, and is no use against a bullet
	local blocked, broke = false, false
	if v.blocking and w.slot == "melee" then
		local fx, fz = math.sin(v.heading), math.cos(v.heading)
		if -(nx * fx + nz * fz) > 0.3 then
			blocked = true
			broke = w.heavy
		end
	end
	if blocked then
		dmg *= if broke then 0.5 else 0.12
	end
	dmg = math.max(1, math.floor(dmg + 0.5))
	v.hp -= dmg
	v.sinceHurt = 0
	v.hitBy = att
	v.hitAge = 0
	local knock = w.knock * (scale or 1)
	if blocked and not broke then
		-- a clean block: barely moves you, and their weapon bounces off (they reel)
		knock *= 0.3
		att.stagger = math.max(att.stagger, 0.35)
	else
		-- hit during your wind-up: the swing is lost
		local va = v.atk
		if va and va.t < va.w.windup then
			v.atk = nil
		end
		v.stagger = math.max(v.stagger, w.stagger * (if broke then 1.2 else 1))
		v.blocking = false
	end
	local killed = false
	if v.hp <= 0 then
		v.hp = 0
		v.dead = true
		v.blocking = false
		v.atk = nil
		killed = true
	end
	return {
		dmg = dmg,
		knock = knock,
		blocked = blocked,
		broke = broke,
		killed = killed,
		headshot = headshot == true and w.slot == "gun",
	}
end

-- a random aim error for one pellet: (yaw, pitch) offsets in radians. err scales it (1 = the weapon's
-- spread; aiming down the sights is steadier). rand() returns 0..1.
function Combat.spread(w: Weapon, err: number, rand: () -> number): (number, number)
	local yaw = (rand() + rand() - 1) * w.spread * err
	local pitch = (rand() + rand() - 1) * w.spread * err * 0.5
	return yaw, pitch
end

return table.freeze(Combat)
