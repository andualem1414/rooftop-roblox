--!strict
-- The modelling kit the tower's rooms are built with (Tower, Props, Themes): parts placed in a frame, and
-- flat art drawn on them with SurfaceGuis (paintings, posters, signs, screens) instead of more parts.
--
-- A builder is bound to a model and a frame (a CFrame on the floor: origin at floor level, front facing
-- -Z) and places parts in that frame's coordinates, in studs, y up from the floor:
--   k.box(x, y, z, sx, sy, sz, ...)        a block centred at (x, y, z)
--   k.ext(x0, x1, y0, y1, z0, z1, ...)     a block by its extents
--   k.post(x, z, y0, y1, d, ...)           a standing cylinder
--   k.disc(x, y, z, d, h, ...)             a flat cylinder, centred at y
--   k.rod(a, b, d, ...)                    a cylinder from point a to point b
--   k.ball(x, y, z, d, ...)                a sphere
--   k.wedge(cf, size, ...)                 a wedge: full height at its back (+Z), sloping down to its front (-Z)
--   k.keepOut(x, z, w, d, h)               an invisible block only climbers bump into, w by d, h high: round
--                                          a piece with a low rail or gaps a body could drop into and be
--                                          wedged in (shots, the camera and sight lines pass through it)
-- Every one takes (color, material?, solid?) last. solid: false (the default here: for show, nothing bumps
-- into it or shoots it), true (collides and stops shots) or "cover" (walked through, stops shots: shots are
-- raycasts).
local Kit = {}

export type Solid = boolean | "cover"

export type Builder = {
	model: Instance,
	cf: CFrame,
	at: (x: number, y: number, z: number) -> CFrame,
	part: (cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, solid: Solid?, shape: Enum.PartType?) -> Part,
	box: (
		x: number,
		y: number,
		z: number,
		sx: number,
		sy: number,
		sz: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	ext: (
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		z0: number,
		z1: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	post: (
		x: number,
		z: number,
		y0: number,
		y1: number,
		d: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	disc: (
		x: number,
		y: number,
		z: number,
		d: number,
		h: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	rod: (a: Vector3, b: Vector3, d: number, color: Color3, mat: Enum.Material?, solid: Solid?) -> Part,
	ball: (x: number, y: number, z: number, d: number, color: Color3, mat: Enum.Material?, solid: Solid?) -> Part,
	wedge: (cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, solid: Solid?) -> WedgePart,
	keepOut: (x: number, z: number, w: number, d: number, h: number) -> Part,
	-- a disc facing the front (its axis along z), e.g. a dial, a washer's door, a speaker cone
	face: (
		x: number,
		y: number,
		z: number,
		d: number,
		h: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	-- an ellipsoid sx by sy by sz (a sand heap, a cushion, a bush): a block drawn as a sphere mesh
	blob: (
		x: number,
		y: number,
		z: number,
		sx: number,
		sy: number,
		sz: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	-- a disc facing the side (its axis along x), e.g. a wheel
	wheel: (
		x: number,
		y: number,
		z: number,
		d: number,
		h: number,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?
	) -> Part,
	-- a builder for a frame inside this one (turned by yaw radians); with a name, its parts go in a model of
	-- their own (a set's pieces: each ghosts on its own when it's in the camera's way)
	sub: (x: number, z: number, yaw: number?, name: string?) -> Builder,
	lift: (y: number) -> Builder,
}

-- What a floor is (server/common/Themes has the twenty)
export type Finish = { color: Color3, mat: Enum.Material }
export type Theme = {
	name: string,
	floor: Color3, -- the floor
	floorMat: Enum.Material,
	border: Finish?, -- a band of another finish along the walls
	walk: Finish?, -- the walkway round the shaft
	wall: Color3, -- the walls' room side (one finish all over, round the windows too)
	wallMat: Enum.Material,
	lower: Color3, -- below the window sills (the same as the wall, or panelling or tiles)
	lowerMat: Enum.Material,
	trim: Color3, -- skirting, sills and cornice
	trimMat: Enum.Material,
	frame: Color3, -- the window frames
	accent: Color3, -- the floor's neon
	accent2: Color3,
	light: Color3, -- its lamps
	props: { { any } }, -- { prop name, how many (min), how many (max) }: placed anywhere they fit
	plan: ((Planner) -> ())?, -- the furniture placed by design, before the rest
	dress: ((Room) -> ())?, -- what's painted on the floor and hung on the walls
}

-- A piece of furniture (server/common/Props): footprint w (x) by d (z) studs, front facing -Z.
--   "low"   you can jump over it and shoot across it, or crouch behind it out of sight
--   "high"  it blocks you, your view and shots
--   "crate" a loose crate you can shove
export type Prop = {
	w: number,
	d: number,
	h: number,
	kind: "low" | "high" | "crate",
	wall: boolean, -- stands against a wall, facing into the room
	set: boolean?, -- a group of pieces (a sofa, a table, a lamp...): each ghosts on its own in the camera's way
	build: (k: Builder, th: Theme, rng: Random) -> (),
}

export type Placed = {
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	h: number,
	kind: string,
	name: string,
	cf: CFrame,
}

-- placing furniture by design (a theme's plan): put returns false (and places nothing) where it doesn't fit
export type Planner = {
	th: Theme,
	rng: Random,
	inner: number, -- the walls' room faces, this far from the middle
	clear: number, -- the walkway round the shaft: nothing stands within this of the middle
	put: (name: string, x: number, z: number, yaw: number?, gap: number?) -> boolean,
	-- its back to a wall ("+x", "-x", "+z", "-z"), u along it, facing into the room
	against: (name: string, side: string, u: number, gap: number?) -> boolean,
}

-- dressing a room (a theme's dress): floor markings, rugs, art and fittings on the walls
export type Room = {
	th: Theme,
	rng: Random,
	model: Instance,
	y0: number, -- the floor's surface
	y1: number, -- the ceiling
	inner: number,
	clear: number,
	floor: Builder, -- x and z as in the world, y up from the floor
	-- on a wall's room face at u along it: x along the wall, y up from the floor, -z out into the room
	-- (what it builds is cut away with the wall)
	wall: (side: string, u: number) -> Builder,
	free: (side: string, u: number, half: number) -> boolean, -- nothing stands against this stretch
	open: (x0: number, x1: number, z0: number, z1: number) -> boolean, -- no furniture, paint or pad here
	placed: { Placed },
	pillars: { number }, -- u of the stretches of wall between the windows
	windows: { number }, -- u of the windows' middles
}

function Kit.rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (x) turned up
Kit.UP = UP

local function solidify(p: BasePart, solid: Solid?)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "Tower"
	if solid ~= true then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = solid == "cover"
		-- small trims and ornaments don't need a shadow of their own
		local s = p.Size
		if math.max(s.X, s.Y, s.Z) < 1.6 then
			p.CastShadow = false
		end
	end
end

function Kit.part(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	solid: Solid?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	solidify(p, solid)
	p.Parent = parent
	return p
end

function Kit.wedge(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	solid: Solid?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	solidify(p, solid)
	p.Parent = parent
	return p
end

-- a builder in a frame; side: what it builds hangs on that outer wall (cut away with it: client/race/Cutaway)
function Kit.on(model: Instance, frame: CFrame, side: string?): Builder
	local k = {} :: Builder
	k.model = model
	k.cf = frame
	local function make(
		cf: CFrame,
		size: Vector3,
		color: Color3,
		mat: Enum.Material?,
		solid: Solid?,
		shape: Enum.PartType?
	): Part
		local p = Kit.part(model, cf, size, color, mat, solid, shape)
		if side then
			p:SetAttribute("Side", side)
		end
		return p
	end
	function k.at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	function k.part(cf, size, color, mat, solid, shape)
		return make(frame * cf, size, color, mat, solid, shape)
	end
	function k.box(x, y, z, sx, sy, sz, color, mat, solid)
		return make(frame * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, mat, solid)
	end
	function k.ext(x0, x1, y0, y1, z0, z1, color, mat, solid)
		return make(
			frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
			Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
			color,
			mat,
			solid
		)
	end
	function k.post(x, z, y0, y1, d, color, mat, solid)
		return make(
			frame * CFrame.new(x, (y0 + y1) / 2, z) * UP,
			Vector3.new(math.abs(y1 - y0), d, d),
			color,
			mat,
			solid,
			Enum.PartType.Cylinder
		)
	end
	function k.disc(x, y, z, d, h, color, mat, solid)
		return make(frame * CFrame.new(x, y, z) * UP, Vector3.new(h, d, d), color, mat, solid, Enum.PartType.Cylinder)
	end
	function k.rod(a, b, d, color, mat, solid)
		local dir = b - a
		local up = if math.abs(dir.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0)
		return make(frame * cf, Vector3.new(dir.Magnitude, d, d), color, mat, solid, Enum.PartType.Cylinder)
	end
	function k.face(x, y, z, d, h, color, mat, solid)
		return make(
			frame * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(h, d, d),
			color,
			mat,
			solid,
			Enum.PartType.Cylinder
		)
	end
	function k.wheel(x, y, z, d, h, color, mat, solid)
		return make(frame * CFrame.new(x, y, z), Vector3.new(h, d, d), color, mat, solid, Enum.PartType.Cylinder)
	end
	function k.blob(x, y, z, sx, sy, sz, color, mat, solid)
		local p = make(frame * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, mat, solid)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	function k.ball(x, y, z, d, color, mat, solid)
		return make(frame * CFrame.new(x, y, z), Vector3.new(d, d, d), color, mat, solid, Enum.PartType.Ball)
	end
	function k.wedge(cf, size, color, mat, solid)
		local p = Kit.wedge(model, frame * cf, size, color, mat, solid)
		if side then
			p:SetAttribute("Side", side)
		end
		return p
	end
	function k.keepOut(x: number, z: number, w: number, d: number, h: number): Part
		local p = Instance.new("Part")
		p.Name = "KeepOut"
		p.Size = Vector3.new(w, h, d)
		p.CFrame = frame * CFrame.new(x, h / 2, z)
		p.Anchored = true
		p.Transparency = 1
		p.CastShadow = false
		p.CanTouch = false
		p.CollisionGroup = "Barrier" -- (server/common/CollisionGroups: only climbers bump into it)
		p.Parent = model
		return p
	end
	function k.sub(x: number, z: number, yaw: number?, name: string?): Builder
		local parent = model
		if name then
			local m = Instance.new("Model")
			m.Name = name
			m.Parent = model
			parent = m
		end
		return Kit.on(parent, frame * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0), side)
	end
	function k.lift(y: number): Builder
		return Kit.on(model, frame * CFrame.new(0, y, 0), side)
	end
	return k
end

---------------------------------------------------------------- flat art

-- a SurfaceGui on one face of a part. glow > 0: it lights itself (screens, signs) at that brightness;
-- otherwise the room's light falls on it (paint, posters)
function Kit.gui(part: BasePart, face: Enum.NormalId, pixelsPerStud: number, glow: number?): Frame
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pixelsPerStud
	if glow and glow > 0 then
		g.LightInfluence = 0
		g.Brightness = glow
	else
		g.LightInfluence = 1
	end
	g.Parent = part
	local root = Instance.new("Frame")
	root.Name = "Art"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Parent = g
	return root
end

-- a rectangle in scale coordinates (0..1 of its parent)
function Kit.rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, round: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

function Kit.gradient(f: GuiObject, c0: Color3, c1: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = f
end

function Kit.text(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	font: Enum.Font?,
	stroke: Color3?
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(x, y)
	t.Size = UDim2.fromScale(w, h)
	t.Font = font or Enum.Font.GothamBlack
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	if stroke then
		t.TextStrokeColor3 = stroke
		t.TextStrokeTransparency = 0.2
	end
	t.Parent = parent
	return t
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end
Kit.pick = pick

-- palettes the paintings are drawn from
local PALETTES = {
	{
		Kit.rgb(240, 106, 84),
		Kit.rgb(252, 196, 96),
		Kit.rgb(52, 74, 120),
		Kit.rgb(240, 232, 214),
		Kit.rgb(40, 140, 140),
	},
	{ Kit.rgb(36, 52, 92), Kit.rgb(90, 150, 210), Kit.rgb(230, 236, 240), Kit.rgb(250, 190, 80), Kit.rgb(200, 70, 90) },
	{
		Kit.rgb(232, 220, 196),
		Kit.rgb(196, 90, 60),
		Kit.rgb(60, 70, 60),
		Kit.rgb(220, 170, 90),
		Kit.rgb(120, 140, 110),
	},
	{
		Kit.rgb(30, 24, 48),
		Kit.rgb(255, 80, 170),
		Kit.rgb(80, 220, 255),
		Kit.rgb(255, 220, 110),
		Kit.rgb(140, 90, 255),
	},
	{ Kit.rgb(244, 240, 230), Kit.rgb(20, 20, 24), Kit.rgb(220, 40, 40), Kit.rgb(30, 80, 190), Kit.rgb(250, 210, 40) },
}

-- a painting drawn on a gui: a landscape (sky, sun, mountains, hills), an abstract of circles and bars, or a
-- grid of colour blocks
function Kit.painting(root: Frame, rng: Random, style: string?)
	local pal = pick(rng, PALETTES)
	local kind = style or pick(rng, { "landscape", "abstract", "blocks", "landscape" })
	if kind == "landscape" then
		local sky = Kit.rect(root, 0, 0, 1, 1, Color3.new(1, 1, 1))
		local dusk = rng:NextNumber() < 0.5
		Kit.gradient(
			sky,
			if dusk then Kit.rgb(40, 50, 110) else Kit.rgb(110, 170, 230),
			if dusk then Kit.rgb(250, 150, 110) else Kit.rgb(230, 240, 250),
			90
		)
		local sun = rng:NextNumber(0.15, 0.7)
		Kit.rect(
			root,
			sun,
			rng:NextNumber(0.12, 0.35),
			0.18,
			0.18 * 1.3,
			if dusk then Kit.rgb(255, 214, 140) else Kit.rgb(255, 250, 230),
			1
		)
		-- mountains: squares turned 45 degrees, their tops showing
		for _ = 1, rng:NextInteger(2, 3) do
			local s = rng:NextNumber(0.45, 0.8)
			local m = Kit.rect(
				root,
				rng:NextNumber(-0.2, 0.7),
				rng:NextNumber(0.42, 0.58),
				s,
				s * 1.3,
				Kit.rgb(70, 80, 110):Lerp(pal[3], 0.4)
			)
			m.Rotation = 45
		end
		local hill = Kit.rect(root, -0.3, 0.7, 1.6, 0.8, Kit.rgb(60, 110, 70):Lerp(pal[5], 0.3), 1)
		hill.Rotation = rng:NextNumber(-6, 6)
		Kit.rect(root, -0.2, 0.84, 1.4, 0.4, Kit.rgb(40, 80, 50), 1)
	elseif kind == "abstract" then
		Kit.rect(root, 0, 0, 1, 1, pal[4])
		for _ = 1, rng:NextInteger(3, 5) do
			local s = rng:NextNumber(0.2, 0.55)
			Kit.rect(root, rng:NextNumber(-0.1, 0.8), rng:NextNumber(-0.1, 0.8), s, s * 1.25, pick(rng, pal), 1)
		end
		for _ = 1, rng:NextInteger(2, 4) do
			local bar = Kit.rect(
				root,
				rng:NextNumber(-0.2, 0.6),
				rng:NextNumber(0, 0.9),
				rng:NextNumber(0.4, 1),
				0.05,
				pick(rng, pal)
			)
			bar.Rotation = rng:NextNumber(-40, 40)
		end
	else
		Kit.rect(root, 0, 0, 1, 1, Kit.rgb(20, 20, 24))
		local cols = rng:NextInteger(2, 4)
		local rows = rng:NextInteger(2, 4)
		for cx = 0, cols - 1 do
			for cy = 0, rows - 1 do
				local c = if rng:NextNumber() < 0.55 then pal[4] else pick(rng, pal)
				Kit.rect(root, cx / cols + 0.012, cy / rows + 0.012, 1 / cols - 0.024, 1 / rows - 0.024, c)
			end
		end
	end
end

-- what a screen shows:
--   "code" lines of code, "chart" bars, "graph" a line going up and down, "game" a space shooter,
--   "eq" a music player's levels, "dna" a turning helix, "server" rack units with their lights,
--   "race" a road into the hills
function Kit.screen(root: Frame, rng: Random, kind: string, accent: Color3)
	local ink = Kit.rgb(14, 18, 28)
	Kit.rect(root, 0, 0, 1, 1, ink)
	local bright = accent:Lerp(Color3.new(1, 1, 1), 0.35)
	if kind == "code" then
		local colors =
			{ Kit.rgb(120, 200, 255), Kit.rgb(255, 160, 110), Kit.rgb(170, 240, 150), Kit.rgb(220, 160, 255) }
		local indent = 0
		for row = 0, 10 do
			indent = math.clamp(indent + rng:NextInteger(-1, 1), 0, 3)
			local x = 0.06 + indent * 0.07
			local w = rng:NextNumber(0.15, 0.6)
			Kit.rect(root, x, 0.06 + row * 0.085, w, 0.045, pick(rng, colors))
			if rng:NextNumber() < 0.5 then
				Kit.rect(root, x + w + 0.03, 0.06 + row * 0.085, rng:NextNumber(0.08, 0.25), 0.045, pick(rng, colors))
			end
		end
	elseif kind == "chart" then
		Kit.rect(root, 0.08, 0.88, 0.86, 0.015, Kit.rgb(120, 130, 150))
		local n = rng:NextInteger(5, 8)
		for i = 0, n - 1 do
			local h = rng:NextNumber(0.2, 0.75)
			Kit.rect(root, 0.1 + i * (0.82 / n), 0.88 - h, 0.82 / n * 0.65, h, if i % 2 == 0 then bright else accent)
		end
		Kit.rect(root, 0.08, 0.06, 0.4, 0.06, Kit.rgb(200, 210, 230))
	elseif kind == "graph" then
		for i = 0, 3 do
			Kit.rect(root, 0.05, 0.2 + i * 0.2, 0.9, 0.006, Kit.rgb(40, 50, 70))
		end
		local y = rng:NextNumber(0.4, 0.7)
		for i = 0, 9 do
			local ny = math.clamp(y + rng:NextNumber(-0.18, 0.15), 0.15, 0.85)
			local x0, x1 = 0.05 + i * 0.09, 0.05 + (i + 1) * 0.09
			local dx, dy = x1 - x0, (ny - y) * 0.6 -- (the screen is wider than tall)
			local seg = Kit.rect(
				root,
				(x0 + x1) / 2 - math.sqrt(dx * dx + dy * dy) / 2,
				(y + ny) / 2,
				math.sqrt(dx * dx + dy * dy),
				0.02,
				bright
			)
			seg.Rotation = math.deg(math.atan2(dy, dx))
			y = ny
		end
	elseif kind == "game" then
		local alien = { Kit.rgb(120, 255, 120), Kit.rgb(255, 120, 220), Kit.rgb(120, 220, 255) }
		for row = 0, 2 do
			for col = 0, 5 do
				local x, yy = 0.14 + col * 0.13, 0.12 + row * 0.12
				Kit.rect(root, x, yy, 0.07, 0.06, alien[row + 1])
				Kit.rect(root, x - 0.015, yy + 0.04, 0.1, 0.025, alien[row + 1])
			end
		end
		Kit.rect(root, 0.44, 0.84, 0.12, 0.05, Kit.rgb(255, 230, 90))
		Kit.rect(root, 0.485, 0.8, 0.03, 0.05, Kit.rgb(255, 230, 90))
		Kit.rect(root, 0.495, 0.55, 0.01, 0.08, Kit.rgb(255, 255, 255))
		for _ = 1, 12 do
			Kit.rect(root, rng:NextNumber(), rng:NextNumber(), 0.008, 0.012, Kit.rgb(200, 200, 255))
		end
		Kit.text(
			root,
			string.format("%06d", rng:NextInteger(1000, 99999)),
			0.05,
			0.01,
			0.35,
			0.08,
			Kit.rgb(255, 255, 255),
			Enum.Font.Arcade
		)
	elseif kind == "eq" then
		for i = 0, 13 do
			local h = rng:NextNumber(0.2, 0.85)
			local bar = Kit.rect(root, 0.04 + i * 0.066, 0.92 - h, 0.05, h, Color3.new(1, 1, 1))
			Kit.gradient(bar, accent, Kit.rgb(255, 230, 120), 270)
		end
	elseif kind == "dna" then
		for i = 0, 15 do
			local t = i / 15
			local a = t * math.pi * 3
			local x1, x2 = 0.5 + math.sin(a) * 0.3, 0.5 - math.sin(a) * 0.3
			local y = 0.05 + t * 0.88
			Kit.rect(root, math.min(x1, x2), y + 0.012, math.abs(x1 - x2), 0.01, Kit.rgb(80, 100, 140))
			Kit.rect(root, x1 - 0.03, y, 0.06, 0.035, bright, 1)
			Kit.rect(root, x2 - 0.03, y, 0.06, 0.035, Kit.rgb(255, 140, 200), 1)
		end
	elseif kind == "server" then
		for row = 0, 9 do
			local y = 0.03 + row * 0.097
			Kit.rect(root, 0.04, y, 0.92, 0.08, Kit.rgb(34, 38, 50))
			for led = 0, rng:NextInteger(1, 4) do
				local c = if rng:NextNumber() < 0.8 then accent else Kit.rgb(255, 180, 60)
				Kit.rect(root, 0.08 + led * 0.07, y + 0.025, 0.035, 0.03, c)
			end
			Kit.rect(root, 0.6, y + 0.03, rng:NextNumber(0.1, 0.3), 0.02, Kit.rgb(70, 80, 100))
		end
	else -- "race"
		local sky = Kit.rect(root, 0, 0, 1, 0.55, Color3.new(1, 1, 1))
		Kit.gradient(sky, Kit.rgb(60, 80, 200), Kit.rgb(255, 150, 120), 90)
		Kit.rect(root, 0, 0.55, 1, 0.45, Kit.rgb(40, 140, 70))
		local road = Kit.rect(root, 0.3, 0.55, 0.4, 0.6, Kit.rgb(60, 60, 70))
		road.Rotation = 0
		Kit.rect(root, 0.49, 0.6, 0.02, 0.1, Kit.rgb(255, 255, 255))
		Kit.rect(root, 0.49, 0.78, 0.02, 0.14, Kit.rgb(255, 255, 255))
		Kit.rect(root, 0.4, 0.78, 0.2, 0.12, accent, 0.3)
	end
end

-- a printed sign: a coloured board with a line or two of text
function Kit.sign(root: Frame, text: string, bg: Color3, fg: Color3, font: Enum.Font?)
	Kit.rect(root, 0, 0, 1, 1, bg)
	Kit.text(root, text, 0.06, 0.12, 0.88, 0.76, fg, font or Enum.Font.GothamBlack)
end

return Kit
