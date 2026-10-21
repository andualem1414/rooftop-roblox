--!strict
-- Furniture for the floors people come to for something: the laundrette, the gym, the canteen, the
-- greenhouse, the arcade and the nightclub.
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

local PROPS: { [string]: Prop } = {}

local CLOTHES =
	{ rgb(220, 70, 80), rgb(70, 120, 210), rgb(240, 200, 80), rgb(90, 180, 120), rgb(236, 236, 236), rgb(160, 90, 180) }

---------------------------------------------------------------- the laundrette

-- a front-loading washing machine (or, with dryer, one with a dryer stacked on it)
local function washer(k: Builder, y: number, th: Kit.Theme, rng: Random, dryer: boolean)
	local white = rgb(238, 240, 242)
	k.box(0, y + 1.8, 0, 3.3, 3.6, 3.1, white, M.Metal, true)
	k.box(0, y + 3.3, -1.56, 3.1, 0.55, 0.04, rgb(206, 212, 218))
	k.face(-0.9, y + 3.3, -1.6, 0.36, 0.1, C.DARK)
	k.box(0.6, y + 3.3, -1.6, 0.9, 0.24, 0.04, th.accent, M.Neon)
	local d = if dryer then 2.6 else 2.4
	k.face(0, y + 1.6, -1.58, d, 0.12, C.CHROME, M.Metal)
	k.face(0, y + 1.6, -1.5, d - 0.6, 0.04, Kit.pick(rng, CLOTHES), M.Fabric)
	local glass = k.face(0, y + 1.6, -1.66, d - 0.5, 0.05, rgb(60, 80, 110), M.Glass)
	glass.Transparency = 0.45
	k.box(0, y + 0.18, -1.56, 3.1, 0.36, 0.04, C.DARK)
end

PROPS.washer = {
	w = 3.4,
	d = 3.2,
	h = 3.6,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		washer(k, 0, th, rng, false)
	end,
}

PROPS.washstack = {
	w = 3.4,
	d = 3.2,
	h = 7.3,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		washer(k, 0, th, rng, false)
		washer(k, 3.65, th, rng, true)
	end,
}

-- a folding table: baskets, piles of folded clothes, a bottle of soap
PROPS.foldtable = {
	w = 10,
	d = 4,
	h = 3.8,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		k.box(0, 1.4, 0, 9.2, 2.8, 3.2, th.accent2, M.SmoothPlastic, true)
		k.box(0, 2.9, 0, 9.8, 0.2, 3.8, C.WHITE, M.SmoothPlastic, true)
		k.box(0, 0.15, 0, 9.2, 0.3, 3.2, C.DARK)
		for _, x in { -3.4, 1.4 } do
			local c = Kit.pick(rng, { rgb(80, 160, 230), rgb(250, 140, 180), rgb(250, 250, 250) })
			k.box(x, 3.5, 0, 2, 1.0, 1.5, c, M.Plastic)
			k.blob(x, 4.0, 0, 1.8, 0.7, 1.3, Kit.pick(rng, CLOTHES), M.Fabric)
		end
		for _, x in { -1.0, 3.6 } do
			local y = 3.0
			for _ = 1, rng:NextInteger(2, 4) do
				k.box(
					x + rng:NextNumber(-0.1, 0.1),
					y + 0.14,
					rng:NextNumber(-0.2, 0.2),
					1.6,
					0.28,
					1.2,
					Kit.pick(rng, CLOTHES),
					M.Fabric
				)
				y += 0.28
			end
		end
		k.post(-4.4, 1.2, 3.0, 4.1, 0.6, th.accent, M.Plastic)
		k.post(-4.4, 1.2, 4.1, 4.3, 0.3, C.WHITE, M.Plastic)
	end,
}

PROPS.laundrycart = {
	w = 2.8,
	d = 3.6,
	h = 4.8,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		for _, sx in { -1.1, 1.1 } do
			for _, sz in { -1.5, 1.5 } do
				k.post(sx, sz, 0.3, 3.3, 0.12, C.CHROME, M.Metal)
				k.ball(sx, 0.2, sz, 0.35, C.BLACK, M.Rubber)
			end
		end
		k.box(0, 2.5, 0, 2.3, 1.6, 3.1, rgb(200, 190, 170), M.Fabric, true)
		k.blob(0, 3.3, 0, 2.0, 0.8, 2.6, Kit.pick(rng, CLOTHES), M.Fabric)
		for _, sz in { -1.5, 1.5 } do
			k.post(0, sz, 3.3, 4.7, 0.12, C.CHROME, M.Metal)
		end
		k.rod(Vector3.new(0, 4.7, -1.5), Vector3.new(0, 4.7, 1.5), 0.12, C.CHROME, M.Metal)
		for _, z in { -0.6, 0.5 } do
			k.box(0, 3.9, z, 1.6, 1.4, 0.1, Kit.pick(rng, CLOTHES), M.Fabric)
		end
	end,
}

-- a bench of three plastic seats on one beam
PROPS.seats = {
	w = 7.6,
	d = 2.8,
	h = 3.2,
	kind = "low",
	wall = true,
	build = function(k, th)
		k.box(0, 1.15, 0, 7.4, 0.25, 0.4, C.STEEL, M.Metal, true)
		for _, sx in { -3.2, 3.2 } do
			k.box(sx, 0.55, 0, 0.25, 1.1, 1.8, C.STEEL, M.Metal, true)
		end
		for _, sx in { -2.4, 0, 2.4 } do
			k.box(sx, 1.45, -0.2, 2.2, 0.22, 1.8, th.accent2, M.Plastic)
			k.part(
				CFrame.new(sx, 2.35, 0.75) * CFrame.Angles(math.rad(10), 0, 0),
				Vector3.new(2.2, 1.5, 0.18),
				th.accent2,
				M.Plastic
			)
		end
	end,
}

PROPS.soapvend = {
	w = 3.2,
	d = 2.8,
	h = 6.6,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		k.box(0, 3.2, 0, 3, 6.4, 2.6, th.accent2, M.Metal, true)
		local window = k.box(-0.3, 3.8, -1.32, 2, 3.4, 0.05, C.DARK)
		local art = Kit.gui(window, Enum.NormalId.Front, 30, 1.2)
		for row = 0, 3 do
			for col = 0, 2 do
				Kit.rect(
					art,
					0.08 + col * 0.3,
					0.06 + row * 0.24,
					0.24,
					0.16,
					Kit.pick(rng, { th.accent, rgb(255, 255, 255), rgb(255, 200, 80), rgb(120, 200, 255) }),
					0.15
				)
			end
			Kit.rect(art, 0.04, 0.23 + row * 0.24, 0.92, 0.015, C.STEEL)
		end
		k.box(1.1, 3.6, -1.32, 0.6, 1.2, 0.05, C.BLACK)
		k.box(0, 1.2, -1.32, 2.2, 0.6, 0.06, C.BLACK)
		Pieces.sign(Kit.on(k.model, k.cf * CFrame.new(0, 0, -1.3)), 0, 6.0, 2.6, 0.6, "SOAP", C.WHITE, th.accent2)
	end,
}

---------------------------------------------------------------- the gym

PROPS.treadmill = {
	w = 3.6,
	d = 7.6,
	h = 5.2,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local dark = rgb(50, 52, 60)
		k.box(0, 0.45, 0.4, 3.2, 0.6, 6.6, dark, M.Metal, true)
		k.box(0, 0.8, 0.6, 2.4, 0.08, 6.0, C.BLACK, M.Rubber)
		for _, sx in { -1.4, 1.4 } do
			k.box(sx, 0.82, 0.6, 0.4, 0.12, 6, C.STEEL, M.Metal)
			k.rod(Vector3.new(sx * 0.9, 1.0, -2.6), Vector3.new(sx * 0.8, 4.3, -3.2), 0.22, dark, M.Metal)
			k.rod(Vector3.new(sx * 1.25, 3.9, -3.0), Vector3.new(sx * 1.25, 3.9, -1.6), 0.18, C.BLACK, M.Rubber)
		end
		k.box(0, 0.85, -2.6, 3.2, 0.8, 1.2, dark, M.Metal)
		k.rod(Vector3.new(-1.25, 3.9, -3.0), Vector3.new(1.25, 3.9, -3.0), 0.18, C.BLACK, M.Rubber)
		local console = k.part(
			CFrame.new(0, 4.6, -3.3) * CFrame.Angles(math.rad(25), 0, 0),
			Vector3.new(2.8, 1.1, 0.4),
			dark,
			M.Metal
		)
		local screen = Kit.gui(console, Enum.NormalId.Front, 40, 1.3)
		Kit.screen(screen, rng, "graph", th.accent)
	end,
}

-- a flat bench with a loaded barbell on its uprights
PROPS.weightbench = {
	w = 7.6,
	d = 5.6,
	h = 4.4,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		k.box(0, 0.8, 0.4, 1.0, 1.2, 4.2, C.STEEL, M.Metal, true)
		k.box(0, 1.6, 0.4, 1.5, 0.45, 4.6, C.BLACK, M.Leather)
		for _, z in { -1.6, 2.4 } do
			k.box(0, 0.1, z, 2.6, 0.2, 0.4, C.BLACK, M.Metal)
		end
		for _, sx in { -1.4, 1.4 } do
			k.post(sx, -2.3, 0, 4.3, 0.3, C.STEEL, M.Metal, true)
			k.box(sx, 4.0, -2.15, 0.3, 0.25, 0.4, th.accent, M.Metal)
		end
		k.rod(Vector3.new(-3.7, 4.1, -2.3), Vector3.new(3.7, 4.1, -2.3), 0.2, C.CHROME, M.Metal)
		local plates = { rgb(30, 30, 34), th.accent, rgb(40, 90, 190) }
		local plate = Kit.pick(rng, plates)
		for _, s in { -1, 1 } do
			k.wheel(s * 2.55, 4.1, -2.3, 2.3, 0.3, plate, M.Rubber)
			k.wheel(s * 2.9, 4.1, -2.3, 1.8, 0.28, darker(plate, 0.2), M.Rubber)
			k.wheel(s * 3.15, 4.1, -2.3, 0.6, 0.15, C.CHROME, M.Metal)
		end
	end,
}

-- a power rack: a cage of uprights, a pull-up bar, a barbell racked, plates on its pegs
PROPS.powerrack = {
	w = 7.8,
	d = 6.4,
	h = 8.4,
	kind = "high",
	wall = false,
	build = function(k, th)
		local frame = rgb(34, 34, 40)
		for _, sx in { -2.6, 2.6 } do
			for _, sz in { -2.4, 2.4 } do
				k.box(sx, 4.1, sz, 0.35, 8.2, 0.35, frame, M.Metal, true)
			end
			k.box(sx, 0.1, 0, 0.5, 0.2, 5.4, frame, M.Metal)
			k.box(sx, 8.2, 0, 0.35, 0.35, 5.2, frame, M.Metal)
			k.rod(Vector3.new(sx, 2.6, -2.6), Vector3.new(sx, 2.6, 2.6), 0.18, C.CHROME, M.Metal)
		end
		for _, sz in { -2.4, 2.4 } do
			k.box(0, 8.2, sz, 5.6, 0.35, 0.35, frame, M.Metal)
		end
		k.rod(Vector3.new(-2.8, 7.8, -2.65), Vector3.new(2.8, 7.8, -2.65), 0.2, C.CHROME, M.Metal)
		k.rod(Vector3.new(-3.8, 4.6, -2.4), Vector3.new(3.8, 4.6, -2.4), 0.2, C.CHROME, M.Metal)
		for _, s in { -1, 1 } do
			k.wheel(s * 3.1, 4.6, -2.4, 2.4, 0.35, th.accent, M.Rubber)
			k.wheel(s * 3.45, 4.6, -2.4, 1.9, 0.3, rgb(30, 30, 34), M.Rubber)
			k.rod(Vector3.new(s * 2.6, 2.0, 2.4), Vector3.new(s * 3.6, 2.0, 2.4), 0.25, C.CHROME, M.Metal)
			k.wheel(s * 3.2, 2.0, 2.4, 2.6, 0.3, rgb(30, 30, 34), M.Rubber)
			k.wheel(s * 3.5, 2.0, 2.4, 2.2, 0.28, rgb(40, 90, 190), M.Rubber)
		end
		k.box(0, 0.05, 0, 5.4, 0.1, 5, darker(th.floor, 0.5), M.Rubber)
	end,
}

-- a two-tier rack of dumbbells, small to big
PROPS.dumbbells = {
	w = 9,
	d = 2.8,
	h = 3.4,
	kind = "low",
	wall = true,
	build = function(k, th)
		local frame = rgb(34, 34, 40)
		for _, sx in { -4.3, 4.3 } do
			k.box(sx, 1.5, 0, 0.3, 3, 2.6, frame, M.Metal, true)
		end
		for _, t in { { y = 1.3, z = -0.55 }, { y = 2.5, z = 0.55 } } do
			k.box(0, t.y - 0.25, t.z, 8.4, 0.15, 0.9, frame, M.Metal, true)
			for i = 0, 3 do
				local x = -3.1 + i * 2.05
				local d = 0.75 + i * 0.12
				k.rod(
					Vector3.new(x, t.y + 0.25, t.z - 0.55),
					Vector3.new(x, t.y + 0.25, t.z + 0.55),
					0.18,
					C.CHROME,
					M.Metal
				)
				for _, s in { -1, 1 } do
					k.face(
						x,
						t.y + 0.25,
						t.z + s * 0.45,
						d,
						0.3,
						if i % 2 == 0 then rgb(30, 30, 34) else th.accent,
						M.Rubber
					)
				end
			end
		end
	end,
}

PROPS.punchbag = {
	w = 4,
	d = 3.8,
	h = 8.4,
	kind = "high",
	wall = false,
	build = function(k, th)
		local frame = rgb(34, 34, 40)
		k.box(-1.5, 0.12, 0, 0.6, 0.25, 3.4, frame, M.Metal)
		k.box(-0.6, 0.12, 0, 2.4, 0.25, 0.6, frame, M.Metal)
		k.wheel(-1.5, 0.6, 1.0, 1.2, 0.3, C.BLACK, M.Rubber)
		k.box(-1.5, 4.2, 0, 0.35, 8.2, 0.35, frame, M.Metal, true)
		k.box(-0.5, 8.1, 0, 2.3, 0.3, 0.3, frame, M.Metal)
		k.rod(Vector3.new(0.4, 8.0, 0), Vector3.new(0.4, 7.0, 0), 0.08, C.STEEL, M.Metal)
		k.post(0.4, 0, 3.0, 7.0, 1.7, th.accent, M.Leather, "cover")
		k.disc(0.4, 7.0, 0, 1.6, 0.15, C.BLACK, M.Leather)
		k.disc(0.4, 3.0, 0, 1.6, 0.15, C.BLACK, M.Leather)
		k.disc(0.4, 5.0, 0, 1.76, 0.3, C.WHITE, M.Leather)
	end,
}

-- a boxing ring: a raised canvas, corner posts and pads, three ropes a side
PROPS.ring = {
	w = 18,
	d = 18,
	h = 5.8,
	kind = "low",
	wall = false,
	build = function(k, th)
		k.box(0, 0.65, 0, 16, 1.3, 16, rgb(30, 40, 80), M.Fabric, true)
		local canvas = k.box(0, 1.33, 0, 16.4, 0.1, 16.4, rgb(226, 222, 214), M.Fabric)
		local art = Kit.gui(canvas, Enum.NormalId.Top, 8)
		Kit.rect(art, 0.35, 0.35, 0.3, 0.3, th.accent, 1)
		Kit.rect(art, 0.37, 0.37, 0.26, 0.26, rgb(226, 222, 214), 1)
		Kit.text(art, "ROOFTOP", 0.38, 0.45, 0.24, 0.1, th.accent, Enum.Font.LuckiestGuy)
		local corners = { { -7.6, -7.6 }, { 7.6, -7.6 }, { 7.6, 7.6 }, { -7.6, 7.6 } }
		for i, c in corners do
			k.post(c[1], c[2], 1.3, 5.6, 0.5, C.BLACK, M.Metal, true)
			k.box(c[1], 3.9, c[2], 0.75, 3.2, 0.75, if i % 2 == 0 then th.accent else rgb(40, 90, 200), M.Leather)
		end
		local ropes = { th.accent, C.WHITE, rgb(40, 90, 200) }
		for i = 1, 4 do
			local a, b = corners[i], corners[i % 4 + 1]
			for r, y in { 2.6, 3.6, 4.6 } do
				k.rod(Vector3.new(a[1], y, a[2]), Vector3.new(b[1], y, b[2]), 0.18, ropes[r], M.Fabric)
			end
		end
		k.box(8.6, 0.4, 8.6, 1.2, 0.8, 2.2, C.DARK, M.Metal)
		k.box(8.6, 0.2, 9.4, 1.2, 0.4, 0.8, C.DARK, M.Metal)
	end,
}

PROPS.lockers = {
	w = 9,
	d = 2.6,
	h = 7,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local body = Kit.pick(rng, { rgb(60, 90, 150), rgb(150, 150, 156), th.accent2, rgb(170, 50, 50) })
		local front = k.box(0, 3.5, 0, 9, 7, 2.6, body, M.Metal, true)
		local art = Kit.gui(front, Enum.NormalId.Front, 16)
		for i = 0, 4 do
			local x = i / 5
			Kit.rect(art, x, 0, 0.006, 1, darker(body, 0.5))
			for v = 0, 2 do
				Kit.rect(art, x + 0.05, 0.05 + v * 0.025, 0.1, 0.012, darker(body, 0.45))
			end
			Kit.rect(art, x + 0.07, 0.16, 0.06, 0.04, C.WHITE)
			Kit.text(art, tostring(rng:NextInteger(10, 99)), x + 0.07, 0.16, 0.06, 0.04, C.BLACK, Enum.Font.GothamBold)
		end
		for i = 0, 4 do
			k.box(-3.2 + i * 1.8, 3.6, -1.34, 0.12, 0.7, 0.1, C.CHROME, M.Metal)
		end
		k.box(0, 0.2, 0, 9, 0.4, 2.6, C.DARK)
	end,
}

PROPS.kettlebells = {
	w = 4.6,
	d = 2.2,
	h = 1.8,
	kind = "low",
	wall = false,
	build = function(k, th)
		for i, x in { -1.5, 0, 1.5 } do
			local d = 0.9 + i * 0.15
			local c = if i == 2 then th.accent else rgb(30, 30, 34)
			k.ball(x, d / 2, 0, d, c, M.Metal)
			for _, s in { -1, 1 } do
				k.post(x + s * 0.3, 0, d * 0.75, d + 0.4, 0.12, c, M.Metal)
			end
			k.rod(Vector3.new(x - 0.36, d + 0.4, 0), Vector3.new(x + 0.36, d + 0.4, 0), 0.15, c, M.Metal)
		end
	end,
}

---------------------------------------------------------------- the canteen

-- the serving counter: food in its wells under a glass guard, a tray rail, trays and a till
PROPS.servery = {
	w = 14,
	d = 4.4,
	h = 5.6,
	kind = "low",
	wall = true,
	build = function(k, th, rng)
		local steel = rgb(196, 200, 206)
		k.box(0, 1.5, 0.2, 13.6, 3, 3.6, steel, M.Metal, true)
		k.box(0, 1.6, -1.62, 13.6, 2.4, 0.08, th.accent2, M.SmoothPlastic)
		k.box(0, 0.2, -1.6, 13.6, 0.4, 0.1, C.DARK)
		k.box(0, 3.07, 0.2, 14, 0.15, 4, lighter(steel, 0.3), M.Metal)
		local foods = {
			rgb(230, 120, 50),
			rgb(110, 170, 70),
			rgb(240, 210, 110),
			rgb(150, 80, 50),
			rgb(220, 60, 50),
			rgb(250, 240, 220),
		}
		for i = 0, 5 do
			local x = -5 + i * 1.9
			k.box(x, 3.12, 0.3, 1.7, 0.08, 1.4, rgb(70, 74, 82), M.Metal)
			k.blob(x, 3.2, 0.3, 1.5, 0.35, 1.2, Kit.pick(rng, foods), M.SmoothPlastic)
		end
		local guard = k.part(
			CFrame.new(0, 4.2, -0.6) * CFrame.Angles(math.rad(35), 0, 0),
			Vector3.new(12.6, 1.8, 0.08),
			rgb(220, 240, 250),
			M.Glass,
			"cover"
		)
		guard.Transparency = 0.6
		for _, x in { -6.2, 0, 6.2 } do
			k.post(x, 0.0, 3.1, 5.2, 0.15, C.CHROME, M.Metal)
		end
		local shelf = k.box(0, 5.25, 0.1, 12.8, 0.08, 1.0, rgb(220, 240, 250), M.Glass)
		shelf.Transparency = 0.4
		k.box(0, 2.5, -2.05, 13.6, 0.12, 0.8, C.CHROME, M.Metal)
		for i = 0, 3 do
			k.box(-6, 3.22 + i * 0.12, 0.5, 1.6, 0.1, 2.2, Kit.pick(rng, { th.accent, th.accent2, rgb(60, 60, 70) }))
		end
		local till = k.box(6, 3.6, 0.6, 1.4, 0.9, 1.2, C.DARK)
		Kit.screen(Kit.gui(till, Enum.NormalId.Front, 40, 1.2), rng, "chart", th.accent)
	end,
}

-- a drinks fridge with a glass door, lit inside
PROPS.glassfridge = {
	w = 4.2,
	d = 3.2,
	h = 7.6,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		k.box(0, 3.8, 0, 4, 7.6, 3, C.WHITE, M.Metal, true)
		local inside = k.box(0, 4.0, -1.3, 3.4, 5.8, 0.1, rgb(240, 248, 255))
		local art = Kit.gui(inside, Enum.NormalId.Front, 24, 1.4)
		Kit.rect(art, 0, 0, 1, 1, rgb(220, 236, 248))
		for shelf = 0, 3 do
			local y = 0.04 + shelf * 0.25
			Kit.rect(art, 0, y + 0.2, 1, 0.012, C.STEEL)
			for b = 0, 6 do
				local c = Kit.pick(
					rng,
					{ rgb(220, 40, 40), rgb(60, 140, 60), rgb(250, 190, 40), rgb(60, 120, 220), rgb(250, 120, 40) }
				)
				Kit.rect(art, 0.04 + b * 0.135, y + 0.05, 0.09, 0.15, c, 0.2)
				Kit.rect(art, 0.065 + b * 0.135, y + 0.01, 0.04, 0.05, c)
			end
		end
		local door = k.box(0, 4.0, -1.52, 3.6, 6.2, 0.08, rgb(220, 240, 250), M.Glass)
		door.Transparency = 0.6
		k.box(1.6, 4.0, -1.62, 0.15, 2.6, 0.15, C.CHROME, M.Metal)
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(0, 0, -1.5)),
			0,
			7.25,
			3.6,
			0.6,
			"COLD DRINKS",
			th.accent2,
			C.WHITE,
			1.4
		)
		k.box(0, 0.4, -1.52, 3.6, 0.6, 0.06, C.DARK)
	end,
}

PROPS.vending = {
	w = 4.2,
	d = 3.6,
	h = 7.6,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local body = Kit.pick(rng, { th.accent2, rgb(200, 40, 50), rgb(40, 60, 120) })
		k.box(0, 3.8, 0, 4.2, 7.6, 3.4, body, M.Metal, true)
		local window = k.box(-0.4, 4.4, -1.72, 2.8, 5, 0.06, C.DARK)
		local art = Kit.gui(window, Enum.NormalId.Front, 24, 1.3)
		Kit.rect(art, 0, 0, 1, 1, rgb(30, 32, 40))
		for row = 0, 4 do
			local y = 0.03 + row * 0.19
			for col = 0, 3 do
				Kit.rect(
					art,
					0.05 + col * 0.235,
					y + 0.02,
					0.19,
					0.12,
					Kit.pick(rng, {
						rgb(250, 200, 40),
						rgb(220, 50, 50),
						rgb(60, 160, 230),
						rgb(250, 130, 40),
						rgb(130, 200, 80),
						rgb(160, 90, 200),
					}),
					0.1
				)
			end
			Kit.rect(art, 0.02, y + 0.155, 0.96, 0.012, C.STEEL)
		end
		local glass = k.box(-0.4, 4.4, -1.76, 2.9, 5.1, 0.04, rgb(220, 240, 250), M.Glass)
		glass.Transparency = 0.7
		local pad = k.box(1.55, 4.6, -1.72, 0.7, 1.4, 0.06, C.DARK)
		local keys = Kit.gui(pad, Enum.NormalId.Front, 40, 1.2)
		for r = 0, 3 do
			for c = 0, 2 do
				Kit.rect(keys, 0.1 + c * 0.3, 0.1 + r * 0.22, 0.2, 0.14, C.STEEL)
			end
		end
		k.box(-0.4, 1.1, -1.72, 2.6, 0.7, 0.06, C.BLACK)
		k.box(0, 7.25, -1.72, 4.0, 0.3, 0.06, th.accent, M.Neon)
	end,
}

-- a square table, four chairs, trays
PROPS.dining = {
	w = 7.6,
	d = 7.6,
	h = 3.2,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local top = Kit.pick(rng, { C.WHITE, C.OAK, lighter(th.accent2, 0.5) })
		k.box(0, 2.5, 0, 3.8, 0.2, 3.8, top, M.SmoothPlastic, true)
		k.post(0, 0, 0.1, 2.4, 0.4, C.STEEL, M.Metal, true)
		k.disc(0, 0.06, 0, 2.2, 0.12, C.STEEL, M.Metal)
		for i = 0, 3 do
			local a = i * Q
			Pieces.simpleChair(k, math.sin(a) * 2.7, math.cos(a) * 2.7, a, C.STEEL, th.accent2)
		end
		for _ = 1, rng:NextInteger(1, 2) do
			local x, z = rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)
			k.box(x, 2.65, z, 1.6, 0.08, 1.2, Kit.pick(rng, { th.accent, th.accent2 }))
			k.disc(x - 0.3, 2.72, z, 0.8, 0.06, C.WHITE)
			k.blob(
				x - 0.3,
				2.8,
				z,
				0.6,
				0.18,
				0.5,
				Kit.pick(rng, { rgb(230, 120, 50), rgb(110, 170, 70), rgb(240, 210, 110) })
			)
			Pieces.mug(k, x + 0.5, 2.7, z, C.WHITE)
		end
	end,
}

-- a long table with its benches
PROPS.longtable = {
	w = 13,
	d = 7,
	h = 3,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local top = Kit.pick(rng, { C.OAK, C.WHITE })
		k.box(0, 2.5, 0, 12, 0.2, 3, top, M.Wood, true)
		for _, sz in { -2.6, 2.6 } do
			k.box(0, 1.5, sz, 12, 0.2, 1.2, top, M.Wood, true)
		end
		for _, sx in { -5, 0, 5 } do
			k.box(sx, 1.2, 0, 0.3, 2.4, 0.3, C.STEEL, M.Metal, true)
			k.box(sx, 0.9, 0, 0.25, 0.25, 6.4, C.STEEL, M.Metal)
			for _, sz in { -2.6, 2.6 } do
				k.box(sx, 0.7, sz, 0.25, 1.4, 0.25, C.STEEL, M.Metal)
			end
		end
		for _ = 1, 3 do
			local x = rng:NextNumber(-5, 5)
			k.box(x, 2.65, rng:NextNumber(-0.6, 0.6), 1.6, 0.08, 1.2, th.accent)
			Pieces.mug(k, x + 0.4, 2.65, 0.2, C.WHITE)
		end
	end,
}

PROPS.bins = {
	w = 6.8,
	d = 2.2,
	h = 3.8,
	kind = "low",
	wall = true,
	build = function(k)
		local bins = { { rgb(40, 100, 200), "PAPER" }, { rgb(60, 160, 80), "GLASS" }, { rgb(90, 94, 104), "WASTE" } }
		for i, b in bins do
			local x = (i - 2) * 2.2
			k.box(x, 1.55, 0, 2, 3.1, 1.8, b[1] :: Color3, M.Plastic, true)
			k.box(x, 3.2, 0, 2.1, 0.2, 1.9, darker(b[1] :: Color3, 0.25), M.Plastic)
			Pieces.sign(
				Kit.on(k.model, k.cf * CFrame.new(x, 0, -0.9)),
				0,
				2.4,
				1.4,
				0.5,
				b[2] :: string,
				C.WHITE,
				b[1] :: Color3
			)
		end
	end,
}

---------------------------------------------------------------- the greenhouse

-- a raised bed of vegetables or flowers under a grow light
PROPS.raisedbed = {
	w = 10.4,
	d = 4.4,
	h = 6.8,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local wood = rgb(150, 110, 70)
		k.box(0, 0.8, 0, 9.6, 1.6, 3.6, rgb(80, 58, 44), M.Ground, true)
		for _, sz in { -1.95, 1.95 } do
			k.box(0, 0.9, sz, 10.2, 1.8, 0.3, wood, M.WoodPlanks)
		end
		for _, sx in { -4.95, 4.95 } do
			k.box(sx, 0.9, 0, 0.3, 1.8, 3.6, wood, M.WoodPlanks)
		end
		local kind = rng:NextInteger(1, 4)
		if kind == 1 then
			for row = -1, 1, 2 do
				for i = 0, 4 do
					k.blob(
						-3.6 + i * 1.8,
						1.9,
						row * 0.8,
						1.3,
						0.8,
						1.3,
						if i % 2 == 0 then rgb(120, 190, 80) else rgb(80, 150, 70),
						M.Grass
					)
				end
			end
		elseif kind == 2 then
			for i = 0, 3 do
				local x = -3.3 + i * 2.2
				k.post(x, 0, 1.6, 4.8, 0.12, rgb(150, 120, 80), M.Wood)
				k.blob(x, 3.4, 0, 1.6, 2.6, 1.4, rgb(60, 130, 60), M.Grass, "cover")
				for _ = 1, 2 do
					k.ball(
						x + rng:NextNumber(-0.6, 0.6),
						rng:NextNumber(2.6, 4.2),
						-0.65,
						0.5,
						rgb(220, 50, 40),
						M.SmoothPlastic
					)
				end
			end
		elseif kind == 3 then
			for i = 0, 9 do
				local x, z = -4 + i * 0.9, (if i % 2 == 0 then -0.6 else 0.6)
				local h = rng:NextNumber(2.2, 3.0)
				k.post(x, z, 1.6, h, 0.1, rgb(70, 140, 60), M.Grass)
				k.ball(
					x,
					h,
					z,
					0.55,
					Kit.pick(rng, { th.accent, th.accent2, rgb(255, 230, 90), rgb(250, 250, 250), rgb(255, 120, 60) }),
					M.Fabric
				)
			end
			k.blob(0, 1.75, 0, 8.8, 0.5, 2.8, rgb(70, 140, 60), M.Grass)
		else
			for i = 0, 5 do
				k.blob(
					-3.8 + i * 1.5,
					2.0,
					if i % 2 == 0 then -0.5 else 0.5,
					1.5,
					1.0,
					1.5,
					if i % 2 == 0 then rgb(110, 150, 120) else rgb(140, 90, 150),
					M.Grass
				)
			end
		end
		for _, sx in { -4.6, 4.6 } do
			k.post(sx, 0, 1.6, 6.5, 0.15, C.STEEL, M.Metal)
		end
		k.box(0, 6.5, 0, 9.6, 0.3, 0.7, C.DARK, M.Metal)
		k.box(0, 6.32, 0, 9.2, 0.08, 0.5, th.accent, M.Neon)
	end,
}

-- a lemon or orange tree in a big pot
PROPS.fruittree = {
	w = 4.8,
	d = 4.8,
	h = 9,
	kind = "high",
	wall = false,
	build = function(k, _th, rng)
		local terra = C.TERRA
		k.post(0, 0, 0, 2.6, 3.6, terra, M.Slate, true)
		k.disc(0, 2.45, 0, 3.9, 0.3, darker(terra, 0.1), M.Slate)
		k.disc(0, 2.58, 0, 3.4, 0.1, rgb(70, 50, 40), M.Ground)
		k.rod(Vector3.new(0, 2.5, 0), Vector3.new(0.3, 5.4, 0.1), 0.45, C.WALNUT, M.Wood)
		k.rod(Vector3.new(0.3, 5.2, 0.1), Vector3.new(-0.6, 6.4, 0.3), 0.3, C.WALNUT, M.Wood)
		local fruit = if rng:NextNumber() < 0.5 then rgb(250, 220, 60) else rgb(250, 150, 40)
		local crowns =
			{ { 0.3, 6.8, 0.1, 3.8, 2.8, 3.6 }, { -0.9, 7.2, 0.4, 2.6, 2.2, 2.6 }, { 1.0, 7.5, -0.4, 2.4, 2.0, 2.2 } }
		for i, c in crowns do
			k.blob(
				c[1],
				c[2],
				c[3],
				c[4],
				c[5],
				c[6],
				if i == 1 then C.LEAF2 else C.LEAF,
				M.Grass,
				if i == 1 then "cover" else false
			)
		end
		for _ = 1, 8 do
			local c = crowns[rng:NextInteger(1, 3)]
			local a = rng:NextNumber(0, math.pi * 2)
			local e = rng:NextNumber(-0.5, 0.4)
			local dir = Vector3.new(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e))
			k.ball(
				c[1] + dir.X * c[4] / 2,
				c[2] + dir.Y * c[5] / 2,
				c[3] + dir.Z * c[6] / 2,
				0.45,
				fruit,
				M.SmoothPlastic
			)
		end
	end,
}

PROPS.pottingbench = {
	w = 8,
	d = 3.6,
	h = 5.4,
	kind = "low",
	wall = true,
	build = function(k)
		local wood = rgb(160, 120, 80)
		for _, z in { -1.0, 0, 1.0 } do
			k.box(0, 2.8, z, 7.6, 0.18, 0.9, wood, M.WoodPlanks, true)
		end
		for _, sx in { -3.6, 3.6 } do
			for _, sz in { -1.3, 1.3 } do
				k.box(sx, 1.4, sz, 0.3, 2.8, 0.3, darker(wood, 0.2), M.Wood, true)
			end
		end
		k.box(0, 0.8, 0, 7.2, 0.15, 2.6, darker(wood, 0.1), M.WoodPlanks)
		k.box(0, 4.3, 1.5, 7.6, 2.8, 0.2, wood, M.WoodPlanks)
		k.box(0, 4.6, 1.15, 7.2, 0.15, 0.6, wood, M.Wood)
		for i = 0, 3 do
			k.post(-2.8 + i * 0.9, 1.15, 4.68, 5.3, 0.6, C.TERRA, M.Slate)
		end
		for i = 0, 2 do
			k.post(2.6, -0.2, 2.9 + i * 0.25, 3.15 + i * 0.25, 1.1 - i * 0.05, C.TERRA, M.Slate)
		end
		k.box(-1.6, 3.05, -0.3, 2.4, 0.3, 1.6, C.BLACK, M.Plastic)
		for i = 0, 5 do
			k.ball(-2.4 + (i % 3) * 0.8, 3.3, -0.65 + math.floor(i / 3) * 0.7, 0.45, rgb(100, 180, 80), M.Grass)
		end
		k.post(0.6, -0.6, 2.9, 3.9, 1.0, rgb(60, 140, 90), M.Metal)
		k.rod(Vector3.new(0.6, 3.4, -1.0), Vector3.new(0.6, 4.1, -1.8), 0.15, rgb(60, 140, 90), M.Metal)
		k.blob(-2.2, 1.4, -0.2, 2.2, 1.2, 1.6, rgb(70, 110, 60), M.Fabric)
	end,
}

-- a stone fountain: an eight-sided basin, a bowl on a pedestal, falling water
PROPS.fountain = {
	w = 8.6,
	d = 8.6,
	h = 5.2,
	kind = "low",
	wall = false,
	build = function(k)
		local stone = rgb(214, 208, 196)
		k.disc(0, 0.15, 0, 8.2, 0.3, stone, M.Limestone, true)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			k.part(
				CFrame.Angles(0, a, 0) * CFrame.new(0, 0.9, -3.7),
				Vector3.new(3.3, 1.8, 0.6),
				stone,
				M.Limestone,
				true
			)
		end
		local water = k.disc(0, 1.3, 0, 7.4, 0.1, rgb(80, 150, 210), M.Glass)
		water.Transparency = 0.25
		k.post(0, 0, 0.3, 3.4, 1.1, stone, M.Limestone, true)
		k.disc(0, 3.5, 0, 3.2, 0.4, stone, M.Limestone)
		k.disc(0, 3.72, 0, 2.8, 0.08, rgb(80, 150, 210), M.Glass).Transparency = 0.2
		k.post(0, 0, 3.7, 4.6, 0.5, stone, M.Limestone)
		local top = k.ball(0, 4.8, 0, 0.6, stone, M.Limestone)
		local spray = Instance.new("ParticleEmitter")
		spray.Rate = 30
		spray.Lifetime = NumberRange.new(0.6, 0.9)
		spray.Speed = NumberRange.new(4, 5)
		spray.SpreadAngle = Vector2.new(25, 25)
		spray.Acceleration = Vector3.new(0, -18, 0)
		spray.Size = NumberSequence.new(0.18)
		spray.Transparency = NumberSequence.new(0.2, 0.8)
		spray.Color = ColorSequence.new(rgb(200, 230, 255))
		spray.LightEmission = 0.3
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = top
	end,
}

PROPS.wheelbarrow = {
	w = 3.2,
	d = 6.6,
	h = 2.8,
	kind = "low",
	wall = false,
	build = function(k, _th, rng)
		local body = Kit.pick(rng, { rgb(60, 140, 80), rgb(200, 50, 40), rgb(40, 90, 170) })
		k.box(0, 1.9, 0.6, 2.6, 1.0, 2.4, body, M.Metal, true)
		k.wedge(
			CFrame.new(0, 1.9, -1.3) * CFrame.Angles(0, math.pi, math.pi),
			Vector3.new(2.6, 1.0, 1.4),
			body,
			M.Metal
		)
		k.blob(0, 2.4, 0.4, 2.3, 0.6, 2.6, rgb(80, 58, 44), M.Ground)
		k.wheel(0, 0.7, -2.2, 1.4, 0.4, C.BLACK, M.Rubber)
		for _, sx in { -1, 1 } do
			k.rod(Vector3.new(sx * 0.5, 1.2, -2.2), Vector3.new(sx * 1.0, 1.7, 3.1), 0.16, C.STEEL, M.Metal)
			k.rod(Vector3.new(sx * 0.9, 1.4, 1.4), Vector3.new(sx * 0.9, 0, 1.6), 0.14, C.STEEL, M.Metal)
		end
	end,
}

---------------------------------------------------------------- the arcade

local GAMES =
	{ "STAR BLASTER", "NEON RACER", "PIXEL PUNCH", "MEGA MAZE", "ROOF RUNNER", "GALAXY ZAP", "TURBO KONG", "SKY DASH" }

PROPS.arcade = {
	w = 3.6,
	d = 3.6,
	h = 7.4,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local body = Kit.pick(rng, { rgb(24, 22, 34), darker(th.accent2, 0.4), darker(th.accent, 0.5) })
		local glow = Kit.pick(rng, { th.accent, th.accent2, rgb(255, 220, 80) })
		k.box(0, 3.5, 0.2, 3.0, 7, 3.2, body, M.SmoothPlastic, true)
		for _, sx in { -1.6, 1.6 } do
			k.box(sx, 3.6, 0, 0.2, 7.2, 3.4, body, M.SmoothPlastic)
			k.box(sx, 3.6, -1.72, 0.22, 6.8, 0.08, glow, M.Neon)
		end
		local screen =
			k.part(CFrame.new(0, 4.7, -1.2) * CFrame.Angles(math.rad(15), 0, 0), Vector3.new(2.6, 2.1, 0.1), C.BLACK)
		Kit.screen(
			Kit.gui(screen, Enum.NormalId.Front, 40, 1.5),
			rng,
			if rng:NextNumber() < 0.7 then "game" else "race",
			glow
		)
		local marquee = k.box(0, 6.75, -1.3, 3.0, 0.8, 0.2, C.BLACK)
		local art = Kit.gui(marquee, Enum.NormalId.Front, 40, 2)
		Kit.rect(art, 0, 0, 1, 1, darker(glow, 0.6))
		Kit.text(art, Kit.pick(rng, GAMES), 0.04, 0.12, 0.92, 0.76, lighter(glow, 0.4), Enum.Font.LuckiestGuy, C.BLACK)
		k.part(
			CFrame.new(0, 3.3, -1.6) * CFrame.Angles(math.rad(-12), 0, 0),
			Vector3.new(3.0, 0.3, 1.2),
			darker(body, 0.3),
			M.SmoothPlastic,
			"cover"
		)
		k.post(-0.7, -1.7, 3.4, 3.8, 0.1, C.BLACK)
		k.ball(-0.7, 3.85, -1.7, 0.3, rgb(220, 40, 40), M.SmoothPlastic)
		for i, c in { rgb(255, 60, 60), rgb(60, 200, 255), rgb(255, 220, 60) } do
			k.disc(0.1 + i * 0.35, 3.48, -1.65, 0.24, 0.1, c, M.Neon)
		end
		k.box(0, 1.8, -1.42, 0.9, 1.0, 0.05, C.DARK)
		for _, sx in { -0.2, 0.2 } do
			k.box(sx, 2.0, -1.46, 0.1, 0.25, 0.04, rgb(255, 60, 40), M.Neon)
		end
	end,
}

-- a claw machine full of soft toys
PROPS.claw = {
	w = 4.4,
	d = 4.4,
	h = 7.8,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local body = Kit.pick(rng, { th.accent, th.accent2, rgb(255, 200, 60) })
		k.box(0, 1.6, 0, 4, 3.2, 4, body, M.SmoothPlastic, true)
		k.box(0, 3.25, 0, 4.1, 0.15, 4.1, C.CHROME, M.Metal)
		k.box(-1.2, 1.2, -2.02, 1.0, 1.0, 0.06, C.DARK)
		local glass = k.box(0, 5.05, 0, 3.9, 3.6, 3.9, rgb(220, 240, 250), M.Glass, true)
		glass.Transparency = 0.8
		for _, sx in { -1.95, 1.95 } do
			for _, sz in { -1.95, 1.95 } do
				k.box(sx, 5.05, sz, 0.15, 3.6, 0.15, C.CHROME, M.Metal)
			end
		end
		for _ = 1, 9 do
			k.ball(
				rng:NextNumber(-1.4, 1.4),
				rng:NextNumber(3.6, 4.1),
				rng:NextNumber(-1.4, 1.4),
				rng:NextNumber(0.7, 1.0),
				Kit.pick(rng, {
					rgb(255, 150, 190),
					rgb(140, 200, 255),
					rgb(255, 230, 120),
					rgb(170, 240, 150),
					rgb(220, 170, 255),
				}),
				M.Fabric
			)
		end
		local cx, cz = rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)
		k.rod(Vector3.new(cx, 6.8, cz), Vector3.new(cx, 5.6, cz), 0.08, C.CHROME, M.Metal)
		k.disc(cx, 5.55, cz, 0.5, 0.2, C.CHROME, M.Metal)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			k.rod(
				Vector3.new(cx, 5.5, cz),
				Vector3.new(cx + math.cos(a) * 0.45, 4.9, cz + math.sin(a) * 0.45),
				0.08,
				C.CHROME,
				M.Metal
			)
		end
		local top = k.box(0, 7.25, 0, 4.2, 0.9, 4.2, body, M.SmoothPlastic)
		local art = Kit.gui(top, Enum.NormalId.Front, 32, 1.8)
		Kit.text(art, "CLAW", 0.1, 0.1, 0.8, 0.8, C.WHITE, Enum.Font.LuckiestGuy, darker(body, 0.5))
		k.ball(0.8, 3.45, -1.7, 0.3, rgb(220, 40, 40), M.SmoothPlastic)
	end,
}

PROPS.airhockey = {
	w = 5.6,
	d = 9.8,
	h = 4.4,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		k.box(0, 1.2, 0, 5, 2.4, 9, darker(th.accent2, 0.3), M.SmoothPlastic, true)
		local surface = k.box(0, 2.45, 0, 4.6, 0.1, 8.6, C.WHITE)
		local art = Kit.gui(surface, Enum.NormalId.Top, 12)
		Kit.rect(art, 0, 0.495, 1, 0.01, th.accent)
		Kit.rect(art, 0.35, 0.44, 0.3, 0.12, th.accent, 1)
		Kit.rect(art, 0.36, 0.445, 0.28, 0.11, C.WHITE, 1)
		for _, y in { 0, 0.92 } do
			Kit.rect(art, 0.3, y, 0.4, 0.08, th.accent2, 0.5)
		end
		for _, sx in { -2.4, 2.4 } do
			k.box(sx, 2.65, 0, 0.3, 0.4, 9, th.accent, M.Neon)
		end
		for _, sz in { -4.4, 4.4 } do
			k.box(0, 2.65, sz, 5, 0.4, 0.3, th.accent2, M.Neon)
		end
		for _, z in { -2.6, 2.1 } do
			k.disc(rng:NextNumber(-1, 1), 2.6, z, 0.8, 0.2, Kit.pick(rng, { rgb(220, 40, 40), rgb(40, 90, 220) }))
		end
		k.disc(0.4, 2.53, 0.6, 0.5, 0.05, C.BLACK)
		k.post(0, 4.9, 2.6, 3.6, 0.2, C.BLACK, M.Metal)
		local score = k.box(0, 4.1, 4.9, 2.6, 1.0, 0.3, C.BLACK)
		local s = Kit.gui(score, Enum.NormalId.Front, 40, 1.5)
		Kit.text(
			s,
			string.format("%d : %d", rng:NextInteger(0, 7), rng:NextInteger(0, 7)),
			0.05,
			0.1,
			0.9,
			0.8,
			rgb(255, 80, 60),
			Enum.Font.Arcade
		)
	end,
}

PROPS.racer = {
	w = 6.4,
	d = 7.2,
	h = 6.6,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local body = Kit.pick(rng, { th.accent2, rgb(220, 40, 40), rgb(250, 200, 40) })
		k.box(0, 0.2, 0, 6.2, 0.4, 7, C.DARK, M.Metal, true)
		k.box(0, 2.9, -2.6, 6, 5, 1.8, body, M.SmoothPlastic, true)
		for _, sx in { -1.5, 1.5 } do
			k.box(sx, 1.2, 1.8, 2.2, 1.6, 2.2, C.BLACK, M.Leather)
			k.part(
				CFrame.new(sx, 2.6, 2.9) * CFrame.Angles(math.rad(12), 0, 0),
				Vector3.new(2.2, 2.8, 0.5),
				C.BLACK,
				M.Leather
			)
			k.rod(Vector3.new(sx, 2.0, -1.7), Vector3.new(sx, 2.9, -1.1), 0.25, C.DARK)
			k.part(
				CFrame.new(sx, 3.0, -1.05) * CFrame.Angles(math.rad(-60), 0, 0) * Kit.UP,
				Vector3.new(0.15, 1.3, 1.3),
				C.BLACK,
				M.Rubber,
				false,
				Enum.PartType.Cylinder
			)
			local screen = k.box(sx, 4.0, -1.68, 2.6, 1.8, 0.08, C.BLACK)
			Kit.screen(Kit.gui(screen, Enum.NormalId.Front, 32, 1.5), rng, "race", th.accent)
		end
		local marquee = k.box(0, 5.8, -2.4, 6, 0.9, 0.3, C.BLACK)
		local art = Kit.gui(marquee, Enum.NormalId.Front, 32, 2)
		Kit.text(art, "NEON RACER", 0.04, 0.1, 0.92, 0.8, th.accent, Enum.Font.LuckiestGuy, C.BLACK)
	end,
}

PROPS.dance = {
	w = 6.6,
	d = 8,
	h = 7.4,
	kind = "high",
	wall = false,
	build = function(k, th, rng)
		local pad = k.box(0, 0.25, 1.4, 6.4, 0.5, 4.6, C.DARK, M.Metal, true)
		local art = Kit.gui(pad, Enum.NormalId.Top, 16, 1.4)
		for p = 0, 1 do
			for cell = 0, 8 do
				local col, row = cell % 3, math.floor(cell / 3)
				local arrow = cell == 1 or cell == 3 or cell == 5 or cell == 7
				Kit.rect(
					art,
					p * 0.5 + 0.02 + col * 0.155,
					0.04 + row * 0.31,
					0.145,
					0.29,
					if arrow then (if (cell + p) % 2 == 0 then th.accent else th.accent2) else rgb(50, 52, 60),
					0.15
				)
			end
		end
		for _, sx in { -2.9, 2.9 } do
			k.post(sx, 3.5, 0.5, 3.6, 0.15, C.CHROME, M.Metal)
		end
		k.rod(Vector3.new(-2.9, 3.6, 3.5), Vector3.new(2.9, 3.6, 3.5), 0.15, C.CHROME, M.Metal)
		k.box(0, 3.3, -2.8, 6, 6.6, 2, rgb(24, 22, 34), M.SmoothPlastic, true)
		local screen = k.box(0, 4.2, -1.78, 4, 2.6, 0.06, C.BLACK)
		Kit.screen(Kit.gui(screen, Enum.NormalId.Front, 32, 1.5), rng, "eq", th.accent)
		for _, sx in { -2.4, 2.4 } do
			k.face(sx, 2.0, -1.8, 1.2, 0.1, C.DARK)
			k.face(sx, 2.0, -1.84, 1.3, 0.04, th.accent2, M.Neon)
		end
		local marquee = k.box(0, 6.4, -1.75, 5.6, 0.9, 0.1, C.BLACK)
		local m = Kit.gui(marquee, Enum.NormalId.Front, 32, 2)
		Kit.text(m, "DANCE!", 0.1, 0.05, 0.8, 0.9, th.accent2, Enum.Font.LuckiestGuy, C.BLACK)
	end,
}

PROPS.pooltable = {
	w = 6.4,
	d = 11,
	h = 3.2,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local wood = rgb(80, 50, 36)
		k.box(0, 2.2, 0, 5.6, 0.9, 10.2, wood, M.Wood, true)
		k.box(0, 1.0, 0, 4.2, 1.6, 8.4, darker(wood, 0.2), M.Wood, true)
		k.box(
			0,
			2.68,
			0,
			5.0,
			0.1,
			9.6,
			Kit.pick(rng, { rgb(40, 130, 90), rgb(40, 80, 160), rgb(150, 40, 60) }),
			M.Fabric
		)
		for _, sx in { -2.65, 2.65 } do
			k.box(sx, 2.78, 0, 0.35, 0.3, 9.6, wood, M.Wood)
		end
		for _, sz in { -4.95, 4.95 } do
			k.box(0, 2.78, sz, 5.6, 0.3, 0.35, wood, M.Wood)
		end
		for _, at in { { -2.4, -4.7 }, { 2.4, -4.7 }, { -2.5, 0 }, { 2.5, 0 }, { -2.4, 4.7 }, { 2.4, 4.7 } } do
			k.disc(at[1], 2.75, at[2], 0.55, 0.08, C.BLACK)
		end
		for _, sx in { -2.3, 2.3 } do
			for _, sz in { -4.3, 4.3 } do
				k.post(sx, sz, 0, 1.8, 0.7, wood, M.Wood)
			end
		end
		local balls = {
			rgb(250, 210, 40),
			rgb(40, 80, 200),
			rgb(220, 40, 40),
			rgb(120, 40, 160),
			rgb(250, 130, 40),
			rgb(40, 140, 70),
			C.BLACK,
		}
		for i, c in balls do
			local row = if i <= 1 then 0 elseif i <= 3 then 1 else 2
			k.ball(-0.5 + (i % 3) * 0.45 + row * 0.1, 2.95, -2.4 - row * 0.4, 0.42, c, M.SmoothPlastic)
		end
		k.ball(rng:NextNumber(-1, 1), 2.95, 2.5, 0.42, C.WHITE, M.SmoothPlastic)
		k.rod(Vector3.new(-1.8, 2.9, 1.2), Vector3.new(1.2, 2.9, 4.4), 0.12, rgb(200, 170, 120), M.Wood)
		k.ball(-0.3, 2.95, 0.4, 0.3, th.accent, M.SmoothPlastic)
	end,
}

-- the prize counter: a glass case and shelves of soft toys
PROPS.prizes = {
	w = 10,
	d = 3.6,
	h = 7.6,
	kind = "high",
	wall = true,
	build = function(k, th, rng)
		local toys = {
			rgb(255, 150, 190),
			rgb(140, 200, 255),
			rgb(255, 230, 120),
			rgb(170, 240, 150),
			rgb(220, 170, 255),
			rgb(255, 160, 100),
		}
		k.box(0, 0.8, -0.8, 9.6, 1.6, 1.6, rgb(24, 22, 34), M.SmoothPlastic, true)
		local case = k.box(0, 2.3, -0.8, 9.6, 1.4, 1.6, rgb(220, 240, 250), M.Glass, true)
		case.Transparency = 0.7
		k.box(0, 1.62, -1.62, 9.6, 0.08, 0.06, th.accent, M.Neon)
		for i = 0, 5 do
			k.ball(-4 + i * 1.6, 2.0, -0.8, 0.6, Kit.pick(rng, toys), M.Fabric)
		end
		for _, y in { 3.6, 5.0, 6.4 } do
			k.box(0, y, 1.1, 9.6, 0.15, 1.2, rgb(60, 50, 80), M.Wood)
			for i = 0, 4 do
				k.ball(
					-3.8 + i * 1.9 + rng:NextNumber(-0.2, 0.2),
					y + 0.5,
					1.1,
					rng:NextNumber(0.8, 1.0),
					Kit.pick(rng, toys),
					M.Fabric
				)
			end
		end
		Pieces.sign(
			Kit.on(k.model, k.cf * CFrame.new(0, 0, 0.5)),
			0,
			7.3,
			4,
			0.6,
			"PRIZES",
			C.BLACK,
			th.accent,
			1.6,
			Enum.Font.LuckiestGuy
		)
	end,
}

---------------------------------------------------------------- the nightclub

PROPS.djbooth = {
	w = 10,
	d = 6,
	h = 5.4,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local dark = rgb(22, 20, 30)
		k.box(0, 0.4, 0, 10, 0.8, 6, dark, M.SmoothPlastic, true)
		k.box(0, 0.4, -3.02, 10, 0.12, 0.06, th.accent2, M.Neon)
		k.box(0, 2.1, -1.4, 8, 2.6, 2.2, dark, M.SmoothPlastic, true)
		local led = k.box(0, 2.1, -2.52, 7.8, 2.2, 0.06, C.BLACK)
		Kit.screen(Kit.gui(led, Enum.NormalId.Front, 16, 1.8), rng, "eq", th.accent)
		k.box(0, 3.45, -1.4, 8.2, 0.15, 2.4, C.BLACK)
		for _, sx in { -2.6, 2.6 } do
			k.box(sx, 3.65, -1.4, 2.2, 0.25, 1.8, C.STEEL, M.Metal)
			k.disc(sx - 0.2, 3.8, -1.4, 1.5, 0.06, C.BLACK)
			k.disc(sx - 0.2, 3.84, -1.4, 0.4, 0.04, th.accent2)
			k.rod(Vector3.new(sx + 0.8, 3.85, -0.8), Vector3.new(sx + 0.2, 3.85, -1.6), 0.08, C.CHROME, M.Metal)
		end
		k.box(0, 3.65, -1.4, 1.6, 0.25, 1.6, C.DARK)
		for i = 0, 2 do
			k.disc(-0.5 + i * 0.5, 3.8, -1.4, 0.2, 0.08, Kit.pick(rng, { th.accent, th.accent2 }), M.Neon)
		end
		k.box(0, 3.55, -0.2, 1.8, 0.08, 1.2, C.STEEL, M.Metal)
		local lid = k.part(
			CFrame.new(0, 4.1, 0.4) * CFrame.Angles(math.rad(15), 0, 0),
			Vector3.new(1.8, 1.2, 0.08),
			C.STEEL,
			M.Metal
		)
		Kit.screen(Kit.gui(lid, Enum.NormalId.Back, 40, 1.3), rng, "eq", th.accent2)
	end,
}

PROPS.speaker = {
	w = 4,
	d = 4,
	h = 8.2,
	kind = "high",
	wall = false,
	build = function(k, th)
		local box = rgb(20, 20, 26)
		k.box(0, 2.0, 0, 3.8, 4, 3.6, box, M.SmoothPlastic, true)
		k.box(0, 6.0, 0.1, 3.4, 4, 3.2, box, M.SmoothPlastic, true)
		k.face(0, 2.0, -1.82, 3.1, 0.06, th.accent, M.Neon)
		k.face(0, 2.0, -1.86, 2.8, 0.06, rgb(46, 46, 54))
		k.face(0, 2.0, -1.92, 0.9, 0.08, C.BLACK)
		k.face(0, 5.4, -1.52, 2.0, 0.06, rgb(46, 46, 54))
		k.face(0, 5.4, -1.56, 0.6, 0.06, C.BLACK)
		k.box(0, 7.3, -1.52, 2.4, 0.9, 0.06, rgb(46, 46, 54))
		k.box(0, 0.06, -1.8, 3.6, 0.08, 0.06, th.accent2, M.Neon)
	end,
}

-- a booth of seats round a low table, lit from underneath
PROPS.booth = {
	w = 9.6,
	d = 7.6,
	h = 4.2,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local fabric = Kit.pick(rng, { rgb(120, 30, 60), rgb(40, 30, 70), rgb(30, 30, 36) })
		k.box(0, 0.8, 2.6, 9.4, 1.6, 2.2, fabric, M.Leather, true)
		k.box(0, 2.6, 3.5, 9.4, 2.4, 0.6, fabric, M.Leather, "cover")
		for _, s in { -1, 1 } do
			k.box(s * 3.7, 0.8, -0.6, 2.0, 1.6, 4.2, fabric, M.Leather, true)
			k.box(s * 4.5, 2.6, -0.6, 0.6, 2.4, 4.2, fabric, M.Leather, "cover")
		end
		k.box(0, 1.65, 2.4, 9.0, 0.1, 1.8, lighter(fabric, 0.12), M.Leather)
		k.box(0, 0.06, 1.48, 9.4, 0.12, 0.06, th.accent, M.Neon)
		for _, s in { -1, 1 } do
			k.box(s * 2.68, 0.06, -0.6, 0.06, 0.12, 4.2, th.accent, M.Neon)
		end
		k.disc(0, 2.3, -0.4, 3, 0.15, C.BLACK, M.SmoothPlastic)
		k.post(0, -0.4, 0.1, 2.25, 0.4, C.CHROME, M.Metal)
		k.post(0.3, -0.4, 2.38, 3.2, 0.8, C.CHROME, M.Metal)
		for _, dx in { -0.1, 0.4 } do
			k.post(0.3 + dx, -0.4 + dx * 0.3, 3.1, 3.8, 0.25, rgb(30, 80, 40), M.Glass)
		end
		for _, at in { { -0.8, -1.0 }, { 0.9, 0.2 } } do
			k.post(at[1], at[2], 2.38, 2.9, 0.3, rgb(220, 240, 250), M.Glass).Transparency = 0.3
			k.post(at[1], at[2], 2.4, 2.7, 0.24, th.accent2, M.Neon)
		end
	end,
}

-- a lighting rig over the dance floor: four towers, moving heads with their beams, a mirror ball, and the
-- dance floor of lit tiles under it
PROPS.truss = {
	w = 16.4,
	d = 16.4,
	h = CEIL,
	kind = "low",
	wall = false,
	build = function(k, th, rng)
		local metal = rgb(60, 62, 70)
		local n = 5
		local tile = 2.7
		for i = 0, n - 1 do
			for j = 0, n - 1 do
				local x, z = (i - (n - 1) / 2) * tile, (j - (n - 1) / 2) * tile
				local lit = rng:NextNumber() < 0.55
				local c = if lit
					then Kit.pick(rng, { th.accent, th.accent2, rgb(255, 220, 80), rgb(140, 90, 255) })
					else rgb(30, 26, 40)
				k.box(
					x,
					0.04,
					z,
					tile - 0.12,
					0.08,
					tile - 0.12,
					if lit then c:Lerp(Color3.new(0, 0, 0), 0.35) else c,
					if lit then M.Neon else M.Glass
				)
			end
		end
		local top = CEIL - 0.5
		for _, sx in { -7.6, 7.6 } do
			for _, sz in { -7.6, 7.6 } do
				k.box(sx, top / 2, sz, 0.6, top, 0.6, metal, M.Metal, true)
				k.box(sx, 0.1, sz, 1.2, 0.2, 1.2, metal, M.Metal)
			end
			k.box(sx, top, 0, 0.6, 0.6, 15.8, metal, M.Metal)
			k.box(0, top, sx, 15.8, 0.6, 0.6, metal, M.Metal)
		end
		k.box(0, top, 0, 15.8, 0.4, 0.4, metal, M.Metal)
		-- moving heads, each throwing a beam onto the floor
		for i, at in { { -5, -7.6 }, { 5, -7.6 }, { -5, 7.6 }, { 5, 7.6 } } do
			local head = k.box(at[1], top - 0.8, at[2], 0.8, 0.8, 0.8, C.BLACK, M.Metal)
			k.box(at[1], top - 0.35, at[2], 0.25, 0.3, 0.25, metal, M.Metal)
			local color = if i % 2 == 0 then th.accent else th.accent2
			k.box(at[1], top - 1.22, at[2], 0.5, 0.05, 0.5, color, M.Neon)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, -0.45, 0)
			a0.Parent = head
			local a1 = Instance.new("Attachment")
			a1.WorldPosition = k.at(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)).Position
			a1.Parent = head
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Width0 = 0.5
			beam.Width1 = 3.4
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Segments = 1
			beam.Color = ColorSequence.new(color)
			beam.Transparency = NumberSequence.new(0.55, 0.92)
			beam.Parent = head
		end
		k.rod(Vector3.new(0, top, 0), Vector3.new(0, top - 1.4, 0), 0.08, C.STEEL, M.Metal)
		local ball = k.ball(0, top - 2.1, 0, 1.6, rgb(220, 224, 236), M.Foil)
		ball.Reflectance = 0.6
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Rate = 8
		sparkle.Lifetime = NumberRange.new(0.3, 0.6)
		sparkle.Speed = NumberRange.new(0, 0)
		sparkle.Size = NumberSequence.new(0.25)
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(C.WHITE)
		sparkle.Transparency = NumberSequence.new(0.1, 1)
		sparkle.Parent = ball
	end,
}

PROPS.hightable = {
	w = 4.8,
	d = 4.8,
	h = 4.2,
	kind = "low",
	wall = false,
	build = function(k, th)
		k.disc(0, 3.7, 0, 2.2, 0.15, C.BLACK, M.SmoothPlastic, true)
		k.post(0, 0, 0.1, 3.65, 0.3, C.CHROME, M.Metal, true)
		k.disc(0, 0.06, 0, 1.6, 0.12, C.CHROME, M.Metal)
		Pieces.stool(k, -1.7, 0.6, 3.0, darker(th.accent, 0.3), C.CHROME)
		Pieces.stool(k, 1.6, -0.9, 3.0, darker(th.accent, 0.3), C.CHROME)
		for _, at in { { -0.4, 0.3 }, { 0.5, -0.2 } } do
			k.post(at[1], at[2], 3.78, 4.3, 0.3, rgb(220, 240, 250), M.Glass).Transparency = 0.3
			k.post(at[1], at[2], 3.8, 4.1, 0.24, th.accent2, M.Neon)
		end
	end,
}

return PROPS
