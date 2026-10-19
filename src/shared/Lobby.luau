--!strict
-- The lobby's rules, pure: when the next group goes, and how long a race server waits for its group.
--   the countdown starts (45 s) when the first player is waiting, drops to 5 s once 20 are waiting, and
--   stops if everyone leaves; at zero everyone in the lobby goes, together, to a fresh race server
--   a race server waits for the whole group the lobby sent (its size rides along in the teleport data)
--   before it starts, but not forever: stragglers join a race already under way
local Config = require("./Config")

local Lobby = {}

-- the server time the group goes, given the one set so far (nil: no countdown) and how many are waiting
function Lobby.deadline(now: number, deadline: number?, waiting: number): number?
	if waiting <= 0 then
		return nil
	end
	local d = deadline or now + Config.LOBBY_COUNTDOWN
	if waiting >= Config.CLIMBERS then
		d = math.min(d, now + Config.LOBBY_FULL_COUNTDOWN)
	end
	return d
end

-- has a race server waited long enough for its group? (expected: the group's size, 0 if unknown)
function Lobby.groupReady(arrived: number, expected: number, waited: number): boolean
	if arrived <= 0 then
		return false
	end
	return arrived >= expected or waited >= Config.GROUP_WAIT
end

-- the teleport data a group carries to its race (the client can read it: nothing secret)
export type GroupData = { group: number, sentAt: number }

function Lobby.groupData(size: number, now: number): GroupData
	return { group = size, sentAt = now }
end

-- a group size read back from someone's teleport data (anything odd counts as unknown: 0)
function Lobby.groupSize(data: any): number
	if type(data) ~= "table" or type(data.group) ~= "number" or data.group ~= data.group then
		return 0
	end
	return math.clamp(math.floor(data.group), 0, Config.CLIMBERS)
end

return table.freeze(Lobby)
