--!strict
-- Outside the tower, after the original's world.js / base.js: the tower stands in a forest clearing in a
-- valley, closed in by mountains, under a big moon. A dirt track runs out of the valley to the entrance.
--   terrain   built by each client from the shared recipe (shared/Valley, ValleyTerrain); the server only
--             uses its heights to place things
--   forest    stylised pines (a trunk and three tiers), kept off the camera's lane up the valley
--   the base  a concrete apron, the entrance (landing, steps, columns, a canopy with the name lit up,
--             steel doors), a walkway with lamp posts and lit bollards, drums, the shaft's pit
--   the title ROOFTOP in giant glowing letters on the hillside behind the tower (the O in red)
-- Everything is seeded, so every server builds the same world. Coordinates: the tower is centred on the
-- origin, its ground floor at y = 0, the entrance facing +Z (down the valley).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Valley = require(ReplicatedStorage.Shared.Valley)

local F = Config.FLOOR_HALF
local FH = Config.FLOOR_HEIGHT
local H = Config.SHAFT_HALF
local APRON = F + 18
local WALK_END = APRON + 60

local World = {}

local rng = Random.new(20261018)
local function rr(a: number, b: number): number
	return a + (b - a) * rng:NextNumber()
end

local folder: Model

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "Tower"
	p.Parent = parent or folder
	return p
end

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- glowing text on a face of a part (the part itself stays invisible)
local function sign(p: BasePart, text: string, color: Color3, face: Enum.NormalId, font: Enum.Font?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.Brightness = 2.2
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeColor3 = Color3.fromRGB(20, 14, 30)
	l.TextStrokeTransparency = 0.2
	l.Parent = g
	g.Parent = p
end

---------------------------------------------------------------- forest

-- a stylised pine: a trunk and three tiers, darker at the bottom
local PINES = {
	Color3.fromRGB(34, 78, 64),
	Color3.fromRGB(40, 88, 66),
	Color3.fromRGB(30, 68, 62),
	Color3.fromRGB(46, 96, 74),
}
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))
local function pine(at: Vector3, s: number, parent: Instance)
	local color = PINES[rng:NextInteger(1, #PINES)]
	local trunk = 7 * s
	part(
		"Trunk",
		Vector3.new(trunk, 2.2 * s, 2.2 * s),
		CFrame.new(at + Vector3.new(0, trunk / 2, 0)) * VERTICAL,
		Color3.fromRGB(70, 50, 44),
		Enum.Material.Wood,
		Enum.PartType.Cylinder,
		parent
	)
	local y = trunk - 1
	for i, d in { 17, 12.5, 7.5 } do
		local th = (9 - i) * s
		local tint = color:Lerp(Color3.fromRGB(90, 140, 120), (i - 1) * 0.12)
		part(
			"Tier",
			Vector3.new(th, d * s, d * s),
			CFrame.new(at + Vector3.new(0, y + th / 2, 0)) * VERTICAL * CFrame.Angles(rr(0, 6.28), 0, 0),
			tint,
			Enum.Material.Grass,
			Enum.PartType.Cylinder,
			parent
		)
		y += th * 0.72
	end
	part(
		"Top",
		Vector3.new(2.6 * s, 2.6 * s, 2.6 * s),
		CFrame.new(at + Vector3.new(0, y + 1.6 * s, 0)),
		color,
		Enum.Material.Grass,
		Enum.PartType.Ball,
		parent
	)
end

local function forest()
	local trees = Instance.new("Model")
	trees.Name = "Forest"
	trees.Parent = folder
	local placed = 0
	for _ = 1, 900 do
		if placed >= 260 then
			break
		end
		local a = rr(0, math.pi * 2)
		local r = 120 + 440 * math.sqrt(rng:NextNumber())
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x) < APRON + 20 and math.abs(z) < APRON + 20 then
			continue
		end
		local pond = Valley.POND
		if Valley.inCameraLane(x, z) or math.sqrt((x - pond.x) ^ 2 + (z - pond.z) ^ 2) < pond.r + 20 then
			continue
		end
		local y = Valley.height(x, z)
		if y > 140 then
			continue
		end
		pine(Vector3.new(x, y - 0.5, z), rr(1.1, 2.1), trees)
		placed += 1
	end
end

---------------------------------------------------------------- the foot of the tower

local CONCRETE = Color3.fromRGB(128, 124, 136)
local CONCRETE_DARK = Color3.fromRGB(92, 88, 102)
local WARM = Color3.fromRGB(255, 190, 120)

local function base()
	-- the apron round the tower and the walkway out front
	for _, r in
		{
			{ -APRON, APRON, F, APRON },
			{ -APRON, APRON, -APRON, -F },
			{ F, APRON, -F, F },
			{ -APRON, -F, -F, F },
		}
	do
		part(
			"Apron",
			Vector3.new(r[2] - r[1], 1, r[4] - r[3]),
			CFrame.new((r[1] + r[2]) / 2, -0.48, (r[3] + r[4]) / 2),
			CONCRETE,
			Enum.Material.Concrete
		)
	end
	part(
		"Walkway",
		Vector3.new(22, 1, WALK_END - APRON),
		CFrame.new(0, -0.5, (APRON + WALK_END) / 2),
		CONCRETE,
		Enum.Material.Concrete
	)
	-- a plinth: a heavier skirt round the ground floor
	for _, s in { 1, -1 } do
		part("Plinth", Vector3.new(2 * F + 3, 2.4, 1.5), CFrame.new(0, 1.2, s * (F + 0.75)), CONCRETE_DARK)
		part("Plinth", Vector3.new(1.5, 2.4, 2 * F + 3), CFrame.new(s * (F + 0.75), 1.2, 0), CONCRETE_DARK)
	end

	-- the entrance, on the +Z face: a landing and steps, columns holding a canopy with the name on it
	local z0 = F + 1.5
	part("Landing", Vector3.new(26, 1.6, 10), CFrame.new(0, 0.8, z0 + 5), CONCRETE)
	for k = 1, 3 do
		part(
			"Step",
			Vector3.new(20, 1.6 - k * 0.5, 2),
			CFrame.new(0, (1.6 - k * 0.5) / 2, z0 + 10 + k * 2 - 1),
			CONCRETE
		)
	end
	for _, sx in { -1, 1 } do
		part("Column", Vector3.new(2.4, 12, 2.4), CFrame.new(sx * 10.5, 7.6, z0 + 8), CONCRETE_DARK)
	end
	local canopy = part("Canopy", Vector3.new(28, 1.6, 13), CFrame.new(0, 14.4, z0 + 5.5), CONCRETE_DARK)
	local name = part(
		"CanopySign",
		Vector3.new(24, 4, 0.4),
		CFrame.new(0, 16.8, z0 + 11.9),
		Color3.new(),
		Enum.Material.SmoothPlastic
	)
	name.Transparency = 1
	name.CanCollide = false
	sign(name, "ROOFTOP", Color3.fromRGB(255, 236, 210), Enum.NormalId.Back)
	local strip = part(
		"CanopyGlow",
		Vector3.new(26, 0.25, 0.25),
		CFrame.new(0, 13.5, z0 + 11.9),
		Color3.fromRGB(255, 90, 130),
		Enum.Material.Neon
	)
	strip.CanCollide = false
	-- the doors: two steel leaves with little lit windows, a warm lamp over them
	for _, sx in { -1, 1 } do
		part(
			"Door",
			Vector3.new(4.6, 10, 0.4),
			CFrame.new(sx * 2.4, 6.6, F + 0.3),
			Color3.fromRGB(70, 78, 92),
			Enum.Material.DiamondPlate
		)
		local w = part(
			"DoorWindow",
			Vector3.new(1.4, 1.8, 0.45),
			CFrame.new(sx * 2.4, 8.8, F + 0.3),
			WARM,
			Enum.Material.Neon
		)
		w.CanCollide = false
	end
	local lamp = part("DoorLamp", Vector3.new(1.6, 0.6, 1.6), CFrame.new(0, 13.3, z0 + 5), WARM, Enum.Material.Neon)
	light(lamp, WARM, 30, 2)
	local _ = canopy

	-- lamp posts down the walkway, lit bollards between them
	for k = 0, 3 do
		local z = APRON + 8 + k * 15
		for _, sx in { -1, 1 } do
			part(
				"LampPost",
				Vector3.new(0.7, 12, 0.7),
				CFrame.new(sx * 13, 6, z),
				Color3.fromRGB(40, 40, 50),
				Enum.Material.Metal
			)
			local head =
				part("LampHead", Vector3.new(2.2, 1, 2.2), CFrame.new(sx * 13, 12.3, z), WARM, Enum.Material.Neon)
			light(head, WARM, 26, 1.4)
			local bollard = part(
				"Bollard",
				Vector3.new(2.6, 1.1, 1.1),
				CFrame.new(sx * 13, 1.3, z + 7.5) * VERTICAL,
				CONCRETE_DARK,
				Enum.Material.Concrete,
				Enum.PartType.Cylinder
			)
			local cap = part(
				"BollardCap",
				Vector3.new(0.3, 1.1, 1.1),
				bollard.CFrame * CFrame.new(1.4, 0, 0),
				Color3.fromRGB(120, 220, 255),
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
			cap.CanCollide = false
		end
	end

	-- dressing: drums, a stack of blocks, puddles that catch the light
	for _, d in
		{
			{ -F - 6, -F + 6, Color3.fromRGB(200, 90, 50) },
			{ -F - 6, -F + 9.5, Color3.fromRGB(60, 110, 170) },
			{ -F - 9, -F + 7.5, Color3.fromRGB(200, 90, 50) },
			{ F + 7, F - 10, Color3.fromRGB(230, 190, 60) },
			{ F + 7, F - 13.5, Color3.fromRGB(60, 110, 170) },
		}
	do
		part(
			"Drum",
			Vector3.new(4.2, 3, 3),
			CFrame.new(d[1], 2.1, d[2]) * VERTICAL,
			d[3],
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	for _ = 1, 6 do
		local a, r = rr(0, 6.28), rr(F + 6, APRON - 4)
		local p = part(
			"Puddle",
			Vector3.new(rr(5, 10), 0.05, rr(3, 7)),
			CFrame.new(math.cos(a) * r, 0.03, math.sin(a) * r) * CFrame.Angles(0, rr(0, 3), 0),
			Color3.fromRGB(40, 50, 80),
			Enum.Material.Glass
		)
		p.Reflectance = 0.5
		p.Transparency = 0.2
		p.CanCollide = false
	end

	-- floodlights at the foot of the tower, washing light up its faces (a light reaches 60 studs at most)
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local along = Vector3.new(side.Z, 0, side.X)
		for _, u in { -F * 0.55, F * 0.55 } do
			local at = side * (F + 9) + along * u + Vector3.new(0, 1, 0)
			local target = side * F + along * u + Vector3.new(0, 45, 0)
			local housing = part(
				"Floodlight",
				Vector3.new(2.4, 1.4, 1.6),
				CFrame.lookAt(at, target),
				Color3.fromRGB(40, 40, 50),
				Enum.Material.Metal
			)
			local lens = part(
				"FloodLens",
				Vector3.new(2, 1, 0.1),
				housing.CFrame * CFrame.new(0, 0, -0.85),
				Color3.fromRGB(255, 240, 220),
				Enum.Material.Neon
			)
			lens.CanCollide = false
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Angle = 55
			spot.Range = 60
			spot.Brightness = 2.2
			spot.Color = Color3.fromRGB(255, 236, 214)
			spot.Shadows = false
			spot.Parent = housing
		end
	end

	-- the shaft's pit under the ground floor
	local pitTop, pitBottom = -0.4, -2 * FH - 2
	local h = pitTop - pitBottom
	for _, s in { 1, -1 } do
		part(
			"PitWall",
			Vector3.new(2 * H + 2, h, 1),
			CFrame.new(0, (pitTop + pitBottom) / 2, s * (H + 0.5)),
			CONCRETE_DARK
		)
		part("PitWall", Vector3.new(1, h, 2 * H), CFrame.new(s * (H + 0.5), (pitTop + pitBottom) / 2, 0), CONCRETE_DARK)
	end
	-- a dark skirt under the whole tower (nothing to see beneath the ground floor)
	part("Underside", Vector3.new(2 * F, 1, 2 * F), CFrame.new(0, -2 * FH - 3, 0), Color3.fromRGB(20, 18, 26))
end

---------------------------------------------------------------- the title on the hill

local function title()
	local text = { "R", "O", "O", "F", "T", "O", "P" }
	local zBase, width = -620, 46
	for i, ch in text do
		local x = (i - 4) * width
		local y = Valley.height(x, zBase) + 34
		local p = part(
			"TitleLetter",
			Vector3.new(40, 56, 2),
			CFrame.new(x, y, zBase) * CFrame.Angles(math.rad(-12), 0, 0),
			Color3.new(),
			Enum.Material.SmoothPlastic
		)
		p.Transparency = 1
		p.CanCollide = false
		p.CastShadow = false
		local color = if i == 2 then Color3.fromRGB(255, 70, 80) else Color3.fromRGB(255, 240, 225)
		sign(p, ch, color, Enum.NormalId.Back)
		local glow =
			part("TitleGlow", Vector3.new(4, 4, 4), CFrame.new(x, y, zBase + 14), color, Enum.Material.SmoothPlastic)
		glow.Transparency = 1
		glow.CanCollide = false
		light(glow, color, 60, 1.2)
	end
end

---------------------------------------------------------------- the moon

-- A big moon high behind the tower, where the opening shots look (the sky's own moon sits wherever the
-- clock puts it): a pale disc, shaded, with craters, in a cold halo. Drawn as a billboard, so it always
-- faces you and stays a clean circle however far away it is.
local function circle(
	parent: Instance,
	size: number,
	x: number,
	y: number,
	color: Color3,
	transparency: number,
	z: number
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(size, size)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

local function moon()
	local anchor =
		part("Moon", Vector3.new(1, 1, 1), CFrame.new(-260, 720, -1500), Color3.new(), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromScale(560, 560) -- studs
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.AlwaysOnTop = false
	g.MaxDistance = 100000
	g.ClipsDescendants = false
	-- the halo
	circle(g, 1, 0.5, 0.5, Color3.fromRGB(150, 170, 255), 0.93, 1)
	circle(g, 0.62, 0.5, 0.5, Color3.fromRGB(170, 190, 255), 0.86, 2)
	-- the disc, lit from the upper left
	local disc = circle(g, 0.4, 0.5, 0.5, Color3.fromRGB(236, 240, 255), 0, 3)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(186, 196, 232))
	shade.Rotation = 45
	shade.Parent = disc
	-- craters
	for _, c in
		{ { 0.3, 0.35, 0.18 }, { 0.62, 0.3, 0.1 }, { 0.55, 0.62, 0.22 }, { 0.28, 0.68, 0.09 }, { 0.75, 0.55, 0.07 } }
	do
		circle(disc, c[3], c[1], c[2], Color3.fromRGB(196, 204, 236), 0.35, 4)
	end
	g.Parent = anchor
end

---------------------------------------------------------------- build

function World.build()
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Model")
	folder.Name = "World"
	folder:SetAttribute("Floor", -1)
	folder.Parent = workspace
	base()
	forest()
	title()
	moon()
end

return World
