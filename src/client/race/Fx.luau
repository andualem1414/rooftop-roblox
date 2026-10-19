--!strict
-- Shots, hits and knock-outs, drawn on every screen:
--   a shot:    a muzzle flash (a bright star in the gun's colour and a burst of light that lights up the
--              room), a glowing tracer to where the bullet stopped, brass flying out of the gun, and at
--              the far end sparks and a mark on a wall, or a bright burst on a body (no blood: Mild)
--   a hit:     an impact star and a shockwave ring, sparks; a blue-white clang off a guard; a damage
--              number that pops up and drifts off (yellow for a headshot)
--   your own:  the flash, the kick and the camera recoil play the moment you shoot; being hit shakes the
--              camera
--   knock-out: a burst, and the body fades away
--   coming to: a shimmer round the body while nobody can hit it (Config.WAKE_PROTECTION)
--   a boost:   jets of fire from both feet and a warm light, while the Boosting attribute is on
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)
local Poser = require(script.Parent.Poser)
local Common = script.Parent.Parent:WaitForChild("Common")
local Audio = require(Common:WaitForChild("Audio")) :: any
local ClientSettings = require(Common:WaitForChild("ClientSettings")) :: any

local player = Players.LocalPlayer

local Fx = {}

local folder: Folder
local ownShotAt = 0
local rng = Random.new()

-- each gun's colour (as on its model: server/race/Tools)
local ACCENT = {
	pistol = Color3.fromRGB(255, 160, 70),
	rifle = Color3.fromRGB(110, 210, 255),
	smg = Color3.fromRGB(180, 255, 110),
	shotgun = Color3.fromRGB(255, 110, 130),
}
-- (a shotgun's pellets arrive together: one flash for all)
local lastMuzzle: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function fade(inst: Instance, life: number, goal: { [string]: any })
	TweenService:Create(inst, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function bit(size: Vector3, cf: CFrame, color: Color3, life: number, grow: number?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = shape or Enum.PartType.Block
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = folder
	fade(p, life, { Transparency = 1, Size = size * (grow or 1) })
	Debris:AddItem(p, life + 0.05)
	return p
end

-- a flash of light that lights up its surroundings for an instant
local function flashLight(at: Vector3, color: Color3, brightness: number, range: number, life: number)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	holder.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = holder
	fade(light, life, { Brightness = 0 })
	Debris:AddItem(holder, life + 0.05)
end

-- a one-off burst of particles at a point
local function burst(
	at: Vector3,
	color: Color3,
	count: number,
	speed: number,
	size: number,
	life: number,
	texture: string?,
	gravity: number?
)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	holder.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK_TEX
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Acceleration = Vector3.new(0, -(gravity or 30), 0)
	e.Rate = 0
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, life + 0.1)
end

-- a star: two thin crossed bars and a core, turned at random
local function star(at: Vector3, facing: Vector3, color: Color3, size: number, life: number)
	local base = CFrame.lookAt(at, at + facing) * CFrame.Angles(0, 0, rng:NextNumber() * math.pi)
	bit(Vector3.new(size * 0.18, size, 0.05), base, color, life, 0.4)
	bit(Vector3.new(size, size * 0.18, 0.05), base, color, life, 0.4)
	bit(
		Vector3.new(size * 0.5, size * 0.5, size * 0.5),
		CFrame.new(at),
		Color3.new(1, 1, 0.92),
		life * 0.8,
		0.3,
		Enum.PartType.Ball
	)
end

-- a tracer: a beam that's hot at the barrel and fades out toward where it struck
local function tracer(from: Vector3, to: Vector3, color: Color3)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.WorldPosition, a1.WorldPosition = from, to
	a0.Parent, a1.Parent = workspace.Terrain, workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0, beam.Width1 = 0.22, 0.08
	beam.Color = ColorSequence.new(Color3.new(1, 0.97, 0.85), color)
	beam.Transparency = NumberSequence.new(0, 0.35)
	beam.Segments = 1
	beam.Parent = a0
	task.spawn(function()
		local t = 0
		while t < 0.1 do
			t += task.wait()
			local k = math.min(1, t / 0.1)
			beam.Transparency = NumberSequence.new(k, math.min(1, 0.35 + k))
		end
		a0:Destroy()
		a1:Destroy()
	end)
end

-- brass out of the side of the gun
local function casing(model: Instance?)
	if not model or not model:IsA("Model") then
		return
	end
	local tool = model:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local eject = handle and handle:FindFirstChild("Eject")
	if not handle or not eject or not eject:IsA("Attachment") then
		return
	end
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.08, 0.08, 0.22)
	p.Color = Color3.fromRGB(230, 180, 70)
	p.Material = Enum.Material.Metal
	p.CanCollide = true
	p.CollisionGroup = "Debris" -- (it bounces on the floor, never off a climber)
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = eject.WorldCFrame
	p.Parent = folder
	local right = (handle :: BasePart).CFrame.RightVector
	p.AssemblyLinearVelocity = right * rng:NextNumber(8, 12) + Vector3.new(0, rng:NextNumber(8, 12), 0)
	p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), 0)
	Debris:AddItem(p, 1.2)
end

local function muzzleOf(model: Instance?): (Vector3?, Vector3?)
	if not model or not model:IsA("Model") then
		return nil, nil
	end
	local tool = model:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local m = handle and handle:FindFirstChild("Muzzle")
	if m and m:IsA("Attachment") then
		return m.WorldPosition, m.WorldCFrame.LookVector
	end
	return nil, nil
end

-- the flash and the kick at someone's gun
local function muzzle(model: Instance?, weapon: string?, fallback: Vector3?, facing: Vector3?)
	local at, look = muzzleOf(model)
	at = at or fallback
	look = look or facing or Vector3.zAxis
	if not at then
		return
	end
	local color = ACCENT[weapon or ""] or ACCENT.pistol
	Audio.play(weapon or "pistol", at)
	star(at + (look :: Vector3) * 0.3, look :: Vector3, color, 1.3, 0.06)
	flashLight(at, color, 7, 16, 0.09)
	burst(at, Color3.fromRGB(120, 116, 112), 3, 4, 0.8, 0.5, SMOKE_TEX, -2)
	casing(model)
	Poser.shot(model, weapon)
end

-- your own shot, the moment you click
function Fx.ownShot(w: Weapons.Weapon)
	ownShotAt = os.clock()
	local char = player.Character
	muzzle(char, w.name, nil, nil)
	CameraAim.kick(0.018 + w.damage * math.max(1, w.pellets) * 0.0006)
end

local function shot(model: Instance, from: Vector3, to: Vector3, kind: string, weapon: string?)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local d = to - from
	if d.Magnitude < 0.05 then
		return
	end
	local color = ACCENT[weapon or ""] or ACCENT.pistol
	-- (your own flash was already shown when you clicked; a shotgun's pellets share one flash)
	local now = os.clock()
	local own = model == player.Character and now - ownShotAt < 0.4
	if not own and now - (lastMuzzle[model] or 0) > 0.03 then
		lastMuzzle[model] = now
		muzzle(model, weapon, from, d.Unit)
	end
	tracer(from, to, color)
	if kind == "wall" then
		local n = -d.Unit
		bit(
			Vector3.new(0.12, 0.42, 0.42),
			CFrame.lookAt(to + n * 0.02, to + n) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(26, 22, 28),
			6,
			1,
			Enum.PartType.Cylinder
		).Material =
			Enum.Material.SmoothPlastic
		burst(to, Color3.fromRGB(255, 170, 60), 10, 22, 0.35, 0.35)
		burst(to, Color3.fromRGB(150, 140, 130), 3, 3, 1.2, 0.7, SMOKE_TEX, -1)
		flashLight(to, Color3.fromRGB(255, 190, 110), 3, 8, 0.08)
	elseif kind == "body" then
		star(to, -d.Unit, Color3.fromRGB(255, 245, 210), 1.2, 0.09)
		burst(to, Color3.fromRGB(255, 230, 160), 8, 16, 0.3, 0.3)
	end
end

-- a damage number that pops up and drifts away (unless they're switched off in the settings)
local function number(at: Vector3, dmg: number, kind: string)
	if not ClientSettings.get().numbers then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at
		+ Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0, 0.6), rng:NextNumber(-0.8, 0.8))
	anchor.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 44)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.StudsOffset = Vector3.new(0, 1, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = if kind == "head" then `{dmg}!` else tostring(dmg)
	label.TextColor3 = if kind == "head"
		then Color3.fromRGB(255, 214, 60)
		elseif kind == "block" then Color3.fromRGB(150, 190, 255)
		else Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(22, 18, 30)
	label.TextStrokeTransparency = 0
	local scale = Instance.new("UIScale")
	scale.Scale = 1.8
	scale.Parent = label
	label.Parent = gui
	gui.Parent = anchor
	TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = if kind == "head" then 1.25 else 1 }
	):Play()
	TweenService:Create(
		gui,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 4, 0) }
	):Play()
	task.delay(0.45, function()
		fade(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 0.95)
end

local function hit(at: Vector3, dmg: number, kind: string, victim: Instance?, attacker: Instance?)
	if typeof(at) ~= "Vector3" then
		return
	end
	local me = player.Character
	if kind == "block" then
		star(at, Vector3.yAxis, Color3.fromRGB(170, 210, 255), 2.2, 0.12)
		burst(at, Color3.fromRGB(150, 200, 255), 14, 26, 0.35, 0.3)
		flashLight(at, Color3.fromRGB(150, 200, 255), 4, 10, 0.12)
	else
		local color = if kind == "head" then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(255, 255, 255)
		star(at, Vector3.yAxis, color, 2.4, 0.12)
		-- the shockwave: a flat ring that grows and fades
		local ring = bit(
			Vector3.new(0.12, 1.2, 1.2),
			CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 236, 200),
			0.22,
			4,
			Enum.PartType.Cylinder
		)
		ring.Transparency = 0.2
		burst(at, Color3.fromRGB(255, 200, 120), 12, 24, 0.35, 0.35)
	end
	number(at, dmg, kind)
	Audio.play(if kind == "block" then "block" else "hit", at)
	-- feel it when it's you
	if victim and victim == me then
		CameraAim.shake(if kind == "block" then 0.15 else 0.35 + dmg * 0.01)
		if kind ~= "block" then
			Audio.play("hurt")
		end
	elseif attacker and attacker == me then
		CameraAim.shake(0.12)
		Audio.play(if kind == "head" then "headshot" else "hitmarker")
	end
end

-- a knock-out: a burst, and the body fades away
local function knockedOut(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local at = root.Position
	Audio.play("knockout", at)
	star(at, Vector3.yAxis, Color3.fromRGB(255, 255, 255), 4, 0.18)
	burst(at, Color3.fromRGB(190, 170, 255), 24, 30, 0.5, 0.6)
	burst(at, Color3.fromRGB(60, 50, 80), 6, 4, 2, 1.2, SMOKE_TEX, -2)
	flashLight(at, Color3.fromRGB(200, 180, 255), 5, 16, 0.25)
	task.delay(1.2, function()
		for _, d in model:GetDescendants() do
			if (d:IsA("BasePart") and d.Transparency < 1) or d:IsA("Decal") then
				fade(d, 1.2, { Transparency = 1 })
			end
		end
	end)
end

-- an ink outline round every climber (one Highlight each: ~20, well under the 255 shown at once)
local function outline(model: Model)
	if model:FindFirstChild("Ink") then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "Ink"
	h.FillTransparency = 1
	h.OutlineColor = Color3.fromRGB(22, 19, 28)
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
end

-- jets from the feet while someone boosts (the Boosting attribute)
local function jets(model: Model, on: boolean)
	for _, side in { "LeftFoot", "RightFoot" } do
		local foot = model:FindFirstChild(side)
		if not foot or not foot:IsA("BasePart") then
			continue
		end
		local old = foot:FindFirstChild("BoostJet")
		if old then
			old:Destroy()
		end
		if on then
			local a = Instance.new("Attachment")
			a.Name = "BoostJet"
			a.Position = Vector3.new(0, -foot.Size.Y / 2, 0)
			a.Orientation = Vector3.new(180, 0, 0) -- (emitters shoot along +Y: down, out of the sole)
			local fire = Instance.new("ParticleEmitter")
			fire.Texture = "rbxasset://textures/particles/fire_main.dds"
			fire.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 230, 255)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 90)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 30)),
			})
			fire.LightEmission = 1
			fire.LightInfluence = 0
			fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0.1) })
			fire.Transparency =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			fire.Lifetime = NumberRange.new(0.18, 0.32)
			fire.Speed = NumberRange.new(26, 34)
			fire.SpreadAngle = Vector2.new(8, 8)
			fire.Rate = 140
			fire.Parent = a
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 170, 80)
			light.Range = 14
			light.Brightness = 3
			light.Parent = a
			a.Parent = foot
		end
	end
end

-- a body just set down can't be hit for a moment: a shimmer shows it (only drawn here: the server keeps
-- the protection)
local function protected(model: Model)
	local at = model:GetAttribute("SpawnedAt")
	if type(at) ~= "number" then
		return
	end
	local left = Config.WAKE_PROTECTION - (workspace:GetServerTimeNow() - at)
	if left <= 0.2 or model:FindFirstChild("Shimmer") then
		return
	end
	local ff = Instance.new("ForceField")
	ff.Name = "Shimmer"
	ff.Visible = true
	ff.Parent = model
	Debris:AddItem(ff, left)
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	protected(model)
	model:GetAttributeChangedSignal("SpawnedAt"):Connect(function()
		protected(model)
	end)
	model:GetAttributeChangedSignal("Boosting"):Connect(function()
		jets(model, model:GetAttribute("Boosting") == true)
	end)
	outline(model)
	-- a reload's clatter, from the gun
	model:GetAttributeChangedSignal("Reloading"):Connect(function()
		if model:GetAttribute("Reloading") == true then
			Audio.play("reload", model:FindFirstChild("HumanoidRootPart"))
		end
	end)
	local hum = model:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			knockedOut(model)
		end)
	end
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "Fx"
	folder.Parent = workspace
	Net.event("ShotFx").OnClientEvent:Connect(shot)
	Net.event("HitFx").OnClientEvent:Connect(hit)
	-- knock-outs: everyone's characters, players and bots
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(watch)
		if p.Character then
			task.spawn(watch, p.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
	task.spawn(function()
		local bots = workspace:WaitForChild("Bots", 30)
		if bots then
			bots.ChildAdded:Connect(watch)
			for _, m in bots:GetChildren() do
				task.spawn(watch, m)
			end
		end
		-- a new race makes a new Bots folder
		workspace.ChildAdded:Connect(function(c)
			if c.Name == "Bots" then
				c.ChildAdded:Connect(watch)
			end
		end)
	end)
end

return Fx
