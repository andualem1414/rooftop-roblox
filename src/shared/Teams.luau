--!strict
-- Teams: the race's 20 climbers play as five teams of four. Each team starts together on its own floor
-- (team 1 on floor 1 … team 5 on floor 5), teammates can't hurt each other, and the race is won by a
-- team: a platform carries riders up through the roof only if they're all on one team, and then every
-- member of that team wins (shared/Rules escape).
-- Who goes where: friends who came in together share a team (a group bigger than a team is split in
-- fours), everyone else is spread over the teams so players fight players, and bots fill the gaps.
-- Teams are numbered 1..TEAMS; 0 means no team. Pure functions: `rand(a, b)` is a random integer a..b.

local Config = require("./Config")

local Teams = {}

Teams.SIZE = Config.TEAM_SIZE
Teams.COUNT = Config.TEAMS

-- names and colours (RGB; Roblox code turns them into Color3, the player list's teams use BRICK)
Teams.NAMES = table.freeze({ "Red", "Blue", "Green", "Gold", "Violet" })
Teams.RGB = table.freeze({
	table.freeze({ 230, 74, 60 }),
	table.freeze({ 66, 146, 245 }),
	table.freeze({ 88, 204, 104 }),
	table.freeze({ 244, 198, 60 }),
	table.freeze({ 176, 104, 236 }),
})
Teams.BRICK = table.freeze({ "Bright red", "Bright blue", "Bright green", "Bright yellow", "Royal purple" })

-- "Red team"
function Teams.label(team: number): string
	local name = Teams.NAMES[team]
	return if name then `{name} team` else "No team"
end

-- the floor a team starts on (0-based: team 1 on floor 0, "floor 1" on screen)
function Teams.startFloor(team: number): number
	return Config.START_FLOORS[1] + (math.clamp(team, 1, Teams.COUNT) - 1)
end

-- the team with the fewest members that has room for n more (ties: a random one of them); all full,
-- the one with the fewest members
local function roomiest(counts: { number }, n: number, rand: (number, number) -> number): number
	local best: { number } = {}
	local bestN = math.huge
	local fits = false
	for t = 1, Teams.COUNT do
		local fit = counts[t] + n <= Teams.SIZE
		if (fit and not fits) or (fit == fits and counts[t] < bestN) then
			best, bestN, fits = { t }, counts[t], fit
		elseif fit == fits and counts[t] == bestN then
			table.insert(best, t)
		end
	end
	return best[rand(1, #best)]
end

-- Put the race into teams. `groups` lists the players as groups of friends by size (1 = on their own);
-- returns each group's members' teams (groupTeams[g][j]: member j of group g), then each bot's team.
-- Big groups go first, each on the emptiest team with room for it; bots then fill the emptiest teams,
-- so a full race is five teams of four and a small Studio test is spread over every team.
function Teams.assign(groups: { number }, bots: number, rand: (number, number) -> number): ({ { number } }, { number })
	local counts = table.create(Teams.COUNT, 0)
	local order = table.create(#groups, 0)
	for g = 1, #groups do
		order[g] = g
	end
	table.sort(order, function(a, b)
		return groups[a] > groups[b]
	end)
	local groupTeams: { { number } } = table.create(#groups)
	for g = 1, #groups do
		groupTeams[g] = {}
	end
	for _, g in order do
		local left = groups[g]
		while left > 0 do
			local chunk = math.min(left, Teams.SIZE)
			local t = roomiest(counts, chunk, rand)
			for _ = 1, chunk do
				table.insert(groupTeams[g], t)
			end
			counts[t] += chunk
			left -= chunk
		end
	end
	local botTeams = table.create(bots, 0)
	for i = 1, bots do
		local t = roomiest(counts, 1, rand)
		botTeams[i] = t
		counts[t] += 1
	end
	return groupTeams, botTeams
end

-- Friends as groups: `friends(i, j)` says whether players i and j (1..n) are friends; friends of friends
-- end up together too. Returns the groups as lists of player numbers.
function Teams.friendGroups(n: number, friends: (number, number) -> boolean): { { number } }
	local root = table.create(n, 0)
	for i = 1, n do
		root[i] = i
	end
	local function find(i: number): number
		while root[i] ~= i do
			root[i] = root[root[i]]
			i = root[i]
		end
		return i
	end
	for i = 1, n do
		for j = i + 1, n do
			if friends(i, j) then
				root[find(i)] = find(j)
			end
		end
	end
	local byRoot: { [number]: { number } } = {}
	local out: { { number } } = {}
	for i = 1, n do
		local r = find(i)
		local g = byRoot[r]
		if not g then
			g = {}
			byRoot[r] = g
			table.insert(out, g)
		end
		table.insert(g, i)
	end
	return out
end

-- the team for someone who turns up once the race has started (Studio, a straggler): the smallest
function Teams.forLatecomer(counts: { number }, rand: (number, number) -> number): number
	local padded = table.create(Teams.COUNT, 0)
	for t = 1, Teams.COUNT do
		padded[t] = counts[t] or 0
	end
	return roomiest(padded, 1, rand)
end

return table.freeze(Teams)
