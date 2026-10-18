--!strict
-- The camera's set pieces (after the original's camera director):
--   the intro: while everyone gets ready, one of three opening shots (picked at random) shows the
--     valley and the tower and settles on the rooftop shot: an orbit round the tower rising as it goes,
--     a crane straight up the face, or a rocket rush in low up the valley and up the face. Then the
--     camera dives down from above, through the floors (they vanish as it passes), into place behind
--     you. A click or a key skips to the dive.
--   the roof opening at 4:00: three seconds on the hatch sliding open (everyone's frozen for it)
--   the win: everyone else's camera circles the winner on the roof
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CameraAim = require(script.Parent.CameraAim)
local Cutaway = require(script.Parent.Cutaway)

local player = Players.LocalPlayer
local H = Config.FLOORS * Config.FLOOR_HEIGHT

local Cinematic = {}

local INTRO_END = Vector3.new(0, H + 40, 170) -- the rooftop shot every intro settles on
local LOOK_END = Vector3.new(0, H - 10, 0)
local INTRO_TIME = 5.5
local DIVE_TIME = 2.6

local function ease(x: number): number
	return -(math.cos(math.pi * x) - 1) / 2
end
local function smooth(x: number, a: number, b: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- a smooth curve through points (Catmull-Rom), t 0..1
local function curve(pts: { Vector3 }, t: number): Vector3
	local n = #pts - 1
	local f = math.clamp(t, 0, 1) * n
	local i = math.min(n - 1, math.floor(f))
	local u = f - i
	local p0 = pts[math.max(1, i)]
	local p1, p2 = pts[i + 1], pts[i + 2]
	local p3 = pts[math.min(#pts, i + 3)]
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

type Shot = (t: number) -> (Vector3, Vector3) -- 0..1 -> camera position, point looked at

local CRANE = { Vector3.new(44, 4, 62), Vector3.new(-12, H * 0.5, 52), Vector3.new(12, H + 12, 70), INTRO_END }
local ROCKET = {
	Vector3.new(-90, 6, 820),
	Vector3.new(-24, 10, 430),
	Vector3.new(0, 14, 270),
	Vector3.new(6, H * 0.45, 220),
	Vector3.new(3, H * 0.85, 190),
	INTRO_END,
}

local SHOTS: { [string]: Shot } = {
	-- a full turn round the tower while rising, pulling way out halfway round then back in
	orbit = function(t)
		local k = ease(t)
		local a = math.pi * 2 * (1 - k)
		local r = 260 + (INTRO_END.Z - 260) * k + math.sin(math.pi * k) ^ 2 * 120
		local y = 8 + (INTRO_END.Y - 8) * smooth(k, 0, 0.6)
		return Vector3.new(math.sin(a) * r, y, math.cos(a) * r), Vector3.new(0, 40, 0):Lerp(LOOK_END, k)
	end,
	-- worm's-eye at the foot of the tower, up the face past the windows, then pull back
	crane = function(t)
		local k = ease(t)
		return curve(CRANE, k), Vector3.new(0, 60, 0):Lerp(LOOK_END, k)
	end,
	-- rush in low up the valley, then rise up the face to the rooftop shot
	rocket = function(t)
		local k = ease(t)
		return curve(ROCKET, k), Vector3.new(0, 20 + (LOOK_END.Y - 20) * smooth(k, 0.3, 0.75), 0)
	end,
}
local NAMES = { "orbit", "crane", "rocket" }

local playing = 0 -- bumped for each new set piece (an older one stops when it sees it changed)
local lastShot = ""

local function begin(): number
	playing += 1
	CameraAim.cinematic = true
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	return playing
end

local function finish(id: number)
	if id ~= playing then
		return
	end
	CameraAim.cinematic = false
	Cutaway.suspend(false)
end

local function aim(pos: Vector3, look: Vector3)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(pos, look)
end

-- the intro: an opening shot, then the dive to you; both fit into the time left before the start
-- (a late arrival gets a shorter shot, or just the dive)
function Cinematic.intro(startAt: number)
	local left = startAt - workspace:GetServerTimeNow()
	local diveTime = math.clamp(left - 0.2, 0.6, DIVE_TIME)
	local introTime = math.clamp(left - diveTime - 0.2, 0, INTRO_TIME)
	if introTime < 1.5 then
		introTime = 0
	end
	local id = begin()
	Cutaway.suspend(true)
	local choices = {}
	for _, n in NAMES do
		if n ~= lastShot then
			table.insert(choices, n)
		end
	end
	lastShot = choices[math.random(1, #choices)]
	local shot = SHOTS[lastShot]
	local skipped = false
	local conn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if
			not processed
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.Keyboard
				or input.UserInputType == Enum.UserInputType.Gamepad1
			)
		then
			skipped = true
		end
	end)
	task.spawn(function()
		local t = 0
		while t < introTime and not skipped and id == playing do
			t += RunService.RenderStepped:Wait()
			local pos, look = shot(math.min(1, t / introTime))
			aim(pos, look)
		end
		if introTime == 0 then
			aim(INTRO_END, LOOK_END)
		end
		conn:Disconnect()
		if id ~= playing then
			return
		end
		-- the dive: from where the shot left off, up over the tower, down through the cut floors to you
		local cam = workspace.CurrentCamera.CFrame
		local from = cam.Position
		Cutaway.suspend(false)
		local d = 0
		while d < diveTime and id == playing do
			d += RunService.RenderStepped:Wait()
			local k = ease(math.min(1, d / diveTime))
			local rest = CameraAim.restingCFrame()
			if not rest then
				break
			end
			local above = rest.Position + Vector3.new(0, 70, 0)
			local p = if k < 0.5
				then from:Lerp(Vector3.new(above.X, math.max(from.Y, above.Y), above.Z), ease(k / 0.5))
				else Vector3.new(above.X, math.max(from.Y, above.Y), above.Z)
					:Lerp(rest.Position, ease((k - 0.5) / 0.5))
			local lookAt = LOOK_END:Lerp(rest.Position + rest.LookVector * 20, smooth(k, 0.2, 0.9))
			local cf = CFrame.lookAt(p, lookAt)
			workspace.CurrentCamera.CFrame = cf:Lerp(rest, smooth(k, 0.75, 1))
		end
		finish(id)
	end)
end

-- the roof opening: the hatch sliding open, from above
function Cinematic.roof(seconds: number)
	local id = begin()
	Cutaway.suspend(true)
	local a, b = Vector3.new(0, H + 33, 57), Vector3.new(9, H + 20, 38)
	local look = Vector3.new(0, H + 2, 0)
	task.spawn(function()
		local t = 0
		while t < seconds and id == playing do
			t += RunService.RenderStepped:Wait()
			aim(a:Lerp(b, ease(math.min(1, t / seconds))), look)
		end
		finish(id)
	end)
end

-- the win: circle the winner on the roof (for everyone but the winner)
function Cinematic.winner(model: Model, seconds: number)
	if model == player.Character then
		Cutaway.suspend(true)
		task.delay(seconds, function()
			Cutaway.suspend(false)
		end)
		return
	end
	local id = begin()
	Cutaway.suspend(true)
	task.spawn(function()
		local t = 0
		while t < seconds and id == playing and model.Parent do
			t += RunService.RenderStepped:Wait()
			local at = model:GetPivot().Position
			local a = t * 0.25
			aim(
				at + Vector3.new(math.sin(a) * 28, 14 + math.sin(t * 0.3) * 4, math.cos(a) * 28),
				at + Vector3.new(0, 2, 0)
			)
		end
		finish(id)
	end)
end

-- stop whatever is playing (a new race, coming to, ...)
function Cinematic.stop()
	playing += 1
	CameraAim.cinematic = false
	Cutaway.suspend(false)
end

function Cinematic.init()
	local state = ReplicatedStorage:WaitForChild("RaceState")
	local race = -1
	local function onPhase()
		local phase = state:GetAttribute("Phase")
		if phase == "ready" and state:GetAttribute("Race") ~= race then
			race = state:GetAttribute("Race") :: number
			-- (wait for your body in the tower, then play)
			task.spawn(function()
				for _ = 1, 50 do
					if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						break
					end
					task.wait(0.1)
				end
				Cinematic.intro((state:GetAttribute("StartAt") :: number?) or workspace:GetServerTimeNow())
			end)
		elseif phase == "over" then
			local name = state:GetAttribute("Winner")
			if type(name) == "string" and name ~= "" then
				for _, m in Cinematic.climbers() do
					local hum = m:FindFirstChildOfClass("Humanoid")
					if m.Name == name or (hum and hum.DisplayName == name) then
						Cinematic.winner(m, Config.CELEBRATION)
						break
					end
				end
			end
		elseif phase == "waiting" then
			Cinematic.stop()
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	state:GetAttributeChangedSignal("RoofSceneAt"):Connect(function()
		local at = state:GetAttribute("RoofSceneAt")
		if type(at) == "number" then
			Cinematic.roof(math.max(0.5, at + Config.ROOF_SCENE - workspace:GetServerTimeNow()))
		end
	end)
	onPhase()
end

function Cinematic.climbers(): { Model }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(out, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") then
				table.insert(out, m)
			end
		end
	end
	return out
end

return Cinematic
