--!strict
-- Furniture for the floors people live and work on: the lobby, the offices, the library, the hotel, the
-- penthouse and the art studio. (Props has how a piece is described; Pieces the chairs, sofas and lamps.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

type Prop = Kit.Prop

local rgb = Kit.rgb
local M = Enum.Material
local C = Pieces.C
local lighter, darker = Pieces.lighter, Pieces.darker
local CEIL = Config.FLOOR_HEIGHT - Config.SLAB -- the ceiling, above the floor
local Q = math.pi / 2

local PROPS: { [string]: Prop } = {}

---------------------------------------------------------------- the lobby

PROPS.reception = {
	w = 15,
	d = 6.8,
	h = 3.9,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local marble = rgb(234, 230, 222)
		local z = -1.4 -- the desk's middle (the chair sits behind it)
		k.box(0, 1.6, z, 11, 3.2, 3.6, marble, M.Marble, true)
		for _, sx in { -1, 1 } do
			k.post(sx * 5.5, z, 0, 3.2, 3.6, marble, M.Marble, true)
			k.disc(sx * 5.5, 3.32, z, 3.8, 0.24, C.WALNUT, M.Wood)
		end
		k.box(0, 3.32, z, 11, 0.24, 3.8, C.WALNUT, M.Wood)
		-- the raised ledge visitors lean on, the kick plate, a brass line
		k.box(0, 3.75, z - 1.1, 8, 0.6, 1.4, marble, M.Marble)
		k.box(0, 4.1, z - 1.1, 8.3, 0.12, 1.6, th.accent2, M.Metal)
		k.box(0, 0.25, z - 1.82, 11, 0.5, 0.1, C.BLACK)
		k.box(0, 0.62, z - 1.83, 11, 0.12, 0.1, C.BRASS, M.Metal)
		local logo = k.box(0, 1.9, z - 1.86, 4.6, 1.5, 0.1, rgb(30, 28, 36))
		local art = Kit.gui(logo, Enum.NormalId.Front, 30, 1.5)
		Kit.text(art, "ROOFTOP", 0.05, 0.1, 0.9, 0.8, th.accent, Enum.Font.LuckiestGuy)
		-- on the desk: two screens facing the receptionist, a bell, flowers
		Pieces.monitor(k, -2, 3.44, z + 0.4, math.pi, 2.2, rng, "code", th.accent)
		Pieces.monitor(k, 1.8, 3.44, z + 0.4, math.pi, 2.2, rng, "chart", th.accent)
		k.disc(-3.4, 4.22, z - 1.1, 0.7, 0.1, C.BRASS, M.Metal)
		k.ball(-3.4, 4.3, z - 1.1, 0.5, C.BRASS, M.Metal)
		k.post(4.6, z - 0.9, 4.16, 5.0, 0.6, rgb(200, 230, 240), M.Glass)
		for i = 0, 2 do
			k.ball(
				4.6 + (i - 1) * 0.35,
				5.25 + (i % 2) * 0.25,
				z - 0.9,
				0.6,
				Kit.pick(rng, { rgb(255, 120, 150), rgb(255, 220, 110), rgb(250, 250, 250) }),
				M.Fabric
			)
		end
		Pieces.officeChair(k, 0, 2.3, 0, darker(th.accent2, 0.2))
	end,
}

-- two sofas facing over a coffee table on a rug, an armchair at the end, a lamp and a plant
PROPS.lounge = {
	w = 17,
	d = 14,
	h = 3.2,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		Pieces.rug(k.sub(0, 0, 0, "Rug"), 0, 0, 15, 11, lighter(th.accent2, 0.55), th.accent2)
		local fabric = Kit.pick(rng, { rgb(70, 84, 100), rgb(120, 90, 70), rgb(60, 90, 80), darker(th.accent2, 0.1) })
		Pieces.sofa(k.sub(0, -4.4, math.pi, "Sofa"), 0, 0, 0, 8, fabric, th.accent)
		Pieces.sofa(k.sub(0, 4.4, 0, "Sofa"), 0, 0, 0, 8, fabric, th.accent)
		Pieces.armchair(k.sub(-6.6, 0, -Q, "Armchair"), 0, 0, 0, lighter(fabric, 0.15), C.WALNUT)
		local t = k.sub(0, 0, 0, "Table")
		t.box(0, 1.25, 0, 5, 0.25, 2.8, C.WALNUT, M.Wood)
		t.box(0, 0.45, 0, 4.4, 0.12, 2.2, darker(C.WALNUT, 0.2), M.Wood)
		for _, sx in { -2.2, 2.2 } do
			for _, sz in { -1.1, 1.1 } do
				t.box(sx, 0.62, sz, 0.25, 1.25, 0.25, C.BLACK, M.Metal)
			end
		end
		t.box(-1.2, 1.5, 0.2, 1.6, 0.25, 1.1, th.accent2, M.SmoothPlastic)
		t.box(-1.2, 1.7, 0.2, 1.4, 0.15, 1.0, C.PAPER, M.SmoothPlastic)
		t.disc(1.3, 1.5, -0.1, 1.2, 0.25, C.WHITE, M.Marble)
		t.ball(1.3, 1.7, -0.1, 0.5, rgb(255, 170, 60), M.SmoothPlastic)
		Pieces.floorLamp(k.sub(-7, 4.6, 0, "Lamp"), 0, 0, C.BLACK)
		Pieces.plant(k.sub(6.8, 4.8, 0, "Plant"), 0, 0, rng, 1)
	end,
}

PROPS.palm = {
	w = 4.5,
	d = 4.5,
	h = 9.5,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		local stone = rgb(214, 208, 196)
		k.box(0, 1.3, 0, 3.2, 2.6, 3.2, stone, M.Limestone, true)
		k.box(0, 2.72, 0, 3.6, 0.3, 3.6, darker(stone, 0.1), M.Limestone)
		k.box(0, 2.7, 0, 2.9, 0.2, 2.9, rgb(70, 50, 40), M.Ground)
		local trunk = rgb(120, 90, 60)
		local a = Vector3.new(0, 2.6, 0)
		local b = Vector3.new(0.3, 4.8, 0.15)
		local c = Vector3.new(0.6, 7.0, 0.3)
		k.rod(a, b, 0.7, trunk, M.Wood, true)
		k.rod(b, c, 0.55, darker(trunk, 0.1), M.Wood, true)
		for i = 0, 4 do
			local y = 3.4 + i * 0.85
			k.disc(0.08 * i + 0.05, y, 0.04 * i, 0.72 - i * 0.03, 0.12, darker(trunk, 0.25), M.Wood)
		end
		local green = C.LEAF:Lerp(rgb(90, 150, 70), rng:NextNumber())
		local top = CFrame.new(c)
		for i = 0, 7 do
			local yaw = i / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			k.part(
				top * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.5, -1.9) * CFrame.Angles(math.rad(-24), 0, 0),
				Vector3.new(1.1, 0.1, 4.0),
				if i % 2 == 0 then green else darker(green, 0.12),
				M.Grass
			)
		end
		for i = 0, 2 do
			k.part(
				top * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0.5, -0.8) * CFrame.Angles(math.rad(40), 0, 0),
				Vector3.new(0.8, 0.1, 1.8),
				lighter(green, 0.1),
				M.Grass
			)
		end
		k.ball(c.X + 0.4, c.Y - 0.3, c.Z, 0.6, rgb(110, 80, 50), M.Wood)
		k.ball(c.X - 0.2, c.Y - 0.35, c.Z + 0.4, 0.6, rgb(110, 80, 50), M.Wood)
	end,
}

-- a round column to the ceiling: plinth, base, shaft, gold bands, capital
PROPS.column = {
	w = 3.8,
	d = 3.8,
	h = CEIL,
	kind = "high",
	wall = false,
	build = function(k, th)
		local stone = rgb(236, 232, 222)
		k.box(0, 0.3, 0, 3.8, 0.6, 3.8, stone, M.Marble, true)
		k.disc(0, 0.78, 0, 3.2, 0.36, stone, M.Marble)
		k.post(0, 0, 0.9, CEIL - 0.9, 2.6, stone, M.Marble, true)
		for _, y in { 1.4, CEIL - 1.4 } do
			k.disc(0, y, 0, 2.76, 0.22, th.accent2:Lerp(C.BRASS, 0.6), M.Metal)
		end
		k.disc(0, CEIL - 0.8, 0, 3.2, 0.4, stone, M.Marble)
		k.box(0, CEIL - 0.3, 0, 3.8, 0.6, 3.8, stone, M.Marble)
	end,
}

-- the building's directory: every floor by its number
PROPS.directory = {
	w = 5.6,
	d = 1.8,
	h = 7.4,
	kind = "high",
	wall = false,
	build = function(k, th)
		k.box(0, 0.3, 0, 5.6, 0.6, 1.6, C.BLACK, M.Metal, true)
		local board = k.box(0, 3.9, 0, 5, 6.4, 0.4, rgb(28, 26, 34), M.SmoothPlastic, true)
		k.box(0, 7.2, 0, 5.4, 0.3, 0.6, th.accent2:Lerp(C.BRASS, 0.6), M.Metal)
		local art = Kit.gui(board, Enum.NormalId.Front, 40, 1.4)
		Kit.text(art, "ROOFTOP TOWER", 0.06, 0.03, 0.88, 0.08, th.accent, Enum.Font.LuckiestGuy)
		Kit.rect(art, 0.06, 0.12, 0.88, 0.006, th.accent)
		local Themes = require(script.Parent.Themes) :: any
		for i, t in Themes.LIST do
			local col = if i <= 10 then 0 else 1
			local row = (i - 1) % 10
			local label = Kit.text(
				art,
				string.format("%02d  %s", i, string.upper(t.name)),
				0.06 + col * 0.46,
				0.15 + row * 0.083,
				0.42,
				0.06,
				rgb(236, 230, 214),
				Enum.Font.GothamBold
			)
			label.TextXAlignment = Enum.TextXAlignment.Left
		end
	end,
}

PROPS.bench = {
	w = 7.4,
	d = 2.6,
	h = 1.9,
	kind = "low",
	wall = false,
	build = function(k)
		for _, sx in { -3, 3 } do
			k.box(sx, 0.8, 0, 0.3, 1.6, 2.2, C.BLACK, M.Metal, true)
		end
		for _, sz in { -0.8, 0, 0.8 } do
			k.box(0, 1.7, sz, 7.4, 0.22, 0.7, C.OAK, M.Wood, true)
		end
	end,
}

---------------------------------------------------------------- the offices

-- four desks back to back round a screen, each with its screen, keyboard and chair
PROPS.deskpod = {
	w = 12,
	d = 11,
	h = 4.4,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		local top = Kit.pick(rng, { C.WHITE, C.OAK, rgb(210, 200, 186) })
		local chair = Kit.pick(rng, { rgb(40, 44, 56), th.accent2, rgb(60, 70, 90) })
		local screens = { "code", "chart", "graph", "code" }
		local n = 0
		for _, sz in { -1, 1 } do
			for _, sx in { -1, 1 } do
				n += 1
				local d = k.sub(sx * 2.9, sz * 1.65, if sz > 0 then math.pi else 0, "Desk")
				-- in the desk's frame the chair is at -z, the screen toward +z
				d.box(0, 2.5, 0, 5.6, 0.2, 3.1, top, M.SmoothPlastic, true)
				for _, ex in { -2.65, 2.65 } do
					d.box(ex, 1.2, 0, 0.2, 2.4, 2.8, C.STEEL, M.Metal, true)
				end
				Pieces.monitor(d, 0, 2.6, 0.75, 0, 2.4, rng, screens[n], th.accent)
				d.box(0, 2.64, -0.55, 1.8, 0.08, 0.55, C.BLACK)
				d.box(1.4, 2.63, -0.5, 0.25, 0.08, 0.4, C.BLACK)
				local extra = rng:NextInteger(1, 3)
				if extra == 1 then
					Pieces.mug(d, -1.9, 2.6, -0.2, Kit.pick(rng, { C.WHITE, th.accent, rgb(220, 90, 70) }))
				elseif extra == 2 then
					d.box(-1.8, 2.7, 0.2, 1.3, 0.2, 1.7, C.PAPER)
				else
					Pieces.lamp(d, -2.1, 2.6, 0.5, C.BLACK, rgb(255, 236, 200))
				end
				Pieces.officeChair(k.sub(sx * 2.9, sz * 4.1, if sz > 0 then 0 else math.pi, "Chair"), 0, 0, 0, chair)
			end
		end
		local screen = k.sub(0, 0, 0, "Screen")
		screen.box(0, 3.4, 0, 11.4, 1.6, 0.2, darker(th.accent2, 0.1), M.Fabric, "cover")
		screen.box(0, 4.25, 0, 11.6, 0.1, 0.3, C.STEEL, M.Metal)
	end,
}

-- a meeting table with rounded ends and six chairs, laptops and notepads
PROPS.meeting = {
	w = 15,
	d = 9.6,
	h = 3,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		local t = k.sub(0, 0, 0, "Table")
		local wood = Kit.pick(rng, { C.WALNUT, C.OAK, rgb(60, 62, 70) })
		t.box(0, 2.5, 0, 9.6, 0.25, 4.2, wood, M.Wood, true)
		for _, sx in { -1, 1 } do
			t.disc(sx * 4.8, 2.5, 0, 4.2, 0.25, wood, M.Wood, true)
			t.box(sx * 3, 1.2, 0, 0.8, 2.4, 2.4, C.BLACK, M.Metal, true)
		end
		for i, sx in { -3.4, 0, 3.4 } do
			for _, sz in { -1, 1 } do
				Pieces.officeChair(
					k.sub(sx, sz * 3.6, if sz > 0 then 0 else math.pi, "Chair"),
					0,
					0,
					0,
					darker(th.accent2, 0.15)
				)
				local item = (i + (if sz > 0 then 1 else 0)) % 3
				if item == 0 then
					-- a laptop, open
					t.box(sx, 2.66, sz * 1.1, 1.8, 0.08, 1.2, C.STEEL, M.Metal)
					local lid = t.part(
						CFrame.new(sx, 3.2, sz * 0.55)
							* CFrame.Angles(0, if sz > 0 then math.pi else 0, 0)
							* CFrame.Angles(math.rad(15), 0, 0),
						Vector3.new(1.8, 1.2, 0.08),
						C.STEEL,
						M.Metal
					)
					Kit.screen(
						Kit.gui(lid, Enum.NormalId.Front, 40, 1.2),
						rng,
						Kit.pick(rng, { "code", "chart", "graph" }),
						th.accent
					)
				elseif item == 1 then
					t.box(sx, 2.66, sz * 1.2, 1.1, 0.06, 1.5, C.PAPER)
					t.box(sx + 0.7, 2.68, sz * 1.2, 0.08, 0.08, 1.2, th.accent2)
				else
					t.post(sx + 0.4, sz * 1.2, 2.62, 3.5, 0.4, rgb(180, 220, 240), M.Glass)
				end
			end
		end
		t.part(CFrame.new(0, 2.75, 0) * CFrame.Angles(0, math.rad(30), 0), Vector3.new(1.2, 0.25, 1.2), C.BLACK)
	end,
}

-- a row of three filing cabinets
PROPS.filing = {
	w = 9,
	d = 2.6,
	h = 4.6,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local body = Kit.pick(rng, { rgb(170, 176, 186), rgb(90, 96, 110), rgb(220, 220, 214) })
		for _, x in { -3, 0, 3 } do
			k.box(x, 2.3, 0, 2.9, 4.6, 2.5, body, M.Metal, true)
			for r = 1, 3 do
				k.box(x, r * 1.15, -1.26, 2.8, 0.06, 0.04, darker(body, 0.45))
			end
			for r = 0, 3 do
				k.box(x, r * 1.15 + 0.85, -1.3, 0.9, 0.14, 0.1, C.CHROME, M.Metal)
				k.box(x, r * 1.15 + 0.5, -1.27, 0.6, 0.25, 0.04, C.PAPER)
			end
		end
		if rng:NextNumber() < 0.6 then
			Pieces.plant(k.lift(4.6), 2.8, 0, rng, 0.55)
		else
			k.box(-2.6, 5.0, 0, 2, 0.8, 1.6, rgb(190, 160, 120), M.Cardboard)
			k.box(-2.4, 5.6, 0, 1.6, 0.4, 1.2, th.accent2, M.SmoothPlastic)
		end
	end,
}

PROPS.printer = {
	w = 3.6,
	d = 3,
	h = 3.8,
	kind = "low",
	wall = true,
	build = function(k, th)
		local grey = rgb(200, 202, 206)
		k.box(0, 0.9, 0, 3.4, 1.8, 2.8, rgb(70, 74, 84), M.SmoothPlastic, true)
		k.box(0, 2.5, 0, 3.4, 1.4, 2.8, grey, M.SmoothPlastic, true)
		k.box(0, 3.3, 0.1, 3.4, 0.2, 2.6, rgb(60, 62, 70))
		k.box(2, 2.4, 0, 0.6, 0.1, 2, grey)
		k.box(2, 2.48, 0, 0.5, 0.08, 1.6, C.PAPER)
		k.box(-1, 3.2, -1.3, 1, 0.3, 0.2, th.accent, M.Neon)
		for i = 0, 2 do
			k.box(0, 1.55 - i * 0.5, -1.42, 3, 0.05, 0.05, rgb(50, 52, 60))
		end
	end,
}

-- a whiteboard on wheels, with the last meeting's scribbles
PROPS.whiteboard = {
	w = 6.4,
	d = 2.2,
	h = 6.8,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		for _, sx in { -2.9, 2.9 } do
			k.box(sx, 0.15, 0, 0.3, 0.3, 2, C.STEEL, M.Metal)
			k.post(sx, 0, 0.3, 6.4, 0.22, C.STEEL, M.Metal)
		end
		k.box(0, 4.4, 0, 6, 3.8, 0.2, C.STEEL, M.Metal, true)
		local board = k.box(0, 4.4, -0.06, 5.7, 3.5, 0.14, rgb(246, 248, 250))
		k.box(0, 2.45, -0.2, 5, 0.12, 0.35, C.STEEL, M.Metal)
		local art = Kit.gui(board, Enum.NormalId.Front, 30)
		local inks = { rgb(30, 60, 160), rgb(200, 40, 40), rgb(30, 130, 60), rgb(20, 20, 24) }
		Kit.text(
			art,
			Kit.pick(rng, { "Q4 PLAN", "ROADMAP", "IDEAS!", "LAUNCH" }),
			0.05,
			0.04,
			0.5,
			0.16,
			inks[1],
			Enum.Font.PermanentMarker
		)
		for i = 0, 4 do
			Kit.rect(art, 0.07, 0.27 + i * 0.11, rng:NextNumber(0.2, 0.42), 0.025, Kit.pick(rng, inks))
		end
		for i = 0, 3 do
			local h = rng:NextNumber(0.15, 0.45)
			Kit.rect(art, 0.6 + i * 0.09, 0.85 - h, 0.06, h, Kit.pick(rng, inks))
		end
		Kit.rect(art, 0.58, 0.85, 0.38, 0.012, inks[4])
		for _ = 1, 2 do
			k.box(rng:NextNumber(-2, 2), 2.55, -0.25, 0.5, 0.12, 0.12, Kit.pick(rng, inks))
		end
	end,
}

PROPS.watercooler = {
	w = 1.8,
	d = 1.8,
	h = 5.6,
	kind = "low",
	wall = true,
	build = function(k)
		k.box(0, 1.8, 0, 1.4, 3.6, 1.4, C.WHITE, M.SmoothPlastic, true)
		k.box(0, 2.1, -0.72, 1, 0.8, 0.1, rgb(60, 62, 70))
		k.box(-0.25, 2.5, -0.78, 0.18, 0.2, 0.18, rgb(60, 120, 255))
		k.box(0.25, 2.5, -0.78, 0.18, 0.2, 0.18, rgb(255, 70, 60))
		local bottle = k.post(0, 0, 3.6, 5.4, 1.2, rgb(150, 200, 240), M.Glass)
		bottle.Transparency = 0.35
		k.post(0, 0, 5.4, 5.6, 0.4, rgb(60, 120, 255))
	end,
}

PROPS.plant = {
	w = 3,
	d = 3,
	h = 6,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		Pieces.plant(k, 0, 0, rng, 1.2)
	end,
}

---------------------------------------------------------------- the library

local function shelfBooks(
	k: Kit.Builder,
	rng: Random,
	x0: number,
	x1: number,
	levels: { number },
	z: number,
	depth: number,
	hmax: number
)
	for _, y in levels do
		Pieces.books(k, x0, x1, y, z, depth, hmax, rng)
	end
end

PROPS.bookcase = {
	w = 9,
	d = 2.4,
	h = 8,
	kind = "high",
	wall = true,
	build = function(k, _th, rng)
		local wood = Kit.pick(rng, { C.WALNUT, rgb(110, 72, 48), rgb(70, 46, 34) })
		k.box(0, 4, 1.05, 9, 8, 0.3, darker(wood, 0.35), M.Wood, true)
		for _, sx in { -4.35, 4.35 } do
			k.box(sx, 4, 0, 0.3, 8, 2.4, wood, M.Wood, true)
		end
		k.box(0, 7.8, -0.1, 9.4, 0.4, 2.4, wood, M.Wood)
		k.box(0, 7.5, -0.1, 9, 0.2, 2.3, darker(wood, 0.15), M.Wood)
		k.box(0, 0.25, 0, 9, 0.5, 2.4, darker(wood, 0.2), M.Wood, true)
		local levels = { 0.5, 2.35, 4.2, 6.05 }
		for i = 2, 4 do
			k.box(0, levels[i] - 0.08, 0, 8.4, 0.16, 2.2, wood, M.Wood, true)
		end
		shelfBooks(k, rng, -4.15, 4.15, levels, -0.05, 1.7, 1.55)
	end,
}

-- a free-standing bookcase, books on both sides
PROPS.stack = {
	w = 10,
	d = 3.4,
	h = 7.2,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		local wood = Kit.pick(rng, { C.WALNUT, rgb(110, 72, 48) })
		k.box(0, 3.6, 0, 9.4, 7.2, 0.3, darker(wood, 0.3), M.Wood, true)
		for _, sx in { -4.85, 4.85 } do
			k.box(sx, 3.6, 0, 0.3, 7.2, 3.4, wood, M.Wood, true)
		end
		k.box(0, 7.1, 0, 10.2, 0.3, 3.6, wood, M.Wood)
		k.box(0, 0.2, 0, 10, 0.4, 3.4, darker(wood, 0.2), M.Wood, true)
		local levels = { 0.4, 2.6, 4.8 }
		for i = 2, 3 do
			k.box(0, levels[i] - 0.08, 0, 9.4, 0.16, 3.2, wood, M.Wood, true)
		end
		shelfBooks(k, rng, -4.6, 4.6, levels, -0.85, 1.25, 1.9)
		shelfBooks(k, rng, -4.6, 4.6, levels, 0.85, 1.25, 1.9)
	end,
}

-- a reading table: four chairs, two green banker's lamps, open books
PROPS.readtable = {
	w = 10,
	d = 7.8,
	h = 3.4,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		local wood = rgb(120, 80, 52)
		k.box(0, 2.55, 0, 9, 0.3, 3.6, wood, M.Wood, true)
		for _, sx in { -3.6, 3.6 } do
			k.box(sx, 1.2, 0, 0.5, 2.4, 3, darker(wood, 0.2), M.Wood, true)
		end
		k.box(0, 0.6, 0, 7, 0.3, 0.4, darker(wood, 0.2), M.Wood)
		for _, sx in { -2.3, 2.3 } do
			for _, sz in { -1, 1 } do
				Pieces.diningChair(k, sx, sz * 2.9, if sz > 0 then 0 else math.pi, wood, rgb(110, 40, 40))
			end
		end
		for _, sx in { -2.2, 2.2 } do
			k.box(sx, 2.78, 0, 0.8, 0.16, 0.5, C.BRASS, M.Metal)
			k.post(sx, 0, 2.8, 3.6, 0.12, C.BRASS, M.Metal)
			k.part(
				CFrame.new(sx, 3.7, 0),
				Vector3.new(1.4, 0.6, 0.6),
				rgb(40, 140, 80),
				M.Neon,
				false,
				Enum.PartType.Cylinder
			)
		end
		for _, sz in { -1, 1 } do
			local x = rng:NextNumber(-1, 1)
			k.part(
				CFrame.new(x - 0.45, 2.75, sz * 0.9) * CFrame.Angles(0, 0, math.rad(8)),
				Vector3.new(0.9, 0.06, 1.2),
				C.PAPER
			)
			k.part(
				CFrame.new(x + 0.45, 2.75, sz * 0.9) * CFrame.Angles(0, 0, math.rad(-8)),
				Vector3.new(0.9, 0.06, 1.2),
				C.PAPER
			)
		end
		for i = 0, 2 do
			k.box(
				3.6,
				2.8 + i * 0.25,
				-1,
				1.2 - i * 0.1,
				0.24,
				0.9,
				Kit.pick(rng, { rgb(150, 50, 50), rgb(50, 90, 140), rgb(200, 170, 90) })
			)
		end
	end,
}

-- a corner to read in: a round rug, a wing chair, a side table and lamp, a footstool
PROPS.nook = {
	w = 9,
	d = 9,
	h = 6.8,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		Pieces.rug(k.sub(0, 0, 0, "Rug"), 0, 0, 8.4, 8.4, lighter(th.accent2, 0.35), darker(th.accent2, 0.2), true)
		local chair = k.sub(-1.2, 1.4, math.rad(20), "Chair")
		local fabric = Kit.pick(rng, { rgb(60, 90, 70), rgb(120, 50, 50), rgb(70, 70, 110) })
		Pieces.armchair(chair, 0, 0, 0, fabric, C.WALNUT)
		for _, sx in { -1.45, 1.45 } do
			chair.box(sx, 3.2, 0.95, 0.5, 1.4, 1.2, fabric, M.Fabric)
		end
		local t = k.sub(2.4, 2.4, 0, "Table")
		t.disc(0, 2.4, 0, 2, 0.16, C.WALNUT, M.Wood)
		t.post(0, 0, 0.1, 2.35, 0.3, C.WALNUT, M.Wood)
		t.disc(0, 0.08, 0, 1.3, 0.16, C.WALNUT, M.Wood)
		Pieces.lamp(t, 0.2, 2.48, 0.2, C.BRASS)
		Pieces.mug(t, -0.5, 2.48, -0.3, C.WHITE)
		local stool = k.sub(-0.6, -2, 0, "Footstool")
		stool.box(0, 0.75, 0, 2.2, 0.9, 1.8, fabric, M.Fabric)
		for i = 0, 2 do
			stool.box(
				0.2,
				1.3 + i * 0.22,
				0,
				1.2 - i * 0.1,
				0.22,
				0.9,
				Kit.pick(rng, { rgb(150, 50, 50), rgb(50, 90, 140), rgb(220, 200, 150) })
			)
		end
		Pieces.floorLamp(k.sub(-3.3, 3.3, 0, "Lamp"), 0, 0, C.BRASS)
	end,
}

PROPS.globe = {
	w = 2.6,
	d = 2.6,
	h = 4.8,
	kind = "low",
	wall = false,
	build = function(k)
		k.disc(0, 0.1, 0, 2.2, 0.2, C.WALNUT, M.Wood, true)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			k.rod(
				Vector3.new(math.cos(a) * 0.9, 0.2, math.sin(a) * 0.9),
				Vector3.new(math.cos(a) * 0.5, 2.2, math.sin(a) * 0.5),
				0.18,
				C.WALNUT,
				M.Wood
			)
		end
		local c = Vector3.new(0, 3.4, 0)
		k.part(
			CFrame.new(c) * CFrame.Angles(0, math.rad(30), math.rad(23)),
			Vector3.new(0.12, 2.5, 2.5),
			C.BRASS,
			M.Metal,
			false,
			Enum.PartType.Cylinder
		)
		k.ball(c.X, c.Y, c.Z, 2.2, rgb(60, 110, 170), M.SmoothPlastic, "cover")
		for _, at in { Vector3.new(0.6, 0.4, -0.4), Vector3.new(-0.5, -0.2, -0.6), Vector3.new(0.1, -0.5, 0.7) } do
			k.ball(c.X + at.X, c.Y + at.Y, c.Z + at.Z, 1.0, rgb(150, 170, 100), M.SmoothPlastic)
		end
	end,
}

PROPS.libdesk = {
	w = 10,
	d = 4.6,
	h = 3.8,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local wood = rgb(110, 72, 48)
		k.box(0, 1.6, 0, 9.6, 3.2, 3, wood, M.Wood, true)
		k.box(0, 3.3, 0, 10, 0.2, 3.4, darker(wood, 0.2), M.Wood)
		k.box(0, 3.42, 0.2, 6, 0.05, 2.2, rgb(40, 90, 60), M.Leather)
		for i = -1, 1 do
			k.box(i * 3, 1.6, -1.52, 2.4, 2.2, 0.06, darker(wood, 0.25), M.Wood)
		end
		Pieces.lamp(k, -3.6, 3.4, 0.4, C.BRASS, rgb(120, 220, 140))
		for i = 0, 3 do
			k.box(
				3.4,
				3.5 + i * 0.26,
				0.3,
				1.4 - i * 0.1,
				0.25,
				1.0,
				Kit.pick(rng, { rgb(150, 50, 50), rgb(50, 90, 140), rgb(200, 170, 90) })
			)
		end
		k.box(1, 3.55, 0.6, 0.4, 0.3, 0.4, rgb(30, 30, 30))
		Pieces.monitor(k, -0.6, 3.4, 0.5, math.pi, 2, rng, "code", th.accent)
	end,
}

---------------------------------------------------------------- the hotel

-- a bed against the wall with its nightstands and lamps, a rug at its foot, a bench
PROPS.suite = {
	w = 12,
	d = 13,
	h = 4.8,
	kind = "low",
	wall = true,
	set = true,
	build = function(k, th, rng)
		Pieces.rug(k.sub(0, 0, 0, "Rug"), 0, -2.6, 10.6, 5, lighter(th.accent2, 0.5), th.accent2)
		local bed = k.sub(0, 0, 0, "Bed")
		local wood = Kit.pick(rng, { C.WALNUT, rgb(70, 50, 40), C.OAK })
		local cover = Kit.pick(rng, { th.accent2, rgb(200, 190, 170), rgb(70, 90, 120), rgb(150, 70, 70) })
		bed.box(0, 0.55, 1.6, 7.2, 1.1, 8.8, wood, M.Wood, true)
		bed.box(0, 1.5, 1.6, 6.9, 0.85, 8.5, C.WHITE, M.Fabric, "cover")
		bed.box(0, 2.0, 0.2, 7.1, 0.25, 5.8, cover, M.Fabric)
		bed.box(0, 2.0, 3.55, 7.0, 0.3, 1.1, C.WHITE, M.Fabric)
		bed.box(0, 2.08, -1.8, 7.3, 0.3, 1.6, lighter(cover, 0.25), M.Fabric)
		for _, sx in { -1.6, 1.6 } do
			bed.box(sx, 2.3, 4.9, 2.7, 0.75, 1.3, C.WHITE, M.Fabric)
			bed.part(
				CFrame.new(sx * 0.7, 2.5, 4.2) * CFrame.Angles(math.rad(-20), 0, 0),
				Vector3.new(1.6, 1.3, 0.4),
				th.accent,
				M.Fabric
			)
		end
		bed.box(0, 2.6, 6.1, 7.8, 4.4, 0.5, darker(cover, 0.25), M.Fabric, "cover")
		for i = -2, 2 do
			bed.box(i * 1.5, 2.6, 5.83, 0.06, 3.9, 0.06, darker(cover, 0.45))
		end
		for _, sx in { -1, 1 } do
			local n = k.sub(sx * 4.95, 5.1, 0, "Nightstand")
			n.box(0, 1.1, 0, 2.1, 2.2, 2, wood, M.Wood, true)
			n.box(0, 1.5, -1.01, 1.8, 0.05, 0.04, darker(wood, 0.4))
			n.box(0, 1.8, -1.04, 0.5, 0.1, 0.08, C.BRASS, M.Metal)
			Pieces.lamp(n, 0, 2.2, 0.1, C.BRASS)
		end
		local bench = k.sub(0, -4.9, 0, "Bench")
		bench.box(0, 1.25, 0, 5.6, 0.5, 1.6, darker(cover, 0.1), M.Fabric)
		for _, sx in { -2.5, 2.5 } do
			bench.box(sx, 0.5, 0, 0.25, 1.0, 1.3, C.BRASS, M.Metal)
		end
	end,
}

PROPS.wardrobe = {
	w = 6,
	d = 2.8,
	h = 8,
	kind = "high",
	wall = true,
	build = function(k, _th, rng)
		local wood = Kit.pick(rng, { C.WALNUT, rgb(70, 50, 40), C.OAK })
		k.box(0, 4, 0, 6, 7.6, 2.6, wood, M.Wood, true)
		k.box(0, 7.85, 0, 6.4, 0.3, 2.9, darker(wood, 0.15), M.Wood)
		k.box(0, 0.2, 0, 5.8, 0.4, 2.5, darker(wood, 0.3), M.Wood)
		for _, sx in { -1.45, 1.45 } do
			k.box(sx, 4.1, -1.32, 2.5, 6.6, 0.08, lighter(wood, 0.08), M.Wood)
			k.box(sx * 0.2, 4.2, -1.4, 0.12, 1.2, 0.12, C.BRASS, M.Metal)
		end
	end,
}

PROPS.tvconsole = {
	w = 8,
	d = 2.4,
	h = 6.2,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		local wood = Kit.pick(rng, { C.WALNUT, C.OAK })
		k.box(0, 1.25, 0, 8, 1.9, 2.2, wood, M.Wood, true)
		for _, sx in { -3.7, 3.7 } do
			k.box(sx, 0.15, 0, 0.3, 0.3, 1.9, C.BLACK, M.Metal)
		end
		for i = -1, 1 do
			k.box(i * 2.6, 1.25, -1.11, 2.4, 1.6, 0.04, darker(wood, 0.15), M.Wood)
			k.box(i * 2.6, 1.7, -1.16, 0.7, 0.1, 0.08, C.BRASS, M.Metal)
		end
		k.box(0, 2.28, 0.3, 1.6, 0.16, 0.8, C.BLACK)
		k.box(0, 2.6, 0.3, 0.3, 0.6, 0.2, C.BLACK)
		local tv = k.box(0, 4.2, 0.3, 6.2, 3.5, 0.2, C.BLACK)
		Kit.painting(Kit.gui(tv, Enum.NormalId.Front, 24, 1.1), rng, "landscape")
		k.post(-3.2, -0.2, 2.2, 3.4, 0.6, th.accent, M.Glass)
		Pieces.plant(k.lift(2.2), 3.2, 0, rng, 0.4)
	end,
}

PROPS.trolley = {
	w = 4,
	d = 6,
	h = 6.4,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		k.box(0, 0.75, 0, 3.6, 0.3, 5.6, C.BRASS, M.Metal, true)
		k.box(0, 0.92, 0, 3.4, 0.06, 5.4, rgb(150, 40, 50), M.Carpet)
		for _, sx in { -1.4, 1.4 } do
			for _, sz in { -2.4, 2.4 } do
				k.wheel(sx, 0.35, sz, 0.7, 0.3, C.BLACK, M.Rubber)
			end
		end
		for _, sz in { -2.6, 2.6 } do
			for _, sx in { -1.6, 1.6 } do
				k.post(sx, sz, 0.9, 6.0, 0.2, C.BRASS, M.Metal)
			end
			k.rod(Vector3.new(-1.6, 6, sz), Vector3.new(1.6, 6, sz), 0.2, C.BRASS, M.Metal)
		end
		k.rod(Vector3.new(0, 6, -2.6), Vector3.new(0, 6, 2.6), 0.2, C.BRASS, M.Metal)
		local cases = { rgb(150, 40, 50), rgb(40, 60, 90), rgb(190, 150, 90), th.accent2 }
		local y = 0.95
		for i = 0, 2 do
			local h = rng:NextNumber(0.9, 1.5)
			local c = Kit.pick(rng, cases)
			k.box(
				rng:NextNumber(-0.3, 0.3),
				y + h / 2,
				rng:NextNumber(-0.8, 0.8),
				2.8 - i * 0.4,
				h,
				3.8 - i * 0.6,
				c,
				M.Leather,
				"cover"
			)
			k.box(0, y + h + 0.08, 0, 0.8, 0.16, 0.2, C.BLACK)
			y += h
		end
	end,
}

PROPS.roomservice = {
	w = 3.4,
	d = 5,
	h = 3.8,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		k.box(0, 1.6, 0, 3, 2.4, 4.6, C.WHITE, M.Fabric, true)
		k.box(0, 2.85, 0, 3.2, 0.1, 4.8, C.WHITE, M.Fabric)
		for _, sz in { -1.9, 1.9 } do
			for _, sx in { -1.2, 1.2 } do
				k.wheel(sx, 0.25, sz, 0.5, 0.2, C.BLACK, M.Rubber)
			end
		end
		k.disc(0, 2.92, -0.8, 1.9, 0.06, C.WHITE, M.SmoothPlastic)
		k.ball(0, 2.92, -0.8, 1.6, C.CHROME, M.Metal)
		k.ball(0, 3.75, -0.8, 0.25, C.CHROME, M.Metal)
		k.disc(0.6, 2.92, 1.1, 1.1, 0.06, C.WHITE, M.SmoothPlastic)
		k.post(-0.8, 1.3, 2.9, 3.8, 0.3, rgb(200, 230, 240), M.Glass)
		k.ball(-0.8, 3.9, 1.3, 0.45, Kit.pick(rng, { rgb(220, 40, 60), rgb(255, 200, 80) }), M.Fabric)
	end,
}

PROPS.writingdesk = {
	w = 6,
	d = 5.2,
	h = 4.6,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		local wood = Kit.pick(rng, { C.WALNUT, C.OAK })
		k.box(0, 2.55, 1.0, 5.6, 0.22, 2.8, wood, M.Wood, true)
		k.box(0, 2.15, 0.2, 2.6, 0.6, 1.6, darker(wood, 0.1), M.Wood)
		for _, sx in { -2.5, 2.5 } do
			for _, sz in { -0.1, 2.1 } do
				k.post(sx, sz, 0, 2.45, 0.3, darker(wood, 0.2), M.Wood, true)
			end
		end
		Pieces.lamp(k, -2, 2.66, 1.6, C.BRASS)
		k.box(0.5, 2.7, 0.6, 1.4, 0.06, 1.8, C.PAPER)
		k.box(1.1, 2.72, 0.5, 0.1, 0.06, 1.2, C.BLACK)
		k.box(2, 2.75, 1.4, 0.9, 0.2, 0.7, C.BLACK)
		Pieces.diningChair(k, 0, -1.5, math.pi, wood, th.accent2)
	end,
}

-- two armchairs turned toward each other over a round table with a lamp
PROPS.armchairs = {
	w = 9,
	d = 6,
	h = 4.8,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		local fabric = Kit.pick(rng, { th.accent2, rgb(200, 180, 150), rgb(70, 90, 110) })
		Pieces.armchair(k.sub(-2.8, 0.4, math.rad(25), "Armchair"), 0, 0, 0, fabric, C.WALNUT)
		Pieces.armchair(k.sub(2.8, 0.4, math.rad(-25), "Armchair"), 0, 0, 0, fabric, C.WALNUT)
		local t = k.sub(0, -1.6, 0, "Table")
		t.disc(0, 2.3, 0, 2, 0.16, C.WALNUT, M.Wood)
		t.post(0, 0, 0.1, 2.25, 0.3, C.WALNUT, M.Wood)
		t.disc(0, 0.08, 0, 1.3, 0.16, C.WALNUT, M.Wood)
		Pieces.lamp(t, 0, 2.38, 0, C.BRASS)
	end,
}

---------------------------------------------------------------- the penthouse

-- an L-shaped sofa round a glass coffee table on a big rug, an armchair, an arc lamp
PROPS.sectional = {
	w = 17,
	d = 15,
	h = 3.4,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		Pieces.rug(k.sub(0, 0, 0, "Rug"), 0.5, 0, 15, 12.5, rgb(220, 214, 204), darker(th.accent2, 0.2))
		local fabric = Kit.pick(rng, { rgb(220, 214, 204), rgb(60, 56, 70), rgb(120, 110, 100) })
		Pieces.sofa(k.sub(0.8, 4.6, 0, "Sofa"), 0, 0, 0, 10, fabric, th.accent)
		Pieces.sofa(k.sub(-6.6, -0.6, -Q, "Sofa"), 0, 0, 0, 7, fabric, th.accent2)
		Pieces.armchair(k.sub(5.6, -3.4, math.rad(-140), "Armchair"), 0, 0, 0, th.accent2, C.BLACK)
		local t = k.sub(0.4, -0.3, 0, "Table")
		local glass = t.box(0, 1.3, 0, 5.2, 0.16, 3.2, rgb(210, 230, 240), M.Glass)
		glass.Transparency = 0.3
		for _, sx in { -2.4, 2.4 } do
			t.box(sx, 0.65, 0, 0.16, 1.3, 2.8, C.BRASS, M.Metal)
		end
		t.box(0, 0.4, 0, 4.6, 0.12, 2.6, rgb(40, 36, 44), M.Marble)
		t.ball(-1, 1.65, 0.2, 0.7, th.accent2, M.Glass)
		t.box(1.2, 1.5, -0.2, 1.4, 0.25, 1.0, th.accent, M.SmoothPlastic)
		t.box(1.2, 1.7, -0.2, 1.2, 0.18, 0.9, C.PAPER)
		local lamp = k.sub(-7.6, 5.6, 0, "Lamp")
		lamp.disc(0, 0.15, 0, 1.6, 0.3, rgb(240, 236, 230), M.Marble)
		local pts = {
			Vector3.new(0, 0.3, 0),
			Vector3.new(0.3, 4.5, 0),
			Vector3.new(1.6, 7.2, 0),
			Vector3.new(3.4, 7.6, 0),
			Vector3.new(4.6, 7.0, 0),
		}
		for i = 1, #pts - 1 do
			lamp.rod(pts[i], pts[i + 1], 0.2, C.BRASS, M.Metal)
		end
		lamp.ball(4.6, 6.7, 0, 1.6, C.BRASS, M.Metal)
		lamp.disc(4.6, 6.15, 0, 1.0, 0.1, C.GLOW, M.Neon)
	end,
}

-- a grand piano, its lid propped open, and its bench
PROPS.grandpiano = {
	w = 7,
	d = 11,
	h = 6.6,
	kind = "low",
	wall = false,
	build = function(k)
		local black = rgb(14, 12, 16)
		local case = k.box(0, 3.0, -0.1, 5.8, 1.2, 5, black, M.SmoothPlastic, true)
		case.Reflectance = 0.15
		k.post(0, 2.4, 2.4, 3.6, 5.8, black, M.SmoothPlastic, true).Reflectance = 0.15
		local hinge = k.at(2.9, 3.62, 0) * CFrame.Angles(0, 0, math.rad(-38))
		Kit.part(
			k.model,
			hinge * CFrame.new(-2.9, 0.06, -0.1),
			Vector3.new(5.8, 0.12, 5),
			black,
			M.SmoothPlastic,
			"cover"
		).Reflectance =
			0.2
		Kit.part(
			k.model,
			hinge * CFrame.new(-2.9, 0.06, 2.4) * Kit.UP,
			Vector3.new(0.12, 5.8, 5.8),
			black,
			M.SmoothPlastic,
			false,
			Enum.PartType.Cylinder
		).Reflectance =
			0.2
		k.rod(Vector3.new(-0.9, 3.6, 0.4), Vector3.new(-0.9, 6.5, 0.4), 0.1, black)
		local keys = k.box(0, 2.78, -3.1, 5.4, 0.3, 1.0, C.WHITE, M.SmoothPlastic)
		local art = Kit.gui(keys, Enum.NormalId.Top, 30)
		for i = 0, 35 do
			if i % 7 ~= 2 and i % 7 ~= 6 then
				Kit.rect(art, (i + 1) / 36 - 0.008, 0, 0.016, 0.6, rgb(14, 12, 16))
			end
		end
		for _, sx in { -2.8, 2.8 } do
			k.box(sx, 3.0, -3.1, 0.3, 0.8, 1.0, black)
		end
		k.box(0, 3.3, -2.6, 5.4, 0.5, 0.12, black)
		k.part(CFrame.new(0, 4.1, -2.4) * CFrame.Angles(math.rad(15), 0, 0), Vector3.new(2.8, 1.2, 0.08), black)
		for _, at in { { -2.4, -2.2 }, { 2.4, -2.2 }, { 0, 3.8 } } do
			k.post(at[1], at[2], 0, 2.4, 0.6, black, M.SmoothPlastic, true)
		end
		k.box(0, 1.2, -1.9, 1.2, 2.0, 0.3, black)
		k.box(0, 0.25, -2.15, 0.9, 0.1, 0.5, C.BRASS, M.Metal)
		k.box(0, 1.75, -4.9, 3, 0.45, 1.2, black, M.Leather)
		for _, sx in { -1.3, 1.3 } do
			k.box(sx, 0.78, -4.9, 0.25, 1.55, 1.0, black)
		end
	end,
}

PROPS.barlux = {
	w = 13,
	d = 8,
	h = 8,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		local wood = rgb(60, 40, 34)
		-- the back bar on the wall: a cabinet, lit glass shelves of bottles
		k.box(0, 1.6, 3.3, 12, 3.2, 1.4, wood, M.Wood, true)
		k.box(0, 3.3, 3.3, 12.2, 0.2, 1.5, rgb(40, 36, 44), M.Marble)
		k.box(0, 5.6, 3.95, 12, 4.4, 0.1, th.accent:Lerp(Color3.new(0, 0, 0), 0.55), M.Neon)
		for _, y in { 4.6, 6.4 } do
			local shelf = k.box(0, y, 3.5, 11.6, 0.1, 0.9, rgb(220, 236, 240), M.Glass)
			shelf.Transparency = 0.4
			local x = -5.4
			while x < 5.4 do
				local h = rng:NextNumber(0.9, 1.4)
				local b = k.post(
					x,
					3.5,
					y + 0.05,
					y + 0.05 + h,
					rng:NextNumber(0.32, 0.45),
					Kit.pick(
						rng,
						{ rgb(120, 60, 30), rgb(40, 110, 60), rgb(200, 210, 220), rgb(160, 40, 50), rgb(230, 190, 90) }
					),
					M.Glass
				)
				b.Transparency = 0.15
				x += rng:NextNumber(0.6, 1.0)
			end
		end
		-- the counter, its top, a foot rail and stools
		k.box(0, 1.7, -1.3, 12, 3.4, 1.8, wood, M.Wood, true)
		k.box(0, 0.12, -2.22, 12, 0.24, 0.08, th.accent, M.Neon)
		k.box(0, 3.5, -1.3, 12.4, 0.24, 2.4, rgb(240, 236, 230), M.Marble)
		k.rod(Vector3.new(-6, 0.6, -2.6), Vector3.new(6, 0.6, -2.6), 0.18, C.BRASS, M.Metal)
		for _, x in { -4.2, -1.4, 1.4, 4.2 } do
			Pieces.stool(k, x, -3.3, 3.0, darker(th.accent2, 0.3), C.BRASS)
		end
		for _, x in { -3, 0.5, 3.6 } do
			k.post(x + rng:NextNumber(-0.4, 0.4), -1.0, 3.62, 4.1, 0.35, rgb(220, 236, 240), M.Glass)
		end
	end,
}

-- a long dining table, six chairs, plates and candles
PROPS.diningset = {
	w = 13,
	d = 9.6,
	h = 3.8,
	kind = "low",
	wall = false,
	set = true,
	build = function(k, th, rng)
		local t = k.sub(0, 0, 0, "Table")
		local top = Kit.pick(rng, { rgb(240, 236, 230), rgb(40, 36, 44) })
		t.box(0, 2.5, 0, 9.4, 0.3, 4, top, M.Marble, true)
		for _, sx in { -3, 3 } do
			t.box(sx, 1.2, 0, 1, 2.4, 1.6, C.BRASS, M.Metal, true)
		end
		for _, sx in { -3.1, 0, 3.1 } do
			for _, sz in { -1, 1 } do
				Pieces.diningChair(
					k.sub(sx, sz * 3.2, if sz > 0 then 0 else math.pi, "Chair"),
					0,
					0,
					0,
					rgb(40, 34, 40),
					th.accent2
				)
				t.disc(sx, 2.68, sz * 1.25, 1.2, 0.06, C.WHITE, M.SmoothPlastic)
			end
		end
		for _, sx in { -1.3, 1.3 } do
			t.post(sx, 0, 2.65, 3.6, 0.2, C.BRASS, M.Metal)
			t.ball(sx, 3.75, 0, 0.3, rgb(255, 200, 120), M.Neon)
		end
		t.disc(0, 2.72, 0, 1.4, 0.16, C.BRASS, M.Metal)
	end,
}

PROPS.fireplace = {
	w = 10,
	d = 2.6,
	h = 7.6,
	kind = "high",
	wall = true,
	build = function(k, _th, rng)
		local stone = rgb(70, 66, 72)
		k.box(0, 3.8, 0.1, 10, 7.6, 2.2, stone, M.Slate, true)
		k.box(0, 1.6, -1.0, 6.4, 2.2, 0.1, rgb(16, 14, 18))
		for i = 0, 3 do
			k.part(
				CFrame.new(-1.8 + i * 1.2, 1.3, -1.1) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10))),
				Vector3.new(0.7, rng:NextNumber(0.8, 1.4), 0.1),
				if i % 2 == 0 then rgb(255, 140, 40) else rgb(255, 210, 90),
				M.Neon
			)
		end
		local glow = k.box(0, 0.75, -1.05, 6, 0.3, 0.1, rgb(255, 120, 40), M.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 150, 70)
		light.Range = 14
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = glow
		k.box(0, 4.2, -0.3, 10.6, 0.3, 2.8, C.WALNUT, M.Wood)
		k.post(-3.8, -0.8, 4.35, 5.6, 0.5, rgb(240, 236, 230), M.SmoothPlastic)
		k.post(-3.1, -0.8, 4.35, 5.0, 0.5, rgb(40, 36, 44), M.SmoothPlastic)
		local over = Kit.on(k.model, k.cf * CFrame.new(0, 0, -0.9))
		Pieces.picture(over, 0, 6.0, 5.4, 2.6, C.BRASS, rng)
	end,
}

PROPS.aquarium = {
	w = 9,
	d = 3.2,
	h = 7.4,
	kind = "high",
	wall = true,
	build = function(k, _th, rng)
		k.box(0, 1.5, 0, 9, 3, 3, C.WALNUT, M.Wood, true)
		local tank = k.box(0, 5.05, 0, 9, 4.1, 3, rgb(200, 230, 240), M.Glass, "cover")
		tank.Transparency = 0.7
		local water = k.box(0, 4.9, 0, 8.7, 3.6, 2.7, rgb(40, 130, 200))
		water.Transparency = 0.6
		k.box(0, 3.2, 0, 8.7, 0.3, 2.7, rgb(220, 200, 150), M.Sand)
		k.box(0, 7.2, 0, 9.2, 0.3, 3.2, C.BLACK)
		k.box(0, 7.0, -0.6, 8.4, 0.1, 0.3, rgb(140, 230, 255), M.Neon)
		for _ = 1, 3 do
			k.ball(
				rng:NextNumber(-3.8, 3.8),
				3.5,
				rng:NextNumber(-0.8, 0.8),
				rng:NextNumber(0.6, 1.2),
				rgb(120, 116, 110),
				M.Slate
			)
		end
		for _ = 1, 4 do
			k.box(
				rng:NextNumber(-4, 4),
				4.4,
				rng:NextNumber(-0.8, 0.8),
				0.25,
				rng:NextNumber(1.5, 2.6),
				0.1,
				rgb(60, 160, 80),
				M.Grass
			)
		end
		for _ = 1, 6 do
			local x, y, z = rng:NextNumber(-3.6, 3.6), rng:NextNumber(4, 6.4), rng:NextNumber(-0.9, 0.9)
			local color = Kit.pick(rng, { rgb(255, 140, 40), rgb(255, 220, 60), rgb(80, 180, 255), rgb(255, 90, 140) })
			local dir = if rng:NextNumber() < 0.5 then 1 else -1
			k.box(x, y, z, 0.6, 0.34, 0.12, color)
			k.box(x + dir * 0.4, y, z, 0.2, 0.3, 0.06, color)
		end
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Rate = 6
		bubbles.Lifetime = NumberRange.new(1.2, 1.8)
		bubbles.Speed = NumberRange.new(1.5, 2.5)
		bubbles.Size = NumberSequence.new(0.12)
		bubbles.Transparency = NumberSequence.new(0.3, 0.8)
		bubbles.Color = ColorSequence.new(rgb(220, 240, 255))
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.SpreadAngle = Vector2.new(5, 5)
		bubbles.Parent = k.box(2.6, 3.4, 0.6, 0.4, 0.2, 0.4, rgb(120, 116, 110), M.Slate)
	end,
}

---------------------------------------------------------------- the art studio

PROPS.easel = {
	w = 3.4,
	d = 3.4,
	h = 7,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		local wood = C.OAK
		for _, sx in { -1, 1 } do
			k.rod(Vector3.new(sx * 1.2, 0, -0.6), Vector3.new(sx * 0.25, 6.8, 0.4), 0.2, wood, M.Wood, true)
		end
		k.rod(Vector3.new(0, 0, 1.7), Vector3.new(0, 6.4, 0.45), 0.2, wood, M.Wood)
		k.part(CFrame.new(0, 2.7, -0.35) * CFrame.Angles(math.rad(8), 0, 0), Vector3.new(2.8, 0.15, 0.5), wood, M.Wood)
		local canvas = k.part(
			CFrame.new(0, 4.3, -0.15) * CFrame.Angles(math.rad(8), 0, 0),
			Vector3.new(3.1, 2.7, 0.14),
			C.WHITE,
			M.Fabric,
			"cover"
		)
		Kit.painting(Kit.gui(canvas, Enum.NormalId.Front, 30), rng)
		k.part(CFrame.new(0, 5.75, -0.02) * CFrame.Angles(math.rad(8), 0, 0), Vector3.new(0.8, 0.25, 0.3), wood, M.Wood)
		k.disc(0.6, 2.82, -0.4, 1.2, 0.06, rgb(220, 190, 140), M.Wood)
		for i = 0, 2 do
			k.disc(0.3 + i * 0.3, 2.86, -0.5, 0.22, 0.04, Color3.fromHSV(rng:NextNumber(), 0.8, 1))
		end
	end,
}

-- a white plinth with a sculpture on it
PROPS.plinth = {
	w = 2.8,
	d = 2.8,
	h = 6.4,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local white = rgb(240, 238, 232)
		k.box(0, 1.9, 0, 2.4, 3.8, 2.4, white, M.Plaster, true)
		k.box(0, 3.88, 0, 2.6, 0.16, 2.6, darker(white, 0.06), M.Plaster)
		local y = 3.96
		local kind = rng:NextInteger(1, 4)
		if kind == 1 then
			k.part(
				CFrame.new(0, y + 0.75, 0) * CFrame.Angles(math.rad(35), math.rad(45), 0),
				Vector3.new(1.1, 1.1, 1.1),
				th.accent,
				M.SmoothPlastic
			)
			k.ball(0, y + 1.9, 0, 0.9, th.accent2, M.SmoothPlastic)
			k.post(0, 0, y, y + 0.3, 1.2, C.BLACK, M.Metal)
		elseif kind == 2 then
			local stone = rgb(236, 232, 222)
			k.box(0, y + 0.35, 0, 1.7, 0.7, 0.9, stone, M.Marble)
			k.post(0, 0, y + 0.6, y + 1.1, 0.5, stone, M.Marble)
			k.ball(0, y + 1.5, 0, 1.0, stone, M.Marble)
			k.box(0, y + 1.5, -0.45, 0.14, 0.3, 0.2, stone, M.Marble)
		elseif kind == 3 then
			for i = 0, 7 do
				local a = i / 8 * math.pi * 2
				k.part(
					CFrame.new(0, y + 1.2, 0) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.85, 0),
					Vector3.new(0.75, 0.3, 0.3),
					C.BRASS,
					M.Metal
				)
			end
			k.post(0, 0, y, y + 0.35, 0.8, C.BLACK, M.Metal)
		else
			k.post(0, 0, y, y + 2.2, 0.16, C.BLACK, M.Metal)
			k.ball(0, y + 2.3, 0, 0.7, th.accent, M.Neon)
			k.ball(0.4, y + 1.4, 0, 0.5, th.accent2, M.SmoothPlastic)
			k.rod(Vector3.new(0, y + 1.0, 0), Vector3.new(0.6, y + 1.8, 0.3), 0.1, C.BLACK, M.Metal)
		end
	end,
}

PROPS.painttable = {
	w = 7.6,
	d = 4,
	h = 3.6,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		local wood = rgb(170, 140, 110)
		k.box(0, 2.5, 0, 7.4, 0.25, 3.6, wood, M.Wood, true)
		for _, sx in { -3.4, 3.4 } do
			for _, sz in { -1.5, 1.5 } do
				k.box(sx, 1.2, sz, 0.3, 2.4, 0.3, darker(wood, 0.2), M.Wood, true)
			end
		end
		k.box(0, 0.7, 0, 6.8, 0.16, 3, darker(wood, 0.1), M.Wood)
		local cloth = k.box(0, 2.65, 0, 6.6, 0.04, 3, rgb(236, 232, 220), M.Fabric)
		local art = Kit.gui(cloth, Enum.NormalId.Top, 12)
		for _ = 1, 10 do
			Kit.rect(
				art,
				rng:NextNumber(),
				rng:NextNumber(),
				rng:NextNumber(0.02, 0.06),
				rng:NextNumber(0.03, 0.1),
				Color3.fromHSV(rng:NextNumber(), 0.7, 0.95),
				1
			)
		end
		for _ = 1, 5 do
			local c = Color3.fromHSV(rng:NextNumber(), 0.8, 0.95)
			local x, z = rng:NextNumber(-3, 3), rng:NextNumber(-1.2, 1.2)
			k.post(x, z, 2.67, 3.2, 0.6, C.CHROME, M.Metal)
			k.disc(x, 3.22, z, 0.52, 0.04, c)
		end
		for _, x in { -2.6, 2.2 } do
			local jar = k.post(x, 1.2, 2.67, 3.4, 0.6, rgb(200, 230, 240), M.Glass)
			jar.Transparency = 0.4
			for i = 0, 2 do
				k.rod(
					Vector3.new(x, 2.8, 1.2),
					Vector3.new(x + (i - 1) * 0.25, 4.1, 1.2 + (i - 1) * 0.1),
					0.08,
					C.WALNUT,
					M.Wood
				)
			end
		end
		for i = 0, 2 do
			k.post(-2 + i * 1.6, 0.5, 0.78, 1.5, 1.0, Color3.fromHSV(rng:NextNumber(), 0.6, 0.9), M.Metal)
		end
	end,
}

-- a round dais for a model, a stool and a draped cloth, a lamp on a tripod
PROPS.modelstand = {
	w = 7.4,
	d = 7.4,
	h = 6.4,
	kind = "low",
	wall = false,
	build = function(k, th)
		k.disc(0, 0.6, 0, 6, 1.2, rgb(150, 110, 80), M.Wood, true)
		k.disc(0, 1.22, 0, 5.6, 0.06, darker(th.accent2, 0.1), M.Fabric)
		Pieces.stool(k, 0.6, 0.3, 3.4, rgb(150, 110, 80), C.BLACK)
		k.wedge(
			CFrame.new(-1.4, 1.8, -0.8) * CFrame.Angles(0, math.rad(40), 0),
			Vector3.new(1.8, 1.1, 2.2),
			rgb(236, 232, 220),
			M.Fabric
		)
		local lx, lz = 3.2, -2.8
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			k.rod(
				Vector3.new(lx + math.cos(a) * 0.9, 0, lz + math.sin(a) * 0.9),
				Vector3.new(lx, 3.4, lz),
				0.12,
				C.BLACK,
				M.Metal
			)
		end
		k.post(lx, lz, 3.4, 5.6, 0.16, C.BLACK, M.Metal)
		k.part(
			CFrame.lookAt(Vector3.new(lx, 5.8, lz), Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(1.0, 1.1, 1.1),
			C.BLACK,
			M.Metal,
			false,
			Enum.PartType.Cylinder
		)
		k.part(
			CFrame.lookAt(Vector3.new(lx, 5.8, lz), Vector3.new(0, 2.5, 0))
				* CFrame.new(0, 0, -0.52)
				* CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(0.05, 0.9, 0.9),
			rgb(255, 245, 220),
			M.Neon,
			false,
			Enum.PartType.Cylinder
		)
	end,
}

-- canvases leaning against the wall
PROPS.canvases = {
	w = 7,
	d = 2.4,
	h = 5.4,
	kind = "high",
	wall = true,
	build = function(k, _th, rng)
		local x = -2.6
		for i = 0, 2 do
			local w = rng:NextNumber(1.8, 2.8)
			local h = rng:NextNumber(2.4, 4.8)
			local c = k.part(
				CFrame.new(x + w / 2, h / 2 * math.cos(math.rad(12)), 0.6 - i * 0.35)
					* CFrame.Angles(math.rad(12), 0, 0),
				Vector3.new(w, h, 0.16),
				C.WHITE,
				M.Fabric,
				i == 0
			)
			if rng:NextNumber() < 0.75 then
				Kit.painting(Kit.gui(c, Enum.NormalId.Front, 20), rng)
			end
			x += w * 0.7
		end
	end,
}

PROPS.worktable = {
	w = 9,
	d = 5,
	h = 3.6,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		local wood = rgb(180, 150, 116)
		k.box(0, 2.5, 0, 8.6, 0.3, 4.6, wood, M.Wood, true)
		for _, sx in { -4, 4 } do
			for _, sz in { -2, 2 } do
				k.box(sx, 1.2, sz, 0.35, 2.4, 0.35, darker(wood, 0.25), M.Wood, true)
			end
		end
		for i = 0, 1 do
			local sheet = k.part(
				CFrame.new(-1.8 + i * 1.4, 2.67 + i * 0.01, rng:NextNumber(-0.6, 0.6))
					* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
				Vector3.new(3, 0.03, 2.2),
				C.PAPER
			)
			if i == 1 then
				Kit.painting(Kit.gui(sheet, Enum.NormalId.Top, 16), rng, "abstract")
			end
		end
		k.disc(2.4, 2.72, 0.4, 1.6, 0.14, C.STEEL, M.Metal)
		k.ball(2.4, 3.2, 0.4, 0.9, rgb(170, 110, 80), M.Ground)
		k.ball(2.5, 3.75, 0.4, 0.55, rgb(170, 110, 80), M.Ground)
		k.box(3.4, 2.7, -1.6, 1.6, 0.06, 0.3, C.BRASS, M.Metal)
	end,
}

return PROPS
