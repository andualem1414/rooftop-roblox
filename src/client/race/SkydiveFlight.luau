--!strict
-- The winner's skydive on this client (shared/Skydive has the flight model, RaceService the rules):
--   the pad:    when a player wins it glows on the roof by the sign, with SKYDIVE over it (on every screen);
--               the winner's client notices them on it and tells the server
--   the rings:  everyone lays the same twelve rings from the server's seed; the next one glows gold, a ring
--               taken bursts and grows, a ring missed fades (worked out on every screen from where the
--               winner flies)
--   the flight: the winner's client flies the body (it owns it): A / D or the stick steer, W dives, S
--               flares; a chase camera behind; the count of rings on screen. Four floors above the ground
--               it's over: they hang there (no hitting the ground), the rings they took show big, and a few
--               seconds later it's back to the main screen (Finish; in Studio: the next race).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Skydive = require(ReplicatedStorage.Shared.Skydive)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)
local Cutaway = require(script.Parent.Cutaway)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any
local Audio = require(Common:WaitForChild("Audio")) :: any

local player = Players.LocalPlayer

local SkydiveFlight = {}

local GOLD = Color3.fromRGB(255, 201, 92)
local PALE = Color3.fromRGB(207, 220, 255)
local SEGMENTS = 20

local folder: Folder? = nil

local function clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

local function holder(): Folder
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "Skydive"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function neon(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	parent: Instance,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.CFrame = cf
	p.Parent = parent
	return p
end

---------------------------------------------------------------- the pad

local function buildPad()
	local x, y, z = Skydive.padAt()
	local r = Skydive.PAD.r
	local model = Instance.new("Model")
	model.Name = "Pad"
	local flat = CFrame.Angles(0, 0, math.rad(90))
	neon("Ring", Vector3.new(0.3, r * 2, r * 2), CFrame.new(x, y + 0.2, z) * flat, GOLD, model, Enum.PartType.Cylinder)
	local core = neon(
		"Core",
		Vector3.new(0.34, r * 2 - 1, r * 2 - 1),
		CFrame.new(x, y + 0.22, z) * flat,
		GOLD,
		model,
		Enum.PartType.Cylinder
	)
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.fromRGB(40, 36, 52)
	-- a beam of light up into the sky
	local beam = neon(
		"Beam",
		Vector3.new(40, r * 1.2, r * 1.2),
		CFrame.new(x, y + 20, z) * flat,
		GOLD,
		model,
		Enum.PartType.Cylinder
	)
	beam.Transparency = 0.82
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 18
	light.Brightness = 2
	light.Parent = core
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(240, 80)
	sign.StudsOffset = Vector3.new(0, 7, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 400
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.65)
	title.Font = Ui.TITLE
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(246, 223, 164)
	title.TextStrokeTransparency = 0.2
	title.Text = "SKYDIVE"
	title.Parent = sign
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.65)
	sub.Size = UDim2.fromScale(1, 0.35)
	sub.Font = Ui.BODY
	sub.TextScaled = true
	sub.TextColor3 = Ui.CHALK
	sub.TextStrokeTransparency = 0.3
	sub.Text = "step on the pad"
	sub.Parent = sign
	sign.Parent = core
	model.Parent = holder()
end

---------------------------------------------------------------- the rings

type RingView = { ring: Skydive.Ring, model: Model, parts: { BasePart }, shown: string }

local function buildRing(r: Skydive.Ring): RingView
	local model = Instance.new("Model")
	model.Name = "Ring"
	local cf = CFrame.lookAt(Vector3.new(r.x, r.y, r.z), Vector3.new(r.x + r.dx, r.y, r.z + r.dz))
	local parts = {}
	local R = Skydive.RING_R
	local seg = 2 * math.pi * R / SEGMENTS
	for i = 1, SEGMENTS do
		local a = (i / SEGMENTS) * 2 * math.pi
		local at = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, R, 0)
		table.insert(parts, neon("Bit", Vector3.new(seg * 1.05, 0.7, 0.7), at, PALE, model))
	end
	model.Parent = holder()
	return { ring = r, model = model, parts = parts, shown = "" }
end

local function sparkle(at: Vector3)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 244, 210))
	e.LightEmission = 1
	e.Size = NumberSequence.new(1.6, 0)
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Speed = NumberRange.new(20, 34)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Rate = 0
	e.Parent = a
	e:Emit(70)
	Debris:AddItem(a, 1.6)
end

-- how a ring looks: the next one gold and bright, the rest pale; taken: it grows and fades; missed: fades
local function show(v: RingView, next: boolean)
	local want = if v.ring.state ~= "ahead" then v.ring.state elseif next then "next" else "ahead"
	if want == v.shown then
		return
	end
	v.shown = want
	for _, p in v.parts do
		if want == "next" then
			p.Color = GOLD
			p.Transparency = 0
		elseif want == "ahead" then
			p.Color = PALE
			p.Transparency = 0.45
		else
			local info = TweenInfo.new(if want == "got" then 0.5 else 0.9)
			TweenService:Create(p, info, { Transparency = 1 }):Play()
		end
	end
	if want == "got" then
		local center = Vector3.new(v.ring.x, v.ring.y, v.ring.z)
		sparkle(center)
		Audio.play("firework", center, 0.6)
	end
end

---------------------------------------------------------------- the flight

local function ringsHud(): (TextLabel, ScreenGui)
	local gui = Ui.screen("SkydiveHud", 15)
	local l = Ui.label(gui, "", 30, Ui.TITLE, Ui.GOLD)
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, 80)
	l.Size = UDim2.fromOffset(400, 40)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextStrokeTransparency = 0.3
	return l, gui
end

local function fly(model: Model, x: number, y: number, z: number, yaw: number, seed: number)
	local mine = model == player.Character
	local f = Skydive.launch(x, y, z, yaw, seed)
	local views: { RingView } = {}
	for _, r in f.rings do
		table.insert(views, buildRing(r))
	end
	Audio.play("boost", Vector3.new(x, y, z))
	Audio.play("boostWhoosh", Vector3.new(x, y, z))

	if not mine then
		-- watching: follow the winner's ring progress from where they fly
		local next = 1
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if not model.Parent or not folder then
				conn:Disconnect()
				return
			end
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local v = views[next]
			if root and v then
				local d = root.Position - Vector3.new(v.ring.x, v.ring.y, v.ring.z)
				if d.Magnitude < Skydive.RING_R + 0.6 * Config.M + 2 then
					v.ring.state = "got"
					next += 1
				elseif d.X * v.ring.dx + d.Z * v.ring.dz > 12 then
					v.ring.state = "missed"
					next += 1
				end
			end
			for i, view in views do
				show(view, i == next)
			end
		end)
		return
	end

	-- my flight: my client moves my body, touching nothing
	local char = model
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end
	local groups: { [BasePart]: string } = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			groups[d] = d.CollisionGroup
			d.CollisionGroup = "Boosting"
		end
	end
	hum.PlatformStand = true
	CameraAim.cinematic = true
	Cutaway.suspend(true)
	local label, gui = ringsHud()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local camPos = camera.CFrame.Position
	local camLook = root.Position
	local lean = 0
	local finished = false
	local ended = false -- the flight's over: hanging in the air with the result up
	local reported = false -- the server has heard how many rings
	local hangAt: CFrame? = nil
	local function report()
		if not reported then
			reported = true
			Net.event("Skydive"):FireServer("done", f.got)
		end
	end

	local conn: RBXScriptConnection
	local function stop()
		if finished then
			return
		end
		finished = true
		conn:Disconnect()
		for part, g in groups do
			if part.Parent then
				part.CollisionGroup = g
			end
		end
		hum.PlatformStand = false
		CameraAim.cinematic = false
		Cutaway.suspend(false)
		camera.CameraType = Enum.CameraType.Custom
		task.delay(3, function()
			gui:Destroy()
		end)
		report()
	end
	conn = RunService.RenderStepped:Connect(function(dt: number)
		dt = math.min(dt, 1 / 20)
		if not root.Parent or hum.Health <= 0 then
			stop()
			return
		end
		if ended then
			-- hang where the flight ended, the camera settling; the main screen comes next
			if hangAt then
				root.CFrame = hangAt
			end
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			return
		end
		-- the move input (keys, stick or thumbpad), as Roblox's controls give it, seen from the chase camera:
		-- right steers right, forward dives, back flares
		local mv = camera.CFrame:VectorToObjectSpace(hum.MoveDirection)
		local steer, pitch = math.clamp(mv.X, -1, 1), math.clamp(-mv.Z, -1, 1)
		local event = Skydive.step(f, dt, steer, pitch)
		-- the body: upright off the pad, then lying out flat on the air, banking into turns
		lean += ((if f.phase == "launch" then 0 else 1.25) - lean) * math.min(1, dt * 3)
		local fwd = Vector3.new(math.sin(f.yaw), 0, math.cos(f.yaw))
		local pos = Vector3.new(f.x, f.y, f.z)
		root.CFrame = CFrame.lookAt(pos, pos + fwd) * CFrame.Angles(-lean, 0, -f.bank * 0.8)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- the chase camera: behind and above, looking ahead (it swings round from the roof view at first)
		local climb = math.clamp(f.vy / 60, -0.6, 0.6)
		local camTo = pos - fwd * 28 + Vector3.new(0, 9.6 - climb * 9, 0)
		local lookTo = pos + fwd * 27 + Vector3.new(0, -3.6 + climb * 12, 0)
		camPos = camPos:Lerp(camTo, math.min(1, dt * 5))
		camLook = camLook:Lerp(lookTo, math.min(1, dt * 7))
		camera.CFrame = CFrame.lookAt(camPos, camLook) * CFrame.Angles(0, 0, -f.bank * 0.3)
		camera.FieldOfView = 70 * (1 + 0.18 * math.clamp((f.speed - 36) / 54, 0, 1))
		for i, v in views do
			show(v, i == f.next)
		end
		label.Text = `Rings {f.got} / {Skydive.RINGS}`
		if event == "ring" then
			Audio.play("go")
		elseif event == "end" then
			-- no hitting the ground: hang here, show the rings, then back to the main screen
			camera.FieldOfView = 70
			ended = true
			hangAt = CFrame.lookAt(pos, pos + fwd)
			report()
			label.Position = UDim2.fromScale(0.5, 0.36)
			label.Size = UDim2.fromOffset(700, 90)
			label.TextSize = 72
			label.Text = `RINGS {f.got} / {Skydive.RINGS}`
			local sub = Ui.label(
				gui,
				if f.got >= Skydive.RINGS then "Every one!" elseif f.got >= 8 then "Great flying!" else "Nice flying!",
				26,
				Ui.TEXT,
				Ui.CHALK
			)
			sub.AnchorPoint = Vector2.new(0.5, 0)
			sub.Position = UDim2.new(0.5, 0, 0.36, 96)
			sub.Size = UDim2.fromOffset(600, 34)
			sub.TextXAlignment = Enum.TextXAlignment.Center
			Audio.play(if f.got >= 8 then "win" else "go")
			task.delay(4.5, function()
				Net.event("Finish"):FireServer("leave")
			end)
		end
	end)
end

function SkydiveFlight.init()
	local state = ReplicatedStorage:WaitForChild("RaceState")
	local askedAt = -math.huge
	local function onSky()
		local sky = state:GetAttribute("Skydive")
		if sky == "ready" then
			clear()
			buildPad()
			askedAt = -math.huge
		elseif sky == "" or sky == nil then
			clear()
		end
	end
	state:GetAttributeChangedSignal("Skydive"):Connect(onSky)
	onSky()
	-- the winner on the pad: tell the server, and again every so often while they stand there (the server
	-- sees you a moment late: stepping on at the edge, it can still have you just off the pad and say no)
	RunService.Heartbeat:Connect(function()
		if os.clock() - askedAt < 0.25 or state:GetAttribute("Skydive") ~= "ready" then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or state:GetAttribute("WinnerId") ~= player.UserId then
			return
		end
		local _, y = Skydive.padAt()
		if Skydive.onPad(root.Position.X, root.Position.Z) and math.abs(root.Position.Y - 3 - y) < 6 then
			askedAt = os.clock()
			Net.event("Skydive"):FireServer("launch")
		end
	end)
	Net.event("Skydive").OnClientEvent
		:Connect(function(model: Model, x: number, y: number, z: number, yaw: number, seed: number)
			if typeof(model) == "Instance" and type(seed) == "number" then
				fly(model, x, y, z, yaw, seed)
			end
		end)
end

return SkydiveFlight
