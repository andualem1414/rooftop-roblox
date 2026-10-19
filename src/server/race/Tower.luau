--!strict
-- Builds the tower: 20 floors of 24 × 24 m round a platform shaft, each with its own theme (Themes.luau):
-- floor finish, coloured inner walls with a glowing baseboard, windows tinted in the floor's colour (so
-- from outside the tower glows in many colours), four ceiling lights, the floor's number and name
-- painted big on the floor, and furniture that doubles as cover. Then the roof with its hatch.
--
-- Floor i's surface is at y = i × FLOOR_HEIGHT (i = 0 is the ground floor). Every floor is a Model
-- named FloorNN with a Floor attribute (the roof is Floor = FLOORS) so clients can cut away the
-- floors above them.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Themes = require(script.Parent.Themes)
local Roof = require(script.Parent.Roof)

local FLOORS = Config.FLOORS
local FH = Config.FLOOR_HEIGHT
local F = Config.FLOOR_HALF
local SLAB = Config.SLAB
local WALL = Config.WALL
local H = Config.SHAFT_HALF
local M = Config.M

local CONCRETE = Color3.fromRGB(150, 146, 140)
local CONCRETE_DARK = Color3.fromRGB(104, 101, 98)

export type Rect = { x0: number, x1: number, z0: number, z1: number }

export type Tower = {
	model: Model,
	floors: { [number]: Model }, -- 0..FLOORS (FLOORS = the roof)
	covers: { [number]: { Rect } },
	gates: { [number]: BasePart }, -- 0..FLOORS-1
	randomSpot: (floor: number) -> Vector3,
	ringSpot: (floor: number) -> Vector3,
	floorOf: (y: number) -> number,
	openHatch: () -> (),
	closeHatch: () -> (),
}

local Tower = {}

local rng = Random.new()
local function rr(a: number, b: number): number
	return a + (b - a) * rng:NextNumber()
end

local function box(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "Tower"
	p.Parent = parent
	return p
end

-- a part you can't bump into or shoot (lights, trim, paint)
local function decor(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- a square slab with the shaft hole in the middle: four parts round the hole
local function slabRing(
	parent: Instance,
	y0: number,
	y1: number,
	outer: number,
	hole: number,
	color: Color3,
	name: string,
	material: Enum.Material?
)
	box(parent, name, -outer, outer, y0, y1, hole, outer, color, material)
	box(parent, name, -outer, outer, y0, y1, -outer, -hole, color, material)
	box(parent, name, hole, outer, y0, y1, -hole, hole, color, material)
	box(parent, name, -outer, -hole, y0, y1, -hole, hole, color, material)
end

-- one outer wall with a row of windows (glass you can't climb through; bullets pass): raw concrete
-- outside; inside, the floor's own colour on the solid bands and a glowing baseboard
local WIN_W = 1.44 * M
local WIN_H = 1.36 * M
local SILL = 1.0 * M
local WIN_STEP = 3 * M
local SKIN = 0.15
local function wall(parent: Instance, side: string, y0: number, y1: number, th: Themes.Theme)
	-- along u (the wall's length), v (height) and d (0 = the outside face .. WALL = the inside face)
	local function place(
		u0: number,
		u1: number,
		v0: number,
		v1: number,
		d0: number,
		d1: number,
		color: Color3,
		mat: Enum.Material?
	): Part
		local a, b = F - d1, F - d0
		if side == "+x" then
			return box(parent, "Wall", a, b, v0, v1, u0, u1, color, mat)
		elseif side == "-x" then
			return box(parent, "Wall", -b, -a, v0, v1, u0, u1, color, mat)
		elseif side == "+z" then
			return box(parent, "Wall", u0, u1, v0, v1, a, b, color, mat)
		end
		return box(parent, "Wall", u0, u1, v0, v1, -b, -a, color, mat)
	end
	local inner = F - WALL
	local top = y0 + SILL + WIN_H
	place(-F, F, y0, y0 + SILL, 0, WALL, CONCRETE)
	place(-F, F, top, y1, 0, WALL, CONCRETE)
	-- the room's side: coloured bands and a glowing strip along the floor
	place(-inner, inner, y0, y0 + SILL, WALL, WALL + SKIN, th.wall, Enum.Material.SmoothPlastic).Name = "Skin"
	place(-inner, inner, top, y1, WALL, WALL + SKIN, th.wall, Enum.Material.SmoothPlastic).Name = "Skin"
	local board =
		decor(place(-inner, inner, y0 + 0.25, y0 + 0.5, WALL + SKIN, WALL + SKIN + 0.08, th.accent, Enum.Material.Neon))
	board.Name = "Baseboard"
	local count = math.floor(2 * F / WIN_STEP)
	local first = -F + (2 * F - (count - 1) * WIN_STEP) / 2
	local edge = -F
	local glassColor = th.light:Lerp(Color3.new(1, 1, 1), 0.25)
	for k = 0, count - 1 do
		local u = first + k * WIN_STEP
		place(edge, u - WIN_W / 2, y0 + SILL, top, 0, WALL, CONCRETE)
		local glass =
			place(u - WIN_W / 2, u + WIN_W / 2, y0 + SILL, top, WALL * 0.4, WALL * 0.6, glassColor, Enum.Material.Glass)
		glass.Name = "Glass"
		glass.Transparency = 0.55
		glass.CanQuery = false
		edge = u + WIN_W / 2
	end
	place(edge, F, y0 + SILL, top, 0, WALL, CONCRETE)
end

-- painted on the floor, big: the floor's number and its name (the camera looks down on it)
local function floorPaint(parent: Instance, i: number, y0: number, th: Themes.Theme): Rect
	local size = 16
	local cx, cz = -F + WALL + 2 + size / 2, F - WALL - 2 - size / 2
	local p = decor(
		box(
			parent,
			"FloorPaint",
			cx - size / 2,
			cx + size / 2,
			y0 + 0.02,
			y0 + 0.06,
			cz - size / 2,
			cz + size / 2,
			th.floor,
			th.floorMat
		)
	)
	p.Transparency = 1
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.LightInfluence = 0.4
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 24
	local num = Instance.new("TextLabel")
	num.BackgroundTransparency = 1
	num.Size = UDim2.fromScale(1, 0.72)
	num.Font = Enum.Font.LuckiestGuy
	num.TextScaled = true
	num.Text = string.format("%02d", i + 1)
	num.TextColor3 = th.accent
	num.TextTransparency = 0.1
	num.Parent = g
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.7)
	name.Size = UDim2.fromScale(1, 0.24)
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.Text = string.upper(th.name)
	name.TextColor3 = th.accent
	name.TextTransparency = 0.15
	name.Parent = g
	g.Parent = p
	return { x0 = cx - size / 2, x1 = cx + size / 2, z0 = cz - size / 2, z1 = cz + size / 2 }
end

-- where the furniture goes on one floor: off the walkway round the shaft, off the painted number and
-- off each other; some pieces stand against a wall, facing into the room
type Placed = Rect & { h: number, kind: string, name: string, cf: CFrame }
local function placeProps(th: Themes.Theme, y0: number, reserved: { Rect }): { Placed }
	local placed: { Placed } = {}
	local inner = F - WALL - 0.1
	local function ok(b: Rect): boolean
		local clear = Config.SHAFT_CLEAR
		if b.x1 > -clear and b.x0 < clear and b.z1 > -clear and b.z0 < clear then
			return false
		end
		if b.x0 < -inner or b.x1 > inner or b.z0 < -inner or b.z1 > inner then
			return false
		end
		local gap = 1.4 * M
		for _, o in placed do
			if b.x1 + gap > o.x0 and b.x0 - gap < o.x1 and b.z1 + gap > o.z0 and b.z0 - gap < o.z1 then
				return false
			end
		end
		for _, o in reserved do
			if b.x1 + 1 > o.x0 and b.x0 - 1 < o.x1 and b.z1 + 1 > o.z0 and b.z0 - 1 < o.z1 then
				return false
			end
		end
		return true
	end
	for _, entry in th.props do
		local name = entry[1] :: string
		local prop = Themes.PROPS[name]
		local count = rng:NextInteger(entry[2] :: number, entry[3] :: number)
		for _ = 1, count do
			for _ = 1, 50 do
				local yaw, x, z
				if prop.wall then
					-- its back to a wall, facing into the room
					local side = rng:NextInteger(1, 4)
					local along = rr(-inner + prop.w / 2 + 1, inner - prop.w / 2 - 1)
					local off = inner - prop.d / 2 - 0.05
					if side == 1 then
						yaw, x, z = math.pi / 2, off, along
					elseif side == 2 then
						yaw, x, z = -math.pi / 2, -off, along
					elseif side == 3 then
						yaw, x, z = 0, along, off
					else
						yaw, x, z = math.pi, along, -off
					end
				else
					yaw = rng:NextInteger(0, 3) * math.pi / 2
					x, z = rr(-inner, inner), rr(-inner, inner)
				end
				local quarter = math.abs(math.sin(yaw)) > 0.5
				local sx = if quarter then prop.d else prop.w
				local sz = if quarter then prop.w else prop.d
				local b = {
					x0 = x - sx / 2,
					x1 = x + sx / 2,
					z0 = z - sz / 2,
					z1 = z + sz / 2,
					h = prop.h,
					kind = prop.kind,
					name = name,
					cf = CFrame.new(x, y0, z) * CFrame.Angles(0, yaw, 0),
				}
				if ok(b) then
					table.insert(placed, b)
					break
				end
			end
		end
	end
	return placed
end

local function buildFloor(root: Model, i: number): (Model, { Rect }, BasePart)
	local th = Themes.forFloor(i)
	local floor = Instance.new("Model")
	floor.Name = string.format("Floor%02d", i + 1)
	floor:SetAttribute("Floor", i)
	floor:SetAttribute("Theme", th.name)
	local y0 = i * FH
	local y1 = (i + 1) * FH - SLAB
	slabRing(floor, y0 - SLAB, y0, F, H, th.floor, "Slab", th.floorMat)
	for _, side in { "+x", "-x", "+z", "-z" } do
		wall(floor, side, y0, y1, th)
	end
	-- a lip round the shaft, its edge glowing in the floor's colour, so the hole reads from above
	local lip = 0.25 * M
	for _, s in { 1, -1 } do
		box(floor, "Lip", -H - lip, H + lip, y0, y0 + 0.15, s * H, s * (H + lip), CONCRETE_DARK)
		box(floor, "Lip", s * H, s * (H + lip), y0, y0 + 0.15, -H, H, CONCRETE_DARK)
		decor(
			box(
				floor,
				"LipGlow",
				-H - lip,
				H + lip,
				y0 + 0.15,
				y0 + 0.22,
				s * H,
				s * (H + 0.2),
				th.accent,
				Enum.Material.Neon
			)
		)
		decor(box(floor, "LipGlow", s * H, s * (H + 0.2), y0 + 0.15, y0 + 0.22, -H, H, th.accent, Enum.Material.Neon))
	end
	-- the floor's number and name, and the furniture
	local rects: { Rect } = {}
	local paint = floorPaint(floor, i, y0, th)
	local furniture = Instance.new("Model")
	furniture.Name = "Furniture"
	furniture.Parent = floor
	for _, c in placeProps(th, y0, { paint }) do
		if c.kind == "crate" then
			local crate = box(
				floor,
				"Crate",
				c.x0,
				c.x1,
				y0,
				y0 + c.h,
				c.z0,
				c.z1,
				Color3.fromRGB(150, 108, 66),
				Enum.Material.WoodPlanks
			)
			crate.Anchored = false
			crate.CollisionGroup = "Crates"
			crate.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0, 1, 1)
		else
			local m = Instance.new("Model")
			m.Name = c.name
			Themes.PROPS[c.name].build(m, c.cf, th, rng)
			m.Parent = furniture
		end
		table.insert(rects, c)
	end
	-- four lights under the ceiling, in the floor's colour (no visible fixtures: the ceiling above you is
	-- cut away, so a lamp would hang in the air). Bright enough on their own: lights shine through floors
	-- (no shadows), and the floors above you switch theirs off when they're cut away
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * F / 2, sz * F / 2
			local lamp = decor(box(floor, "Lamp", x - 0.5, x + 0.5, y1 - 1.5, y1 - 0.5, z - 0.5, z + 0.5, th.light))
			lamp.Transparency = 1
			local light = Instance.new("PointLight")
			light.Color = th.light
			light.Range = 36
			light.Brightness = 1.0
			light.Shadows = false
			light.Parent = lamp
		end
	end
	-- outside: a glowing band in the floor's colour at its floor line, so the tower reads from afar
	local band = 0.35
	local by0, by1 = y0 - SLAB / 2 - band / 2, y0 - SLAB / 2 + band / 2
	for _, s in { 1, -1 } do
		decor(box(floor, "Band", -F - 0.2, F + 0.2, by0, by1, s * F, s * (F + 0.2), th.accent, Enum.Material.Neon))
		decor(box(floor, "Band", s * F, s * (F + 0.2), by0, by1, -F, F, th.accent, Enum.Material.Neon))
	end
	-- the shaft gate: climbers can't step into the shaft unless a platform is near; crates never can
	local gate = box(floor, "ShaftGate", -H, H, y0, y1, -H, H, Color3.new())
	gate.Transparency = 1
	gate.CanQuery = false
	gate.CanTouch = false
	gate.CollisionGroup = "ShaftGate"
	local fence = gate:Clone()
	fence.Name = "CrateFence"
	fence.CollisionGroup = "CrateFence"
	fence.Parent = floor
	floor.Parent = root
	return floor, rects, gate
end

function Tower.build(): Tower
	local old = workspace:FindFirstChild("Tower")
	if old then
		old:Destroy()
	end
	-- the race place stands on its own ground (Studio's template baseplate would block the shaft)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	-- nobody spawns at a SpawnLocation here (the race places everyone), and Studio's template has one
	-- sitting right in the shaft
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end

	local root = Instance.new("Model")
	root.Name = "Tower"

	-- the pit under the shaft where the platforms start (the ground round the tower is terrain: World)
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	box(ground, "Pit", -H, H, -2 * FH - 2, -2 * FH - 1, -H, H, CONCRETE_DARK)
	ground:SetAttribute("Floor", -1)
	ground.Parent = root

	local floors: { [number]: Model } = {}
	local covers: { [number]: { Rect } } = {}
	local gates: { [number]: BasePart } = {}
	for i = 0, FLOORS - 1 do
		floors[i], covers[i], gates[i] = buildFloor(root, i)
	end

	-- the roof: a slab with the hatch over the shaft, and a low parapet
	local roof = Instance.new("Model")
	roof.Name = "Roof"
	roof:SetAttribute("Floor", FLOORS)
	local ry = FLOORS * FH
	slabRing(roof, ry - SLAB, ry, F, H, CONCRETE, "Slab")
	local p = 1 * M
	box(roof, "Parapet", -F, F, ry, ry + p, F - WALL, F, CONCRETE)
	box(roof, "Parapet", -F, F, ry, ry + p, -F, -F + WALL, CONCRETE)
	box(roof, "Parapet", F - WALL, F, ry, ry + p, -F, F, CONCRETE)
	box(roof, "Parapet", -F, -F + WALL, ry, ry + p, -F, F, CONCRETE)
	local doors = {
		box(roof, "Hatch", -H, 0, ry - 0.6, ry, -H, H, Color3.fromRGB(70, 74, 80), Enum.Material.DiamondPlate),
		box(roof, "Hatch", 0, H, ry - 0.6, ry, -H, H, Color3.fromRGB(70, 74, 80), Enum.Material.DiamondPlate),
	}
	local closedAt = { doors[1].CFrame, doors[2].CFrame }
	roof.Parent = root
	floors[FLOORS] = roof
	covers[FLOORS] = Roof.dress(roof, ry)

	root.Parent = workspace

	local inner = F - WALL - 2
	local function floorY(floor: number): number
		return floor * FH
	end
	local function free(floor: number, x: number, z: number, margin: number): boolean
		local clear = H + 2 * M
		if math.abs(x) < clear and math.abs(z) < clear then
			return false
		end
		for _, r in covers[floor] or {} do
			if x > r.x0 - margin and x < r.x1 + margin and z > r.z0 - margin and z < r.z1 + margin then
				return false
			end
		end
		return true
	end

	local tower: Tower = {
		model = root,
		floors = floors,
		covers = covers,
		gates = gates,
		-- a clear spot to stand on a floor (3 studs above its surface, for spawning)
		randomSpot = function(floor: number): Vector3
			for _ = 1, 40 do
				local x, z = rr(-inner, inner), rr(-inner, inner)
				if free(floor, x, z, 2.5) then
					return Vector3.new(x, floorY(floor) + 3, z)
				end
			end
			return Vector3.new(inner * 0.8, floorY(floor) + 3, inner * 0.8)
		end,
		-- a spot just off the shaft's edge (where the platform throws its riders)
		ringSpot = function(floor: number): Vector3
			for _ = 1, 20 do
				local a = rr(0, 2 * math.pi)
				local r = H + rr(2, 4.5) * M
				local x, z = math.cos(a) * r, math.sin(a) * r
				x = math.clamp(x, -inner, inner)
				z = math.clamp(z, -inner, inner)
				if math.abs(x) > H + 1 or math.abs(z) > H + 1 then
					if free(floor, x, z, 1.5) or floor >= FLOORS then
						return Vector3.new(x, floorY(floor) + 3, z)
					end
				end
			end
			return Vector3.new(H + 2 * M, floorY(floor) + 3, 0)
		end,
		floorOf = function(y: number): number
			return math.clamp(math.floor(y / FH + 0.3), 0, FLOORS)
		end,
		openHatch = function()
			local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			TweenService:Create(doors[1], info, { CFrame = closedAt[1] * CFrame.new(-H - 0.3, 0, 0) }):Play()
			TweenService:Create(doors[2], info, { CFrame = closedAt[2] * CFrame.new(H + 0.3, 0, 0) }):Play()
		end,
		closeHatch = function()
			doors[1].CFrame = closedAt[1]
			doors[2].CFrame = closedAt[2]
		end,
	}
	return tower
end

return Tower
