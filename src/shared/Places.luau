--!strict
-- The two places of the experience, by place id. Both are 0 until the game is published (phase 7): then
-- fill them in from Creator Hub (the experience → Places) and commit. While a number is 0 the servers
-- look the place up by name instead (server/common/PlaceFinder): the race place is the one whose name
-- has "Race" in it, the lobby the other one.
return table.freeze({
	LOBBY = 0,
	RACE = 0,
})
