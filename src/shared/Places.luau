--!strict
-- The two places of the experience, by place id (Creator Hub → the experience → Places). While a number is 0
-- the servers look the place up by name instead (server/common/Travel): the race place is the one
-- whose name has "Race" in it, the lobby the other one.
return table.freeze({
	LOBBY = 96194017293551,
	RACE = 127585457284186,
})
