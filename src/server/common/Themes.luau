--!strict
-- What each floor is: 20 themes, bottom to top, each with its own floor, colours, lights and furniture.
-- Furniture doubles as cover:
--   "low"   you can jump over it and see / shoot across it (desks, sofas, beds, counters)
--   "high"  it blocks you, your view and shots (shelves, racks, lockers, vending machines)
--   "crate" a loose crate you can shove
-- Props are built from parts here, in their own frame: origin on the floor at the middle of the
-- footprint, front facing -Z, footprint w (x) by d (z) studs. Pieces that aren't the main body don't
-- collide (and don't stop shots), so cover behaves like its silhouette.

local Themes = {}

export type Theme = {
	name: string,
	floor: Color3,
	floorMat: Enum.Material,
	wall: Color3,
	accent: Color3,
	accent2: Color3,
	light: Color3,
	props: { { string | number } }, -- { prop name, how many (min), how many (max) }
}

export type Prop = {
	w: number,
	d: number,
	h: number,
	kind: "low" | "high" | "crate",
	wall: boolean, -- stands against a wall, facing into the room
	build: (parent: Instance, cf: CFrame, th: Theme, rng: Random) -> (),
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- one piece of a prop
local function piece(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
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

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up
local DARK = rgb(34, 32, 40)
local METAL = rgb(120, 124, 134)
local WOOD = rgb(140, 98, 66)
local WHITE = rgb(232, 230, 226)

local function at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local PROPS: { [string]: Prop } = {
	desk = {
		w = 9,
		d = 5,
		h = 2.9,
		kind = "low",
		wall = false,
		build = function(m, cf, th, rng)
			piece(m, at(cf, 0, 2.7, 0), Vector3.new(9, 0.4, 4.4), WOOD, Enum.Material.Wood)
			for _, x in { -4, 4 } do
				piece(m, at(cf, x, 1.25, 0), Vector3.new(0.4, 2.5, 4), DARK, Enum.Material.Metal)
			end
			piece(m, at(cf, -1.2, 4.1, 1.2), Vector3.new(3.4, 2.2, 0.25), DARK, nil, false)
			piece(
				m,
				at(cf, -1.2, 4.1, 1.05),
				Vector3.new(3.0, 1.8, 0.1),
				th.accent:Lerp(WHITE, 0.4),
				Enum.Material.Neon,
				false
			)
			piece(m, at(cf, 2.2, 3.0, 0.5), Vector3.new(1.6, 0.2, 1.1), rgb(20, 20, 24), nil, false)
			piece(
				m,
				at(cf, rng:NextNumber(-2, 2), 1.4, -3.3),
				Vector3.new(2.6, 0.5, 2.6),
				th.accent2,
				Enum.Material.Fabric,
				false
			)
			piece(m, at(cf, 0, 2.6, -4.5), Vector3.new(2.6, 2.6, 0.4), th.accent2, Enum.Material.Fabric, false)
		end,
	},
	sofa = {
		w = 9,
		d = 4,
		h = 2.8,
		kind = "low",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 0.9, 0), Vector3.new(9, 1.8, 4), th.accent2, Enum.Material.Fabric)
			piece(m, at(cf, 0, 2.3, 1.5), Vector3.new(9, 1.6, 1), th.accent2, Enum.Material.Fabric, false)
			for _, x in { -4.1, 4.1 } do
				piece(
					m,
					at(cf, x, 1.8, 0),
					Vector3.new(0.9, 1.4, 4),
					th.accent2:Lerp(DARK, 0.25),
					Enum.Material.Fabric,
					false
				)
			end
			piece(m, at(cf, -2, 2.1, -0.4), Vector3.new(1.6, 1.2, 0.5), th.accent, Enum.Material.Fabric, false)
		end,
	},
	plant = {
		w = 3,
		d = 3,
		h = 7,
		kind = "high",
		wall = false,
		build = function(m, cf, _th, rng)
			piece(
				m,
				at(cf, 0, 1.2, 0) * UPRIGHT,
				Vector3.new(2.4, 2.6, 2.6),
				rgb(200, 110, 70),
				Enum.Material.Slate,
				true,
				Enum.PartType.Cylinder
			)
			local green = rgb(54, 140, 80):Lerp(rgb(30, 100, 70), rng:NextNumber())
			piece(
				m,
				at(cf, 0, 4.2, 0),
				Vector3.new(3.6, 3.6, 3.6),
				green,
				Enum.Material.Grass,
				false,
				Enum.PartType.Ball
			)
			piece(
				m,
				at(cf, 0.5, 5.8, 0.3),
				Vector3.new(2.6, 2.6, 2.6),
				green:Lerp(WHITE, 0.15),
				Enum.Material.Grass,
				false,
				Enum.PartType.Ball
			)
		end,
	},
	shelf = {
		w = 10,
		d = 3,
		h = 7.5,
		kind = "high",
		wall = true,
		build = function(m, cf, th, rng)
			piece(m, at(cf, 0, 3.75, 0.6), Vector3.new(10, 7.5, 0.4), METAL, Enum.Material.Metal)
			for _, x in { -4.9, 4.9 } do
				piece(m, at(cf, x, 3.75, 0), Vector3.new(0.3, 7.5, 3), METAL, Enum.Material.Metal)
			end
			for k = 0, 3 do
				local y = 0.3 + k * 2.3
				piece(m, at(cf, 0, y, 0), Vector3.new(9.6, 0.25, 3), METAL, Enum.Material.Metal, false)
				for b = 1, 3 do
					local c = ({ th.accent, th.accent2, rgb(196, 160, 110) })[rng:NextInteger(1, 3)]
					piece(
						m,
						at(cf, -3.6 + b * 2.3 + rng:NextNumber(-0.4, 0.4), y + 0.9, 0),
						Vector3.new(1.8, 1.5, 2.2),
						c,
						Enum.Material.Cardboard,
						false
					)
				end
			end
		end,
	},
	rack = {
		w = 4.5,
		d = 3.5,
		h = 7.5,
		kind = "high",
		wall = false,
		build = function(m, cf, th, rng)
			piece(m, at(cf, 0, 3.75, 0), Vector3.new(4.5, 7.5, 3.5), rgb(26, 28, 36), Enum.Material.Metal)
			for k = 0, 9 do
				local c = if rng:NextNumber() < 0.75 then th.accent else th.accent2
				piece(
					m,
					at(cf, rng:NextNumber(-1.4, 1.4), 0.8 + k * 0.65, -1.78),
					Vector3.new(rng:NextNumber(0.4, 1.6), 0.12, 0.05),
					c,
					Enum.Material.Neon,
					false
				)
			end
		end,
	},
	vending = {
		w = 4.2,
		d = 3.6,
		h = 7.6,
		kind = "high",
		wall = true,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 3.8, 0), Vector3.new(4.2, 7.6, 3.6), th.accent2, Enum.Material.Metal)
			piece(
				m,
				at(cf, -0.4, 4.4, -1.82),
				Vector3.new(2.8, 5, 0.1),
				th.accent:Lerp(WHITE, 0.5),
				Enum.Material.Neon,
				false
			)
			piece(m, at(cf, 1.6, 3.6, -1.85), Vector3.new(0.6, 1.4, 0.1), DARK, nil, false)
		end,
	},
	lockers = {
		w = 9,
		d = 2.6,
		h = 7,
		kind = "high",
		wall = true,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 3.5, 0), Vector3.new(9, 7, 2.6), th.accent2, Enum.Material.Metal)
			for k = 0, 4 do
				local x = -3.6 + k * 1.8
				piece(m, at(cf, x + 0.9, 3.5, -1.32), Vector3.new(0.08, 6.6, 0.06), DARK, nil, false)
				piece(m, at(cf, x + 0.4, 5.6, -1.33), Vector3.new(0.8, 0.12, 0.06), DARK, nil, false)
			end
		end,
	},
	counter = {
		w = 10,
		d = 3.4,
		h = 3.1,
		kind = "low",
		wall = true,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 1.4, 0), Vector3.new(10, 2.8, 3.2), th.accent2, Enum.Material.Wood)
			piece(m, at(cf, 0, 2.95, 0), Vector3.new(10.2, 0.3, 3.4), WHITE, Enum.Material.Marble)
			piece(m, at(cf, 2.5, 3.3, 0.2), Vector3.new(1.5, 0.6, 1.2), METAL, Enum.Material.Metal, false)
		end,
	},
	fridge = {
		w = 3.6,
		d = 3.4,
		h = 7.6,
		kind = "high",
		wall = true,
		build = function(m, cf)
			piece(m, at(cf, 0, 3.8, 0), Vector3.new(3.6, 7.6, 3.4), WHITE, Enum.Material.Metal)
			piece(m, at(cf, 1.3, 4.6, -1.75), Vector3.new(0.2, 2.4, 0.2), METAL, Enum.Material.Metal, false)
			piece(m, at(cf, 0, 5.2, -1.72), Vector3.new(3.4, 0.08, 0.05), DARK, nil, false)
		end,
	},
	bed = {
		w = 7,
		d = 10,
		h = 2.2,
		kind = "low",
		wall = true,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 0.8, 0), Vector3.new(7, 1.6, 10), WOOD, Enum.Material.Wood)
			piece(m, at(cf, 0, 1.9, 0), Vector3.new(6.6, 0.7, 9.6), WHITE, Enum.Material.Fabric, false)
			piece(m, at(cf, 0, 2.3, -1.2), Vector3.new(6.7, 0.3, 6.5), th.accent2, Enum.Material.Fabric, false)
			piece(m, at(cf, 0, 2.5, 3.8), Vector3.new(4.5, 0.7, 1.6), WHITE, Enum.Material.Fabric, false)
			piece(m, at(cf, 0, 2.8, 4.9), Vector3.new(7, 4, 0.4), WOOD, Enum.Material.Wood, false)
		end,
	},
	car = {
		w = 7,
		d = 13,
		h = 4.3,
		kind = "high",
		wall = false,
		build = function(m, cf, _th, rng)
			local paint = ({
				rgb(210, 60, 70),
				rgb(60, 140, 220),
				rgb(240, 200, 70),
				rgb(80, 200, 140),
				rgb(240, 240, 240),
			})[rng:NextInteger(1, 5)]
			piece(m, at(cf, 0, 1.6, 0), Vector3.new(7, 2.2, 13), paint, Enum.Material.SmoothPlastic)
			piece(m, at(cf, 0, 3.4, 0.6), Vector3.new(6.2, 1.8, 7), rgb(40, 50, 70), Enum.Material.Glass, false).Reflectance =
				0.3
			for _, x in { -3.3, 3.3 } do
				for _, z in { -4, 4 } do
					piece(m, at(cf, x, 1, z), Vector3.new(0.8, 2, 2), DARK, nil, false, Enum.PartType.Cylinder)
				end
			end
			piece(
				m,
				at(cf, -2.2, 1.9, -6.52),
				Vector3.new(1.2, 0.5, 0.05),
				rgb(255, 250, 220),
				Enum.Material.Neon,
				false
			)
			piece(
				m,
				at(cf, 2.2, 1.9, -6.52),
				Vector3.new(1.2, 0.5, 0.05),
				rgb(255, 250, 220),
				Enum.Material.Neon,
				false
			)
			piece(m, at(cf, -2.2, 1.9, 6.52), Vector3.new(1.2, 0.5, 0.05), rgb(255, 40, 60), Enum.Material.Neon, false)
			piece(m, at(cf, 2.2, 1.9, 6.52), Vector3.new(1.2, 0.5, 0.05), rgb(255, 40, 60), Enum.Material.Neon, false)
		end,
	},
	pillar = {
		w = 3.4,
		d = 3.4,
		h = 8.5,
		kind = "high",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 4.27, 0), Vector3.new(3.4, 8.55, 3.4), rgb(150, 146, 140), Enum.Material.Concrete)
			piece(m, at(cf, 0, 1.2, 0), Vector3.new(3.5, 1.2, 3.5), th.accent, Enum.Material.SmoothPlastic, false)
		end,
	},
	washer = {
		w = 3.6,
		d = 3.6,
		h = 3.6,
		kind = "low",
		wall = true,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 1.8, 0), Vector3.new(3.6, 3.6, 3.6), WHITE, Enum.Material.Metal)
			piece(
				m,
				at(cf, 0, 1.6, -1.82) * CFrame.Angles(0, math.rad(90), 0),
				Vector3.new(0.1, 2.4, 2.4),
				rgb(70, 90, 130),
				Enum.Material.Glass,
				false,
				Enum.PartType.Cylinder
			)
			piece(m, at(cf, 1.1, 3.2, -1.82), Vector3.new(0.5, 0.3, 0.05), th.accent, Enum.Material.Neon, false)
		end,
	},
	bookcase = {
		w = 9,
		d = 2.6,
		h = 7.5,
		kind = "high",
		wall = true,
		build = function(m, cf, _th, rng)
			piece(m, at(cf, 0, 3.75, 0.5), Vector3.new(9, 7.5, 1.6), WOOD:Lerp(DARK, 0.3), Enum.Material.Wood)
			for k = 0, 3 do
				local y = 0.4 + k * 1.85
				local x = -4.1
				while x < 4 do
					local bw = rng:NextNumber(0.35, 0.7)
					local c = ({
						rgb(180, 60, 60),
						rgb(60, 110, 170),
						rgb(220, 180, 80),
						rgb(80, 150, 90),
						rgb(150, 90, 160),
					})[rng:NextInteger(1, 5)]
					piece(
						m,
						at(cf, x + bw / 2, y + 0.75, -0.3),
						Vector3.new(bw * 0.9, rng:NextNumber(1.1, 1.5), 1.4),
						c,
						Enum.Material.SmoothPlastic,
						false
					)
					x += bw
				end
			end
		end,
	},
	arcade = {
		w = 3.6,
		d = 3.6,
		h = 7.2,
		kind = "high",
		wall = true,
		build = function(m, cf, th, rng)
			local body = if rng:NextNumber() < 0.5 then th.accent2 else DARK
			piece(m, at(cf, 0, 3.6, 0.3), Vector3.new(3.6, 7.2, 3), body, Enum.Material.SmoothPlastic)
			piece(
				m,
				at(cf, 0, 4.6, -1.25) * CFrame.Angles(math.rad(-15), 0, 0),
				Vector3.new(3, 2.2, 0.1),
				th.accent:Lerp(WHITE, 0.3),
				Enum.Material.Neon,
				false
			)
			piece(m, at(cf, 0, 6.8, -1.2), Vector3.new(3.4, 0.7, 0.1), th.accent, Enum.Material.Neon, false)
			piece(m, at(cf, 0, 3.2, -1.6), Vector3.new(3.4, 0.4, 1.2), DARK, nil, false)
		end,
	},
	pooltable = {
		w = 6,
		d = 10.5,
		h = 2.9,
		kind = "low",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 2.5, 0), Vector3.new(6, 0.8, 10.5), WOOD:Lerp(DARK, 0.4), Enum.Material.Wood)
			piece(m, at(cf, 0, 2.92, 0), Vector3.new(5.2, 0.1, 9.7), rgb(40, 130, 90), Enum.Material.Fabric, false)
			for _, x in { -2.4, 2.4 } do
				for _, z in { -4.4, 4.4 } do
					piece(m, at(cf, x, 1.05, z), Vector3.new(0.8, 2.1, 0.8), DARK)
				end
			end
			piece(
				m,
				at(cf, 0, 3.15, -2),
				Vector3.new(0.45, 0.45, 0.45),
				th.accent,
				Enum.Material.SmoothPlastic,
				false,
				Enum.PartType.Ball
			)
		end,
	},
	tank = {
		w = 4.4,
		d = 4.4,
		h = 7.5,
		kind = "high",
		wall = false,
		build = function(m, cf, th)
			piece(
				m,
				at(cf, 0, 0.5, 0) * UPRIGHT,
				Vector3.new(1, 4.4, 4.4),
				METAL,
				Enum.Material.Metal,
				true,
				Enum.PartType.Cylinder
			)
			local glass = piece(
				m,
				at(cf, 0, 3.6, 0) * UPRIGHT,
				Vector3.new(5.2, 3.8, 3.8),
				th.accent,
				Enum.Material.Glass,
				true,
				Enum.PartType.Cylinder
			)
			glass.Transparency = 0.35
			piece(
				m,
				at(cf, 0, 3.3, 0) * UPRIGHT,
				Vector3.new(4.4, 3.2, 3.2),
				th.accent,
				Enum.Material.Neon,
				false,
				Enum.PartType.Cylinder
			).Transparency =
				0.4
			piece(
				m,
				at(cf, 0, 6.7, 0) * UPRIGHT,
				Vector3.new(1, 4.4, 4.4),
				METAL,
				Enum.Material.Metal,
				false,
				Enum.PartType.Cylinder
			)
		end,
	},
	boiler = {
		w = 5,
		d = 9,
		h = 6.5,
		kind = "high",
		wall = true,
		build = function(m, cf, th)
			piece(
				m,
				at(cf, 0, 3.2, 0) * CFrame.Angles(0, math.rad(90), 0),
				Vector3.new(9, 5, 5),
				rgb(160, 74, 52),
				Enum.Material.CorrodedMetal,
				true,
				Enum.PartType.Cylinder
			)
			piece(m, at(cf, 0, 6.6, 2), Vector3.new(1.2, 3, 1.2), METAL, Enum.Material.Metal, false)
			piece(m, at(cf, 0, 3.2, -4.55), Vector3.new(1.4, 1.4, 0.1), th.accent, Enum.Material.Neon, false)
		end,
	},
	planter = {
		w = 9,
		d = 3,
		h = 4.5,
		kind = "low",
		wall = false,
		build = function(m, cf, th, rng)
			piece(m, at(cf, 0, 1, 0), Vector3.new(9, 2, 3), WOOD, Enum.Material.WoodPlanks)
			piece(m, at(cf, 0, 2.05, 0), Vector3.new(8.6, 0.1, 2.6), rgb(70, 50, 40), Enum.Material.Ground, false)
			for k = -3, 3 do
				local c = ({ rgb(60, 160, 80), rgb(80, 180, 100), th.accent2 })[rng:NextInteger(1, 3)]
				piece(
					m,
					at(cf, k * 1.2, 2.8 + rng:NextNumber(0, 0.6), 0),
					Vector3.new(1.4, 1.6, 1.4),
					c,
					Enum.Material.Grass,
					false,
					Enum.PartType.Ball
				)
			end
		end,
	},
	bench = {
		w = 3,
		d = 8,
		h = 2,
		kind = "low",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 1.6, 0), Vector3.new(2.4, 0.6, 7), th.accent2, Enum.Material.Fabric)
			piece(m, at(cf, 0, 0.7, 0), Vector3.new(1, 1.2, 6), METAL, Enum.Material.Metal)
			piece(
				m,
				at(cf, 0, 3.6, -2.6) * CFrame.Angles(0, math.rad(90), 0),
				Vector3.new(7, 0.25, 0.25),
				METAL,
				Enum.Material.Metal,
				false,
				Enum.PartType.Cylinder
			)
			for _, x in { -3, 3 } do
				piece(m, at(cf, x, 3.6, -2.6), Vector3.new(0.5, 2.2, 2.2), DARK, nil, false, Enum.PartType.Cylinder)
			end
		end,
	},
	easel = {
		w = 3,
		d = 3,
		h = 6,
		kind = "high",
		wall = false,
		build = function(m, cf, _th, rng)
			piece(
				m,
				at(cf, 0, 2.6, 0.6) * CFrame.Angles(math.rad(10), 0, 0),
				Vector3.new(0.3, 5.4, 0.3),
				WOOD,
				Enum.Material.Wood
			)
			piece(m, at(cf, -1.2, 2.4, 0), Vector3.new(0.25, 4.8, 0.25), WOOD, Enum.Material.Wood, false)
			piece(m, at(cf, 1.2, 2.4, 0), Vector3.new(0.25, 4.8, 0.25), WOOD, Enum.Material.Wood, false)
			piece(
				m,
				at(cf, 0, 4.2, -0.15) * CFrame.Angles(math.rad(10), 0, 0),
				Vector3.new(3, 2.4, 0.15),
				WHITE,
				Enum.Material.Fabric,
				false
			)
			for _ = 1, 3 do
				local c = Color3.fromHSV(rng:NextNumber(), 0.8, 1)
				piece(
					m,
					at(cf, rng:NextNumber(-1, 1), 4.2 + rng:NextNumber(-0.8, 0.8), -0.25)
						* CFrame.Angles(math.rad(10), 0, rng:NextNumber(0, 3)),
					Vector3.new(rng:NextNumber(0.6, 1.4), 0.3, 0.05),
					c,
					Enum.Material.SmoothPlastic,
					false
				)
			end
		end,
	},
	speaker = {
		w = 4,
		d = 4,
		h = 8,
		kind = "high",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 4, 0), Vector3.new(4, 8, 4), rgb(20, 20, 26), Enum.Material.SmoothPlastic)
			for _, y in { 2.4, 5.6 } do
				piece(
					m,
					at(cf, 0, y, -2.02) * CFrame.Angles(0, math.rad(90), 0),
					Vector3.new(0.05, 2.8, 2.8),
					th.accent,
					Enum.Material.Neon,
					false,
					Enum.PartType.Cylinder
				)
				piece(
					m,
					at(cf, 0, y, -2.04) * CFrame.Angles(0, math.rad(90), 0),
					Vector3.new(0.05, 2.2, 2.2),
					rgb(20, 20, 26),
					nil,
					false,
					Enum.PartType.Cylinder
				)
			end
		end,
	},
	djbooth = {
		w = 10,
		d = 4,
		h = 3.4,
		kind = "low",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 1.7, 0), Vector3.new(10, 3.4, 4), rgb(24, 22, 30), Enum.Material.SmoothPlastic)
			piece(m, at(cf, 0, 1.7, -2.02), Vector3.new(9.6, 0.4, 0.05), th.accent, Enum.Material.Neon, false)
			piece(m, at(cf, 0, 0.9, -2.02), Vector3.new(9.6, 0.4, 0.05), th.accent2, Enum.Material.Neon, false)
			for _, x in { -2.5, 2.5 } do
				piece(
					m,
					at(cf, x, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
					Vector3.new(0.2, 2.2, 2.2),
					DARK,
					nil,
					false,
					Enum.PartType.Cylinder
				)
			end
		end,
	},
	scaffold = {
		w = 9,
		d = 4,
		h = 8.5,
		kind = "high",
		wall = false,
		build = function(m, cf, th)
			for _, x in { -4.3, 4.3 } do
				for _, z in { -1.8, 1.8 } do
					piece(m, at(cf, x, 4.25, z), Vector3.new(0.3, 8.5, 0.3), th.accent2, Enum.Material.Metal, false)
				end
			end
			piece(m, at(cf, 0, 4.2, 0), Vector3.new(9, 0.4, 4), WOOD, Enum.Material.WoodPlanks)
			piece(m, at(cf, 0, 1.2, 0), Vector3.new(9, 2.4, 4), rgb(150, 146, 140), Enum.Material.Concrete)
			piece(
				m,
				at(cf, 0, 2.6, -2) * CFrame.Angles(0, 0, math.rad(25)),
				Vector3.new(9.6, 0.25, 0.25),
				th.accent2,
				Enum.Material.Metal,
				false
			)
		end,
	},
	cabinets = {
		w = 9,
		d = 3,
		h = 5,
		kind = "high",
		wall = true,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 2.5, 0), Vector3.new(9, 5, 3), rgb(150, 156, 166), Enum.Material.Metal)
			for k = 0, 2 do
				for r = 0, 2 do
					piece(
						m,
						at(cf, -3 + k * 3, 0.9 + r * 1.6, -1.52),
						Vector3.new(1, 0.2, 0.05),
						th.accent,
						Enum.Material.SmoothPlastic,
						false
					)
				end
			end
		end,
	},
	piano = {
		w = 6,
		d = 6,
		h = 3.6,
		kind = "low",
		wall = false,
		build = function(m, cf)
			piece(m, at(cf, 0, 2.4, 0.4), Vector3.new(6, 1.6, 5.2), rgb(16, 14, 18), Enum.Material.SmoothPlastic).Reflectance =
				0.2
			piece(m, at(cf, 0, 2.2, -2.5), Vector3.new(5.6, 0.25, 0.9), WHITE, nil, false)
			piece(
				m,
				at(cf, 0, 3.6, 1.5) * CFrame.Angles(math.rad(-30), 0, 0),
				Vector3.new(6, 0.2, 3.5),
				rgb(16, 14, 18),
				nil,
				false
			)
			for _, x in { -2.6, 2.6 } do
				piece(m, at(cf, x, 0.8, 0.4), Vector3.new(0.6, 1.6, 0.6), rgb(16, 14, 18))
			end
		end,
	},
	machine = {
		w = 7,
		d = 7,
		h = 7.5,
		kind = "high",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 3, 0), Vector3.new(7, 6, 7), rgb(70, 74, 86), Enum.Material.DiamondPlate)
			piece(
				m,
				at(cf, 0, 6.4, 0) * CFrame.Angles(0, 0, 0),
				Vector3.new(1.4, 6.4, 6.4),
				rgb(180, 140, 60),
				Enum.Material.Metal,
				false,
				Enum.PartType.Cylinder
			)
			piece(m, at(cf, 0, 3, -3.52), Vector3.new(7, 0.6, 0.05), th.accent, Enum.Material.Neon, false)
			piece(m, at(cf, 0, 4.8, -3.52), Vector3.new(1.4, 1.4, 0.05), th.accent2, Enum.Material.Neon, false)
		end,
	},
	reception = {
		w = 14,
		d = 4,
		h = 3.6,
		kind = "low",
		wall = false,
		build = function(m, cf, th)
			piece(m, at(cf, 0, 1.8, 0), Vector3.new(14, 3.6, 4), WHITE, Enum.Material.Marble)
			piece(m, at(cf, 0, 3.7, 0), Vector3.new(14.4, 0.25, 4.4), th.accent2, Enum.Material.Metal)
			piece(m, at(cf, 0, 0.6, -2.02), Vector3.new(13.6, 0.3, 0.05), th.accent, Enum.Material.Neon, false)
		end,
	},
	crate = {
		w = 3.6,
		d = 3.6,
		h = 2.85,
		kind = "crate",
		wall = false,
		build = function() end, -- (crates are loose: made by the tower builder)
	},
}

Themes.PROPS = PROPS

local function theme(
	name: string,
	floor: Color3,
	floorMat: Enum.Material,
	wall: Color3,
	accent: Color3,
	accent2: Color3,
	light: Color3,
	props: { { string | number } }
): Theme
	return {
		name = name,
		floor = floor,
		floorMat = floorMat,
		wall = wall,
		accent = accent,
		accent2 = accent2,
		light = light,
		props = props,
	}
end

-- bottom to top (floor 1 is the ground floor)
Themes.LIST = {
	theme(
		"Lobby",
		rgb(214, 208, 198),
		Enum.Material.Marble,
		rgb(196, 176, 150),
		rgb(255, 196, 90),
		rgb(120, 70, 60),
		rgb(255, 214, 160),
		{ { "reception", 1, 1 }, { "sofa", 3, 4 }, { "plant", 4, 6 }, { "pillar", 2, 2 } }
	),
	theme(
		"Parking",
		rgb(96, 98, 104),
		Enum.Material.Asphalt,
		rgb(140, 140, 136),
		rgb(255, 210, 60),
		rgb(240, 240, 240),
		rgb(255, 200, 120),
		{ { "car", 4, 6 }, { "pillar", 4, 4 }, { "crate", 2, 3 } }
	),
	theme(
		"Warehouse",
		rgb(130, 112, 92),
		Enum.Material.Concrete,
		rgb(150, 120, 90),
		rgb(255, 150, 50),
		rgb(90, 140, 200),
		rgb(255, 190, 120),
		{ { "shelf", 4, 6 }, { "crate", 6, 8 } }
	),
	theme(
		"Laundry",
		rgb(170, 210, 214),
		Enum.Material.Plastic,
		rgb(120, 190, 200),
		rgb(70, 230, 230),
		rgb(255, 140, 180),
		rgb(190, 250, 255),
		{ { "washer", 6, 9 }, { "counter", 1, 2 }, { "crate", 2, 3 } }
	),
	theme(
		"Gym",
		rgb(120, 80, 60),
		Enum.Material.WoodPlanks,
		rgb(60, 60, 70),
		rgb(255, 60, 70),
		rgb(240, 240, 240),
		rgb(255, 150, 140),
		{ { "bench", 4, 6 }, { "lockers", 2, 3 }, { "plant", 1, 2 } }
	),
	theme(
		"Offices",
		rgb(90, 104, 128),
		Enum.Material.Fabric,
		rgb(210, 214, 222),
		rgb(110, 190, 255),
		rgb(80, 90, 120),
		rgb(220, 236, 255),
		{ { "desk", 6, 8 }, { "cabinets", 1, 2 }, { "plant", 2, 3 } }
	),
	theme(
		"Canteen",
		rgb(200, 140, 90),
		Enum.Material.Plastic,
		rgb(240, 200, 150),
		rgb(255, 120, 60),
		rgb(70, 160, 120),
		rgb(255, 210, 160),
		{ { "counter", 2, 3 }, { "fridge", 2, 3 }, { "vending", 2, 2 }, { "desk", 2, 3 } }
	),
	theme(
		"Server Room",
		rgb(40, 44, 56),
		Enum.Material.DiamondPlate,
		rgb(30, 34, 44),
		rgb(60, 255, 170),
		rgb(70, 140, 255),
		rgb(120, 255, 220),
		{ { "rack", 9, 12 } }
	),
	theme(
		"Greenhouse",
		rgb(110, 90, 70),
		Enum.Material.Ground,
		rgb(220, 240, 230),
		rgb(255, 80, 220),
		rgb(255, 120, 160),
		rgb(255, 150, 255),
		{ { "planter", 6, 8 }, { "plant", 4, 6 } }
	),
	theme(
		"Library",
		rgb(120, 60, 50),
		Enum.Material.Carpet,
		rgb(150, 110, 80),
		rgb(255, 190, 90),
		rgb(110, 40, 40),
		rgb(255, 210, 150),
		{ { "bookcase", 5, 7 }, { "desk", 2, 3 }, { "sofa", 1, 2 } }
	),
	theme(
		"Arcade",
		rgb(50, 30, 80),
		Enum.Material.Carpet,
		rgb(40, 24, 70),
		rgb(255, 60, 220),
		rgb(60, 220, 255),
		rgb(220, 120, 255),
		{ { "arcade", 8, 10 }, { "pooltable", 1, 2 } }
	),
	theme(
		"Hotel",
		rgb(140, 40, 60),
		Enum.Material.Carpet,
		rgb(230, 210, 180),
		rgb(255, 200, 100),
		rgb(180, 140, 100),
		rgb(255, 220, 170),
		{ { "bed", 4, 5 }, { "sofa", 1, 2 }, { "plant", 2, 3 } }
	),
	theme(
		"Boiler Room",
		rgb(70, 60, 56),
		Enum.Material.DiamondPlate,
		rgb(90, 70, 60),
		rgb(255, 110, 40),
		rgb(255, 200, 60),
		rgb(255, 150, 80),
		{ { "boiler", 3, 4 }, { "tank", 2, 3 }, { "crate", 2, 3 } }
	),
	theme(
		"Art Studio",
		rgb(230, 226, 214),
		Enum.Material.WoodPlanks,
		rgb(250, 248, 240),
		rgb(255, 90, 90),
		rgb(80, 160, 255),
		rgb(255, 245, 230),
		{ { "easel", 6, 8 }, { "desk", 2, 2 }, { "plant", 2, 3 } }
	),
	theme(
		"Lab",
		rgb(210, 226, 232),
		Enum.Material.Plastic,
		rgb(220, 236, 240),
		rgb(90, 255, 140),
		rgb(90, 200, 255),
		rgb(200, 255, 230),
		{ { "tank", 4, 6 }, { "counter", 2, 3 }, { "cabinets", 1, 2 } }
	),
	theme(
		"Nightclub",
		rgb(24, 20, 34),
		Enum.Material.Glass,
		rgb(20, 16, 30),
		rgb(255, 40, 160),
		rgb(40, 200, 255),
		rgb(255, 80, 200),
		{ { "speaker", 4, 4 }, { "djbooth", 1, 1 }, { "sofa", 2, 3 } }
	),
	theme(
		"Construction",
		rgb(150, 146, 140),
		Enum.Material.Concrete,
		rgb(170, 166, 156),
		rgb(255, 200, 40),
		rgb(255, 140, 40),
		rgb(255, 230, 170),
		{ { "scaffold", 3, 4 }, { "crate", 4, 5 }, { "pillar", 2, 3 } }
	),
	theme(
		"Archive",
		rgb(150, 160, 176),
		Enum.Material.Fabric,
		rgb(180, 190, 206),
		rgb(120, 170, 255),
		rgb(200, 210, 230),
		rgb(210, 225, 255),
		{ { "cabinets", 6, 8 }, { "shelf", 2, 3 } }
	),
	theme(
		"Penthouse",
		rgb(40, 34, 48),
		Enum.Material.Marble,
		rgb(60, 50, 76),
		rgb(255, 200, 80),
		rgb(160, 90, 255),
		rgb(255, 210, 150),
		{ { "sofa", 3, 4 }, { "piano", 1, 1 }, { "counter", 1, 2 }, { "plant", 3, 4 } }
	),
	theme(
		"Machine Room",
		rgb(56, 58, 66),
		Enum.Material.DiamondPlate,
		rgb(70, 72, 80),
		rgb(255, 50, 50),
		rgb(255, 200, 40),
		rgb(255, 120, 100),
		{ { "machine", 3, 4 }, { "crate", 3, 4 } }
	),
}

function Themes.forFloor(i: number): Theme
	return Themes.LIST[(i % #Themes.LIST) + 1]
end

return Themes
