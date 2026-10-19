--!strict
-- The looks a climber can wear, after the original's looks.js: each is a whole outfit (top, sleeves,
-- trousers, boots, gloves, a hat, something on the back or round the neck), worn over your own avatar
-- (your face, skin and hair stay yours). "Your avatar" wears nothing over it and is the default; The
-- Climber is free; the rest unlock as you play. The server checks the unlock before it lets a look be
-- worn (server/common/ProfileStore), and puts it on (server/common/LookService).
-- Colours are hex strings, so this runs in the tests as well as in Roblox.

export type Stat = "free" | "rounds" | "wins" | "knockouts" | "highestFloor" | "bestTime"

export type Look = {
	id: string,
	name: string,
	how: string, -- how to unlock it, for the wardrobe
	stat: Stat,
	need: number,
	top: string?, -- torso
	sleeve: string?, -- arms (the top's colour if nil)
	pants: string?,
	boots: string?,
	gloves: string?, -- hands (your skin if nil)
	hat: ("hood" | "cap" | "bandana" | "goggles" | "beanie" | "headband")?,
	hatColor: string?,
	extra: ("backpack" | "satchel" | "scarf")?,
	extraColor: string?,
	accent: string?, -- straps, trims
	kneepads: boolean?,
}

export type Stats = {
	rounds: number,
	wins: number,
	knockouts: number,
	bestTime: number?, -- seconds to get out, the fastest (nil: never got out)
	highestFloor: number, -- 1..20, 21 = the roof
}

local LOOKS: { Look } = {
	{ id = "own", name = "Your avatar", how = "yours from the start", stat = "free", need = 0 },
	{
		id = "climber",
		name = "The Climber",
		how = "yours from the start",
		stat = "free",
		need = 0,
		top = "#c99a3e",
		pants = "#2c3446",
		boots = "#4a3326",
		gloves = "#2a2622",
		extra = "scarf",
		extraColor = "#b8423a",
		accent = "#5b3e27",
	},
	{
		id = "night-shift",
		name = "Night Shift",
		how = "play 3 races",
		stat = "rounds",
		need = 3,
		top = "#34405a",
		pants = "#25272d",
		boots = "#1e1d22",
		hat = "hood",
		hatColor = "#34405a",
		extra = "backpack",
		extraColor = "#8ea5c3",
		accent = "#8ea5c3",
	},
	{
		id = "stairwell",
		name = "Stairwell",
		how = "reach floor 8",
		stat = "highestFloor",
		need = 8,
		top = "#4a5545",
		sleeve = "#b9b2a0",
		pants = "#3d4b66",
		boots = "#3e2c21",
		hat = "cap",
		hatColor = "#c47d3c",
		extra = "satchel",
		extraColor = "#6b4a2e",
		accent = "#c47d3c",
		kneepads = true,
	},
	{
		id = "scrapper",
		name = "Scrapper",
		how = "knock out 5 climbers",
		stat = "knockouts",
		need = 5,
		top = "#8a4e3c",
		sleeve = "#5b5e66",
		pants = "#36312b",
		boots = "#2a221d",
		gloves = "#2a2622",
		hat = "bandana",
		hatColor = "#b4513c",
		accent = "#b4513c",
	},
	{
		id = "roofer",
		name = "Roofer",
		how = "reach floor 16",
		stat = "highestFloor",
		need = 16,
		top = "#6f7a59",
		pants = "#2a2d26",
		boots = "#4b3b2d",
		hat = "goggles",
		hatColor = "#5a4233",
		extra = "backpack",
		extraColor = "#c8b27a",
		accent = "#c8b27a",
		kneepads = true,
	},
	{
		id = "veteran",
		name = "Veteran",
		how = "play 20 races",
		stat = "rounds",
		need = 20,
		top = "#5a5f68",
		pants = "#4a4234",
		boots = "#3e2c21",
		hat = "beanie",
		hatColor = "#6d2f33",
		extra = "scarf",
		extraColor = "#7f8f4e",
		accent = "#d6cebb",
	},
	{
		id = "bruiser",
		name = "Bruiser",
		how = "knock out 30 climbers",
		stat = "knockouts",
		need = 30,
		top = "#3e6562",
		sleeve = "#86847b",
		pants = "#25272d",
		boots = "#1e1d22",
		gloves = "#4a3a2c",
		accent = "#c8b27a",
		kneepads = true,
	},
	{
		id = "escapee",
		name = "Escapee",
		how = "get out first once",
		stat = "wins",
		need = 1,
		top = "#8a3a2e",
		pants = "#2b3242",
		boots = "#2a221d",
		hat = "headband",
		hatColor = "#d6cebb",
		extra = "scarf",
		extraColor = "#c8b27a",
		accent = "#d6cebb",
	},
	{
		id = "ghost",
		name = "Ghost",
		how = "get out in under 4:30",
		stat = "bestTime",
		need = 270,
		top = "#bdb8aa",
		pants = "#3a3e45",
		boots = "#30333a",
		hat = "hood",
		hatColor = "#bdb8aa",
		accent = "#5e9392",
	},
	{
		id = "legend",
		name = "Legend",
		how = "get out first 10 times",
		stat = "wins",
		need = 10,
		top = "#6d2f33",
		pants = "#2c3446",
		boots = "#4a3326",
		gloves = "#2a2622",
		extra = "scarf",
		extraColor = "#c99a3e",
		accent = "#c99a3e",
	},
}

local Looks = {}

Looks.LIST = LOOKS
Looks.DEFAULT = "own"

function Looks.byId(id: string?): Look?
	for _, l in LOOKS do
		if l.id == id then
			return l
		end
	end
	return nil
end

-- is it unlocked by these stats?
function Looks.isUnlocked(l: Look, s: Stats): boolean
	if l.stat == "free" then
		return true
	elseif l.stat == "bestTime" then
		return s.bestTime ~= nil and s.bestTime <= l.need
	end
	return ((s :: any)[l.stat] or 0) >= l.need
end

-- how far along: 0..1 (the bar under a locked look)
function Looks.progress(l: Look, s: Stats): number
	if Looks.isUnlocked(l, s) then
		return 1
	elseif l.stat == "bestTime" then
		return 0
	end
	return math.min(1, ((s :: any)[l.stat] or 0) / l.need)
end

-- the looks these stats unlock that `before` didn't
function Looks.newlyUnlocked(before: Stats, after: Stats): { Look }
	local out = {}
	for _, l in LOOKS do
		if not Looks.isUnlocked(l, before) and Looks.isUnlocked(l, after) then
			table.insert(out, l)
		end
	end
	return out
end

-- a bot's look (bots wear the outfits too, one each, the same for the same bot)
function Looks.forBot(i: number): Look
	return LOOKS[2 + (i - 1) % (#LOOKS - 1)]
end

return table.freeze(Looks)
