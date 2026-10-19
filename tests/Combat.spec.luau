--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Weapons = require("../src/shared/Weapons")
local Combat = require("../src/shared/Combat")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function noWall()
	return false
end

local function fighter(x: number, z: number, heading: number?)
	local f = Combat.newFighter()
	Combat.loadout(f)
	f.equipped = "melee"
	f.x, f.z, f.heading = x, z, heading or 0
	return f
end

-- run the attacker's attack until its blow lands; returns the blow
local function swing(f, heading: number)
	local a = Combat.startAttack(f, heading)
	assert(a, "attack didn't start")
	for _ = 1, 100 do
		local blow = Combat.tick(f, 0.01)
		if blow then
			return blow
		end
	end
	error("the blow never landed")
end

describe("loadout", function()
	it("starts with a bat and a loaded pistol with spare rounds", function()
		local f = fighter(0, 0)
		expect(f.melee).toBe("bat")
		expect(f.gun).toBe("pistol")
		expect(f.mag).toBe(Weapons.pistol.mag)
		expect(f.reserve).toBe(Weapons.pistol.reserve)
	end)
end)

describe("melee", function()
	it("hits someone in front and in reach", function()
		local a, b = fighter(0, 0, 0), fighter(0, 4)
		local blow = swing(a, 0)
		local hits = Combat.findVictims(a, blow, { a, b }, noWall)
		expect(#hits).toBe(1)
		local r = Combat.applyHit(a, blow.w, b, hits[1].nx, hits[1].nz)
		expect(r.dmg).toBe(Weapons.bat.damage)
		expect(b.hp).toBe(Config.MAX_HP - Weapons.bat.damage)
		expect(b.stagger).toBeNear(Weapons.bat.stagger)
	end)
	it("misses someone behind", function()
		local a, b = fighter(0, 0, 0), fighter(0, -4)
		expect(#Combat.findVictims(a, swing(a, 0), { a, b }, noWall)).toBe(0)
	end)
	it("misses someone out of reach", function()
		local a, b = fighter(0, 0, 0), fighter(0, 30)
		expect(#Combat.findVictims(a, swing(a, 0), { a, b }, noWall)).toBe(0)
	end)
	it("doesn't go through a wall", function()
		local a, b = fighter(0, 0, 0), fighter(0, 4)
		local hits = Combat.findVictims(a, swing(a, 0), { a, b }, function()
			return true
		end)
		expect(#hits).toBe(0)
	end)
	it("the bat cleaves: hits everyone in its arc", function()
		local a, b, c = fighter(0, 0, 0), fighter(-2, 4), fighter(2, 4)
		expect(#Combat.findVictims(a, swing(a, 0), { a, b, c }, noWall)).toBe(2)
	end)
	it("a low swing goes under someone jumping", function()
		local a, b = fighter(0, 0, 0), fighter(0, 4)
		b.lift = 1 * Config.M
		expect(#Combat.findVictims(a, swing(a, 0), { a, b }, noWall)).toBe(0)
	end)
	it("a block in front soaks most of it and makes the attacker reel", function()
		local a, b = fighter(0, 0, 0), fighter(0, 4, math.pi) -- b faces a
		b.blocking = true
		local blow = swing(a, 0)
		local r = Combat.applyHit(a, blow.w, b, 0, 1)
		expect(r.blocked).toBe(true)
		expect(r.dmg).toBe(math.max(1, math.floor(Weapons.bat.damage * 0.12 + 0.5)))
		expect(a.stagger).toBeNear(0.35)
	end)
	it("a block doesn't cover your back", function()
		local a, b = fighter(0, 0, 0), fighter(0, 4, 0) -- b faces away
		b.blocking = true
		local r = Combat.applyHit(a, swing(a, 0).w, b, 0, 1)
		expect(r.blocked).toBe(false)
	end)
	it("knocks out at 0 hp", function()
		local a, b = fighter(0, 0, 0), fighter(0, 4)
		b.hp = 5
		local r = Combat.applyHit(a, swing(a, 0).w, b, 0, 1)
		expect(r.killed).toBe(true)
		expect(b.dead).toBe(true)
		expect(b.hitBy).toBe(a)
	end)
	it("can't swing again until the last swing is over", function()
		local a = fighter(0, 0, 0)
		expect(Combat.startAttack(a, 0) ~= nil).toBe(true)
		local again, why = Combat.startAttack(a, 0)
		expect(again).toBe(nil)
		expect(why).toBe("busy")
	end)
end)

describe("guns", function()
	it("a shot uses a round; an empty gun starts reloading", function()
		local f = fighter(0, 0)
		f.equipped = "gun"
		f.mag = 1
		expect(Combat.startAttack(f, 0) ~= nil).toBe(true)
		expect(f.mag).toBe(0)
		for _ = 1, 50 do
			Combat.tick(f, 0.01)
		end
		local a, why = Combat.startAttack(f, 0)
		expect(a).toBe(nil)
		expect(why).toBe("empty")
		expect(f.reloadT > 0).toBe(true)
	end)
	it("a reload fills the mag from the spare rounds", function()
		local f = fighter(0, 0)
		f.equipped = "gun"
		f.mag, f.reserve = 2, 5
		expect(Combat.startReload(f)).toBe(true)
		for _ = 1, 200 do
			Combat.tick(f, 0.01)
		end
		expect(f.mag).toBe(7)
		expect(f.reserve).toBe(0)
	end)
	it("a headshot does 1.5x, and a guard doesn't stop a bullet", function()
		local a, b = fighter(0, 0), fighter(0, 10, math.pi)
		b.blocking = true
		local r = Combat.applyHit(a, Weapons.pistol, b, 0, 1, true)
		expect(r.blocked).toBe(false)
		expect(r.headshot).toBe(true)
		expect(r.dmg).toBe(math.floor(Weapons.pistol.damage * Config.HEADSHOT + 0.5))
	end)
	it("an ammo box adds two mags, up to a cap", function()
		local f = fighter(0, 0)
		f.reserve = 0
		Combat.addAmmo(f)
		expect(f.reserve).toBe(Weapons.pistol.mag * 2)
		for _ = 1, 10 do
			Combat.addAmmo(f)
		end
		expect(f.reserve).toBe(Weapons.pistol.mag * 8)
	end)
	it("a full climber leaves the ammo box for someone else", function()
		local f = fighter(0, 0)
		f.reserve = Weapons.pistol.mag * 8
		expect(Combat.addAmmo(f)).toBe(false)
		f.reserve = Weapons.pistol.mag * 8 - 1
		expect(Combat.addAmmo(f)).toBe(true)
		expect(f.reserve).toBe(Weapons.pistol.mag * 8)
	end)
end)

describe("health", function()
	it("heals after a quiet spell", function()
		local f = fighter(0, 0)
		f.hp = 50
		f.sinceHurt = 0
		for _ = 1, 400 do
			Combat.tick(f, 0.01) -- 4 s: not yet
		end
		expect(f.hp).toBe(50)
		for _ = 1, 200 do
			Combat.tick(f, 0.01) -- 2 more: healing at 5 a second since 5 s
		end
		expect(f.hp > 50 and f.hp < 60).toBe(true)
	end)
	it("coming to: full health, the starting loadout, a moment of protection", function()
		local f = fighter(0, 0)
		f.hp, f.dead, f.melee, f.gun = 0, true, "sword", nil
		Combat.revive(f)
		expect(f.hp).toBe(Config.MAX_HP)
		expect(f.melee).toBe("bat")
		expect(f.gun).toBe("pistol")
		expect(f.invuln).toBe(Config.WAKE_PROTECTION)
	end)
end)
