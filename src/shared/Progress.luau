--!strict
-- A player's saved profile: their stats, the look they wear, their settings, their boost credits (bought
-- boosts not yet used: shared/Booster) and the purchases already handed out (so a purchase Roblox reports
-- twice is only counted once). The data store holds it (server/common/ProfileStore); this is the pure part:
-- a fresh profile, cleaning up whatever was stored, adding a race's result to the stats, credits, and the
-- numbers the leaderboards keep.
local Settings = require("./Settings")
local Looks = require("./Looks")

export type Stats = Looks.Stats

export type Profile = {
	v: number,
	stats: Stats,
	look: string,
	settings: Settings.Settings,
	credits: { [string]: number }, -- boost size ("1", "3", "5", "10") -> how many
	receipts: { string }, -- the latest purchases handed out (their PurchaseIds)
}

-- what one race did for one player
export type Result = {
	won: boolean,
	time: number?, -- seconds to get out (the winner)
	knockouts: number,
	highestFloor: number, -- 1..21
}

local Progress = {}

Progress.VERSION = 1
Progress.RECEIPTS_KEPT = 50
local CREDIT_SIZES = { "1", "3", "5", "10" }

-- the leaderboards (OrderedDataStores keep whole numbers: the best time is in tenths of a second)
Progress.BOARDS = {
	{ id = "wins", title = "Most escapes", ascending = false },
	{ id = "knockouts", title = "Most knock-outs", ascending = false },
	{ id = "bestTime", title = "Fastest escapes", ascending = true },
}

function Progress.newStats(): Stats
	return { rounds = 0, wins = 0, knockouts = 0, bestTime = nil, highestFloor = 0 }
end

function Progress.newProfile(): Profile
	return {
		v = Progress.VERSION,
		stats = Progress.newStats(),
		look = Looks.DEFAULT,
		settings = Settings.defaults(),
		credits = {},
		receipts = {},
	}
end

local function count(v: any): number
	if type(v) ~= "number" or v ~= v or v < 0 then
		return 0
	end
	return math.floor(math.min(v, 1e9))
end

-- whatever the data store held (or nothing) as a valid profile
function Progress.sanitize(raw: any): Profile
	local p = Progress.newProfile()
	if type(raw) ~= "table" then
		return p
	end
	local s = raw.stats
	if type(s) == "table" then
		p.stats.rounds = count(s.rounds)
		p.stats.wins = count(s.wins)
		p.stats.knockouts = count(s.knockouts)
		p.stats.highestFloor = math.min(count(s.highestFloor), 21)
		if type(s.bestTime) == "number" and s.bestTime == s.bestTime and s.bestTime > 0 then
			p.stats.bestTime = s.bestTime
		end
	end
	local look = Looks.byId(raw.look)
	if look and Looks.isUnlocked(look, p.stats) then
		p.look = look.id
	end
	p.settings = Settings.sanitize(raw.settings)
	if type(raw.credits) == "table" then
		for _, size in CREDIT_SIZES do
			local n = math.min(count(raw.credits[size]), 999)
			if n > 0 then
				p.credits[size] = n
			end
		end
	end
	if type(raw.receipts) == "table" then
		for _, r in raw.receipts do
			if type(r) == "string" and #r < 80 then
				table.insert(p.receipts, r)
			end
		end
		while #p.receipts > Progress.RECEIPTS_KEPT do
			table.remove(p.receipts, 1)
		end
	end
	return p
end

-- a purchase handed out: one more credit of that size (once per purchase id). Returns false if this
-- purchase was already handed out.
function Progress.grant(p: Profile, purchaseId: string, size: number): boolean
	if table.find(p.receipts, purchaseId) then
		return false
	end
	local k = tostring(size)
	p.credits[k] = (p.credits[k] or 0) + 1
	table.insert(p.receipts, purchaseId)
	while #p.receipts > Progress.RECEIPTS_KEPT do
		table.remove(p.receipts, 1)
	end
	return true
end

-- use one credit of a size. Returns false if there's none.
function Progress.spend(p: Profile, size: number): boolean
	local k = tostring(size)
	local n = p.credits[k] or 0
	if n <= 0 then
		return false
	end
	p.credits[k] = if n > 1 then n - 1 else nil
	return true
end

-- the stats after one more race
function Progress.applyRound(s: Stats, r: Result): Stats
	local out: Stats = {
		rounds = s.rounds + 1,
		wins = s.wins + (if r.won then 1 else 0),
		knockouts = s.knockouts + math.max(0, math.floor(r.knockouts)),
		bestTime = s.bestTime,
		highestFloor = math.max(s.highestFloor, math.clamp(math.floor(r.highestFloor), 0, 21)),
	}
	if r.won and r.time and r.time > 0 and (s.bestTime == nil or r.time < s.bestTime) then
		out.bestTime = math.floor(r.time * 10 + 0.5) / 10
	end
	return out
end

-- what a leaderboard stores for these stats (a whole number), or nil if there's nothing to show
function Progress.boardValue(board: string, s: Stats): number?
	if board == "wins" then
		return if s.wins > 0 then s.wins else nil
	elseif board == "knockouts" then
		return if s.knockouts > 0 then s.knockouts else nil
	elseif board == "bestTime" then
		return if s.bestTime then math.floor(s.bestTime * 10 + 0.5) else nil
	end
	return nil
end

-- a stored leaderboard value as the board shows it
function Progress.boardText(board: string, value: number): string
	if board == "bestTime" then
		local t = value / 10
		return string.format("%d:%04.1f", t // 60, t % 60)
	end
	return tostring(value)
end

return table.freeze(Progress)
