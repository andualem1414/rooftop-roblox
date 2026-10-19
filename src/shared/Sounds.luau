--!strict
-- Every sound the game plays, by cue name. Only sounds we may use: Roblox's own licensed library on the
-- Creator Store (ProSoundEffects for effects, APM Music for music; "Courtesy of ..." in their
-- descriptions) and the sounds that ship with every Roblox client (rbxasset://sounds/...).
-- Several cues are cut from a longer recording (region: start and length in seconds, found by measuring
-- the recording's loudness in Studio) or pitched (a range: each play picks one).
-- To change a sound: swap its id here (and listen in Studio).
--   kind: "effects" (in the world, positional when played somewhere), "ui" (flat), "music"

export type Cue = {
	id: string,
	volume: number,
	pitch: { number }?, -- { low, high }
	region: { number }?, -- { start, length }
	range: number?, -- studs it carries (positional sounds)
	kind: "effects" | "ui" | "music",
	loop: boolean?,
}

local REVOLVER = "rbxassetid://9118163044" -- Revolver Standard Bullets 5 (ProSoundEffects)
local RIFLE = "rbxassetid://9118173739" -- Rifle Single Shots 1 (ProSoundEffects)
local PISTOL_KIT = "rbxassetid://9117399029" -- Pistol Single Shots 1: shot, ricochets, handling
local WHOOSH = "rbxassetid://9120972444" -- Wood Whoosh Slicing Air Quick Swings 1 (ProSoundEffects)
local WHOOSH_FAST = "rbxassetid://9120972321" -- Wood Whoosh Slicing Air Quick Swings 4 (ProSoundEffects)
local THUD = "rbxasset://sounds/action_jump_land.mp3" -- (ships with Roblox)
local BOOM = "rbxasset://sounds/impact_explosion_03.mp3" -- (ships with Roblox)
local TICK = "rbxasset://sounds/volume_slider.ogg" -- (ships with Roblox)

local CUES: { [string]: Cue } = {
	-- guns (the shot cue is the gun's name)
	pistol = { id = REVOLVER, volume = 0.7, pitch = { 0.96, 1.04 }, region = { 0, 0.6 }, range = 220, kind = "effects" },
	rifle = { id = RIFLE, volume = 0.5, pitch = { 1.08, 1.16 }, region = { 0, 0.45 }, range = 260, kind = "effects" },
	smg = { id = REVOLVER, volume = 0.42, pitch = { 1.38, 1.5 }, region = { 0, 0.22 }, range = 180, kind = "effects" },
	shotgun = { id = RIFLE, volume = 0.85, pitch = { 0.72, 0.78 }, region = { 0, 0.7 }, range = 240, kind = "effects" },
	reload = { id = PISTOL_KIT, volume = 0.55, region = { 0.28, 0.34 }, range = 50, kind = "effects" },
	empty = { id = TICK, volume = 0.5, pitch = { 1.8, 1.8 }, kind = "ui" },
	-- melee
	bat = { id = WHOOSH, volume = 0.6, pitch = { 0.85, 1 }, range = 70, kind = "effects" },
	sword = { id = WHOOSH_FAST, volume = 0.6, pitch = { 1.1, 1.25 }, range = 70, kind = "effects" },
	hit = { id = THUD, volume = 1, pitch = { 0.7, 0.85 }, range = 90, kind = "effects" },
	block = { id = REVOLVER, volume = 0.3, pitch = { 1.9, 2.1 }, region = { 0, 0.12 }, range = 90, kind = "effects" },
	-- you
	hitmarker = { id = TICK, volume = 0.45, pitch = { 2.2, 2.2 }, kind = "ui" },
	headshot = { id = TICK, volume = 0.6, pitch = { 2.8, 2.8 }, kind = "ui" },
	hurt = { id = THUD, volume = 0.6, pitch = { 0.55, 0.6 }, kind = "ui" },
	pickup = { id = PISTOL_KIT, volume = 0.5, pitch = { 1.2, 1.2 }, region = { 0.48, 0.15 }, kind = "ui" },
	knockout = { id = BOOM, volume = 0.3, pitch = { 1.5, 1.7 }, range = 120, kind = "effects" },
	-- a boost: the jets light, the whoosh up the shaft, the landing
	boost = { id = BOOM, volume = 0.45, pitch = { 1.9, 2.1 }, range = 140, kind = "effects" },
	boostWhoosh = { id = WHOOSH, volume = 0.9, pitch = { 0.42, 0.48 }, range = 140, kind = "effects" },
	land = { id = THUD, volume = 1, pitch = { 0.6, 0.65 }, range = 80, kind = "effects" },
	-- the tower
	platform = { id = THUD, volume = 0.9, pitch = { 0.42, 0.48 }, range = 70, kind = "effects" },
	roof = { id = BOOM, volume = 0.8, pitch = { 0.45, 0.5 }, range = 600, kind = "effects" },
	firework = { id = BOOM, volume = 0.45, pitch = { 0.8, 1.2 }, range = 900, kind = "effects" },
	-- the screen
	tick = { id = TICK, volume = 0.6, kind = "ui" },
	go = { id = TICK, volume = 0.8, pitch = { 0.7, 0.7 }, kind = "ui" },
	click = { id = TICK, volume = 0.35, pitch = { 1.3, 1.3 }, kind = "ui" },
	notice = { id = TICK, volume = 0.4, pitch = { 0.85, 0.85 }, kind = "ui" },
	-- music (APM Music, licensed for Roblox)
	win = { id = "rbxassetid://1836473422", volume = 0.7, kind = "music" }, -- Victory Fanfare Sting
	lobbyMusic = { id = "rbxassetid://1846313691", volume = 0.5, kind = "music", loop = true }, -- Zentity A
	raceMusic = { id = "rbxassetid://1837630713", volume = 0.45, kind = "music", loop = true }, -- Distorted Space
	roofMusic = { id = "rbxassetid://1843756238", volume = 0.55, kind = "music", loop = true }, -- Low Drone 25
}

return table.freeze(CUES)
