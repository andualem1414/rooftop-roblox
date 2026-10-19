--!strict
-- Plays the game's sounds (shared/Sounds) on this client: effects where they happen (a position or a part),
-- interface sounds flat, and one music track at a time, faded across. The Music and Effects volumes come
-- from your settings. A cue can't pile up: at most a few copies of it play at once.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientSettings = require(script.Parent.ClientSettings)

local Audio = {}

local MAX_SAME = 6 -- copies of one cue playing at once
local rng = Random.new()
local playing: { [string]: number } = {}
local groups: { [string]: SoundGroup } = {}
local music: Sound? = nil
local musicName: string? = nil

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

local function make(name: string, cue: Sounds.Cue): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = cue.id
	sound.Volume = cue.volume
	sound.Looped = cue.loop == true
	sound.SoundGroup = group(if cue.kind == "music" then "Music" else "Effects")
	local p = cue.pitch
	sound.PlaybackSpeed = if p then p[1] + (p[2] - p[1]) * rng:NextNumber() else 1
	local r = cue.region
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

-- play a cue: at a position, on a part (it follows it), or flat (nil); volume scales it (1 = as listed)
function Audio.play(name: string, at: (Vector3 | Instance)?, volume: number?)
	local cue = Sounds[name]
	if not cue then
		return
	end
	if (playing[name] or 0) >= MAX_SAME then
		return
	end
	local sound = make(name, cue)
	sound.Volume = cue.volume * (volume or 1)
	local holder: Instance? = nil
	if typeof(at) == "Vector3" and cue.kind == "effects" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at :: Vector3
		a.Parent = workspace.Terrain
		holder = a
		sound.Parent = a
	elseif typeof(at) == "Instance" and cue.kind == "effects" then
		sound.Parent = at :: Instance
	else
		sound.Parent = SoundService
	end
	playing[name] = (playing[name] or 0) + 1
	sound:Play()
	local length = if cue.region then cue.region[2] else 3
	local life = length / math.max(0.1, sound.PlaybackSpeed) + 0.25
	task.delay(life, function()
		playing[name] = math.max(0, (playing[name] or 1) - 1)
	end)
	Debris:AddItem(holder or sound, life + 0.1)
end

-- the music: one track at a time, faded across (nil: silence)
function Audio.music(name: string?)
	if name == musicName then
		return
	end
	musicName = name
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
	local s = make(name :: string, cue)
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2), { Volume = cue.volume }):Play()
	music = s
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
