--!strict
local Test = require("./lib/Test")
local Progress = require("../src/shared/Progress")
local Looks = require("../src/shared/Looks")
local Settings = require("../src/shared/Settings")
local Lobby = require("../src/shared/Lobby")
local Config = require("../src/shared/Config")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function result(won: boolean, time: number?, kos: number, floor: number): Progress.Result
	return { won = won, time = time, knockouts = kos, highestFloor = floor }
end

describe("Progress", function()
	it("starts a new player with nothing, their own avatar and the default settings", function()
		local p = Progress.newProfile()
		expect(p.stats.rounds).toBe(0)
		expect(p.stats.bestTime).toBe(nil)
		expect(p.look).toBe("own")
		expect(p.settings.music).toBe(Settings.defaults().music)
	end)
	it("cleans up whatever the data store held", function()
		local p = Progress.sanitize({
			stats = { rounds = 4.7, wins = -3, knockouts = "lots", highestFloor = 99, bestTime = 0 / 0 },
			look = "legend",
			settings = { music = 5, effects = -1, sensitivity = 100, shake = "yes" },
		})
		expect(p.stats.rounds).toBe(4)
		expect(p.stats.wins).toBe(0)
		expect(p.stats.knockouts).toBe(0)
		expect(p.stats.highestFloor).toBe(21)
		expect(p.stats.bestTime).toBe(nil)
		expect(p.look).toBe("own") -- (Legend isn't unlocked by these stats)
		expect(p.settings.music).toBe(1)
		expect(p.settings.effects).toBe(0)
		expect(p.settings.sensitivity).toBe(Settings.SENSITIVITY[2])
		expect(p.settings.shake).toBe(true)
		expect(Progress.sanitize(nil).look).toBe("own")
		expect(Progress.sanitize("junk").stats.rounds).toBe(0)
	end)
	it("keeps a look the stats unlock", function()
		local p = Progress.sanitize({ stats = { rounds = 3 }, look = "night-shift" })
		expect(p.look).toBe("night-shift")
	end)
	it("adds a race to the stats", function()
		local s = Progress.newStats()
		s = Progress.applyRound(s, result(false, nil, 2, 7))
		s = Progress.applyRound(s, result(true, 301.26, 1, 21))
		s = Progress.applyRound(s, result(true, 330, 0, 21))
		expect(s.rounds).toBe(3)
		expect(s.wins).toBe(2)
		expect(s.knockouts).toBe(3)
		expect(s.highestFloor).toBe(21)
		expect(s.bestTime).toBeNear(301.3)
	end)
	it("never lowers the highest floor", function()
		local s = Progress.applyRound(Progress.newStats(), result(false, nil, 0, 12))
		s = Progress.applyRound(s, result(false, nil, 0, 3))
		expect(s.highestFloor).toBe(12)
	end)
	it("keeps whole numbers for the leaderboards (the best time in tenths)", function()
		local s = Progress.applyRound(Progress.newStats(), result(true, 263.44, 4, 21))
		expect(Progress.boardValue("wins", s)).toBe(1)
		expect(Progress.boardValue("knockouts", s)).toBe(4)
		expect(Progress.boardValue("bestTime", s)).toBe(2634)
		expect(Progress.boardValue("bestTime", Progress.newStats())).toBe(nil)
		expect(Progress.boardText("bestTime", 2634)).toBe("4:23.4")
		expect(Progress.boardText("wins", 12)).toBe("12")
	end)
end)

describe("Looks", function()
	it("has your own avatar plus ten looks, with unique ids", function()
		expect(#Looks.LIST).toBe(11)
		local seen = {}
		for _, l in Looks.LIST do
			expect(seen[l.id]).toBe(nil)
			seen[l.id] = true
		end
		expect(Looks.byId("own") ~= nil).toBe(true)
		expect(Looks.byId("nope")).toBe(nil)
	end)
	it("unlocks looks by playing", function()
		local s = Progress.newStats()
		expect(Looks.isUnlocked(Looks.byId("climber") :: any, s)).toBe(true)
		expect(Looks.isUnlocked(Looks.byId("night-shift") :: any, s)).toBe(false)
		local after = s
		for _ = 1, 3 do
			after = Progress.applyRound(after, result(false, nil, 0, 8))
		end
		local names = {}
		for _, l in Looks.newlyUnlocked(s, after) do
			names[l.id] = true
		end
		expect(names["night-shift"]).toBe(true)
		expect(names["stairwell"]).toBe(true)
		expect(names["roofer"]).toBe(nil)
	end)
	it("unlocks the Ghost only for a fast escape", function()
		local ghost = Looks.byId("ghost") :: any
		local slow = Progress.applyRound(Progress.newStats(), result(true, 300, 0, 21))
		local fast = Progress.applyRound(Progress.newStats(), result(true, 250, 0, 21))
		expect(Looks.isUnlocked(ghost, slow)).toBe(false)
		expect(Looks.isUnlocked(ghost, fast)).toBe(true)
	end)
	it("shows how far along a locked look is", function()
		local s = Progress.newStats()
		s.knockouts = 15
		expect(Looks.progress(Looks.byId("bruiser") :: any, s)).toBeNear(0.5)
		expect(Looks.progress(Looks.byId("scrapper") :: any, s)).toBe(1)
	end)
	it("gives bots real looks, never your own avatar", function()
		for i = 1, 25 do
			expect(Looks.forBot(i).id ~= "own").toBe(true)
		end
	end)
end)

describe("Lobby", function()
	it("starts the countdown with the first player and stops it when everyone leaves", function()
		expect(Lobby.deadline(100, nil, 0)).toBe(nil)
		expect(Lobby.deadline(100, nil, 1)).toBe(100 + Config.LOBBY_COUNTDOWN)
		expect(Lobby.deadline(110, 145, 3)).toBe(145)
		expect(Lobby.deadline(110, 145, 0)).toBe(nil)
	end)
	it("drops to 5 s once 20 are waiting, never pushing a nearer deadline back", function()
		expect(Lobby.deadline(110, 145, Config.CLIMBERS)).toBe(110 + Config.LOBBY_FULL_COUNTDOWN)
		expect(Lobby.deadline(143, 145, Config.CLIMBERS)).toBe(145)
	end)
	it("waits for the whole group, but not forever", function()
		expect(Lobby.groupReady(0, 5, 100)).toBe(false)
		expect(Lobby.groupReady(4, 5, 3)).toBe(false)
		expect(Lobby.groupReady(5, 5, 3)).toBe(true)
		expect(Lobby.groupReady(4, 5, Config.GROUP_WAIT)).toBe(true)
		expect(Lobby.groupReady(1, 0, 0)).toBe(true)
	end)
	it("reads a group's size back from teleport data, safely", function()
		expect(Lobby.groupSize(Lobby.groupData(7, 0))).toBe(7)
		expect(Lobby.groupSize(nil)).toBe(0)
		expect(Lobby.groupSize({ group = 999 })).toBe(Config.CLIMBERS)
		expect(Lobby.groupSize({ group = "7" })).toBe(0)
	end)
end)
