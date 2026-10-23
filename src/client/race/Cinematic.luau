--!strict
-- The camera's set pieces (after the original's camera director):
--   the intro: while everyone gets ready, one of three opening shots (picked at random) shows the
--     valley and the tower and settles on the rooftop shot: an orbit round the tower rising as it goes,
--     a crane straight up the face, or a rocket rush in low up the valley and up the face. Then the
--     camera dives down from above, through the floors (they vanish as it passes), into place behind
--     you, and the screen dips to a title card naming your floor ("FLOOR 3 · WAREHOUSE") for a couple
--     of seconds before the start: Roblox rebuilds its lighting round the camera after a big move
--     (measured: about 2.5 s, nearest surfaces first), so without it your room showed dark, then lit up.
--     A click or a key skips to the dive.
--   the roof opening at 4:00: three seconds on the hatch sliding open, then a card ("THE ROOF IS OPEN")
--     while the camera is back with you and the lighting builds (everyone's frozen for all of it)
--   the win: everyone else's camera circles the winner on the roof
-- While a set piece has the camera, Camera.Focus stays on you: Roblox builds its lighting round the focus
-- (create.roblox.com: Camera.Focus), which a scripted camera never moves by itself, so your room keeps its
-- lighting while the camera is away. The cards cover whatever is still building when it comes back.
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
local INTRO_TIME = 4.6
local DIVE_TIME = 2.4
local CURTAIN = 2.4 -- seconds the title card covers the screen at the end, while the lighting builds
local CURTAIN_IN, CURTAIN_OUT = 0.35, 0.6
local ROOF_CARD = 3.2 -- longer: from the roof the camera comes back from much farther (measured ~3.5 s)

-- the title card over the end of the dive: dark, with your floor's number and name
local curtain: ScreenGui? = nil
local function card(): (Frame, TextLabel, TextLabel)
	local gui = curtain
	if not gui then
		local g = Instance.new("ScreenGui")
		g.Name = "Curtain"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 50
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(12, 10, 22)
		back.BackgroundTransparency = 1
		back.BorderSizePixel = 0
		back.Parent = g
		local function text(name: string, size: number, y: number, font: Enum.Font, color: Color3)
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5, y)
			l.Size = UDim2.new(0.9, 0, 0, size * 1.3)
			l.Font = font
			l.TextSize = size
			l.TextColor3 = color
			l.TextTransparency = 1
			l.Parent = back
		end
		text("Floor", 84, 0.44, Enum.Font.LuckiestGuy, Color3.fromRGB(240, 236, 226))
		text("Name", 26, 0.54, Enum.Font.GothamBold, Color3.fromRGB(255, 90, 170))
		g.Parent = player:WaitForChild("PlayerGui")
		curtain = g
		gui = g
	end
	local back = (gui :: ScreenGui):FindFirstChild("Back") :: Frame
	return back, back:FindFirstChild("Floor") :: TextLabel, back:FindFirstChild("Name") :: TextLabel
end

-- show (k = 1) or hide (k = 0) the card, part way
local function curtainTo(k: number)
	local back, floor, name = card()
	back.BackgroundTransparency = 1 - k
	floor.TextTransparency = 1 - k
	name.TextTransparency = 1 - k
end

local function setCard(title: string, sub: string)
	local _, floor, name = card()
	floor.Text = title
	name.Text = sub
end

-- the card's words: your floor and its theme
local function cardFor(char: Model?)
	local _, floor, name = card()
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local f = if root
		then math.clamp(math.floor((root.Position.Y - 3) / Config.FLOOR_HEIGHT + 0.3), 0, Config.FLOORS - 1)
		else 0
	floor.Text = `FLOOR {f + 1}`
	local tower = workspace:FindFirstChild("Tower")
	local model = tower and tower:FindFirstChild(string.format("Floor%02d", f + 1))
	local theme = model and model:GetAttribute("Theme")
	name.Text = if type(theme) == "string" then string.upper(theme) else ""
end

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
	-- (a late arrival gets a shorter card, and shot)
	local hold = math.clamp(left - 1, 0, CURTAIN)
	local diveTime = math.clamp(left - hold - 0.2, 0.6, DIVE_TIME)
	local introTime = math.clamp(left - hold - diveTime - 0.2, 0, INTRO_TIME)
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
		cardFor(player.Character)
		local d = 0
		while d < diveTime and id == playing do
			d += RunService.RenderStepped:Wait()
			-- the card comes up over the last moment of the dive
			if hold > 0 then
				curtainTo(math.clamp((d - (diveTime - CURTAIN_IN)) / CURTAIN_IN, 0, 1))
			end
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
		-- behind the card the camera waits in place while the lighting builds round it, then the card fades
		-- out onto your lit room as the race starts
		while hold > 0 and id == playing do
			RunService.RenderStepped:Wait()
			local rest = CameraAim.restingCFrame()
			if rest then
				workspace.CurrentCamera.CFrame = rest
			end
			local toGo = startAt - workspace:GetServerTimeNow()
			curtainTo(math.clamp(toGo / CURTAIN_OUT, 0, 1))
			if toGo <= 0 then
				break
			end
		end
		curtainTo(0)
		finish(id)
	end)
end

-- the roof opening: the hatch sliding open, from above
function Cinematic.roof(seconds: number)
	local id = begin()
	Cutaway.suspend(true)
	local a, b = Vector3.new(0, H + 33, 57), Vector3.new(9, H + 20, 38)
	local look = Vector3.new(0, H + 2, 0)
	local hold = math.clamp(seconds - 1, 0, ROOF_CARD) -- the card at the end
	local shot = seconds - hold
	local endsAt = os.clock() + seconds
	setCard("THE ROOF IS OPEN", "ONLY ONE CAN ESCAPE")
	task.spawn(function()
		local t = 0
		while t < shot and id == playing do
			t += RunService.RenderStepped:Wait()
			aim(a:Lerp(b, ease(math.min(1, t / shot))), look)
			if hold > 0 then
				curtainTo(math.clamp((t - (shot - CURTAIN_IN)) / CURTAIN_IN, 0, 1))
			end
		end
		-- back with you behind the card while the lighting builds, then the card fades as you're let go
		Cutaway.suspend(false)
		while hold > 0 and id == playing do
			RunService.RenderStepped:Wait()
			local rest = CameraAim.restingCFrame()
			if rest then
				workspace.CurrentCamera.CFrame = rest
			end
			local toGo = endsAt - os.clock()
			curtainTo(math.clamp(toGo / CURTAIN_OUT, 0, 1))
			if toGo <= 0 then
				break
			end
		end
		curtainTo(0)
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
	curtainTo(0)
	CameraAim.cinematic = false
	Cutaway.suspend(false)
end

function Cinematic.init()
	-- the lighting's focus stays on you while a set piece (or the skydive) has the camera
	RunService:BindToRenderStep("RooftopFocus", Enum.RenderPriority.Camera.Value + 2, function()
		if not CameraAim.cinematic then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			workspace.CurrentCamera.Focus = CFrame.new(root.Position + Vector3.new(0, 1.6, 0))
		end
	end)
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
				-- the bodies of those who got out are marked (Escaped): your own if you're one of them
				local found: Model? = nil
				for _, m in Cinematic.climbers() do
					if m:GetAttribute("Escaped") == true and (not found or m == player.Character) then
						found = m
					end
				end
				if found then
					Cinematic.winner(found, Config.CELEBRATION)
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
