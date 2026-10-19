--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Weapons = require("../src/shared/Weapons")
local Combat = require("../src/shared/Combat")
local Rules = require("../src/shared/Rules")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- damage a second, every pellet landing
local function dps(w: Weapons.Weapon): number
	return w.damage * math.max(1, w.pellets) / (w.windup + w.strike + w.recover)
end

describe("Weapons", function()
	it("has the two melee weapons and the four guns", function()
		for _, name in { "bat", "sword" } do
			expect(Weapons[name].slot).toBe("melee")
		end
		for _, name in { "pistol", "rifle", "smg", "shotgun" } do
			local w = Weapons[name]
			expect(w.slot).toBe("gun")
			expect(w.mag > 0).toBe(true)
			expect(w.reserve >= w.mag * 2).toBe(true)
			expect(w.range > 0).toBe(true)
		end
	end)
	it("names every weapon after itself and gives it a tier", function()
		for name, w in Weapons do
			expect(w.name).toBe(name)
			expect(w.tier > 0).toBe(true)
		end
	end)
	it("makes the found guns better than the pistol everyone starts with", function()
		for _, name in { "rifle", "smg", "shotgun" } do
			expect(Weapons[name].tier > Weapons.pistol.tier).toBe(true)
			expect(dps(Weapons[name]) > dps(Weapons.pistol)).toBe(true)
		end
	end)
	it("gives the rifle the longest range and the shotgun the shortest", function()
		for _, name in { "pistol", "smg", "shotgun" } do
			expect(Weapons.rifle.range > Weapons[name].range).toBe(true)
		end
		for _, name in { "pistol", "rifle", "smg" } do
			expect(Weapons.shotgun.range < Weapons[name].range).toBe(true)
		end
	end)
	it("makes the rifle and the SMG full auto, the pistol and the shotgun not", function()
		expect(Weapons.rifle.auto).toBe(true)
		expect(Weapons.smg.auto).toBe(true)
		expect(Weapons.pistol.auto).toBe(false)
		expect(Weapons.shotgun.auto).toBe(false)
	end)
	it("never knocks out a full-health climber with one shotgun blast", function()
		local blast = Weapons.shotgun.damage * Weapons.shotgun.pellets
		expect(blast < Config.MAX_HP).toBe(true)
	end)
end)

describe("pellets", function()
	it("counts several pellets as one blow, scaled", function()
		local a, v = Combat.newFighter(), Combat.newFighter()
		local r = Combat.applyHit(a, Weapons.shotgun, v, 0, 1, false, 5)
		expect(r.dmg).toBe(Weapons.shotgun.damage * 5)
		expect(r.knock).toBeNear(Weapons.shotgun.knock * 5)
		expect(v.hp).toBe(Config.MAX_HP - Weapons.shotgun.damage * 5)
	end)
	it("picking up a found gun loads it with its own spare rounds", function()
		local f = Combat.newFighter()
		Combat.loadout(f)
		Combat.giveGun(f, "rifle")
		expect(f.gun).toBe("rifle")
		expect(f.mag).toBe(Weapons.rifle.mag)
		expect(f.reserve).toBe(Weapons.rifle.reserve)
	end)
end)

describe("found guns", function()
	it("are never the pistol", function()
		for i = 0, 99 do
			local r = i / 100
			local g = Rules.foundGun(function()
				return r
			end)
			expect(g ~= "pistol").toBe(true)
			expect(Weapons[g].slot).toBe("gun")
		end
	end)
	it("turn up as rifles, SMGs and shotguns", function()
		local seen = {}
		for i = 0, 99 do
			local r = i / 100
			seen[Rules.foundGun(function()
				return r
			end)] = true
		end
		expect(seen.rifle and seen.smg and seen.shotgun).toBe(true)
	end)
	it("lie on floors as swords or found guns", function()
		expect(Rules.floorWeapon(function()
			return 0.1
		end)).toBe("sword")
		local rolls, i = { 0.9, 0.5 }, 0
		local w = Rules.floorWeapon(function()
			i += 1
			return rolls[i]
		end)
		expect(Weapons[w].slot).toBe("gun")
	end)
end)
