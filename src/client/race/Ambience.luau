--!strict
-- The world's small motions, drawn on each client (none of it matters to the game):
--   the roof's two searchlights sweep the sky (faster, and pink, once the roof is open); the mast's
--   beacon blinks; low mist drifts round the foot of the tower; fireflies at the forest's edge
--   the win: fireworks all round the tower (rockets with trails, coloured bursts that light up the
--   valley), and confetti blown out over the roof
--   the sound of it: the music (low while you climb, a drone once the roof is open, the fanfare for the
--   win), a platform's clunk as it stops on your floor or near it, the roof grinding open, fireworks
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Platforms = require(ReplicatedStorage.Shared.Platforms)
local Hatch = require(ReplicatedStorage.Shared.Hatch)
local Audio = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Audio")) :: any

local Ambience = {}

local H = Config.FLOORS * Config.FLOOR_HEIGHT
local F = Config.FLOOR_HALF
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local rng = Random.new()
local folder: Folder

local function attachmentAt(pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	return a
end

---------------------------------------------------------------- always

local function mist()
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local at = attachmentAt(Vector3.new(math.cos(a) * (F + 40), 2, math.sin(a) * (F + 40)))
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(150, 140, 210))
		e.LightEmission = 0.2
		e.LightInfluence = 0.6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 30) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.86),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(10, 14)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 10)
		e.Rate = 0.6
		e.RotSpeed = NumberRange.new(-6, 6)
		e.Parent = at
	end
end

local function fireflies()
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + rng:NextNumber(0, 0.4)
		local r = rng:NextNumber(110, 170)
		local at = attachmentAt(Vector3.new(math.cos(a) * r, 6, math.sin(a) * r))
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Lifetime = NumberRange.new(3, 6)
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 3
		e.Acceleration = Vector3.new(0, 0.4, 0)
		e.Parent = at
	end
end

local function motion()
	local t = 0
	local hatchDone: number? = nil -- the opening (its HatchOpenAt) whose doors are already drawn open
	RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		local state = ReplicatedStorage:FindFirstChild("RaceState")
		local open = state ~= nil and state:GetAttribute("RoofOpen") == true
		local tower = workspace:FindFirstChild("Tower")
		local roof = tower and tower:FindFirstChild("Roof")
		if not roof then
			return
		end
		-- the hatch sliding open, drawn here every frame (the server only puts the doors where they end up)
		local openAt = roof:GetAttribute("HatchOpenAt") :: number?
		local p = if openAt and openAt ~= hatchDone
			then math.clamp((workspace:GetServerTimeNow() - openAt) / Hatch.OPEN_TIME, 0, 1)
			else nil
		if p and p >= 1 then
			hatchDone = openAt
		end
		for _, d in roof:GetChildren() do
			if d.Name == "Hatch" and d:IsA("BasePart") then
				local closed = d:GetAttribute("Closed") :: CFrame?
				local side = d:GetAttribute("Side") :: number?
				if p and closed and side then
					d.CFrame = closed * Hatch.offset(side, p)
				end
			elseif d.Name == "Searchlight" and d:IsA("BasePart") then
				local phase = (d:GetAttribute("Phase") :: number?) or 0
				local speed = if open then 1.8 else 1
				local to = d:FindFirstChild("To") :: Attachment?
				if to then
					to.Position = Vector3.new(
						math.sin(t * 0.33 * speed + phase) * 140,
						300,
						math.cos(t * 0.27 * speed + phase * 1.3) * 140
					)
				end
				local beam = d:FindFirstChildOfClass("Beam")
				if beam and open then
					beam.Color = ColorSequence.new(Color3.fromRGB(255, 90, 170))
				end
			elseif d.Name == "Beacon" and d:IsA("BasePart") then
				local on = (t % 1.2) < 0.25
				d.Transparency = if on then 0 else 0.85
				local l = d:FindFirstChildOfClass("PointLight")
				if l then
					l.Enabled = on
				end
			end
		end
	end)
end

---------------------------------------------------------------- the win

local function burst(at: Vector3)
	Audio.play("firework", at)
	local a = attachmentAt(at)
	local hue = rng:NextNumber()
	local c1 = Color3.fromHSV(hue, 0.75, 1)
	local c2 = Color3.fromHSV((hue + rng:NextNumber(0.1, 0.4)) % 1, 0.7, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(c1, c2)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(1.4, 2.2)
	e.Speed = NumberRange.new(40, 60)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2.2
	e.Acceleration = Vector3.new(0, -16, 0)
	e.Rate = 0
	e.Parent = a
	e:Emit(90)
	local light = Instance.new("PointLight")
	light.Color = c1
	light.Range = 140
	light.Brightness = 4
	light.Parent = a
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(a, 2.5)
end

local function rocket()
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(80, 220)
	local from = Vector3.new(math.cos(a) * r, 4, math.sin(a) * r)
	local to = Vector3.new(from.X * 0.8, H + rng:NextNumber(40, 140), from.Z * 0.8)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 230, 180)
	p.CFrame = CFrame.new(from)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0.3, 0, 0), Vector3.new(-0.3, 0, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(255, 120, 60))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = p
	p.Parent = folder
	local rise = rng:NextNumber(0.9, 1.3)
	TweenService
		:Create(p, TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(to) })
		:Play()
	task.delay(rise, function()
		burst(to)
		if rng:NextNumber() < 0.35 then
			task.delay(0.15, function()
				burst(to + Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-10, 10), rng:NextNumber(-20, 20)))
			end)
		end
		p:Destroy()
	end)
end

local CONFETTI = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(120, 255, 140),
	Color3.fromRGB(200, 120, 255),
	Color3.fromRGB(255, 255, 255),
}
local function confetti()
	for _, c in { Vector2.new(1, 1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(-1, -1) } do
		local origin = Vector3.new(c.X * (F - 3), H + 3, c.Y * (F - 3))
		for _ = 1, 40 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.5, 0.05, 0.35)
			p.Color = CONFETTI[rng:NextInteger(1, #CONFETTI)]
			p.Material = Enum.Material.SmoothPlastic
			p.CollisionGroup = "Debris"
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.CFrame = CFrame.new(origin) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			p.Parent = folder
			p.AssemblyLinearVelocity =
				Vector3.new(-c.X * rng:NextNumber(5, 25), rng:NextNumber(30, 55), -c.Y * rng:NextNumber(5, 25))
			p.AssemblyAngularVelocity =
				Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
			Debris:AddItem(p, 12)
		end
	end
end

local function celebrate(seconds: number)
	confetti()
	task.spawn(function()
		local t = 0
		while t < seconds - 1.5 do
			rocket()
			t += task.wait(rng:NextNumber(0.2, 0.45))
		end
	end)
end

---------------------------------------------------------------- sound

-- a platform's clunk as it stops, on your floor or the ones next to it (from the shared timetable)
local function platformClunks(state: Instance)
	local stops: { [number]: number } = {}
	RunService.Heartbeat:Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase ~= "climb" and phase ~= "roof" then
			return
		end
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			return
		end
		local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
		local mine = math.floor(feet / Config.FLOOR_HEIGHT + 0.3)
		local t = workspace:GetServerTimeNow() - ((state:GetAttribute("StartAt") :: number?) or 0)
		local roofOpen = state:GetAttribute("RoofOpen") == true
		local first, last = Platforms.launchRange(t)
		for k = first, last do
			local s = Platforms.state(Platforms.age(k, t), roofOpen)
			local stop = s.stop
			if stop and stops[k] ~= stop then
				stops[k] = stop
				if math.abs(stop - mine) <= 1 then
					Audio.play("platform", Vector3.new(0, stop * Config.FLOOR_HEIGHT, 0))
				end
			end
		end
	end)
end

local function music(state: Instance)
	local function pick()
		local phase = state:GetAttribute("Phase")
		local w = state:GetAttribute("Winner")
		if phase == "over" and type(w) == "string" and w ~= "" then
			Audio.music(nil)
			Audio.play("win")
		elseif phase == "roof" then
			Audio.music("roofMusic")
		elseif phase == "ready" or phase == "climb" then
			Audio.music("raceMusic")
		elseif phase == "over" or phase == "leaving" then
			Audio.music(nil)
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(pick)
	pick()
end

function Ambience.init()
	folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = workspace
	mist()
	fireflies()
	motion()
	local state = ReplicatedStorage:WaitForChild("RaceState")
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local w = state:GetAttribute("Winner")
		if state:GetAttribute("Phase") == "over" and type(w) == "string" and w ~= "" then
			celebrate(Config.CELEBRATION)
		end
	end)
	-- the roof grinding open
	state:GetAttributeChangedSignal("RoofSceneAt"):Connect(function()
		if type(state:GetAttribute("RoofSceneAt")) == "number" then
			Audio.play("roof", Vector3.new(0, H + 4, 0))
		end
	end)
	platformClunks(state)
	music(state)
end

return Ambience
