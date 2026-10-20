--!strict
local Test = require("./lib/Test")
local Sounds = require("../src/shared/Sounds")
local Weapons = require("../src/shared/Weapons")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function isAsset(id: any): boolean
	return type(id) == "string" and (id:match("^rbxassetid://%d+$") ~= nil or id:match("^rbxasset://sounds/") ~= nil)
end

describe("Sounds", function()
	it("gives every cue a recording, a kind and a volume", function()
		for name, cue in Sounds do
			local kinds = { effects = true, ui = true, music = true }
			expect(kinds[cue.kind] == true).toBeTruthy()
			expect(cue.volume > 0 and cue.volume <= 10).toBeTruthy()
			local takes = cue.takes or cue.tracks
			if takes then
				expect(#takes > 0).toBeTruthy()
				for _, take in takes do
					expect(isAsset(take.id)).toBeTruthy()
				end
			else
				expect(isAsset(cue.id)).toBeTruthy()
			end
			if cue.pitch then
				expect(cue.pitch[1] > 0 and cue.pitch[1] <= cue.pitch[2]).toBeTruthy()
			end
			if cue.range then
				expect(cue.kind).toBe("effects")
			end
			if cue.tracks then
				expect(cue.kind).toBe("music")
			end
			expect(type(name)).toBe("string")
		end
	end)
	it("cuts regions that are long enough to fade", function()
		for _, cue in Sounds do
			for _, take in cue.takes or {} do
				local r = take.region or cue.region
				if r then
					expect(r[1] >= 0 and r[2] > 0.05).toBeTruthy()
					expect((cue.fade or 0) < r[2]).toBeTruthy()
				end
			end
		end
	end)
	it("has a shot for every gun and a swing for every melee weapon", function()
		for _, w in Weapons do
			if type(w) == "table" and w.name then
				expect(Sounds[w.name] ~= nil).toBeTruthy()
			end
		end
	end)
	it("has every cue the game plays", function()
		for _, name in
			{
				"pump",
				"casing",
				"hull",
				"empty",
				"magOut",
				"magDrop",
				"magIn",
				"magInRifle",
				"slide",
				"bolt",
				"shellIn",
				"impact",
				"ricochet",
				"whiz",
				"bodyHit",
				"batHit",
				"block",
				"hitmarker",
				"headshot",
				"hurt",
				"pickup",
				"knockout",
				"boost",
				"boostWhoosh",
				"land",
				"platform",
				"roof",
				"firework",
				"tick",
				"go",
				"click",
				"notice",
				"win",
				"lobbyMusic",
				"raceMusic",
				"roofMusic",
			}
		do
			expect(Sounds[name] ~= nil).toBeTruthy()
		end
	end)
	it("turns the guns' bursts down rather than piling them up", function()
		expect(Sounds.rifle.far and Sounds.smg.far and Sounds.pistol.far and Sounds.shotgun.far).toBeTruthy()
		expect((Sounds.smg.stack or 6) >= 8).toBeTruthy()
		expect((Sounds.rifle.stack or 6) >= 8).toBeTruthy()
	end)
end)
