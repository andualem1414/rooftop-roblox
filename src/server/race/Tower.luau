--!strict
-- Builds the tower: 20 floors of 24 × 24 m round a platform shaft, windows all round, cover on every
-- floor (half walls, low barriers, loose crates), a lamp per floor, and the roof with its hatch.
-- Plain parts for now; the look (night forest, ink style) comes in phase 4.
--
-- Floor i's surface is at y = i × FLOOR_HEIGHT (i = 0 is the ground floor). Every floor is a Model
-- named FloorNN with a Floor attribute (the roof is Floor = FLOORS) so clients can cut away the
-- floors above them.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local FLOORS = Config.FLOORS
local FH = Config.FLOOR_HEIGHT
local F = Config.FLOOR_HALF
local SLAB = Config.SLAB
local WALL = Config.WALL
local H = Config.SHAFT_HALF
local M = Config.M

local CONCRETE = Color3.fromRGB(150, 146, 140)
local CONCRETE_DARK = Color3.fromRGB(104, 101, 98)
local FLOOR_TINTS = {
	Color3.fromRGB(122, 118, 112),
	Color3.fromRGB(112, 116, 120),
	Color3.fromRGB(120, 112, 108),
	Color3.fromRGB(110, 116, 108),
}

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

-- a square slab with the shaft hole in the middle: four parts round the hole
local function slabRing(
	parent: Instance,
	y0: number,
	y1: number,
	outer: number,
	hole: number,
	color: Color3,
	name: string
)
	box(parent, name, -outer, outer, y0, y1, hole, outer, color)
	box(parent, name, -outer, outer, y0, y1, -outer, -hole, color)
	box(parent, name, hole, outer, y0, y1, -hole, hole, color)
	box(parent, name, -outer, -hole, y0, y1, -hole, hole, color)
end

-- one outer wall with a row of windows (glass you can't climb through; bullets pass)
local WIN_W = 1.44 * M
local WIN_H = 1.36 * M
local SILL = 1.0 * M
local WIN_STEP = 3 * M
local function wall(parent: Instance, side: string, y0: number, y1: number)
	-- work along u (the wall's length) and map to x/z
	local function place(u0: number, u1: number, v0: number, v1: number, color: Color3, mat: Enum.Material?): Part
		local a, b = F - WALL, F
		if side == "+x" then
			return box(parent, "Wall", a, b, v0, v1, u0, u1, color, mat)
		elseif side == "-x" then
			return box(parent, "Wall", -b, -a, v0, v1, u0, u1, color, mat)
		elseif side == "+z" then
			return box(parent, "Wall", u0, u1, v0, v1, a, b, color, mat)
		end
		return box(parent, "Wall", u0, u1, v0, v1, -b, -a, color, mat)
	end
	local top = y0 + SILL + WIN_H
	place(-F, F, y0, y0 + SILL, CONCRETE)
	place(-F, F, top, y1, CONCRETE)
	local count = math.floor(2 * F / WIN_STEP)
	local first = -F + (2 * F - (count - 1) * WIN_STEP) / 2
	local edge = -F
	for k = 0, count - 1 do
		local u = first + k * WIN_STEP
		place(edge, u - WIN_W / 2, y0 + SILL, top, CONCRETE)
		local glass =
			place(u - WIN_W / 2, u + WIN_W / 2, y0 + SILL, top, Color3.fromRGB(150, 175, 200), Enum.Material.Glass)
		glass.Name = "Glass"
		glass.Transparency = 0.7
		glass.CanQuery = false
		edge = u + WIN_W / 2
	end
	place(edge, F, y0 + SILL, top, CONCRETE)
end

-- where the cover goes on one floor: half walls, low barriers and crates, kept off the walkway round
-- the shaft and off each other (a port of the original's placeCovers)
type Cover = Rect & { h: number, crate: boolean }
local function placeCovers(): { Cover }
	local covers: { Cover } = {}
	local inner = F - WALL - 1
	local function ok(b: Rect): boolean
		local clear = Config.SHAFT_CLEAR
		if b.x1 > -clear and b.x0 < clear and b.z1 > -clear and b.z0 < clear then
			return false
		end
		if b.x0 < -inner or b.x1 > inner or b.z0 < -inner or b.z1 > inner then
			return false
		end
		local gap = 1.2 * M
		for _, o in covers do
			if b.x1 + gap > o.x0 and b.x0 - gap < o.x1 and b.z1 + gap > o.z0 and b.z0 - gap < o.z1 then
				return false
			end
		end
		return true
	end
	local function add(w: number, d: number, h: number, crate: boolean)
		for _ = 1, 40 do
			local sx, sz = w, d
			if rng:NextNumber() < 0.5 then
				sx, sz = d, w
			end
			local x, z = rr(-inner, inner), rr(-inner, inner)
			local b = { x0 = x - sx / 2, x1 = x + sx / 2, z0 = z - sz / 2, z1 = z + sz / 2, h = h, crate = crate }
			if ok(b) then
				table.insert(covers, b)
				return
			end
		end
	end
	for _ = 1, rng:NextInteger(2, 4) do
		add(rr(2.5, 4.5) * M, 0.3 * M, Config.HALF_WALL, false)
	end
	for _ = 1, rng:NextInteger(3, 5) do
		add(rr(1.6, 2.8) * M, 0.5 * M, Config.LOW_COVER, false)
	end
	for _ = 1, rng:NextInteger(4, 6) do
		add(1.2 * M, 1.2 * M, Config.LOW_COVER, true)
	end
	return covers
end

local function buildFloor(root: Model, i: number): (Model, { Rect }, BasePart)
	local floor = Instance.new("Model")
	floor.Name = string.format("Floor%02d", i + 1)
	floor:SetAttribute("Floor", i)
	local y0 = i * FH
	local y1 = (i + 1) * FH - SLAB
	slabRing(floor, y0 - SLAB, y0, F, H, FLOOR_TINTS[i % #FLOOR_TINTS + 1], "Slab")
	for _, side in { "+x", "-x", "+z", "-z" } do
		wall(floor, side, y0, y1)
	end
	-- a lip round the shaft so the hole reads from above
	local lip = 0.25 * M
	for _, s in { 1, -1 } do
		box(floor, "Lip", -H - lip, H + lip, y0, y0 + 0.15, s * H, s * (H + lip), CONCRETE_DARK)
		box(floor, "Lip", s * H, s * (H + lip), y0, y0 + 0.15, -H, H, CONCRETE_DARK)
	end
	-- cover
	local rects: { Rect } = {}
	for _, c in placeCovers() do
		if c.crate then
			local crate = box(
				floor,
				"Crate",
				c.x0,
				c.x1,
				y0,
				y0 + c.h,
				c.z0,
				c.z1,
				Color3.fromRGB(122, 92, 60),
				Enum.Material.WoodPlanks
			)
			crate.Anchored = false
			crate.CollisionGroup = "Crates"
			crate.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0, 1, 1)
		else
			local name = if c.h > Config.LOW_COVER then "HalfWall" else "Barrier"
			box(floor, name, c.x0, c.x1, y0, y0 + c.h, c.z0, c.z1, CONCRETE_DARK)
		end
		table.insert(rects, c)
	end
	-- one warm lamp under the ceiling
	local lamp = box(
		floor,
		"Lamp",
		-0.6,
		0.6,
		y1 - 0.4,
		y1,
		F / 2 - 0.6,
		F / 2 + 0.6,
		Color3.fromRGB(255, 214, 150),
		Enum.Material.Neon
	)
	lamp.CanCollide = false
	lamp.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Range = 36
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = lamp
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

	local root = Instance.new("Model")
	root.Name = "Tower"

	-- the ground round the tower, and the pit under the shaft where the platforms start
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	slabRing(ground, -4, 0, 400, F, Color3.fromRGB(58, 66, 54), "Ground")
	for _, g in ground:GetChildren() do
		(g :: Part).Material = Enum.Material.Grass
	end
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
	covers[FLOORS] = {}

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
