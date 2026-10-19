--!strict
-- What each weapon does. Melee numbers are the original's (rooftop/src/weapons.js); the pistol is the
-- original's too, with more range for the bigger floors. Times are seconds, distances studs.
--
-- An attack is wind-up -> strike (the blow lands partway in) -> recover; for a gun, the three add up to
-- the time between shots.
--   reach: melee, from your centre to the edge of theirs; range: how far a bullet goes
--   arc: the swing's width in degrees; cleave: hits everyone in the arc, not just the nearest
--   heavy: breaks a block (half the damage gets through)
--   knock: how hard it shoves (studs/s); stagger: how long the one you hit can't act
--   move: running speed while you carry it
--   guns: pellets per shot, spread (radians of aim error), mag, reload (seconds), reserve (spare
--   rounds you start with), auto (hold to keep firing)
--   tier: how much a climber wants it (bots swap up to a higher tier)
--
-- The guns (no real brand names): everyone starts with the pistol. The rifle (full auto, long range),
-- the SMG (full auto, fast, short range, sprays) and the shotgun (eight pellets, brutal up close, slow
-- to reload) turn up on platforms and lying on floors.

local Config = require("./Config")
local M = Config.M

export type Weapon = {
	name: string,
	label: string,
	slot: "melee" | "gun",
	damage: number,
	windup: number,
	strike: number,
	recover: number,
	knock: number,
	stagger: number,
	move: number,
	-- melee
	reach: number,
	arc: number,
	cleave: boolean,
	heavy: boolean,
	style: string,
	-- guns
	range: number,
	pellets: number,
	spread: number,
	mag: number,
	reload: number,
	reserve: number,
	auto: boolean,
	tier: number,
}

local function melee(w: { [string]: any }): Weapon
	w.slot = "melee"
	w.reach *= M
	w.knock *= M
	w.range, w.pellets, w.spread, w.mag, w.reload, w.reserve, w.auto = 0, 0, 0, 0, 0, 0, false
	return table.freeze(w) :: any
end

local function gun(w: { [string]: any }): Weapon
	w.slot = "gun"
	w.range *= M
	w.knock *= M
	w.reach, w.arc, w.cleave, w.heavy, w.style = 0, 0, false, false, "shoot"
	return table.freeze(w) :: any
end

local Weapons: { [string]: Weapon } = {
	bat = melee({
		name = "bat",
		label = "Bat",
		reach = 1.6,
		arc = 140,
		damage = 16,
		windup = 0.24,
		strike = 0.14,
		recover = 0.34,
		knock = 8,
		stagger = 0.5,
		cleave = true,
		heavy = false,
		style = "swing",
		move = 0.97,
		tier = 2,
	}),
	sword = melee({
		name = "sword",
		label = "Sword",
		reach = 1.75,
		arc = 125,
		damage = 22,
		windup = 0.16,
		strike = 0.12,
		recover = 0.27,
		knock = 3,
		stagger = 0.32,
		cleave = true,
		heavy = false,
		style = "slash",
		move = 0.97,
		tier = 2.7,
	}),
	pistol = gun({
		name = "pistol",
		label = "Pistol",
		range = 40,
		damage = 18,
		pellets = 1,
		spread = 0.03,
		windup = 0.02,
		strike = 0.03,
		recover = 0.27,
		mag = 12,
		reload = 1.1,
		reserve = 48,
		auto = false,
		knock = 0.6,
		stagger = 0.1,
		move = 1,
		tier = 3.4,
	}),
	rifle = gun({
		name = "rifle",
		label = "Rifle",
		range = 55,
		damage = 13,
		pellets = 1,
		spread = 0.035,
		windup = 0.01,
		strike = 0.03,
		recover = 0.075,
		mag = 30,
		reload = 1.9,
		reserve = 90,
		auto = true,
		knock = 0.8,
		stagger = 0.06,
		move = 0.92,
		tier = 4.5,
	}),
	smg = gun({
		name = "smg",
		label = "SMG",
		range = 28,
		damage = 8,
		pellets = 1,
		spread = 0.06,
		windup = 0.01,
		strike = 0.02,
		recover = 0.045,
		mag = 32,
		reload = 1.5,
		reserve = 128,
		auto = true,
		knock = 0.4,
		stagger = 0.04,
		move = 1,
		tier = 4,
	}),
	shotgun = gun({
		name = "shotgun",
		label = "Shotgun",
		range = 20,
		damage = 9,
		pellets = 8,
		spread = 0.12,
		windup = 0.02,
		strike = 0.05,
		recover = 0.78,
		mag = 6,
		reload = 2.1,
		reserve = 24,
		auto = false,
		knock = 1.1,
		stagger = 0.35,
		move = 0.95,
		tier = 4.2,
	}),
}

return table.freeze(Weapons)
