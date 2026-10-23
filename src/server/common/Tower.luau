--!strict
-- Builds the tower: 20 floors of 24 × 24 m round a platform shaft, each with its own theme (Themes.luau):
-- its floor with a border and a walkway round the shaft, walls finished all over on the room side (round
-- the window reveals too) with a skirting and its glowing line, a sill and a cornice, framed windows
-- tinted in the floor's colour (so from outside the tower glows in many colours), four soft lights, the
-- floor's number and name painted big on the floor, furniture placed by the theme's plan (it doubles as
-- cover: Props), and the theme's dressing (signs, paintings, pipes, floor markings). Then the roof.
--
-- Floor i's surface is at y = i × FLOOR_HEIGHT (i = 0 is the ground floor). Every floor is a Model
-- named FloorNN with a Floor attribute (the roof is Floor = FLOORS) so clients can cut away the
-- floors above them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Booster = require(ReplicatedStorage.Shared.Booster)
local Hatch = require(ReplicatedStorage.Shared.Hatch)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)
local Themes = require(script.Parent.Themes)
local Roof = require(script.Parent.Roof)
local CollisionGroups = require(script.Parent.CollisionGroups)

local FLOORS = Config.FLOORS
local FH = Config.FLOOR_HEIGHT
local F = Config.FLOOR_HALF
local SLAB = Config.SLAB
local WALL = Config.WALL
local H = Config.SHAFT_HALF
local M = Config.M

local CONCRETE = Color3.fromRGB(150, 146, 140)
local CONCRETE_DARK = Color3.fromRGB(104, 101, 98)
local CAP = Color3.fromRGB(40, 36, 44) -- the cut top of the walls, seen once the floors above are cut away

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

-- interiors = false: only the floors' shells and lights, no furniture or dressing (the lobby, which only
-- sees the tower from out on the forecourt)
export type Options = { interiors: boolean? }

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
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
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
-- outside; on the room side one finish all over (the theme's wall, and below the sills its lower finish)
-- that turns into the window reveals up to the glass, a skirting with a glowing line, a sill all along the
-- windows, a cornice, and window frames (a transom across them all, a mullion in each)
local WIN_W = 1.44 * M
local WIN_H = 1.36 * M
local SILL = 1.0 * M
local WIN_STEP = 3 * M
local SKIN = 0.15
local FACE = F - WALL - SKIN -- the walls' room faces, this far from the middle
local COUNT = math.floor(2 * F / WIN_STEP)
local FIRST = -F + (2 * F - (COUNT - 1) * WIN_STEP) / 2
local WINDOWS: { number } = {} -- the windows' middles along a wall
local PILLARS: { number } = {} -- the stretches of wall between them
for k = 0, COUNT - 1 do
	table.insert(WINDOWS, FIRST + k * WIN_STEP)
	if k > 0 then
		table.insert(PILLARS, FIRST + (k - 0.5) * WIN_STEP)
	end
end

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
		mat: Enum.Material?,
		name: string
	): Part
		local a, b = F - d1, F - d0
		local p
		if side == "+x" then
			p = box(parent, name, a, b, v0, v1, u0, u1, color, mat)
		elseif side == "-x" then
			p = box(parent, name, -b, -a, v0, v1, u0, u1, color, mat)
		elseif side == "+z" then
			p = box(parent, name, u0, u1, v0, v1, a, b, color, mat)
		else
			p = box(parent, name, u0, u1, v0, v1, -b, -a, color, mat)
		end
		-- which wall it's part of: the one between the camera and you is cut away (client/race/Cutaway)
		p:SetAttribute("Side", side)
		return p
	end
	local function trim(
		u0: number,
		u1: number,
		v0: number,
		v1: number,
		d0: number,
		d1: number,
		color: Color3,
		mat: Enum.Material?,
		name: string
	)
		decor(place(u0, u1, v0, v1, d0, d1, color, mat, name))
	end
	local inner = F - WALL
	local sill = y0 + SILL
	local top = sill + WIN_H
	local reveal = WALL * 0.62 -- the room's finish turns into the reveals up to here (just inside the glass)
	local room = WALL + SKIN
	-- the concrete shell, and the room's finish over it
	place(-F, F, y0, sill, 0, WALL, CONCRETE, nil, "Wall")
	place(-F, F, top, y1, 0, WALL, CONCRETE, nil, "Wall")
	place(-inner, inner, y0, sill, WALL, room, th.lower, th.lowerMat, "Skin")
	place(-inner, inner, top, y1, WALL, room, th.wall, th.wallMat, "Skin")
	local function pier(u0: number, u1: number)
		place(u0, u1, sill, top, 0, WALL, CONCRETE, nil, "Wall")
		place(
			math.max(u0 - 0.03, -inner),
			math.min(u1 + 0.03, inner),
			sill,
			top,
			reveal,
			room,
			th.wall,
			th.wallMat,
			"Skin"
		)
	end
	local edge = -F
	for _, u in WINDOWS do
		pier(edge, u - WIN_W / 2)
		edge = u + WIN_W / 2
	end
	pier(edge, F)
	-- one pane along the whole row, inside the wall: the piers hide it (one see-through part a wall rather
	-- than one a window: far fewer to draw)
	local last = WINDOWS[#WINDOWS]
	local glass = place(
		FIRST - WIN_W / 2,
		last + WIN_W / 2,
		sill,
		top,
		WALL * 0.4,
		WALL * 0.6,
		th.light:Lerp(Color3.new(1, 1, 1), 0.25),
		Enum.Material.Glass,
		"Glass"
	)
	glass.Transparency = 0.55
	glass.CanQuery = false
	-- the frames: a transom across every window (the piers hide it between them) and a mullion in each
	local transom = sill + WIN_H * 0.66
	trim(
		FIRST - WIN_W / 2,
		last + WIN_W / 2,
		transom - 0.09,
		transom + 0.09,
		WALL * 0.3,
		WALL * 0.7,
		th.frame,
		Enum.Material.Metal,
		"Frame"
	)
	for _, u in WINDOWS do
		trim(u - 0.09, u + 0.09, sill, top, WALL * 0.3, WALL * 0.7, th.frame, Enum.Material.Metal, "Frame")
	end
	-- the skirting and its glowing line, the sill and its apron, the cornice
	trim(-inner, inner, y0, y0 + 0.55, room, room + 0.1, th.trim, th.trimMat, "Trim")
	trim(-inner, inner, y0 + 0.1, y0 + 0.24, room + 0.1, room + 0.16, th.accent, Enum.Material.Neon, "Baseboard")
	trim(-inner, inner, sill - 0.12, sill + 0.1, reveal, room + 0.38, th.trim, th.trimMat, "Sill")
	trim(-inner, inner, sill - 0.42, sill - 0.12, room, room + 0.06, th.trim, th.trimMat, "Trim")
	trim(-inner, inner, y1 - 0.4, y1, room, room + 0.2, th.trim, th.trimMat, "Trim")
	-- the wall's cut top, one dark band (inside the slab above while that's drawn)
	trim(-F, F, y1 + 0.005, y1 + 0.05, 0, room + 0.2, CAP, nil, "Cap")
end

-- the floor's finishes: a band along the walls, and the walkway round the shaft with an inlaid line
local function finishes(floor: Instance, y0: number, th: Themes.Theme)
	local border = th.border
	if border then
		local b = 2.6
		local c, m = border.color, border.mat
		decor(box(floor, "Border", -FACE, FACE, y0, y0 + 0.03, FACE - b, FACE, c, m))
		decor(box(floor, "Border", -FACE, FACE, y0, y0 + 0.03, -FACE, -FACE + b, c, m))
		decor(box(floor, "Border", FACE - b, FACE, y0, y0 + 0.03, -FACE + b, FACE - b, c, m))
		decor(box(floor, "Border", -FACE, -FACE + b, y0, y0 + 0.03, -FACE + b, FACE - b, c, m))
	end
	local walk = th.walk
	if walk then
		local a, b = H + 0.25 * M, Config.SHAFT_CLEAR - 0.3
		local c, m = walk.color, walk.mat
		for _, s in { 1, -1 } do
			decor(box(floor, "Walk", -b, b, y0, y0 + 0.03, math.min(s * a, s * b), math.max(s * a, s * b), c, m))
			decor(box(floor, "Walk", math.min(s * a, s * b), math.max(s * a, s * b), y0, y0 + 0.03, -a, a, c, m))
			decor(
				box(
					floor,
					"Walk",
					-b - 0.2,
					b + 0.2,
					y0,
					y0 + 0.04,
					math.min(s * b, s * (b + 0.2)),
					math.max(s * b, s * (b + 0.2)),
					th.trim,
					th.trimMat
				)
			)
			decor(
				box(
					floor,
					"Walk",
					math.min(s * b, s * (b + 0.2)),
					math.max(s * b, s * (b + 0.2)),
					y0,
					y0 + 0.04,
					-b,
					b,
					th.trim,
					th.trimMat
				)
			)
		end
	end
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

-- where the furniture goes on one floor: the theme's plan first (its spots, if they fit), then its other
-- pieces wherever they fit, some against a wall facing into the room. Nothing on the walkway round the
-- shaft, the painted number or the booster pad, and nothing on top of anything else.
local INNER = FACE - 0.02
local GAP = 1.4 * M -- between pieces dropped at random
local function placeProps(th: Themes.Theme, y0: number, reserved: { Rect }): { Kit.Placed }
	local placed: { Kit.Placed } = {}
	local function fits(b: Rect, gap: number): boolean
		local clear = Config.SHAFT_CLEAR
		if b.x1 > -clear and b.x0 < clear and b.z1 > -clear and b.z0 < clear then
			return false
		end
		if b.x0 < -INNER - 0.05 or b.x1 > INNER + 0.05 or b.z0 < -INNER - 0.05 or b.z1 > INNER + 0.05 then
			return false
		end
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
	local function add(name: string, x: number, z: number, yaw: number, gap: number): boolean
		local prop = Props[name]
		assert(prop, `there's no prop called {name}`)
		local quarter = math.abs(math.sin(yaw)) > 0.5
		local sx = if quarter then prop.d else prop.w
		local sz = if quarter then prop.w else prop.d
		local b: Kit.Placed = {
			x0 = x - sx / 2,
			x1 = x + sx / 2,
			z0 = z - sz / 2,
			z1 = z + sz / 2,
			h = prop.h,
			kind = prop.kind,
			name = name,
			cf = CFrame.new(x, y0, z) * CFrame.Angles(0, yaw, 0),
		}
		if fits(b, gap) then
			table.insert(placed, b)
			return true
		end
		return false
	end
	-- its back to a wall, facing into the room
	local function against(name: string, side: string, u: number, gap: number): boolean
		local prop = Props[name]
		assert(prop, `there's no prop called {name}`)
		local off = INNER - prop.d / 2
		if side == "+x" then
			return add(name, off, u, math.pi / 2, gap)
		elseif side == "-x" then
			return add(name, -off, u, -math.pi / 2, gap)
		elseif side == "+z" then
			return add(name, u, off, 0, gap)
		end
		return add(name, u, -off, math.pi, gap)
	end
	local plan = th.plan
	if plan then
		plan({
			th = th,
			rng = rng,
			inner = INNER,
			clear = Config.SHAFT_CLEAR,
			put = function(name: string, x: number, z: number, yaw: number?, gap: number?): boolean
				return add(name, x, z, yaw or 0, gap or 2)
			end,
			against = function(name: string, side: string, u: number, gap: number?): boolean
				return against(name, side, u, gap or 2)
			end,
		})
	end
	for _, entry in th.props do
		local name = entry[1] :: string
		local prop = Props[name]
		assert(prop, `there's no prop called {name}`)
		for _ = 1, rng:NextInteger(entry[2] :: number, entry[3] :: number) do
			for _ = 1, 50 do
				if prop.wall then
					local side = ({ "+x", "-x", "+z", "-z" })[rng:NextInteger(1, 4)]
					if against(name, side, rr(-INNER + prop.w / 2 + 1, INNER - prop.w / 2 - 1), GAP) then
						break
					end
				elseif add(name, rr(-INNER, INNER), rr(-INNER, INNER), rng:NextInteger(0, 3) * math.pi / 2, GAP) then
					break
				end
			end
		end
	end
	return placed
end

-- the frame on a wall's room face at u along it, at floor level: x runs along the wall, -z out into the room
local function wallFrame(side: string, u: number, y0: number): CFrame
	local pos, dir
	if side == "+x" then
		pos, dir = Vector3.new(FACE, y0, u), Vector3.new(-1, 0, 0)
	elseif side == "-x" then
		pos, dir = Vector3.new(-FACE, y0, u), Vector3.new(1, 0, 0)
	elseif side == "+z" then
		pos, dir = Vector3.new(u, y0, FACE), Vector3.new(0, 0, -1)
	else
		pos, dir = Vector3.new(u, y0, -FACE), Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(pos, pos + dir)
end

-- the room a theme dresses (Kit.Room)
local function roomOf(
	floor: Instance,
	th: Themes.Theme,
	y0: number,
	y1: number,
	placed: { Kit.Placed },
	reserved: { Rect }
): Kit.Room
	local model = Instance.new("Model")
	model.Name = "Dressing"
	model.Parent = floor
	local function overlaps(list: { any }, x0: number, x1: number, z0: number, z1: number): boolean
		for _, o in list do
			if x1 + 0.5 > o.x0 and x0 - 0.5 < o.x1 and z1 + 0.5 > o.z0 and z0 - 0.5 < o.z1 then
				return true
			end
		end
		return false
	end
	return {
		th = th,
		rng = rng,
		model = model,
		y0 = y0,
		y1 = y1,
		inner = FACE,
		clear = Config.SHAFT_CLEAR,
		floor = Kit.on(model, CFrame.new(0, y0, 0)),
		wall = function(side: string, u: number): Kit.Builder
			return Kit.on(model, wallFrame(side, u, y0), side)
		end,
		free = function(side: string, u: number, half: number): boolean
			for _, p in placed do
				local near, a0, a1
				if side == "+x" then
					near, a0, a1 = p.x1 > FACE - 3, p.z0, p.z1
				elseif side == "-x" then
					near, a0, a1 = p.x0 < -FACE + 3, p.z0, p.z1
				elseif side == "+z" then
					near, a0, a1 = p.z1 > FACE - 3, p.x0, p.x1
				else
					near, a0, a1 = p.z0 < -FACE + 3, p.x0, p.x1
				end
				if near and a1 > u - half and a0 < u + half then
					return false
				end
			end
			return true
		end,
		open = function(x0: number, x1: number, z0: number, z1: number): boolean
			local clear = Config.SHAFT_CLEAR
			if x1 > -clear and x0 < clear and z1 > -clear and z0 < clear then
				return false
			end
			if x0 < -FACE or x1 > FACE or z0 < -FACE or z1 > FACE then
				return false
			end
			return not overlaps(placed, x0, x1, z0, z1) and not overlaps(reserved, x0, x1, z0, z1)
		end,
		placed = placed,
		pillars = PILLARS,
		windows = WINDOWS,
	}
end

local function buildFloor(root: Model, i: number, interiors: boolean): (Model, { Rect }, BasePart)
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
	finishes(floor, y0, th)
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
	-- the floor's number and name, and the furniture (kept off the paint and the booster pad, which
	-- reaches out past the walkway: server/race/BoostService)
	local rects: { Rect } = {}
	local paint = floorPaint(floor, i, y0, th)
	local reserved = { paint }
	if i < Booster.MAX_FLOOR then
		local bx, _, bz = Booster.pad(i)
		local r = Booster.PAD_R + 0.5
		table.insert(reserved, { x0 = bx - r, x1 = bx + r, z0 = bz - r, z1 = bz + r })
	end
	if interiors then
		local furniture = Instance.new("Model")
		furniture.Name = "Furniture"
		furniture.Parent = floor
		local placed = placeProps(th, y0, reserved)
		for _, c in placed do
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
				local prop = Props[c.name]
				if prop.set then
					-- (its pieces ghost one by one when they're in the camera's way: client/race/Cutaway)
					m:SetAttribute("Set", true)
				end
				prop.build(Kit.on(m, c.cf), th, rng)
				m.Parent = furniture
			end
			table.insert(rects, c)
		end
		local dress = th.dress
		if dress then
			dress(roomOf(floor, th, y0, y1, placed, reserved))
		end
	end
	-- four lights under the ceiling, in the floor's colour (no visible fixtures: the ceiling above you is
	-- cut away, so a lamp would hang in the air). Soft accents: the moonlight and the ambient light the room
	-- (it's under the open sky once the floors above are cut away, and those switch their lamps off); at
	-- 1.8 they washed pale floors out to white (shared/Look has the whole story)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * F / 2, sz * F / 2
			local lamp = decor(box(floor, "Lamp", x - 0.5, x + 0.5, y1 - 1.5, y1 - 0.5, z - 0.5, z + 0.5, th.light))
			lamp.Transparency = 1
			local light = Instance.new("PointLight")
			light.Color = th.light
			light.Range = 28
			light.Brightness = 0.45
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

function Tower.build(options: Options?): Tower
	local interiors = not (options and options.interiors == false)
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
		floors[i], covers[i], gates[i] = buildFloor(root, i, interiors)
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
	local doorColor = Color3.fromRGB(70, 74, 80)
	local doors = {
		box(roof, "Hatch", -H, 0, ry - Hatch.THICK, ry, -H, H, doorColor, Enum.Material.DiamondPlate),
		box(roof, "Hatch", 0, H, ry - Hatch.THICK, ry, -H, H, doorColor, Enum.Material.DiamondPlate),
	}
	local sides = { -1, 1 }
	local closedAt = { doors[1].CFrame, doors[2].CFrame }
	for i, d in doors do
		-- (each client slides its doors open from these: client/race/Ambience)
		d:SetAttribute("Side", sides[i])
		d:SetAttribute("Closed", closedAt[i])
	end
	local opening = 0
	roof.Parent = root
	floors[FLOORS] = roof
	covers[FLOORS] = Roof.dress(roof, ry)
	-- an invisible fence on the parapet's inner face, from the roof up (the floors below don't have it): the
	-- winner can't walk or jump off; the only way down is the skydive, which flies through it (Boosting)
	local edge = F - WALL
	CollisionGroups.fence(roof, -edge, edge, -edge, edge, ry, ry + 60)

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
		-- every client draws the doors sliding open from HatchOpenAt; here they're simply open once it's done
		openHatch = function()
			opening += 1
			local this = opening
			roof:SetAttribute("HatchOpenAt", workspace:GetServerTimeNow())
			task.delay(Hatch.OPEN_TIME, function()
				if this == opening then
					for i, d in doors do
						d.CFrame = closedAt[i] * Hatch.offset(sides[i], 1)
					end
				end
			end)
		end,
		closeHatch = function()
			opening += 1
			roof:SetAttribute("HatchOpenAt", nil)
			for i, d in doors do
				d.CFrame = closedAt[i]
			end
		end,
	}
	return tower
end

return Tower
