--!strict
-- Plays the game's sounds (shared/Sounds) on this client: effects where they happen (a position or a part),
-- interface sounds flat, and one music track at a time, faded across (a playlist plays through, track
-- after track). The Music and Effects volumes come from your settings.
--   takes:   a cue with several recordings picks one each time, never the same twice running
--   a cut:   a region of a longer recording, faded out at its end when it would stop mid-ring
--   a crowd: at most a few copies of a cue play at once; a new one cuts the oldest short (a burst of
--            full auto keeps its newest shots, not its first ones)
--   a burst: shots from the same gun (play's `source`) turn the one before down as they fire, so a burst
--            doesn't pile up into a roar and its last shot rings out in full
--   distance: a `far` cue heard from far off loses its top end, as air does to a distant shot
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientSettings = require(script.Parent.ClientSettings)

local Audio = {}

local MAX_SAME = 6 -- copies of one cue playing at once (unless the cue says)
local DUCK = 0.3 -- an earlier shot of a burst is turned down to this
local FAR_FROM = 40 -- studs: farther, a far cue starts losing its top end
local rng = Random.new()
local playing: { [string]: { Sound } } = {}
local lastTake: { [string]: number } = {}
local lastBy: { [Instance]: { [string]: Sound } } = setmetatable({}, { __mode = "k" }) :: any
local groups: { [string]: SoundGroup } = {}
local music: Sound? = nil
local musicName: string? = nil
local musicTurn = 0 -- (a new choice of music cancels the old playlist's next track)

local function group(name: string): SoundGroup
	local g = groups[name]
	if g then
		return g
	end
	local ng = Instance.new("SoundGroup")
	ng.Name = "Rooftop" .. name
	ng.Parent = SoundService
	groups[name] = ng
	return ng
end

local function applyVolumes()
	local s = ClientSettings.get()
	group("Effects").Volume = s.effects
	group("Music").Volume = s.music
end

-- which recording: one of the takes (not the last one again), or the cue's own
local function pick(name: string, cue: Sounds.Cue): Sounds.Take
	local takes = cue.takes
	if not takes or #takes == 0 then
		return { id = cue.id or "" }
	end
	local k = 1
	if #takes > 1 then
		k = rng:NextInteger(1, #takes - 1)
		if k >= (lastTake[name] or 0) then
			k += 1
		end
	end
	lastTake[name] = k
	return takes[k]
end

local function make(name: string, cue: Sounds.Cue, take: Sounds.Take): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = take.id
	sound.Volume = cue.volume * (take.volume or 1)
	sound.Looped = cue.loop == true
	sound.SoundGroup = group(if cue.kind == "music" then "Music" else "Effects")
	local p = cue.pitch
	sound.PlaybackSpeed = if p then p[1] + (p[2] - p[1]) * rng:NextNumber() else 1
	local r = take.region or cue.region
	if r then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(r[1], r[1] + r[2])
	end
	if cue.range then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = cue.range
	end
	return sound
end

-- far off, the top end goes (up to 18 dB off the highs, a little off the middle)
local function distance(sound: Sound, at: Vector3)
	local cam = workspace.CurrentCamera
	local d = if cam then (cam.CFrame.Position - at).Magnitude else 0
	local k = math.clamp((d - FAR_FROM) / 140, 0, 1)
	if k > 0 then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 0
		eq.MidGain = -6 * k
		eq.HighGain = -18 * k
		eq.Parent = sound
	end
end

-- play a cue: at a position, on a part (it follows it), or flat (nil); volume scales it (1 = as listed);
-- source: whose it is (a climber), for a gun's burst
function Audio.play(name: string, at: (Vector3 | Instance)?, volume: number?, source: Instance?)
	local cue = Sounds[name]
	if not cue then
		return
	end
	local list = playing[name]
	if not list then
		list = {}
		playing[name] = list
	end
	if #list >= (cue.stack or MAX_SAME) then
		local oldest = table.remove(list, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local take = pick(name, cue)
	local sound = make(name, cue, take)
	sound.Volume *= volume or 1
	local holder: Instance? = nil
	local where: Vector3? = nil
	if typeof(at) == "Vector3" and cue.kind == "effects" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at :: Vector3
		a.Parent = workspace.Terrain
		holder = a
		sound.Parent = a
		where = at :: Vector3
	elseif typeof(at) == "Instance" and cue.kind == "effects" then
		sound.Parent = at :: Instance
		where = if (at :: Instance):IsA("BasePart") then (at :: BasePart).Position else nil
	else
		sound.Parent = SoundService
	end
	if cue.far and where then
		distance(sound, where)
	end
	-- a burst: the shot before from this gun steps back
	if source then
		local mine = lastBy[source]
		if not mine then
			mine = {}
			lastBy[source] = mine
		end
		local before = mine[name]
		if before and before.Parent then
			TweenService:Create(before, TweenInfo.new(0.06), { Volume = before.Volume * DUCK }):Play()
		end
		mine[name] = sound
	end
	table.insert(list, sound)
	sound:Play()
	local r = take.region or cue.region
	local length = if r then r[2] else 3
	local speed = math.max(0.1, sound.PlaybackSpeed)
	local life = length / speed + 0.05
	-- a cut faded out at its end (no click)
	local fade = cue.fade
	if fade and r then
		task.delay(math.max(0, (length - fade) / speed), function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(fade / speed), { Volume = 0 }):Play()
			end
		end)
	end
	task.delay(life, function()
		local i = table.find(list, sound)
		if i then
			table.remove(list, i)
		end
	end)
	Debris:AddItem(holder or sound, life + 0.1)
end

-- the music: one track at a time, faded across (nil: silence); a playlist goes on to its next track as
-- each one ends
function Audio.music(name: string?)
	if name == musicName then
		return
	end
	musicName = name
	musicTurn += 1
	local turn = musicTurn
	local old = music
	if old then
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		Debris:AddItem(old, 1.6)
	end
	music = nil
	local cue = name and Sounds[name]
	if not cue then
		return
	end
	local tracks = cue.tracks
	local function start(take: Sounds.Take, fadeIn: number)
		local s = make(name :: string, cue, take)
		s.Looped = tracks == nil
		local full = s.Volume
		s.Volume = 0
		s.Parent = SoundService
		s:Play()
		TweenService:Create(s, TweenInfo.new(fadeIn), { Volume = full }):Play()
		music = s
		return s
	end
	if not tracks or #tracks == 0 then
		start({ id = cue.id or "" }, 2)
		return
	end
	local k = rng:NextInteger(1, #tracks)
	local function nextTrack(fadeIn: number)
		if turn ~= musicTurn then
			return
		end
		local s = start(tracks[k], fadeIn)
		k = k % #tracks + 1
		s.Ended:Once(function()
			Debris:AddItem(s, 0.1)
			nextTrack(0.5)
		end)
	end
	nextTrack(2)
end

function Audio.init()
	applyVolumes()
	ClientSettings.changed:Connect(applyVolumes)
	-- cues the server plays for you (a pickup, a look unlocked)
	Net.event("Cue").OnClientEvent:Connect(function(name: string, at: Vector3?)
		if type(name) == "string" then
			Audio.play(name, at)
		end
	end)
end

return Audio
