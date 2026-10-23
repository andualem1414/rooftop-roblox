--!strict
local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Teams = require("../src/shared/Teams")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- always the first of the tied teams
local function first(a: number, _b: number): number
	return a
end

local function sizes(groupTeams: { { number } }, botTeams: { number }): { number }
	local count = table.create(Teams.COUNT, 0)
	for _, g in groupTeams do
		for _, t in g do
			count[t] += 1
		end
	end
	for _, t in botTeams do
		count[t] += 1
	end
	return count
end

describe("Teams", function()
	it("are five teams of four", function()
		expect(Teams.COUNT * Teams.SIZE).toBe(Config.CLIMBERS)
		expect(#Teams.NAMES).toBe(Teams.COUNT)
		expect(#Teams.RGB).toBe(Teams.COUNT)
		expect(#Teams.BRICK).toBe(Teams.COUNT)
	end)
	it("start on their own floor: team 1 on floor 1 … team 5 on floor 5", function()
		for t = 1, Teams.COUNT do
			expect(Teams.startFloor(t)).toBe(t - 1)
		end
		expect(Teams.startFloor(Teams.COUNT)).toBe(Config.START_FLOORS[2])
	end)
	it("fill a full race to four each", function()
		local groups = { 1, 1, 1 }
		local g, b = Teams.assign(groups, 17, first)
		for _, n in sizes(g, b) do
			expect(n).toBe(4)
		end
	end)
	it("spread players on their own over the teams", function()
		local g = Teams.assign({ 1, 1, 1, 1, 1 }, 15, first)
		local seen = {}
		for _, members in g do
			expect(seen[members[1]]).toBe(nil)
			seen[members[1]] = true
		end
	end)
	it("keep friends together", function()
		local g, b = Teams.assign({ 1, 3, 1, 2 }, 13, first)
		expect(g[2][1]).toBe(g[2][2])
		expect(g[2][2]).toBe(g[2][3])
		expect(g[4][1]).toBe(g[4][2])
		-- the two groups and the two on their own each get a team of their own
		local teams = { g[1][1], g[2][1], g[3][1], g[4][1] }
		for i = 1, #teams do
			for j = i + 1, #teams do
				expect(teams[i] ~= teams[j]).toBe(true)
			end
		end
		for _, n in sizes(g, b) do
			expect(n).toBe(4)
		end
	end)
	it("split a group bigger than a team into fours", function()
		local g = Teams.assign({ 6 }, 14, first)
		local count = {}
		for _, t in g[1] do
			count[t] = (count[t] or 0) + 1
		end
		local parts = {}
		for _, n in count do
			table.insert(parts, n)
		end
		table.sort(parts)
		expect(#parts).toBe(2)
		expect(parts[1]).toBe(2)
		expect(parts[2]).toBe(4)
	end)
	it("spread a small test's bots over every team", function()
		local g, b = Teams.assign({ 1 }, 3, first)
		local count = sizes(g, b)
		local used = 0
		for _, n in count do
			expect(n <= 1).toBe(true)
			used += n
		end
		expect(used).toBe(4)
	end)
	it("find friends of friends", function()
		-- 1-2 and 2-3 are friends, 4 is on their own
		local groups = Teams.friendGroups(4, function(i, j)
			return (i == 1 and j == 2) or (i == 2 and j == 3)
		end)
		expect(#groups).toBe(2)
		expect(#groups[1]).toBe(3)
		expect(groups[2][1]).toBe(4)
	end)
	it("put a latecomer on the smallest team", function()
		expect(Teams.forLatecomer({ 4, 4, 3, 4, 4 }, first)).toBe(3)
		expect(Teams.forLatecomer({ 4, 4, 4, 4, 4 }, first)).toBe(1)
		expect(Teams.forLatecomer({}, first)).toBe(1)
	end)
	it("have labels", function()
		expect(Teams.label(1)).toBe("Red team")
		expect(Teams.label(0)).toBe("No team")
	end)
end)
