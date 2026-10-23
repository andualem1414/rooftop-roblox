--!strict
-- Every sound the game plays, by cue name. Only sounds we may use: Roblox's own licensed library on the
-- Creator Store (ProSoundEffects for effects, APM Music for music; "Courtesy of ..." in their
-- descriptions) and the sounds that ship with every Roblox client (rbxasset://sounds/...).
-- Most cues are cut from a longer recording (region: start and length in seconds). The cuts were found by
-- measuring each recording's loudness and spectrum (where each shot, click or clink starts and how long it
-- rings) and the volumes balance their measured loudness. A cue with takes picks one each time it plays
-- (never the same twice running), and a pitch range picks a speed: no two shots sound quite alike.
-- To change a sound: swap its id here (and listen in Studio).
--   kind: "effects" (in the world, positional when played somewhere), "ui" (flat), "music"
--
-- The guns are real recordings, built the way a gunshot is heard: the crack and the body of the shot, its
-- echo dying away (the rifle's comes back off the valley a second later), and the gun's own mechanics
-- played as their own cues where they happen (the shotgun's pump after each shot, brass ringing on the
-- floor, the magazine out, slapped in, the slide or bolt worked). Heard from far off a shot loses its top
-- (`far`), and a full-auto burst turns its earlier shots down as the next one fires so only the last one
-- rings out (client/common/Audio).
--   pistol   a .45 Win Mag (an L.A.R. Grizzly, five takes): a hard crack, a heavy body and a tail that
--            rings for over half a second (the 9mm takes it had rang for 30 ms: a dull, flat pop)
--   smg      a 9mm Beretta, live rounds, bright takes, a little faster
--   rifle    a .223 CAR-16 (an M16 carbine) outdoors: a hard crack and a long airy echo
--   shotgun  a 12 gauge Mossberg pump (five takes); its pump racked after each shot

export type Take = {
	id: string,
	region: { number }?, -- { start, length }: else the cue's region
	volume: number?, -- scales the cue's volume
}

export type Cue = {
	id: string?, -- one recording, or:
	takes: { Take }?, -- several: one is picked each time
	volume: number,
	pitch: { number }?, -- { low, high }
	region: { number }?, -- { start, length }
	fade: number?, -- seconds faded out at the end of the region (a cut that would otherwise click)
	range: number?, -- studs it carries (positional sounds)
	far: boolean?, -- far off, it loses its top end (air takes the highs out of a distant shot)
	stack: number?, -- at most this many at once (6): a new one cuts the oldest short
	kind: "effects" | "ui" | "music",
	loop: boolean?,
	tracks: { Take }?, -- music: a playlist, played through from a random track (each with its volume)
}

local function asset(id: number): string
	return "rbxassetid://" .. id
end

-- a take: an asset cut at start for length seconds
local function cut(id: number, start: number, length: number, volume: number?): Take
	return { id = asset(id), region = { start, length }, volume = volume }
end

-- the guns
local PISTOL = { -- Pistol Single Shots 12, 5, 4, 11, 3: L.A.R. Grizzly Win Mag .45 (measured: each rings ~0.6 s)
	cut(9117398126, 0, 1.1),
	cut(9117397547, 0, 1.1),
	cut(9117397321, 0, 1.1),
	cut(9117398114, 0, 1.1),
	cut(9117402315, 0, 1.1, 1.1),
}
local SMG = { cut(9114720234, 0, 0.7), cut(9114705401, 0.148, 0.7), cut(9114705646, 0.148, 0.7) } -- 9mm Beretta, live ammunition (single shots, the second of a double)
local RIFLE = { cut(9116335273, 0, 1.3), cut(9116335315, 0, 1.3) } -- Machine Gun 4 and 5: .223 CAR-16, single shots, exterior
local SHOTGUN =
	{ -- 12 Gauge Pump Action Shotgun 1, 2, 6, 8, 10: Mossberg (each recording racks it first: the shot only)
		cut(9112909820, 2.86, 1.1),
		cut(9112909833, 2.27, 1.1),
		cut(9112910052, 2.97, 1.1),
		cut(9112909382, 2.094, 1.0),
		cut(9112909372, 1.36, 1.1),
	}
local PUMP = { cut(9112913173, 0, 0.34), cut(9112913280, 0, 0.34), cut(9112913564, 0, 0.34) } -- 12 Gauge Shotgun, Pump Action, Quick Pumps: back and forward
local CASING = { cut(9113631210, 0, 0.65), cut(9113631437, 0, 0.8), cut(9113631067, 0, 0.9) } -- Bullet Drops: .45 cartridges on concrete
local HULL = { cut(9113105344, 0, 0.35) } -- Ammo Rounds Drop (pitched down: a shotgun shell's dull clack)
-- the gun's mechanics
local MAG_SLAP = cut(9113104358, 0.78, 0.25) -- Ammo Magazine 1: a magazine slapped home
local MAG_RIFLE = cut(9116347641, 1.64, 0.3) -- Machine Gun 12: AK-47 magazine handling, the clip going in
local SLIDE = cut(9117399110, 1.92, 0.35) -- Pistol Single Shots 2: the slide racked back and let go
local BOLT = cut(9116357383, 0.04, 0.55) -- Machine Gun Bolt 3: M85 bolt pulled and released
local PPSH = 9117888960 -- Ppsh Burp Gun 4: cocking and loading, single clicks
local CLICK_MAG = cut(PPSH, 0.74, 0.15) -- the magazine catch
local CLICK_DRY = cut(PPSH, 4.33, 0.12) -- a hammer falling on nothing
local SHELL_IN = cut(9117889191, 1.06, 0.12) -- Ppsh Burp Gun 7: a round pushed in
local MAG_DROP = cut(9113704798, 0, 0.42) -- Canister Drop: a small metal thing landing and bouncing
-- where bullets land
local IMPACT = { cut(9113632248, 0.03, 0.5), cut(9113632257, 0.06, 0.5), cut(9113632067, 0.17, 0.5) } -- Bullet Impact: into a wall
local RICOCHET = { cut(9118168612, 0.188, 0.9), cut(9118168962, 0.182, 0.9), cut(9118168943, 0.186, 0.9) } -- Ricochet Metal
local WHIZ = { cut(9113634444, 0.09, 0.4) } -- Bullet Whiz, Whoosh By
local BODY = { cut(9113514100, 0.01, 0.3), cut(9113573371, 0, 0.25), cut(9113573702, 0, 0.25) } -- Body Hits (gut hits), Boxing Hits: body impacts
-- melee
local WHOOSH = "rbxassetid://9120972444" -- Wood Whoosh Slicing Air Quick Swings 1 (ProSoundEffects; peaks at 0.14)
local SHING = { cut(9119076604, 0.02, 0.7), cut(9119076600, 0.05, 0.7) } -- Shing: a large ringing metal blade swiped
local BAT_HIT = { cut(9125380870, 0.026, 0.4), cut(9125380595, 0.328, 0.4), cut(9125380871, 0.686, 0.4) } -- Baseball, Wood Bat Hits Hard Ball, Power Whacks
local CLANG = { -- Shield, Clang As Hit, Metal Sword; Sword Impact, Multiple Metal Hits
	cut(9119072660, 0, 0.55),
	cut(9119072674, 0, 0.6),
	cut(9119747138, 0.05, 0.5),
	cut(9119747138, 0.69, 0.5),
}
local FALL = { cut(9113481839, 0.02, 0.7), cut(9113481994, 0.06, 0.6) } -- Body Fall Wood, Interior, On Floor (quiet)
-- the screen
local TINK = 9116651688 -- Metal Hits, With Hammer: a light tap
local DING = 9116652187 -- the same, a ringing one
local BEEP = 9117060347 -- NASA Transmission Beep: a short clean tone
local SWITCH = { cut(9117028855, 0, 0.15), cut(9117029050, 0.01, 0.15) } -- Moviola Toggle Switch: sharp single clicks
-- built into Roblox
local THUD = "rbxasset://sounds/action_jump_land.mp3" -- (quiet: peaks at 0.10)
local BOOM = "rbxasset://sounds/impact_explosion_03.mp3"

local CUES: { [string]: Cue } = {
	-- guns (the shot cue is the gun's name)
	pistol = {
		takes = PISTOL,
		volume = 1.1,
		pitch = { 0.97, 1.04 },
		fade = 0.35,
		range = 260,
		far = true,
		kind = "effects",
	},
	smg = {
		takes = SMG,
		volume = 0.9,
		pitch = { 1.06, 1.14 },
		fade = 0.25,
		range = 220,
		far = true,
		stack = 10,
		kind = "effects",
	},
	rifle = {
		takes = RIFLE,
		volume = 0.8,
		pitch = { 0.97, 1.03 },
		fade = 0.4,
		range = 320,
		far = true,
		stack = 10,
		kind = "effects",
	},
	shotgun = {
		takes = SHOTGUN,
		volume = 1.4,
		pitch = { 0.97, 1.03 },
		fade = 0.35,
		range = 300,
		far = true,
		kind = "effects",
	},
	pump = { takes = PUMP, volume = 0.55, pitch = { 0.97, 1.05 }, fade = 0.05, range = 45, kind = "effects" },
	casing = {
		takes = CASING,
		volume = 0.22,
		pitch = { 0.95, 1.1 },
		fade = 0.15,
		range = 28,
		stack = 5,
		kind = "effects",
	},
	hull = { takes = HULL, volume = 0.35, pitch = { 0.7, 0.78 }, fade = 0.1, range = 28, kind = "effects" },
	empty = { takes = { CLICK_DRY }, volume = 1.2, pitch = { 1, 1.05 }, kind = "ui" },
	-- reloads (client/race/Poser plays them as the hands do it)
	magOut = { takes = { CLICK_MAG }, volume = 1.4, pitch = { 1.1, 1.2 }, range = 40, kind = "effects" },
	magDrop = { takes = { MAG_DROP }, volume = 0.35, pitch = { 0.8, 0.9 }, fade = 0.1, range = 35, kind = "effects" },
	magIn = { takes = { MAG_SLAP }, volume = 0.5, pitch = { 0.95, 1.05 }, fade = 0.08, range = 40, kind = "effects" },
	magInRifle = {
		takes = { MAG_RIFLE },
		volume = 0.5,
		pitch = { 0.95, 1.05 },
		fade = 0.08,
		range = 40,
		kind = "effects",
	},
	slide = { takes = { SLIDE }, volume = 0.9, pitch = { 1, 1.08 }, fade = 0.08, range = 40, kind = "effects" },
	bolt = { takes = { BOLT }, volume = 0.6, pitch = { 1, 1.1 }, fade = 0.15, range = 40, kind = "effects" },
	shellIn = { takes = { SHELL_IN }, volume = 1.2, pitch = { 0.9, 1.05 }, range = 35, kind = "effects" },
	-- where bullets land
	impact = {
		takes = IMPACT,
		volume = 0.45,
		pitch = { 0.9, 1.1 },
		fade = 0.15,
		range = 70,
		stack = 5,
		kind = "effects",
	},
	ricochet = {
		takes = RICOCHET,
		volume = 0.3,
		pitch = { 0.9, 1.15 },
		fade = 0.3,
		range = 100,
		stack = 3,
		kind = "effects",
	},
	whiz = { takes = WHIZ, volume = 0.7, pitch = { 0.9, 1.2 }, fade = 0.08, range = 25, stack = 3, kind = "effects" },
	bodyHit = {
		takes = BODY,
		volume = 0.75,
		pitch = { 0.9, 1.1 },
		fade = 0.08,
		range = 80,
		stack = 5,
		kind = "effects",
	},
	-- melee
	bat = { id = WHOOSH, volume = 2.2, pitch = { 0.85, 1 }, range = 70, kind = "effects" }, -- (a quiet recording)
	sword = { takes = SHING, volume = 0.45, pitch = { 1, 1.12 }, fade = 0.25, range = 70, kind = "effects" },
	batHit = { takes = BAT_HIT, volume = 0.55, pitch = { 0.75, 0.85 }, fade = 0.15, range = 90, kind = "effects" },
	block = { takes = CLANG, volume = 0.7, pitch = { 0.95, 1.08 }, fade = 0.15, range = 90, kind = "effects" },
	-- you
	hitmarker = { takes = { cut(TINK, 0, 0.18) }, volume = 0.35, pitch = { 1.25, 1.35 }, fade = 0.06, kind = "ui" },
	headshot = { takes = { cut(DING, 0, 0.6) }, volume = 0.5, pitch = { 1.15, 1.15 }, fade = 0.2, kind = "ui" },
	hurt = { takes = { cut(9113514100, 0.01, 0.35) }, volume = 0.8, pitch = { 0.8, 0.9 }, fade = 0.1, kind = "ui" },
	pickup = { takes = { SLIDE }, volume = 0.6, pitch = { 1.05, 1.05 }, fade = 0.08, kind = "ui" },
	knockout = { takes = FALL, volume = 3, pitch = { 0.9, 1 }, fade = 0.15, range = 90, kind = "effects" },
	-- a boost: the jets light, the whoosh up the shaft, the landing
	boost = { id = BOOM, volume = 0.45, pitch = { 1.9, 2.1 }, range = 140, kind = "effects" },
	boostWhoosh = { id = WHOOSH, volume = 2.6, pitch = { 0.42, 0.48 }, range = 140, kind = "effects" },
	land = { id = THUD, volume = 2.4, pitch = { 0.6, 0.65 }, range = 80, kind = "effects" },
	-- the tower
	platform = { id = THUD, volume = 2.2, pitch = { 0.42, 0.48 }, range = 70, kind = "effects" },
	roof = { id = BOOM, volume = 0.8, pitch = { 0.45, 0.5 }, range = 600, kind = "effects" },
	firework = { id = BOOM, volume = 0.45, pitch = { 0.8, 1.2 }, range = 900, kind = "effects" },
	-- the screen
	tick = { takes = { cut(BEEP, 0, 0.12) }, volume = 0.5, fade = 0.03, kind = "ui" },
	go = { takes = { cut(BEEP, 0, 0.32) }, volume = 0.6, pitch = { 1.5, 1.5 }, fade = 0.08, kind = "ui" },
	click = { takes = SWITCH, volume = 0.45, pitch = { 1, 1.1 }, kind = "ui" },
	notice = { takes = { cut(BEEP, 0, 0.1) }, volume = 0.35, pitch = { 0.8, 0.8 }, fade = 0.03, kind = "ui" },
	-- music (APM Music, licensed for Roblox). Volumes even out the tracks' measured loudness.
	win = { id = asset(1836473422), volume = 0.7, kind = "music" }, -- Victory Fanfare Sting
	lobbyMusic = { -- Gaming Drum & Bass: made for game menus
		volume = 1,
		kind = "music",
		tracks = {
			{ id = asset(80257380636383), volume = 0.62 }, -- Game Lobby
			{ id = asset(140228184971194), volume = 0.66 }, -- Game Lobby Alternate
		},
	},
	raceMusic = { -- Gaming Drum & Bass: fast, bright, the climb
		volume = 1,
		kind = "music",
		tracks = {
			{ id = asset(128698082525288), volume = 0.37 }, -- Speed Test
			{ id = asset(133054925243074), volume = 0.35 }, -- Time Chasing
			{ id = asset(140461535677127), volume = 0.34 }, -- Stamina
			{ id = asset(136116314392444), volume = 0.39 }, -- Take the Money and Run
			{ id = asset(140727561824584), volume = 0.51 }, -- Wave Racer
		},
	},
	roofMusic = { id = asset(81163365032353), volume = 0.42, kind = "music", loop = true }, -- Fighting Robots (Gaming Drum & Bass)
}

return table.freeze(CUES)
