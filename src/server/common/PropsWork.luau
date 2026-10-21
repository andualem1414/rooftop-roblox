--!strict
-- Furniture for the floors where things are kept, run and built: the car park, the warehouse, the server
-- room, the boiler room, the lab, the building site, the archive and the machine room.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

type Prop = Kit.Prop
type Builder = Kit.Builder

local rgb = Kit.rgb
local M = Enum.Material
local C = Pieces.C
local lighter, darker = Pieces.lighter, Pieces.darker
local CEIL = Config.FLOOR_HEIGHT - Config.SLAB
local Q = math.pi / 2
local ALONG_Z = CFrame.Angles(0, Q, 0) -- a cylinder lying along z

local PROPS: { [string]: Prop } = {}

-- a wooden pallet (its deck's top at 0.6)
local function pallet(k: Builder, x: number, z: number, w: number, d: number)
	local wood = rgb(176, 136, 92)
	k.box(x, 0.52, z, w, 0.16, d, wood, M.WoodPlanks, true)
	for _, sz in { -1, 0, 1 } do
		k.box(x, 0.22, z + sz * (d / 2 - 0.3), w, 0.44, 0.55, darker(wood, 0.15), M.Wood, true)
	end
end

-- a cardboard box with a tape line
local function carton(
	k: Builder,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	solid: Kit.Solid?
)
	local brown = rgb(196, 156, 108)
	k.box(x, y + sy / 2, z, sx, sy, sz, brown, M.Cardboard, solid)
	k.box(x, y + sy + 0.01, z, sx + 0.02, 0.03, 0.35, rgb(220, 196, 150))
end

-- a striped hazard band
local HAZARD = rgb(250, 200, 40)

---------------------------------------------------------------- the car park

PROPS.car = {
	w = 7,
	d = 13.6,
	h = 4.6,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		local paint = Kit.pick(rng, {
			rgb(196, 44, 52),
			rgb(40, 110, 200),
			rgb(240, 196, 60),
			rgb(60, 170, 120),
			rgb(236, 236, 236),
			rgb(30, 30, 36),
			rgb(140, 146, 156),
			rgb(250, 120, 40),
		})
		local glass = rgb(30, 40, 58)
		local trim = rgb(30, 30, 34)
		k.box(0, 1.75, 0, 6.6, 1.7, 11.4, paint, M.SmoothPlastic, true).Reflectance = 0.1
		for _, s in { -1, 1 } do
			k.box(0, 1.2, s * 5.95, 6.4, 0.6, 0.7, trim)
			k.box(0, 0.95, s * 5.4, 6.0, 0.15, 1.2, trim)
			k.box(0, 1.25, s * 6.32, 1.6, 0.45, 0.06, rgb(240, 236, 220))
		end
		k.box(0, 2.05, -5.72, 2.8, 0.6, 0.06, trim)
		for _, sx in { -2.4, 2.4 } do
			k.box(sx, 2.15, -5.72, 1.2, 0.45, 0.08, rgb(255, 250, 225), M.Neon)
			k.box(sx, 2.15, 5.72, 1.3, 0.4, 0.08, rgb(255, 40, 50), M.Neon)
		end
		-- the hood, the glass and the roof
		k.wedge(CFrame.new(0, 2.75, -3.95), Vector3.new(6.4, 0.3, 3.5), paint, M.SmoothPlastic).Reflectance = 0.1
		k.wedge(CFrame.new(0, 3.45, -1.1), Vector3.new(6.0, 1.7, 2.2), glass, M.Glass, "cover")
		k.box(0, 3.4, 1.8, 5.9, 1.55, 3.6, glass, M.Glass, "cover")
		k.box(0, 4.3, 1.8, 6.0, 0.25, 3.6, paint, M.SmoothPlastic)
		k.box(0, 3.4, 1.7, 6.0, 1.6, 0.25, paint, M.SmoothPlastic)
		k.wedge(
			CFrame.new(0, 3.45, 4.5) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(6.0, 1.7, 1.8),
			glass,
			M.Glass,
			"cover"
		)
		-- wheels, mirrors, door seams
		for _, sx in { -1, 1 } do
			for _, sz in { -3.9, 3.9 } do
				k.wheel(sx * 3.0, 1.15, sz, 2.3, 0.9, trim, M.Rubber)
				k.wheel(sx * 3.46, 1.15, sz, 1.3, 0.06, C.CHROME, M.Metal)
			end
			k.box(sx * 3.32, 3.0, -1.7, 0.5, 0.35, 0.3, paint)
			k.box(sx * 3.31, 1.8, 0.5, 0.04, 1.5, 0.06, darker(paint, 0.4))
			k.box(sx * 3.32, 2.2, -0.4, 0.06, 0.12, 0.5, C.CHROME, M.Metal)
		end
	end,
}

-- a concrete column with a striped foot and a P
PROPS.hazardpillar = {
	w = 3.4,
	d = 3.4,
	h = CEIL,
	kind = "high",
	wall = false,
	build = function(k)
		k.box(0, CEIL / 2, 0, 3, CEIL, 3, rgb(176, 172, 164), M.Concrete, true)
		for i = 0, 3 do
			k.box(0, 0.25 + i * 0.5, 0, 3.08, 0.5, 3.08, if i % 2 == 0 then HAZARD else C.BLACK)
		end
		for _, yaw in { 0, math.pi } do
			local f = k.sub(0, 0, yaw)
			Pieces.sign(
				Kit.on(k.model, f.cf * CFrame.new(0, 0, -1.5)),
				0,
				5.6,
				1.6,
				1.6,
				"P",
				rgb(30, 90, 190),
				C.WHITE
			)
		end
	end,
}

PROPS.paystation = {
	w = 2.8,
	d = 2.4,
	h = 6,
	kind = "high",
	wall = false,
	build = function(k, th)
		k.box(0, 0.3, 0, 2.4, 0.6, 2, C.DARK, M.Metal, true)
		k.box(0, 3, 0, 2.2, 5, 1.8, th.accent, M.Metal, true)
		k.box(0, 5.7, 0, 2.6, 0.4, 2.2, C.DARK, M.Metal)
		Pieces.sign(Kit.on(k.model, k.cf * CFrame.new(0, 0, -0.9)), 0, 4.6, 1.8, 0.8, "PAY HERE", C.DARK, C.WHITE, 1.2)
		local screen = k.box(0, 3.5, -0.92, 1.2, 0.9, 0.06, C.BLACK)
		Kit.screen(Kit.gui(screen, Enum.NormalId.Front, 40, 1.2), Random.new(), "chart", th.accent)
		k.box(-0.5, 2.6, -0.94, 0.5, 0.12, 0.06, C.BLACK)
		k.box(0.5, 2.6, -0.94, 0.2, 0.3, 0.06, C.BLACK)
		k.box(0, 1.6, -0.94, 1.2, 0.4, 0.08, C.BLACK)
	end,
}

-- a barrier arm at the car park's way out
PROPS.boomgate = {
	w = 11,
	d = 2,
	h = 4.2,
	kind = "low",
	wall = false,
	build = function(k)
		k.box(-4.6, 1.8, 0, 1.4, 3.6, 1.4, HAZARD, M.Metal, true)
		k.box(-4.6, 3.7, 0, 1.6, 0.2, 1.6, C.BLACK, M.Metal)
		k.box(-4.6, 2.8, -0.72, 0.6, 0.6, 0.06, rgb(255, 60, 50), M.Neon)
		for i = 0, 7 do
			k.box(-3.4 + i * 1.1, 3.1, 0, 1.1, 0.3, 0.3, if i % 2 == 0 then rgb(220, 40, 40) else C.WHITE)
		end
		k.post(5.1, 0, 0, 2.9, 0.3, C.BLACK, M.Metal, true)
		k.box(5.1, 2.95, 0, 0.6, 0.15, 0.5, C.BLACK, M.Metal)
	end,
}

PROPS.cones = {
	w = 4,
	d = 4,
	h = 1.9,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		for _ = 1, 3 do
			local x, z = rng:NextNumber(-1.3, 1.3), rng:NextNumber(-1.3, 1.3)
			k.box(x, 0.06, z, 1, 0.12, 1, rgb(250, 110, 30), M.Rubber)
			k.post(x, z, 0.12, 0.7, 0.75, rgb(250, 110, 30), M.Rubber)
			k.post(x, z, 0.7, 1.1, 0.55, C.WHITE, M.Rubber)
			k.post(x, z, 1.1, 1.75, 0.38, rgb(250, 110, 30), M.Rubber)
		end
	end,
}

---------------------------------------------------------------- the warehouse

-- two bays of pallet racking, three levels of loads
PROPS.palletrack = {
	w = 12,
	d = 4,
	h = 8.4,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local upright = th.accent2
		local beam = th.accent
		for _, x in { -5.85, 0, 5.85 } do
			for _, z in { -1.75, 1.75 } do
				k.box(x, 4.2, z, 0.3, 8.4, 0.3, upright, M.Metal, true)
			end
			k.rod(Vector3.new(x, 0.5, -1.6), Vector3.new(x, 8.0, 1.6), 0.12, upright, M.Metal)
		end
		for _, y in { 2.77, 5.72 } do
			for _, z in { -1.8, 1.8 } do
				k.box(0, y, z, 12, 0.35, 0.16, beam, M.Metal)
			end
		end
		for _, bx in { -2.92, 2.92 } do
			for level, y in { 0, 2.95, 5.9 } do
				local base = k.lift(y)
				pallet(base, bx, 0, 5, 3.4)
				local solid: Kit.Solid = if level == 1 then true else "cover"
				local load = rng:NextInteger(1, 4)
				local top = if level == 3 then 1.8 else 2.1
				if load == 1 then
					carton(base, bx - 1.2, 0.6, 0, 2.4, top * 0.55, 3.2, solid)
					carton(base, bx + 1.2, 0.6, 0, 2.4, top * 0.7, 3.2, solid)
					carton(base, bx - 1.2, 0.6 + top * 0.55, 0.2, 2.2, top * 0.4, 2.6)
				elseif load == 2 then
					local wrap = base.box(bx, 0.6 + top / 2, 0, 4.6, top, 3.2, rgb(230, 236, 240), M.Glass, solid)
					wrap.Transparency = 0.25
				elseif load == 3 then
					for _, dx in { -1.3, 0, 1.3 } do
						for _, dz in { -0.8, 0.8 } do
							base.post(
								bx + dx,
								dz,
								0.6,
								0.6 + top * 0.9,
								1.2,
								Kit.pick(rng, { rgb(40, 90, 180), rgb(200, 50, 40), rgb(60, 140, 70) }),
								M.Metal,
								if dx == 0 and dz < 0 then solid else nil
							)
						end
					end
				else
					base.box(bx, 0.6 + top * 0.35, 0, 4.6, top * 0.7, 3.2, rgb(214, 200, 170), M.Fabric, solid)
					base.blob(bx, 0.6 + top * 0.7, 0, 4.4, 0.6, 3.0, rgb(214, 200, 170), M.Fabric)
				end
			end
			-- a bay label on the front beam
			Pieces.sign(
				Kit.on(k.model, k.cf * CFrame.new(bx, 0, -1.9)),
				0,
				2.77,
				1.1,
				0.32,
				string.format("%s-%02d", string.char(64 + rng:NextInteger(1, 8)), rng:NextInteger(1, 40)),
				C.WHITE,
				C.BLACK
			)
		end
	end,
}

PROPS.forklift = {
	w = 4.6,
	d = 9.2,
	h = 7.2,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local body = th.accent
		local dark = rgb(44, 46, 54)
		k.box(0, 1.7, 0.9, 3.8, 1.8, 5, body, M.Metal, true)
		k.box(0, 2.1, 3.1, 3.8, 2.6, 1.2, dark, M.Metal, true)
		k.part(CFrame.new(0, 3.4, 3.1), Vector3.new(3.8, 1.2, 1.2), dark, M.Metal, false, Enum.PartType.Cylinder)
		for _, sx in { -1, 1 } do
			k.wheel(sx * 1.75, 1.0, -0.9, 2.0, 0.8, C.BLACK, M.Rubber)
			k.wheel(sx * 1.75, 0.75, 2.6, 1.5, 0.7, C.BLACK, M.Rubber)
			k.wheel(sx * 2.16, 1.0, -0.9, 1.1, 0.04, C.STEEL, M.Metal)
		end
		k.box(0, 2.85, 1.5, 1.6, 0.4, 1.4, C.BLACK, M.Leather)
		k.box(0, 3.6, 2.2, 1.6, 1.4, 0.3, C.BLACK, M.Leather)
		k.rod(Vector3.new(0, 2.6, -0.4), Vector3.new(0, 3.7, 0.2), 0.15, C.BLACK)
		k.part(
			CFrame.new(0, 3.75, 0.25) * CFrame.Angles(math.rad(-30), 0, 0) * Kit.UP,
			Vector3.new(0.1, 1.0, 1.0),
			C.BLACK,
			M.Rubber,
			false,
			Enum.PartType.Cylinder
		)
		for _, at in { { -1.7, -0.6 }, { 1.7, -0.6 }, { -1.7, 2.5 }, { 1.7, 2.5 } } do
			k.post(at[1], at[2], 2.6, 6.4, 0.2, C.BLACK, M.Metal)
		end
		k.box(0, 6.45, 0.95, 3.7, 0.12, 3.4, dark, M.DiamondPlate)
		k.ball(1.4, 6.7, 2.2, 0.45, rgb(255, 150, 30), M.Neon)
		-- the mast and the forks
		for _, sx in { -1, 1 } do
			k.box(sx * 1.0, 3.5, -1.95, 0.35, 7, 0.35, dark, M.Metal)
			k.box(sx * 0.75, 0.3, -3.9, 0.45, 0.15, 3.6, dark, M.Metal)
			k.box(sx * 0.75, 0.9, -2.2, 0.45, 1.4, 0.15, dark, M.Metal)
		end
		k.box(0, 6.9, -1.95, 2.4, 0.3, 0.35, dark, M.Metal)
		k.box(0, 1.4, -2.15, 2.6, 1.4, 0.2, dark, M.Metal)
		k.post(0, -1.95, 0.5, 5.5, 0.3, C.CHROME, M.Metal)
		for _, sx in { -0.8, 0.8 } do
			k.box(sx, 6.6, -2.2, 0.5, 0.35, 0.1, rgb(255, 250, 225), M.Neon)
		end
		if rng:NextNumber() < 0.5 then
			pallet(k.lift(0.05), 0, -4.0, 3.4, 3.4)
			carton(k, -0.6, 0.65, -4.0, 1.6, 1.4, 2.8)
			carton(k, 0.9, 0.65, -4.0, 1.3, 1.1, 2.6)
		end
	end,
}

PROPS.pallet = {
	w = 4.4,
	d = 4.4,
	h = 3.6,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		pallet(k, 0, 0, 3.8, 3.8)
		if rng:NextNumber() < 0.6 then
			carton(k, -0.9, 0.6, -0.9, 1.8, 1.4, 1.8, true)
			carton(k, 0.9, 0.6, -0.9, 1.7, 1.2, 1.8, true)
			carton(k, 0, 0.6, 0.9, 3.4, 1.6, 1.8, true)
			if rng:NextNumber() < 0.6 then
				carton(k, -0.6, 2.2, 0.9, 1.6, 0.9, 1.4)
			end
		else
			for i = 0, 2 do
				k.blob(0, 0.95 + i * 0.6, 0, 3.4 - i * 0.3, 0.75, 3.4 - i * 0.4, rgb(220, 206, 176), M.Fabric, i == 0)
			end
		end
	end,
}

PROPS.palletjack = {
	w = 2.6,
	d = 5.6,
	h = 4,
	kind = "low",
	wall = false,
	build = function(k, th)
		for _, sx in { -0.7, 0.7 } do
			k.box(sx, 0.3, -0.8, 0.6, 0.3, 4, th.accent, M.Metal)
		end
		k.box(0, 0.7, 1.7, 2, 1.0, 0.9, th.accent, M.Metal, true)
		k.wheel(0, 0.4, 2.0, 0.8, 0.6, C.BLACK, M.Rubber)
		k.rod(Vector3.new(0, 1.2, 1.9), Vector3.new(0, 3.7, 2.5), 0.2, C.BLACK, M.Metal)
		k.rod(Vector3.new(-0.5, 3.75, 2.5), Vector3.new(0.5, 3.75, 2.5), 0.22, C.BLACK, M.Rubber)
	end,
}

---------------------------------------------------------------- the server room

-- three racks side by side, lit fronts, end panels and a cable tray on top
PROPS.rackrow = {
	w = 14.4,
	d = 4.6,
	h = 8.8,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		for _, x in { -4.6, 0, 4.6 } do
			k.box(x, 4, 0, 4.5, 8, 4, rgb(20, 22, 28), M.Metal, true)
			local door = k.box(x, 4, -2.02, 4.1, 7.6, 0.08, rgb(30, 32, 40), M.Metal)
			Kit.screen(Kit.gui(door, Enum.NormalId.Front, 20, 1.2), rng, "server", th.accent)
			k.box(x + 1.85, 4, -2.1, 0.12, 1.2, 0.1, C.CHROME, M.Metal)
		end
		for _, sx in { -7.0, 7.0 } do
			k.box(sx, 4.1, 0, 0.25, 8.2, 4.2, th.accent2, M.Metal)
		end
		for _, z in { -0.9, 0.9 } do
			k.box(0, 8.12, z, 14, 0.15, 0.15, C.STEEL, M.Metal)
		end
		for i = -3, 3 do
			k.box(i * 2, 8.08, 0, 0.12, 0.08, 1.9, C.STEEL, M.Metal)
		end
		k.rod(Vector3.new(-7, 8.28, -0.4), Vector3.new(7, 8.28, -0.4), 0.3, rgb(240, 200, 50))
		k.rod(Vector3.new(-7, 8.28, 0.3), Vector3.new(7, 8.28, 0.3), 0.3, rgb(60, 120, 230))
	end,
}

-- a cooling unit against the wall
PROPS.crac = {
	w = 7.2,
	d = 3.6,
	h = 7.4,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local grey = rgb(206, 210, 216)
		k.box(0, 3.6, 0, 7, 7.2, 3.4, grey, M.Metal, true)
		local vents = k.box(0, 2.9, -1.72, 6.4, 4.8, 0.06, darker(grey, 0.1), M.Metal)
		local art = Kit.gui(vents, Enum.NormalId.Front, 20)
		for i = 0, 15 do
			Kit.rect(art, 0.03, 0.04 + i * 0.06, 0.94, 0.025, darker(grey, 0.45))
		end
		local screen = k.box(-2, 6.3, -1.73, 1.6, 0.9, 0.06, C.BLACK)
		Kit.screen(Kit.gui(screen, Enum.NormalId.Front, 40, 1.3), rng, "graph", th.accent)
		k.box(1.4, 6.3, -1.74, 3, 0.12, 0.06, th.accent, M.Neon)
	end,
}

PROPS.ups = {
	w = 6.6,
	d = 3,
	h = 5.6,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		for i, x in { -2.2, 0, 2.2 } do
			k.box(x, 2.75, 0, 2.1, 5.5, 2.8, rgb(54, 58, 68), M.Metal, true)
			k.box(
				x,
				4.6,
				-1.42,
				1.2,
				0.5,
				0.06,
				if i == 2 and rng:NextNumber() < 0.5 then rgb(255, 170, 40) else th.accent,
				M.Neon
			)
			k.box(x, 1.8, -1.42, 1.6, 2.4, 0.04, rgb(40, 42, 50))
		end
	end,
}

PROPS.firetanks = {
	w = 4.6,
	d = 2.2,
	h = 6.2,
	kind = "high",
	wall = true,
	build = function(k)
		local red = rgb(200, 36, 40)
		for _, x in { -1.4, 0, 1.4 } do
			k.post(x, 0, 0, 4.8, 1.2, red, M.Metal, true)
			k.ball(x, 4.8, 0, 1.2, red, M.Metal)
			k.box(x, 5.55, 0, 0.4, 0.4, 0.4, C.BLACK, M.Metal)
		end
		k.rod(Vector3.new(-2, 5.85, 0), Vector3.new(2, 5.85, 0), 0.25, C.STEEL, M.Metal)
		k.box(0, 3.4, -0.62, 4.2, 0.25, 0.1, C.BLACK, M.Metal)
		Pieces.sign(Kit.on(k.model, k.cf * CFrame.new(0, 0, -0.65)), 0, 2.2, 2.6, 0.9, "FIRE SUPPRESSION", red, C.WHITE)
	end,
}

-- the operators' desk: three screens, a keyboard, a chair
PROPS.nocdesk = {
	w = 10,
	d = 5.4,
	h = 5.6,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local dark = rgb(40, 42, 50)
		k.box(0, 2.5, 0.4, 6, 0.2, 2.8, dark, M.SmoothPlastic, true)
		for _, s in { -1, 1 } do
			k.part(
				CFrame.new(s * 3.9, 2.5, 0.0) * CFrame.Angles(0, s * math.rad(-25), 0),
				Vector3.new(2.4, 0.2, 2.8),
				dark,
				M.SmoothPlastic,
				true
			)
		end
		k.box(0, 1.2, 1.6, 8, 2.4, 0.2, rgb(30, 32, 38), M.SmoothPlastic, true)
		Pieces.monitor(k, 0, 2.6, 1.0, 0, 2.6, rng, "graph", th.accent)
		Pieces.monitor(k, -3.0, 2.6, 0.8, math.rad(25), 2.4, rng, "server", th.accent)
		Pieces.monitor(k, 3.0, 2.6, 0.8, math.rad(-25), 2.4, rng, "chart", th.accent2)
		k.box(0, 2.64, -0.4, 1.8, 0.08, 0.55, C.BLACK)
		Pieces.mug(k, 1.6, 2.6, -0.3, th.accent)
		Pieces.officeChair(k, 0, -1.9, math.pi, rgb(40, 44, 56))
	end,
}

---------------------------------------------------------------- the boiler room

PROPS.boiler = {
	w = 6.4,
	d = 12,
	h = CEIL,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local paint = Kit.pick(rng, { rgb(70, 100, 80), rgb(160, 60, 44), rgb(60, 70, 96) })
		local band = darker(paint, 0.35)
		for _, z in { -3, 3 } do
			k.box(0, 0.7, z, 5, 1.4, 1.2, rgb(50, 48, 50), M.Metal, true)
		end
		k.part(CFrame.new(0, 3.7, 0) * ALONG_Z, Vector3.new(9.6, 5, 5), paint, M.Metal, true, Enum.PartType.Cylinder)
		for _, z in { -3.6, -1.2, 1.2, 3.6 } do
			k.part(
				CFrame.new(0, 3.7, z) * ALONG_Z,
				Vector3.new(0.3, 5.25, 5.25),
				band,
				M.Metal,
				false,
				Enum.PartType.Cylinder
			)
		end
		k.face(0, 3.7, -4.9, 4.6, 0.3, band, M.Metal)
		k.face(0, 3.1, -5.08, 1.3, 0.08, rgb(255, 120, 30), M.Neon)
		k.face(0, 3.1, -5.06, 1.6, 0.06, C.BLACK, M.Metal)
		k.box(1.6, 3.7, -5.12, 0.8, 0.25, 0.2, C.STEEL, M.Metal)
		k.face(0, 3.7, 4.9, 4.6, 0.3, band, M.Metal)
		-- gauges, the flue, a valve
		for _, gx in { -1.2, 1.2 } do
			k.post(gx, -2, 6.0, 6.6, 0.15, C.STEEL, M.Metal)
			k.face(gx, 6.95, -2, 0.75, 0.15, C.BLACK, M.Metal)
			k.face(gx, 6.95, -2.09, 0.6, 0.04, C.WHITE)
		end
		k.post(0, 3.4, 5.9, CEIL, 1.4, rgb(60, 58, 60), M.Metal)
		k.disc(0, 6.3, 3.4, 1.8, 0.3, rgb(60, 58, 60), M.Metal)
		k.post(-1.6, 0.6, 5.9, CEIL, 0.6, th.accent2, M.Metal)
		k.disc(-1.6, 7.0, 0.6, 1.3, 0.12, rgb(200, 40, 40), M.Metal)
		local steam = Instance.new("ParticleEmitter")
		steam.Rate = 4
		steam.Lifetime = NumberRange.new(1.4, 2.2)
		steam.Speed = NumberRange.new(1.5, 3)
		steam.SpreadAngle = Vector2.new(20, 20)
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2) })
		steam.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		steam.Color = ColorSequence.new(rgb(230, 230, 236))
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = k.box(-1.6, 7.3, 0.6, 0.4, 0.2, 0.4, rgb(60, 58, 60), M.Metal)
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(2.55, 0, 0) * CFrame.Angles(0, -Q, 0)),
			0,
			3.6,
			1.8,
			1.0,
			"HOT",
			HAZARD,
			C.BLACK
		)
	end,
}

-- a tall tank with a domed top and a ladder
PROPS.vtank = {
	w = 5.2,
	d = 5.2,
	h = 8.6,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local paint = Kit.pick(rng, { rgb(170, 176, 186), rgb(60, 90, 140), rgb(150, 70, 50) })
		for _, sx in { -1.4, 1.4 } do
			for _, sz in { -1.4, 1.4 } do
				k.post(sx, sz, 0, 1.2, 0.45, C.DARK, M.Metal, true)
			end
		end
		k.post(0, 0, 1.1, 6.4, 4.4, paint, M.Metal, true)
		k.ball(0, 6.4, 0, 4.4, paint, M.Metal)
		for _, y in { 2.4, 5.2 } do
			k.disc(0, y, 0, 4.55, 0.25, darker(paint, 0.3), M.Metal)
		end
		for _, sz in { -0.45, 0.45 } do
			k.box(2.45, 4.4, sz, 0.12, 7, 0.12, C.STEEL, M.Metal)
		end
		for i = 0, 5 do
			k.rod(
				Vector3.new(2.45, 1.4 + i * 1.15, -0.45),
				Vector3.new(2.45, 1.4 + i * 1.15, 0.45),
				0.1,
				C.STEEL,
				M.Metal
			)
		end
		k.post(-1.6, -1.4, 7.6, 8.4, 0.12, C.STEEL, M.Metal)
		k.face(-1.6, 7.8, -1.6, 0.6, 0.12, C.WHITE)
		k.rod(Vector3.new(0, 1.5, -2.2), Vector3.new(0, 1.5, -2.8), 0.5, th.accent2, M.Metal)
		k.rod(Vector3.new(0, 1.5, -2.8), Vector3.new(0, 0, -2.8), 0.5, th.accent2, M.Metal)
	end,
}

PROPS.pump = {
	w = 4.4,
	d = 6.6,
	h = 4.2,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local motor = Kit.pick(rng, { rgb(40, 90, 150), rgb(50, 120, 80), rgb(80, 84, 92) })
		k.box(0, 0.25, 0, 3.6, 0.5, 6.2, C.DARK, M.Metal, true)
		k.part(
			CFrame.new(0, 1.8, 1.3) * ALONG_Z,
			Vector3.new(3, 2.4, 2.4),
			motor,
			M.Metal,
			true,
			Enum.PartType.Cylinder
		)
		for _, z in { 0.5, 1.3, 2.1 } do
			k.part(
				CFrame.new(0, 1.8, z) * ALONG_Z,
				Vector3.new(0.15, 2.65, 2.65),
				darker(motor, 0.2),
				M.Metal,
				false,
				Enum.PartType.Cylinder
			)
		end
		k.face(0, 1.8, 2.85, 2.2, 0.15, C.DARK, M.Metal)
		k.box(0, 1.6, -0.7, 1.6, 1.4, 1.2, HAZARD, M.Metal)
		k.face(0, 1.7, -2.0, 2.6, 1.0, rgb(180, 50, 40), M.Metal)
		k.rod(Vector3.new(0, 1.7, -2.5), Vector3.new(0, 1.7, -3.2), 0.7, th.accent2, M.Metal)
		k.face(0, 1.7, -3.1, 1.1, 0.12, C.STEEL, M.Metal)
		k.rod(Vector3.new(0, 2.9, -2.0), Vector3.new(0, 4.2, -2.0), 0.6, th.accent2, M.Metal)
		k.disc(0, 3.6, -2.0, 1.1, 0.12, rgb(200, 40, 40), M.Metal)
	end,
}

PROPS.drums = {
	w = 4.6,
	d = 4.6,
	h = 3.4,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		for i, at in { { -1.0, -0.9 }, { 1.1, -0.7 }, { 0, 1.1 } } do
			local c = Kit.pick(rng, { rgb(40, 80, 170), rgb(190, 40, 40), rgb(230, 180, 40), rgb(50, 130, 70) })
			k.post(at[1], at[2], 0, 3.0, 2.0, c, M.Metal, if i == 3 then "cover" else true)
			for _, y in { 1.0, 2.0 } do
				k.disc(at[1], y, at[2], 2.1, 0.1, darker(c, 0.25), M.Metal)
			end
			k.disc(at[1], 3.02, at[2], 1.8, 0.05, darker(c, 0.15), M.Metal)
			k.disc(at[1] + 0.5, 3.06, at[2] + 0.3, 0.3, 0.06, C.DARK, M.Metal)
		end
	end,
}

PROPS.workbench = {
	w = 9,
	d = 3.6,
	h = 7.2,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		local wood = rgb(150, 110, 70)
		k.box(0, 2.9, -0.2, 8.6, 0.3, 3, wood, M.Wood, true)
		for _, sx in { -4, 4 } do
			for _, sz in { -1.4, 1.0 } do
				k.box(sx, 1.4, sz, 0.3, 2.8, 0.3, rgb(70, 74, 84), M.Metal, true)
			end
		end
		k.box(0, 0.8, -0.2, 8, 0.15, 2.6, rgb(70, 74, 84), M.Metal)
		carton(k, -2.5, 0.88, -0.2, 2, 1.0, 1.8)
		k.post(1.5, -0.2, 0.88, 2.0, 1.2, th.accent2, M.Metal)
		local board = k.box(0, 5.1, 1.5, 8, 3.6, 0.15, rgb(170, 130, 90), M.Cardboard)
		local art = Kit.gui(board, Enum.NormalId.Front, 20)
		local tool = rgb(50, 52, 60)
		Kit.rect(art, 0.06, 0.15, 0.04, 0.6, tool)
		Kit.rect(art, 0.03, 0.12, 0.1, 0.1, tool, 0.5)
		Kit.rect(art, 0.16, 0.2, 0.03, 0.55, rgb(160, 110, 60))
		Kit.rect(art, 0.12, 0.15, 0.11, 0.1, tool)
		Kit.rect(art, 0.28, 0.12, 0.2, 0.42, rgb(180, 184, 190))
		Kit.rect(art, 0.28, 0.5, 0.06, 0.2, rgb(160, 40, 40))
		for i = 0, 4 do
			Kit.rect(
				art,
				0.56 + i * 0.07,
				0.15,
				0.025,
				0.4 + (i % 2) * 0.1,
				Kit.pick(rng, { rgb(200, 50, 40), rgb(240, 190, 40), rgb(50, 90, 180) })
			)
		end
		Kit.rect(art, 0.56, 0.7, 0.35, 0.05, tool)
		k.box(3.4, 3.35, -1.0, 0.8, 0.6, 0.9, rgb(60, 64, 74), M.Metal)
		k.box(3.4, 3.35, -1.5, 0.9, 0.5, 0.15, rgb(60, 64, 74), M.Metal)
		k.box(-2, 3.5, -0.4, 2, 0.9, 1, rgb(200, 40, 40), M.Metal)
		k.box(-2, 4.05, -0.4, 1.2, 0.15, 0.15, C.BLACK, M.Metal)
	end,
}

-- the boiler's control panel: dials, switches and lights
PROPS.gauges = {
	w = 7,
	d = 2.2,
	h = 7,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local body = rgb(90, 110, 100)
		local panel = k.box(0, 3.5, 0, 7, 7, 2, body, M.Metal, true)
		local art = Kit.gui(panel, Enum.NormalId.Front, 24)
		Kit.rect(art, 0.05, 0.04, 0.9, 0.1, rgb(30, 32, 36))
		Kit.text(art, "BOILER CONTROL", 0.08, 0.05, 0.84, 0.08, HAZARD, Enum.Font.GothamBlack)
		for i = 0, 3 do
			local cx = 0.08 + i * 0.22
			Kit.rect(art, cx, 0.2, 0.18, 0.18, C.BLACK, 1)
			Kit.rect(art, cx + 0.015, 0.215, 0.15, 0.15, C.WHITE, 1)
			local needle = Kit.rect(art, cx + 0.04, 0.287, 0.1, 0.008, rgb(220, 30, 30))
			needle.Rotation = rng:NextNumber(-60, 60)
		end
		for i = 0, 5 do
			Kit.rect(art, 0.1 + i * 0.14, 0.55, 0.06, 0.1, C.BLACK)
			Kit.rect(art, 0.11 + i * 0.14, if rng:NextNumber() < 0.5 then 0.55 else 0.6, 0.04, 0.05, C.STEEL)
		end
		for i = 0, 2 do
			k.face(
				-1.5 + i * 1.5,
				1.8,
				-1.02,
				0.5,
				0.12,
				Kit.pick(rng, { rgb(255, 60, 50), rgb(60, 255, 100), th.accent }),
				M.Neon
			)
		end
	end,
}

---------------------------------------------------------------- the building site

PROPS.scaffold = {
	w = 9.6,
	d = 4.4,
	h = 8.6,
	kind = "high",
	wall = false,
	build = function(k, th)
		local tube = rgb(170, 176, 186)
		for _, x in { -4.3, 0, 4.3 } do
			for _, z in { -1.8, 1.8 } do
				k.post(x, z, 0, 8.6, 0.25, tube, M.Metal, true)
			end
			k.rod(Vector3.new(x, 4.0, -1.8), Vector3.new(x, 4.0, 1.8), 0.22, tube, M.Metal)
		end
		for _, y in { 4.0, 8.2 } do
			for _, z in { -1.8, 1.8 } do
				k.rod(Vector3.new(-4.4, y, z), Vector3.new(4.4, y, z), 0.22, tube, M.Metal)
			end
		end
		k.rod(Vector3.new(-4.3, 0.3, -1.8), Vector3.new(0, 3.9, -1.8), 0.2, tube, M.Metal)
		k.rod(Vector3.new(0, 4.2, -1.8), Vector3.new(4.3, 8.1, -1.8), 0.2, tube, M.Metal)
		for _, z in { -1.2, 0, 1.2 } do
			k.box(0, 4.2, z, 9.2, 0.18, 1.1, C.OAK, M.WoodPlanks, true)
		end
		k.box(0, 4.6, -1.9, 9, 0.6, 0.12, th.accent, M.Wood)
		for _, z in { -0.5, 0.5 } do
			k.box(4.75, 2.6, z, 0.12, 5.2, 0.12, th.accent2, M.Metal)
		end
		for i = 0, 3 do
			k.rod(
				Vector3.new(4.75, 0.8 + i * 1.1, -0.5),
				Vector3.new(4.75, 0.8 + i * 1.1, 0.5),
				0.1,
				th.accent2,
				M.Metal
			)
		end
		for i = 0, 2 do
			k.blob(-2 + i * 0.4, 0.45 + i * 0.75, 0, 2.6, 0.8, 1.6, rgb(200, 196, 186), M.Fabric, i == 0)
		end
	end,
}

PROPS.mixer = {
	w = 4.8,
	d = 6.4,
	h = 5.6,
	kind = "high",
	wall = false,
	build = function(k, th)
		local frame = rgb(60, 64, 72)
		for _, sx in { -1.5, 1.5 } do
			k.rod(Vector3.new(sx, 0.13, -1.6), Vector3.new(sx * 0.6, 3.0, 0.2), 0.25, frame, M.Metal)
			k.rod(Vector3.new(sx, 1.2, 1.9), Vector3.new(sx * 0.6, 3.0, 0.2), 0.25, frame, M.Metal)
			k.wheel(sx * 1.7, 1.0, 1.9, 2.0, 0.6, C.BLACK, M.Rubber, true)
		end
		k.rod(Vector3.new(-1.9, 1.0, 1.9), Vector3.new(1.9, 1.0, 1.9), 0.2, frame, M.Metal)
		local drum = k.at(0, 3.4, -0.4) * CFrame.Angles(math.rad(-35), 0, 0)
		Kit.part(k.model, drum * Kit.UP, Vector3.new(2.8, 3.2, 3.2), th.accent2, M.Metal, true, Enum.PartType.Cylinder)
		Kit.part(
			k.model,
			drum * CFrame.new(0, -1.9, 0) * Kit.UP,
			Vector3.new(1.0, 2.6, 2.6),
			th.accent2,
			M.Metal,
			false,
			Enum.PartType.Cylinder
		)
		Kit.part(
			k.model,
			drum * CFrame.new(0, 2.0, 0),
			Vector3.new(2.4, 2.4, 2.4),
			th.accent2,
			M.Metal,
			false,
			Enum.PartType.Ball
		)
		Kit.part(
			k.model,
			drum * CFrame.new(0, -2.42, 0) * Kit.UP,
			Vector3.new(0.05, 2.0, 2.0),
			rgb(60, 56, 52),
			M.Concrete,
			false,
			Enum.PartType.Cylinder
		)
		k.box(0, 2.4, 2.3, 1.6, 1.3, 1.3, frame, M.Metal)
		k.wheel(1.8, 3.2, 0.8, 1.2, 0.1, rgb(200, 40, 40), M.Metal)
	end,
}

PROPS.bricks = {
	w = 4.4,
	d = 4.4,
	h = 3.4,
	kind = "low",
	wall = false,
	build = function(k)
		pallet(k, 0, 0, 3.8, 3.8)
		local brick = rgb(170, 84, 60)
		k.box(0, 1.75, 0, 3.6, 2.3, 3.6, brick, M.Brick, true)
		k.box(-0.9, 3.15, 0, 1.8, 0.5, 3.6, brick, M.Brick)
		for _, x in { -1.2, 1.2 } do
			k.box(x, 1.9, 0, 0.1, 2.6, 3.64, C.BLACK)
		end
	end,
}

PROPS.blocks = {
	w = 4.4,
	d = 4.4,
	h = 3,
	kind = "low",
	wall = false,
	build = function(k)
		pallet(k, 0, 0, 3.8, 3.8)
		local grey = rgb(150, 150, 146)
		for layer = 0, 1 do
			for _, x in { -0.9, 0.9 } do
				k.box(x, 1.05 + layer * 0.92, 0, 1.75, 0.9, 3.6, grey, M.Concrete, layer == 0)
			end
		end
		k.box(0.9, 2.9, 0.9, 1.75, 0.9, 1.75, grey, M.Concrete)
	end,
}

PROPS.ibeams = {
	w = 4.4,
	d = 12,
	h = 2.6,
	kind = "low",
	wall = false,
	build = function(k)
		local steel = rgb(160, 70, 54)
		for _, z in { -4, 4 } do
			k.box(0, 0.25, z, 4, 0.5, 0.6, rgb(150, 110, 70), M.Wood, true)
		end
		local function beam(x: number, y: number)
			k.box(x, y + 0.06, 0, 1.0, 0.12, 11, steel, M.CorrodedMetal, true)
			k.box(x, y + 0.5, 0, 0.14, 0.8, 11, steel, M.CorrodedMetal)
			k.box(x, y + 0.94, 0, 1.0, 0.12, 11, steel, M.CorrodedMetal)
		end
		beam(-1.2, 0.5)
		beam(0, 0.5)
		beam(1.2, 0.5)
		beam(-0.6, 1.5)
	end,
}

PROPS.rebar = {
	w = 3,
	d = 10.4,
	h = 1.6,
	kind = "low",
	wall = false,
	build = function(k)
		local rust = rgb(130, 76, 54)
		for _, z in { -3.5, 3.5 } do
			k.box(0, 0.2, z, 2.6, 0.4, 0.5, rgb(150, 110, 70), M.Wood, true)
		end
		for i, at in { { -0.6, 0 }, { -0.2, 0 }, { 0.2, 0 }, { 0.6, 0 }, { -0.4, 1 }, { 0, 1 }, { 0.4, 1 } } do
			local y = 0.55 + at[2] * 0.32
			k.rod(
				Vector3.new(at[1], y, -5.1 + i * 0.05),
				Vector3.new(at[1], y, 5.1 - i * 0.05),
				0.28,
				rust,
				M.CorrodedMetal
			)
		end
		for _, z in { -2, 2 } do
			k.part(
				CFrame.new(0, 0.7, z) * ALONG_Z,
				Vector3.new(0.08, 1.3, 1.3),
				C.DARK,
				M.Metal,
				false,
				Enum.PartType.Cylinder
			)
		end
	end,
}

PROPS.sandpile = {
	w = 7,
	d = 7,
	h = 2.4,
	kind = "low",
	wall = false,
	build = function(k)
		local sand = rgb(214, 186, 132)
		k.blob(0, 0, 0, 6.4, 2.0, 6.0, sand, M.Sand, true)
		k.blob(1.4, 0, 1.0, 3.6, 1.6, 3.2, darker(sand, 0.04), M.Sand)
		k.rod(Vector3.new(-0.8, 0.6, -0.4), Vector3.new(-1.6, 3.4, -1.2), 0.14, rgb(150, 110, 70), M.Wood)
		k.part(
			CFrame.new(-0.6, 0.6, -0.2) * CFrame.Angles(math.rad(25), 0, math.rad(-20)),
			Vector3.new(0.8, 1.0, 0.06),
			C.STEEL,
			M.Metal
		)
	end,
}

-- a work light on a tripod, lit
PROPS.worklight = {
	w = 3.4,
	d = 3.4,
	h = 7.6,
	kind = "low",
	wall = false,
	build = function(k, th)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			k.rod(
				Vector3.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4),
				Vector3.new(0, 3.2, 0),
				0.14,
				th.accent,
				M.Metal
			)
		end
		k.post(0, 0, 3.0, 6.6, 0.18, th.accent, M.Metal)
		k.rod(Vector3.new(-1.2, 6.6, 0), Vector3.new(1.2, 6.6, 0), 0.16, th.accent, M.Metal)
		for _, sx in { -0.9, 0.9 } do
			k.part(
				CFrame.new(sx, 7.0, -0.1) * CFrame.Angles(math.rad(-25), 0, 0),
				Vector3.new(1.3, 1.0, 0.5),
				C.DARK,
				M.Metal
			)
			k.part(
				CFrame.new(sx, 6.94, -0.38) * CFrame.Angles(math.rad(-25), 0, 0),
				Vector3.new(1.1, 0.8, 0.06),
				rgb(255, 246, 220),
				M.Neon
			)
		end
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 80
		spot.Range = 18
		spot.Brightness = 0.9
		spot.Color = rgb(255, 240, 210)
		spot.Shadows = false
		spot.Parent =
			k.part(CFrame.new(0, 6.9, -0.4) * CFrame.Angles(math.rad(-35), 0, 0), Vector3.new(0.2, 0.2, 0.2), C.DARK)
	end,
}

PROPS.barrier = {
	w = 6.4,
	d = 2.4,
	h = 3.6,
	kind = "low",
	wall = false,
	build = function(k)
		for _, sx in { -2.8, 2.8 } do
			k.rod(Vector3.new(sx, 0, -0.9), Vector3.new(sx, 3.4, 0), 0.18, C.STEEL, M.Metal)
			k.rod(Vector3.new(sx, 0, 0.9), Vector3.new(sx, 3.4, 0), 0.18, C.STEEL, M.Metal)
		end
		for _, y in { 1.6, 2.8 } do
			local board = k.box(0, y, -0.32 + (y - 1.6) * 0.22, 6, 0.6, 0.1, C.WHITE, M.Plastic, true)
			local art = Kit.gui(board, Enum.NormalId.Front, 16)
			for i = 0, 7 do
				local stripe = Kit.rect(art, i * 0.14 - 0.02, -0.6, 0.06, 2.2, rgb(220, 40, 40))
				stripe.Rotation = 35
			end
		end
	end,
}

-- a portable toilet: every building site has one
PROPS.porta = {
	w = 4,
	d = 4,
	h = 7.8,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		local body = Kit.pick(rng, { rgb(40, 100, 190), rgb(60, 150, 80), rgb(230, 130, 40) })
		k.box(0, 0.15, 0, 3.8, 0.3, 3.8, C.DARK, M.Plastic, true)
		k.box(0, 3.65, 0, 3.6, 7, 3.6, body, M.Plastic, true)
		k.box(0, 7.3, 0, 3.9, 0.4, 3.9, C.WHITE, M.Plastic)
		k.post(1.2, 1.2, 7.4, 8.2, 0.3, C.DARK, M.Plastic)
		k.box(0, 3.5, -1.82, 2.6, 6, 0.06, lighter(body, 0.1), M.Plastic)
		k.box(1.0, 3.5, -1.88, 0.18, 0.6, 0.12, C.STEEL, M.Metal)
		k.box(
			0,
			5.6,
			-1.88,
			1.0,
			0.25,
			0.06,
			if rng:NextNumber() < 0.5 then rgb(255, 60, 50) else rgb(60, 220, 90),
			M.Neon
		)
	end,
}

-- a stretch of new wall: studs, plates, a sheet of drywall
PROPS.framing = {
	w = 10.2,
	d = 1.2,
	h = CEIL,
	kind = "high",
	wall = false,
	build = function(k)
		local wood = rgb(200, 170, 120)
		k.box(0, 0.15, 0, 10, 0.3, 0.6, wood, M.Wood, true)
		k.box(0, CEIL - 0.15, 0, 10, 0.3, 0.6, wood, M.Wood)
		for i = 0, 7 do
			k.box(-4.85 + i * 1.385, CEIL / 2, 0, 0.3, CEIL - 0.6, 0.6, wood, M.Wood, true)
		end
		k.box(-2.4, CEIL / 2, -0.36, 4.6, CEIL - 0.6, 0.12, rgb(226, 224, 218), M.Plaster, true)
		k.box(-2.4, 4.5, -0.43, 4.6, 0.06, 0.02, rgb(200, 200, 196))
	end,
}

PROPS.toolchest = {
	w = 4,
	d = 2.6,
	h = 4.4,
	kind = "low",
	wall = true,
	build = function(k)
		local red = rgb(200, 36, 40)
		k.box(0, 2.1, 0, 3.6, 3.4, 2.2, red, M.Metal, true)
		k.box(0, 3.95, 0, 3.7, 0.3, 2.3, darker(red, 0.2), M.Metal)
		for i = 0, 3 do
			local y = 0.75 + i * 0.8
			k.box(0, y, -1.12, 3.4, 0.04, 0.04, C.BLACK)
			k.box(0, y + 0.45, -1.16, 2.4, 0.08, 0.08, C.CHROME, M.Metal)
		end
		for _, sx in { -1.5, 1.5 } do
			for _, sz in { -0.8, 0.8 } do
				k.ball(sx, 0.2, sz, 0.4, C.BLACK, M.Rubber)
			end
		end
	end,
}

---------------------------------------------------------------- the archive

-- steel shelving of archive boxes and binders, a crank wheel at its end
PROPS.archshelf = {
	w = 10.4,
	d = 3.8,
	h = 8,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local steel = rgb(196, 200, 208)
		for _, sx in { -5.05, 5.05 } do
			k.box(sx, 4, 0, 0.3, 8, 3.8, th.accent2, M.Metal, true)
		end
		k.box(0, 7.9, 0, 10.4, 0.2, 3.8, steel, M.Metal)
		k.face(5.35, 4.2, 0, 1.6, 0.12, C.DARK, M.Metal)
		k.wheel(5.32, 4.2, 0, 1.6, 0.12, C.DARK, M.Metal)
		k.ball(5.4, 4.8, 0.3, 0.3, C.DARK, M.Metal)
		local levels = { 0.3, 2.2, 4.1, 6.0 }
		for i, y in levels do
			k.box(0, y - 0.05, 0, 9.8, 0.1, 3.6, steel, M.Metal, i == 1)
			local x = -4.8
			while x < 4.6 do
				if rng:NextNumber() < 0.55 then
					local bw = 1.5
					local box = rgb(200, 170, 120):Lerp(rgb(170, 140, 100), rng:NextNumber())
					k.box(
						x + bw / 2,
						y + 0.6,
						0,
						bw - 0.08,
						1.2,
						3.2,
						box,
						M.Cardboard,
						if i == 1 then true else "cover"
					)
					k.box(x + bw / 2, y + 0.7, -1.62, 0.8, 0.4, 0.02, C.PAPER)
					x += bw
				else
					local bw = rng:NextNumber(1.0, 2.2)
					k.box(
						x + bw / 2,
						y + 0.75,
						0,
						bw - 0.06,
						1.5,
						3.0,
						Kit.pick(
							rng,
							{ rgb(40, 70, 140), rgb(150, 40, 40), rgb(40, 110, 70), rgb(30, 30, 34), rgb(220, 180, 60) }
						),
						M.SmoothPlastic,
						"cover"
					)
					x += bw
				end
				if rng:NextNumber() < 0.15 then
					x += rng:NextNumber(0.6, 1.4)
				end
			end
		end
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(-5.2, 0, 0) * CFrame.Angles(0, Q, 0)),
			0,
			7.0,
			1.6,
			0.9,
			string.char(64 + rng:NextInteger(1, 12)),
			C.WHITE,
			C.BLACK
		)
	end,
}

PROPS.mapcab = {
	w = 6.4,
	d = 4.4,
	h = 3.8,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		local body = Kit.pick(rng, { rgb(120, 140, 120), C.OAK, rgb(150, 156, 166) })
		k.box(0, 1.6, 0, 6, 3.2, 4, body, M.Metal, true)
		for i = 0, 4 do
			local y = 0.35 + i * 0.6
			k.box(0, y + 0.28, -2.01, 5.8, 0.03, 0.03, darker(body, 0.4))
			k.box(0, y, -2.04, 1.2, 0.12, 0.1, C.BRASS, M.Metal)
		end
		k.rod(Vector3.new(-2.5, 3.4, 0.6), Vector3.new(1.8, 3.4, 0.9), 0.4, C.PAPER)
		local map = k.part(
			CFrame.new(-0.6, 3.22, -0.6) * CFrame.Angles(0, 0.15, 0),
			Vector3.new(3, 0.03, 2.2),
			rgb(236, 226, 196)
		)
		local art = Kit.gui(map, Enum.NormalId.Top, 20)
		Kit.rect(art, 0.1, 0.15, 0.4, 0.5, rgb(170, 200, 160), 0.3)
		Kit.rect(art, 0.5, 0.4, 0.35, 0.45, rgb(190, 210, 170), 0.4)
		Kit.rect(art, 0.05, 0.62, 0.9, 0.02, rgb(80, 120, 180))
		k.disc(1.8, 3.24, -1, 0.9, 0.05, rgb(200, 230, 240), M.Glass)
		k.rod(Vector3.new(2.2, 3.25, -1.2), Vector3.new(2.9, 3.25, -1.6), 0.15, C.BLACK)
	end,
}

-- a desk with a microfiche reader
PROPS.readdesk = {
	w = 6.4,
	d = 5.4,
	h = 5,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		k.box(0, 2.5, 1.0, 6, 0.2, 3, C.OAK, M.Wood, true)
		for _, sx in { -2.8, 2.8 } do
			k.box(sx, 1.2, 1.0, 0.2, 2.4, 2.8, C.STEEL, M.Metal, true)
		end
		k.box(0, 3.1, 1.6, 2.4, 1.0, 1.8, rgb(220, 216, 200), M.Plastic)
		local screen = k.part(
			CFrame.new(0, 4.1, 1.5) * CFrame.Angles(math.rad(12), 0, 0),
			Vector3.new(2.2, 1.6, 0.3),
			rgb(220, 216, 200),
			M.Plastic
		)
		local art = Kit.gui(screen, Enum.NormalId.Front, 40, 1.3)
		Kit.rect(art, 0, 0, 1, 1, rgb(20, 24, 22))
		for i = 0, 7 do
			Kit.rect(art, 0.1, 0.1 + i * 0.1, rng:NextNumber(0.4, 0.8), 0.04, rgb(170, 255, 190))
		end
		Pieces.lamp(k, -2.3, 2.6, 1.6, C.BLACK)
		k.box(1.9, 2.66, 0.6, 1.2, 0.1, 1.5, C.PAPER)
		Pieces.officeChair(k, 0, -1.4, math.pi, th.accent2)
	end,
}

PROPS.bookcart = {
	w = 2.8,
	d = 5.2,
	h = 4.2,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		local frame = C.OAK
		for _, sz in { -2.4, 2.4 } do
			k.box(0, 2, sz, 2.4, 3.4, 0.2, frame, M.Wood, true)
		end
		for _, y in { 0.9, 2.6 } do
			k.box(0, y, 0, 2.2, 0.12, 4.6, frame, M.Wood)
			local row = Kit.on(k.model, k.cf * CFrame.new(0, y + 0.06, 0) * CFrame.Angles(0, Q, 0))
			Pieces.books(row, -2.2, 2.2, 0, 0, 1.8, 1.4, rng)
		end
		for _, sz in { -2.2, 2.2 } do
			for _, sx in { -1, 1 } do
				k.ball(sx, 0.2, sz, 0.4, C.BLACK, M.Rubber)
			end
		end
	end,
}

PROPS.boxstack = {
	w = 4.4,
	d = 4.4,
	h = 4.4,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		pallet(k, 0, 0, 3.8, 3.8)
		local spots = {
			{ -0.9, 0.6, -0.9 },
			{ 0.9, 0.6, -0.9 },
			{ -0.9, 0.6, 0.9 },
			{ 0.9, 0.6, 0.9 },
			{ 0, 1.8, -0.9 },
			{ 0, 1.8, 0.9 },
			{ 0.2, 3.0, 0 },
		}
		for i, s in spots do
			if i > 4 and rng:NextNumber() < 0.35 then
				continue
			end
			local color = rgb(200, 170, 120):Lerp(rgb(160, 130, 96), rng:NextNumber())
			k.box(s[1], s[2] + 0.6, s[3], 1.75, 1.2, 1.75, color, M.Cardboard, i <= 4)
			k.box(s[1], s[2] + 1.2, s[3], 1.85, 0.12, 1.85, darker(color, 0.1), M.Cardboard)
			k.box(s[1], s[2] + 0.7, s[3] - 0.89, 0.9, 0.4, 0.02, C.PAPER)
		end
	end,
}

-- a vault door set into a stretch of steel wall
PROPS.vault = {
	w = 10,
	d = 2.6,
	h = CEIL,
	kind = "high",
	wall = true,
	build = function(k, th)
		local steel = rgb(130, 136, 146)
		k.box(0, CEIL / 2, 0.2, 10, CEIL, 2.2, rgb(90, 94, 104), M.Metal, true)
		k.face(0, 4.0, -0.95, 7.2, 0.3, darker(steel, 0.3), M.Metal)
		k.face(0, 4.0, -1.15, 6.4, 0.5, steel, M.Metal)
		k.face(0, 4.0, -1.45, 1.2, 0.3, C.CHROME, M.Metal)
		for i = 0, 2 do
			local a = i / 3 * math.pi
			local dx, dy = math.cos(a) * 1.7, math.sin(a) * 1.7
			k.rod(Vector3.new(-dx, 4.0 - dy, -1.5), Vector3.new(dx, 4.0 + dy, -1.5), 0.2, C.CHROME, M.Metal)
			k.ball(dx, 4.0 + dy, -1.5, 0.45, C.CHROME, M.Metal)
			k.ball(-dx, 4.0 - dy, -1.5, 0.45, C.CHROME, M.Metal)
		end
		for _, y in { 2.4, 5.6 } do
			k.box(3.6, y, -1.2, 0.8, 1.0, 0.6, darker(steel, 0.2), M.Metal)
		end
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			k.face(math.cos(a) * 2.9, 4.0 + math.sin(a) * 2.9, -1.42, 0.3, 0.1, darker(steel, 0.15), M.Metal)
		end
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(0, 0, -0.9)),
			0,
			7.9,
			3,
			0.7,
			"VAULT 3",
			rgb(30, 32, 40),
			th.accent,
			1.2
		)
	end,
}

---------------------------------------------------------------- the machine room

-- the lift's hoist: a motor, a gearbox and a sheave on a plinth, its ropes going up, a rail round it
PROPS.hoist = {
	w = 9,
	d = 9,
	h = CEIL,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local paint = Kit.pick(rng, { rgb(60, 100, 80), rgb(60, 80, 120), rgb(110, 110, 116) })
		k.box(0, 0.6, 0, 7, 1.2, 5, rgb(150, 146, 140), M.Concrete, true)
		k.box(0, 1.4, 0, 6.4, 0.4, 3.6, rgb(50, 52, 58), M.Metal, true)
		k.part(CFrame.new(-1.7, 3.0, 0), Vector3.new(3.2, 2.8, 2.8), paint, M.Metal, true, Enum.PartType.Cylinder)
		for _, x in { -2.6, -1.7, -0.8 } do
			k.wheel(x, 3.0, 0, 3.0, 0.15, darker(paint, 0.25), M.Metal)
		end
		k.wheel(-3.35, 3.0, 0, 2.2, 0.15, C.DARK, M.Metal)
		k.box(0.6, 2.8, 0, 1.6, 2.4, 2.4, darker(paint, 0.15), M.Metal, true)
		k.wheel(2.3, 3.4, 0, 3.8, 1.0, rgb(60, 60, 64), M.Metal, true)
		for _, x in { 2.0, 2.3, 2.6 } do
			k.wheel(x, 3.4, 0, 3.86, 0.08, C.BLACK, M.Metal)
		end
		k.box(0.6, 4.3, 0, 1.0, 0.6, 1.6, rgb(200, 40, 40), M.Metal)
		for _, x in { 2.0, 2.2, 2.4, 2.6 } do
			k.rod(Vector3.new(x, 5.2, -0.3), Vector3.new(x, CEIL, -0.6), 0.1, C.STEEL, M.Metal)
		end
		local rail = th.accent2
		for _, sx in { -4.2, 4.2 } do
			for _, sz in { -4.2, 4.2 } do
				k.post(sx, sz, 0, 3.6, 0.25, rail, M.Metal, true)
			end
		end
		for _, s in { -4.2, 4.2 } do
			k.box(0, 3.5, s, 8.4, 0.2, 0.2, rail, M.Metal, true)
			k.box(s, 3.5, 0, 0.2, 0.2, 8.4, rail, M.Metal, true)
			k.box(0, 1.8, s, 8.4, 0.15, 0.15, rail, M.Metal)
		end
	end,
}

PROPS.controlcab = {
	w = 7.2,
	d = 2.6,
	h = 7.4,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local grey = rgb(170, 174, 180)
		for _, x in { -2.35, 0, 2.35 } do
			k.box(x, 3.6, 0, 2.3, 7.2, 2.4, grey, M.Metal, true)
			k.box(x, 3.6, -1.21, 2.0, 6.6, 0.04, darker(grey, 0.06), M.Metal)
			k.box(x + 0.75, 3.6, -1.26, 0.12, 0.8, 0.1, C.DARK, M.Metal)
			k.face(
				x - 0.5,
				6.4,
				-1.25,
				0.35,
				0.1,
				Kit.pick(rng, { rgb(60, 255, 100), rgb(60, 255, 100), rgb(255, 60, 50) }),
				M.Neon
			)
			k.box(x - 0.3, 5.2, -1.24, 0.8, 0.6, 0.02, HAZARD)
		end
		k.rod(Vector3.new(-3.6, 7.5, 0), Vector3.new(3.6, 7.5, 0), 0.5, th.accent2, M.Metal)
	end,
}

PROPS.generator = {
	w = 6.4,
	d = 11,
	h = 6.8,
	kind = "high",
	wall = false,
	build = function(k, th)
		k.box(0, 0.3, 0, 6, 0.6, 10.4, C.DARK, M.Metal, true)
		k.box(0, 1.1, 0, 5.6, 1, 9.6, rgb(70, 72, 80), M.Metal, true)
		k.box(0, 3.4, 0.4, 5.6, 3.6, 8, th.accent2, M.Metal, true)
		local grille = k.box(0, 3.4, -3.62, 5, 3, 0.1, C.DARK, M.Metal)
		local art = Kit.gui(grille, Enum.NormalId.Front, 16)
		for i = 0, 9 do
			Kit.rect(art, 0.04, 0.05 + i * 0.095, 0.92, 0.04, rgb(80, 84, 92))
		end
		for _, z in { -0.6, 2.4 } do
			for _, sx in { -2.82, 2.82 } do
				k.box(sx, 3.4, z, 0.04, 3.2, 0.04, darker(th.accent2, 0.4))
			end
		end
		k.rod(Vector3.new(1.6, 5.2, 3.0), Vector3.new(1.6, 6.6, 3.0), 0.5, C.DARK, M.Metal)
		k.part(
			CFrame.new(1.6, 6.6, 2.2) * ALONG_Z,
			Vector3.new(2.4, 0.9, 0.9),
			C.STEEL,
			M.Metal,
			false,
			Enum.PartType.Cylinder
		)
		local panel = k.box(-2.85, 4.2, 3.2, 0.1, 1.2, 1.6, C.BLACK)
		Kit.screen(Kit.gui(panel, Enum.NormalId.Left, 40, 1.2), Random.new(), "graph", th.accent)
	end,
}

PROPS.transformer = {
	w = 6.4,
	d = 5.6,
	h = 7.4,
	kind = "high",
	wall = false,
	build = function(k)
		local grey = rgb(120, 130, 124)
		k.box(0, 0.3, 0, 5.6, 0.6, 4.6, C.DARK, M.Metal, true)
		k.box(0, 2.7, 0, 4.4, 4.2, 3.2, grey, M.Metal, true)
		for i = 0, 3 do
			for _, s in { -1, 1 } do
				k.box(-1.5 + i, 2.6, s * 2.05, 0.12, 3.6, 0.9, darker(grey, 0.1), M.Metal)
			end
		end
		for i = -1, 1 do
			local x = i * 1.3
			k.post(x, -0.6, 4.8, 6.6, 0.25, C.STEEL, M.Metal)
			for j = 0, 2 do
				k.disc(x, 5.1 + j * 0.45, -0.6, 0.8 - (j % 2) * 0.2, 0.2, rgb(150, 80, 50), M.SmoothPlastic)
			end
		end
		k.part(CFrame.new(0, 5.6, 1.0), Vector3.new(3.6, 1.2, 1.2), grey, M.Metal, false, Enum.PartType.Cylinder)
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(0, 0, -1.6)),
			0,
			3.0,
			2.2,
			1.2,
			"DANGER\nHIGH VOLTAGE",
			HAZARD,
			C.BLACK
		)
	end,
}

PROPS.spool = {
	w = 4.2,
	d = 4.2,
	h = 4.2,
	kind = "low",
	wall = false,
	build = function(k)
		local wood = rgb(170, 130, 80)
		for _, x in { -1.25, 1.25 } do
			k.wheel(x, 2.05, 0, 4.1, 0.3, wood, M.WoodPlanks, true)
		end
		k.wheel(0, 2.05, 0, 3.0, 2.2, rgb(30, 30, 34), M.Rubber, true)
		k.wheel(1.45, 2.05, 0, 0.7, 0.05, C.DARK)
	end,
}

PROPS.fanunit = {
	w = 6.4,
	d = 3,
	h = 5.4,
	kind = "high",
	wall = true,
	build = function(k, _th, rng)
		local grey = rgb(150, 156, 164)
		k.box(0, 2.6, 0, 6.2, 5.2, 2.8, grey, M.Metal, true)
		for _, x in { -1.5, 1.5 } do
			k.face(x, 2.8, -1.42, 2.6, 0.08, C.DARK, M.Metal)
			local spin = rng:NextNumber(0, math.pi)
			for i = 0, 2 do
				k.part(
					CFrame.new(x, 2.8, -1.5) * CFrame.Angles(0, 0, spin + i * math.pi / 3),
					Vector3.new(2.2, 0.4, 0.05),
					C.STEEL,
					M.Metal
				)
			end
			k.face(x, 2.8, -1.55, 0.5, 0.1, C.DARK, M.Metal)
		end
	end,
}

---------------------------------------------------------------- the lab

-- an island bench: cabinets, a black top, a sink, a microscope, glassware and a reagent shelf
PROPS.labbench = {
	w = 12,
	d = 4.8,
	h = 6.4,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local white = rgb(232, 236, 238)
		local body = k.box(0, 1.3, 0, 11.6, 2.6, 4.4, white, M.SmoothPlastic, true)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local art = Kit.gui(body, face, 12)
			for i = 0, 5 do
				Kit.rect(art, i / 6 + 0.006, 0.08, 1 / 6 - 0.012, 0.84, rgb(214, 220, 224))
				Kit.rect(art, i / 6 + 0.06, 0.18, 0.05, 0.03, rgb(120, 126, 134))
			end
		end
		k.box(0, 2.72, 0, 12, 0.25, 4.8, rgb(24, 24, 28), M.SmoothPlastic, true)
		-- the reagent shelf down the middle
		for _, sx in { -5.4, 5.4 } do
			k.post(sx, 0, 2.85, 6.2, 0.18, C.STEEL, M.Metal)
		end
		local colors = { rgb(120, 60, 30), rgb(200, 210, 220), rgb(40, 90, 160), rgb(220, 180, 60) }
		for _, y in { 4.3, 5.8 } do
			local shelf = k.box(0, y, 0, 11, 0.1, 1.0, rgb(220, 236, 240), M.Glass)
			shelf.Transparency = 0.4
			for _ = 1, 5 do
				local bottle = k.post(
					rng:NextNumber(-5, 5),
					rng:NextNumber(-0.25, 0.25),
					y + 0.05,
					y + rng:NextNumber(0.7, 1.1),
					0.45,
					Kit.pick(rng, colors),
					M.Glass
				)
				bottle.Transparency = 0.2
			end
		end
		-- a sink and its tap
		k.box(-4, 2.86, -1.3, 1.6, 0.04, 1.2, rgb(60, 64, 70), M.Metal)
		k.post(-4, -1.95, 2.85, 3.9, 0.15, C.CHROME, M.Metal)
		k.rod(Vector3.new(-4, 3.9, -1.95), Vector3.new(-4, 3.9, -1.35), 0.15, C.CHROME, M.Metal)
		-- a microscope
		k.box(-1.6, 2.98, -1.3, 0.9, 0.25, 1.1, C.WHITE)
		k.box(-1.6, 3.6, -0.95, 0.3, 1.3, 0.3, C.WHITE)
		k.rod(Vector3.new(-1.6, 4.3, -1.0), Vector3.new(-1.6, 3.5, -1.5), 0.3, C.DARK)
		k.box(-1.6, 3.3, -1.45, 0.7, 0.08, 0.6, C.DARK)
		-- flasks of something glowing, test tubes in a rack
		for i = 0, 2 do
			local x, z = 0.8 + i * 1.1, -1.3 + rng:NextNumber(-0.2, 0.3)
			local glass = k.ball(x, 3.25, z, 0.85, rgb(220, 240, 250), M.Glass)
			glass.Transparency = 0.5
			k.ball(x, 3.18, z, 0.6, Kit.pick(rng, { th.accent, th.accent2, rgb(255, 120, 200) }), M.Neon)
			k.post(x, z, 3.5, 4.0, 0.22, rgb(220, 240, 250), M.Glass).Transparency = 0.4
		end
		k.box(4.4, 3.0, -1.2, 1.8, 0.3, 0.6, C.WHITE)
		for i = 0, 3 do
			k.post(
				3.75 + i * 0.42,
				-1.2,
				2.9,
				3.6,
				0.2,
				Kit.pick(rng, { th.accent, th.accent2, rgb(255, 120, 200), rgb(255, 220, 90) }),
				M.Neon
			)
		end
		k.box(1.5, 2.88, 1.3, 2.2, 0.08, 1.6, C.PAPER)
	end,
}

-- a tube of glowing liquid with something floating in it
PROPS.specimen = {
	w = 4.6,
	d = 4.6,
	h = CEIL,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local steel = rgb(150, 156, 166)
		k.post(0, 0, 0, 1.3, 4.2, steel, M.Metal, true)
		k.disc(0, 1.35, 0, 4.3, 0.12, th.accent, M.Neon)
		local tube = k.post(0, 0, 1.3, 6.9, 3.6, rgb(210, 240, 240), M.Glass, true)
		tube.Transparency = 0.6
		local liquid = k.post(0, 0, 1.4, 6.6, 3.3, th.accent, M.Glass)
		liquid.Transparency = 0.45
		local creature = rgb(60, 90, 70):Lerp(th.accent2, 0.3)
		k.blob(0, 4.2, 0, 1.6, 2.2, 1.3, creature, M.SmoothPlastic)
		k.blob(0.3, 5.4, 0.1, 1.0, 0.9, 0.9, creature, M.SmoothPlastic)
		k.post(0, 0, 6.9, 7.8, 4.0, steel, M.Metal)
		k.disc(0, 7.85, 0, 2.4, 0.1, darker(steel, 0.3), M.Metal)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2 + rng:NextNumber(0, 1)
			k.rod(
				Vector3.new(math.cos(a) * 1.2, 7.8, math.sin(a) * 1.2),
				Vector3.new(math.cos(a) * 1.6, CEIL, math.sin(a) * 1.6),
				0.25,
				C.DARK,
				M.Rubber
			)
		end
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Rate = 5
		bubbles.Lifetime = NumberRange.new(1.6, 2.4)
		bubbles.Speed = NumberRange.new(1.5, 2.5)
		bubbles.Size = NumberSequence.new(0.14)
		bubbles.Transparency = NumberSequence.new(0.3, 0.9)
		bubbles.LightEmission = 0.6
		bubbles.Color = ColorSequence.new(lighter(th.accent, 0.5))
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.SpreadAngle = Vector2.new(10, 10)
		bubbles.Parent = k.box(0, 1.5, 0, 2.2, 0.1, 2.2, th.accent, M.Neon)
	end,
}

PROPS.fumehood = {
	w = 7,
	d = 3.8,
	h = CEIL,
	kind = "high",
	wall = true,
	build = function(k, th)
		local white = rgb(232, 236, 238)
		k.box(0, 1.3, 0, 7, 2.6, 3.4, white, M.SmoothPlastic, true)
		k.box(0, 2.7, 0, 7, 0.2, 3.6, rgb(24, 24, 28))
		for _, sx in { -3.35, 3.35 } do
			k.box(sx, 4.6, 0, 0.3, 3.6, 3.4, white, M.SmoothPlastic, true)
		end
		k.box(0, 4.6, 1.55, 6.4, 3.6, 0.2, rgb(200, 206, 210), M.SmoothPlastic, true)
		k.box(0, 7.2, 0, 7, 1.6, 3.4, white, M.SmoothPlastic, true)
		local sash = k.box(0, 4.0, -1.6, 6.4, 2.4, 0.1, rgb(220, 240, 250), M.Glass, "cover")
		sash.Transparency = 0.5
		k.box(0, 2.85, -1.62, 6.4, 0.12, 0.14, C.STEEL, M.Metal)
		k.box(0, 6.3, 0.2, 6.2, 0.12, 0.3, rgb(240, 250, 255), M.Neon)
		k.ball(-1, 3.2, 0.3, 0.8, th.accent, M.Neon)
		k.post(-1, 0.3, 3.5, 4.2, 0.25, rgb(220, 240, 250), M.Glass)
		k.post(1.6, 0.4, 2.8, 4.4, 0.12, C.STEEL, M.Metal)
		k.box(2.6, 7.4, -1.72, 1.2, 0.5, 0.06, th.accent, M.Neon)
		k.post(0, 0.5, 8.0, CEIL, 1.6, C.STEEL, M.Metal)
	end,
}

PROPS.chemcab = {
	w = 4.4,
	d = 2.4,
	h = 6,
	kind = "high",
	wall = true,
	build = function(k)
		local yellow = rgb(240, 196, 40)
		k.box(0, 3, 0, 4.2, 6, 2.2, yellow, M.Metal, true)
		k.box(0, 3, -1.11, 0.05, 5.6, 0.04, darker(yellow, 0.4))
		for _, sx in { -0.4, 0.4 } do
			k.box(sx, 3.2, -1.16, 0.12, 0.9, 0.1, C.DARK, M.Metal)
		end
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(0, 0, -1.1)),
			0,
			4.8,
			3.2,
			0.9,
			"FLAMMABLE",
			rgb(200, 30, 30),
			C.WHITE
		)
	end,
}

PROPS.freezer = {
	w = 4.2,
	d = 3.2,
	h = 7.6,
	kind = "high",
	wall = true,
	build = function(k, th)
		local white = rgb(236, 238, 240)
		k.box(0, 3.8, 0, 4, 7.6, 3, white, M.Metal, true)
		k.box(0, 4.0, -1.52, 3.6, 6.4, 0.06, lighter(white, 0.3), M.Metal)
		k.box(1.5, 4.0, -1.62, 0.15, 3, 0.15, C.CHROME, M.Metal)
		k.box(0, 0.4, -1.52, 3.6, 0.5, 0.06, C.DARK)
		local display = k.box(-0.8, 6.6, -1.58, 1.4, 0.6, 0.06, C.BLACK)
		local art = Kit.gui(display, Enum.NormalId.Front, 40, 1.4)
		Kit.text(art, "-80°C", 0.05, 0.05, 0.9, 0.9, th.accent2, Enum.Font.Code)
	end,
}

PROPS.console = {
	w = 7.2,
	d = 4.6,
	h = 6,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		k.box(0, 2.5, 0.6, 7, 0.2, 3, C.WHITE, M.SmoothPlastic, true)
		k.box(0, 1.2, 2.0, 6.6, 2.4, 0.2, rgb(200, 206, 210), M.SmoothPlastic, true)
		for _, sx in { -3.3, 3.3 } do
			k.box(sx, 1.2, 0.6, 0.2, 2.4, 2.8, rgb(200, 206, 210), M.SmoothPlastic, true)
		end
		Pieces.monitor(k, 0, 2.6, 1.3, 0, 4.0, rng, "dna", th.accent2)
		Pieces.monitor(k, -2.7, 2.6, 1.0, math.rad(20), 1.8, rng, "graph", th.accent)
		Pieces.monitor(k, 2.7, 2.6, 1.0, math.rad(-20), 1.8, rng, "code", th.accent)
		k.box(0, 2.64, -0.3, 1.8, 0.08, 0.55, C.BLACK)
		Pieces.officeChair(k, 0, -1.6, math.pi, rgb(220, 224, 230))
	end,
}

return PROPS
