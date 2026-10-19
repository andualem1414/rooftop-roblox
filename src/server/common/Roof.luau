--!strict
-- The roof's dressing: where the race ends, so it should look like a prize. A hazard-striped frame round
-- the hatch, a helipad with lit edges, air-conditioning units, a water tower, a radio mast with a red
-- beacon, string lights all along the parapet, a big lit ROOFTOP sign facing down the valley, and two
-- searchlights whose beams sweep the sky (Ambience.luau moves them on each client).
-- Returns the footprints of the solid pieces (so nobody is set down inside one).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local F = Config.FLOOR_HALF
local H = Config.SHAFT_HALF
local WALL = Config.WALL

local Roof = {}

type Rect = { x0: number, x1: number, z0: number, z1: number }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "Tower"
	if solid == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder lying flat as a disc: its axis up

function Roof.dress(roof: Model, ry: number): { Rect }
	local rects: { Rect } = {}
	local function rect(x: number, z: number, w: number, d: number)
		table.insert(rects, { x0 = x - w / 2, x1 = x + w / 2, z0 = z - d / 2, z1 = z + d / 2 })
	end

	-- hazard stripes round the hatch
	local ring = H + 1.4
	local seg = 1.6
	local n = math.floor(2 * ring / seg)
	for k = 0, n - 1 do
		local u = -ring + (k + 0.5) * (2 * ring / n)
		local color = if k % 2 == 0 then rgb(255, 204, 40) else rgb(26, 24, 30)
		for _, side in { 1, -1 } do
			part(
				roof,
				"Stripe",
				Vector3.new(2 * ring / n, 0.08, 1.2),
				CFrame.new(u, ry + 0.04, side * (ring - 0.6)),
				color,
				nil,
				false
			)
			part(
				roof,
				"Stripe",
				Vector3.new(1.2, 0.08, 2 * ring / n),
				CFrame.new(side * (ring - 0.6), ry + 0.04, u),
				color,
				nil,
				false
			)
		end
	end

	-- the helipad, with green lights round its edge (in its corner, clear of the hatch's stripes)
	local pad = CFrame.new(-19, ry + 0.06, -19)
	part(roof, "Helipad", Vector3.new(0.12, 22, 22), pad * FLAT, rgb(46, 50, 62), nil, false, Enum.PartType.Cylinder)
	part(
		roof,
		"HelipadRing",
		Vector3.new(0.14, 19, 19),
		pad * FLAT,
		rgb(240, 240, 240),
		nil,
		false,
		Enum.PartType.Cylinder
	)
	part(
		roof,
		"HelipadInner",
		Vector3.new(0.16, 17.6, 17.6),
		pad * FLAT,
		rgb(46, 50, 62),
		nil,
		false,
		Enum.PartType.Cylinder
	)
	for _, x in { -3, 3 } do
		part(roof, "H", Vector3.new(1.2, 0.2, 9), pad * CFrame.new(x, 0.05, 0), rgb(240, 240, 240), nil, false)
	end
	part(roof, "H", Vector3.new(6, 0.2, 1.2), pad * CFrame.new(0, 0.05, 0), rgb(240, 240, 240), nil, false)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		part(
			roof,
			"PadLight",
			Vector3.new(0.5, 0.5, 0.5),
			pad * CFrame.new(math.cos(a) * 10.6, 0.3, math.sin(a) * 10.6),
			rgb(90, 255, 140),
			Enum.Material.Neon,
			false,
			Enum.PartType.Ball
		)
	end

	-- air conditioning units
	for _, at in { { 19, -22 }, { 27, -10 } } do
		local cf = CFrame.new(at[1], ry, at[2])
		part(roof, "AC", Vector3.new(7, 4, 5), cf * CFrame.new(0, 2, 0), rgb(176, 182, 190), Enum.Material.Metal)
		part(
			roof,
			"Fan",
			Vector3.new(0.3, 3.4, 3.4),
			cf * CFrame.new(-1.5, 4.1, 0) * UPRIGHT,
			rgb(40, 42, 50),
			nil,
			false,
			Enum.PartType.Cylinder
		)
		part(
			roof,
			"Fan",
			Vector3.new(0.3, 3.4, 3.4),
			cf * CFrame.new(1.8, 4.1, 0) * UPRIGHT,
			rgb(40, 42, 50),
			nil,
			false,
			Enum.PartType.Cylinder
		)
		rect(at[1], at[2], 7, 5)
	end

	-- the water tower: a tank on legs, a ladder
	local tank = CFrame.new(22, ry, 22)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			part(
				roof,
				"Leg",
				Vector3.new(0.7, 9, 0.7),
				tank * CFrame.new(x, 4.5, z),
				rgb(70, 60, 56),
				Enum.Material.Metal
			)
		end
	end
	part(
		roof,
		"Tank",
		Vector3.new(10, 11, 11),
		tank * CFrame.new(0, 14, 0) * UPRIGHT,
		rgb(150, 92, 64),
		Enum.Material.WoodPlanks,
		true,
		Enum.PartType.Cylinder
	)
	part(
		roof,
		"TankBand",
		Vector3.new(0.4, 11.3, 11.3),
		tank * CFrame.new(0, 11, 0) * UPRIGHT,
		rgb(60, 56, 60),
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	part(
		roof,
		"TankBand",
		Vector3.new(0.4, 11.3, 11.3),
		tank * CFrame.new(0, 17, 0) * UPRIGHT,
		rgb(60, 56, 60),
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	part(
		roof,
		"TankTop",
		Vector3.new(11.6, 4, 11.6),
		tank * CFrame.new(0, 19.6, 0),
		rgb(110, 70, 56),
		Enum.Material.WoodPlanks,
		false,
		Enum.PartType.Ball
	)
	part(
		roof,
		"Ladder",
		Vector3.new(0.3, 18, 1.4),
		tank * CFrame.new(-5.8, 9, 0),
		rgb(60, 60, 66),
		Enum.Material.Metal,
		false
	)
	rect(22, 22, 9, 9)

	-- the radio mast, its red beacon blinking at the top (Ambience)
	local mast = CFrame.new(-26, ry, 24)
	part(roof, "MastBase", Vector3.new(3, 1.2, 3), mast * CFrame.new(0, 0.6, 0), rgb(60, 60, 66), Enum.Material.Metal)
	part(roof, "Mast", Vector3.new(0.6, 34, 0.6), mast * CFrame.new(0, 17, 0), rgb(200, 200, 210), Enum.Material.Metal)
	for y = 6, 30, 8 do
		part(
			roof,
			"MastBar",
			Vector3.new(3, 0.25, 0.25),
			mast * CFrame.new(0, y, 0),
			rgb(200, 60, 60),
			Enum.Material.Metal,
			false
		)
	end
	local beacon = part(
		roof,
		"Beacon",
		Vector3.new(1.2, 1.2, 1.2),
		mast * CFrame.new(0, 34.6, 0),
		rgb(255, 40, 40),
		Enum.Material.Neon,
		false,
		Enum.PartType.Ball
	)
	local bl = Instance.new("PointLight")
	bl.Color = rgb(255, 50, 50)
	bl.Range = 22
	bl.Brightness = 2
	bl.Parent = beacon
	rect(-26, 24, 3, 3)

	-- string lights along the parapet, in four colours
	local bulbs = { rgb(255, 80, 160), rgb(80, 220, 255), rgb(255, 220, 80), rgb(120, 255, 140) }
	local top = ry + 1 * Config.M + 0.6
	local k = 0
	for u = -F + 2, F - 2, 3.4 do
		for _, pos in
			{
				Vector3.new(u, top, F - WALL / 2),
				Vector3.new(u, top, -F + WALL / 2),
				Vector3.new(F - WALL / 2, top, u),
				Vector3.new(-F + WALL / 2, top, u),
			}
		do
			k += 1
			part(
				roof,
				"Bulb",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(pos),
				bulbs[k % #bulbs + 1],
				Enum.Material.Neon,
				false,
				Enum.PartType.Ball
			)
		end
	end

	-- the sign, facing down the valley
	local signCf = CFrame.new(0, ry, F - 3)
	for _, x in { -14, 14 } do
		part(
			roof,
			"SignPost",
			Vector3.new(0.8, 12, 0.8),
			signCf * CFrame.new(x, 6, 0.6),
			rgb(50, 50, 60),
			Enum.Material.Metal
		)
	end
	local board = part(
		roof,
		"SignBoard",
		Vector3.new(32, 7, 0.6),
		signCf * CFrame.new(0, 9.5, 0),
		rgb(24, 20, 34),
		Enum.Material.SmoothPlastic
	)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back -- (+Z: toward the valley)
	g.LightInfluence = 0
	g.Brightness = 2.5
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.Text = "ROOFTOP"
	text.TextColor3 = rgb(255, 90, 170)
	text.TextStrokeColor3 = rgb(255, 230, 250)
	text.TextStrokeTransparency = 0.4
	text.Parent = g
	g.Parent = board
	for _, y in { 6, 13 } do
		part(
			roof,
			"SignTrim",
			Vector3.new(32, 0.3, 0.2),
			signCf * CFrame.new(0, y, -0.4),
			rgb(80, 220, 255),
			Enum.Material.Neon,
			false
		)
	end
	rect(0, F - 3, 30, 2)

	-- two searchlights on opposite corners; their beams reach up into the sky
	for i, at in { { -30, 30 }, { 30, -30 } } do
		local base = CFrame.new(at[1], ry, at[2])
		part(
			roof,
			"SearchlightBase",
			Vector3.new(3, 2, 3),
			base * CFrame.new(0, 1, 0),
			rgb(50, 50, 60),
			Enum.Material.Metal
		)
		local head = part(
			roof,
			"Searchlight",
			Vector3.new(2.6, 2.6, 2.6),
			base * CFrame.new(0, 3, 0),
			rgb(240, 240, 250),
			Enum.Material.Neon,
			false,
			Enum.PartType.Ball
		)
		head:SetAttribute("Phase", i * 2.1)
		local a0 = Instance.new("Attachment")
		a0.Name = "From"
		a0.Parent = head
		local a1 = Instance.new("Attachment")
		a1.Name = "To"
		a1.Position = Vector3.new(0, 300, 0)
		a1.Parent = head
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 2.4
		beam.Width1 = 34
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		local c = if i == 1 then rgb(120, 220, 255) else rgb(255, 120, 220)
		beam.Color = ColorSequence.new(c)
		beam.Transparency = NumberSequence.new(0.55, 1)
		beam.Parent = head
		rect(at[1], at[2], 3, 3)
	end

	return rects
end

return Roof
