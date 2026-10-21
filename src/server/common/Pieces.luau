--!strict
-- Furniture that turns up on many floors, built into a Kit builder: chairs, sofas, tables, lamps, plants,
-- rows of books, screens, rugs. Each takes the builder it goes into and where (x, z in its frame, turned
-- by yaw radians: the piece's front faces -Z before it's turned).
local Kit = require(script.Parent.Kit)

type Builder = Kit.Builder

local rgb = Kit.rgb
local M = Enum.Material

local Pieces = {}

-- the materials' everyday colours
local C = {
	DARK = rgb(34, 32, 40),
	BLACK = rgb(22, 22, 26),
	METAL = rgb(120, 124, 134),
	STEEL = rgb(168, 174, 184),
	CHROME = rgb(206, 210, 218),
	WOOD = rgb(140, 98, 66),
	OAK = rgb(196, 156, 106),
	WALNUT = rgb(92, 62, 44),
	WHITE = rgb(236, 234, 228),
	CREAM = rgb(236, 226, 206),
	BRASS = rgb(206, 166, 84),
	LEAF = rgb(64, 146, 74),
	LEAF2 = rgb(38, 108, 62),
	TERRA = rgb(190, 104, 70),
	GLOW = rgb(255, 222, 170),
	PAPER = rgb(244, 242, 234),
}
Pieces.C = C

local function lighter(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end
local function darker(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end
Pieces.lighter = lighter
Pieces.darker = darker

-- an office chair on a star of legs
function Pieces.officeChair(k: Builder, x: number, z: number, yaw: number, color: Color3)
	local c = k.sub(x, z, yaw)
	for i = 0, 2 do
		local a = i * math.pi / 3
		local dx, dz = math.cos(a) * 1.05, math.sin(a) * 1.05
		c.rod(Vector3.new(-dx, 0.18, -dz), Vector3.new(dx, 0.18, dz), 0.16, C.BLACK, M.Metal)
	end
	c.post(0, 0, 0.2, 1.5, 0.22, C.CHROME, M.Metal)
	c.box(0, 1.62, 0, 1.8, 0.34, 1.7, color, M.Fabric)
	c.box(0, 2.0, 0.9, 0.3, 0.8, 0.12, C.BLACK)
	c.box(0, 3.0, 0.98, 1.7, 1.8, 0.26, color, M.Fabric)
end

-- a dining chair: wooden legs and back, a padded seat
function Pieces.diningChair(k: Builder, x: number, z: number, yaw: number, frame: Color3, seat: Color3)
	local c = k.sub(x, z, yaw)
	c.box(0, 1.55, 0, 1.7, 0.24, 1.6, seat, M.Fabric)
	for _, sx in { -0.72, 0.72 } do
		c.box(sx, 0.72, -0.66, 0.18, 1.44, 0.18, frame, M.Wood)
		c.box(sx, 1.7, 0.7, 0.18, 3.4, 0.18, frame, M.Wood)
	end
	c.box(0, 2.85, 0.72, 1.4, 0.9, 0.12, frame, M.Wood)
end

-- a light chair on sled legs (canteens, labs)
function Pieces.simpleChair(k: Builder, x: number, z: number, yaw: number, frame: Color3, seat: Color3)
	local c = k.sub(x, z, yaw)
	c.box(0, 1.5, 0, 1.6, 0.18, 1.5, seat, M.Plastic)
	c.box(0, 2.6, 0.72, 1.6, 1.3, 0.14, seat, M.Plastic)
	for _, sx in { -0.72, 0.72 } do
		c.box(sx, 0.72, 0, 0.12, 1.44, 1.3, frame, M.Metal)
	end
end

-- a bar stool, its seat at height h
function Pieces.stool(k: Builder, x: number, z: number, h: number, seat: Color3, metal: Color3)
	k.disc(x, h - 0.15, z, 1.5, 0.3, seat, M.Leather)
	k.post(x, z, 0.1, h - 0.3, 0.2, metal, M.Metal)
	k.disc(x, h * 0.38, z, 1.1, 0.08, metal, M.Metal)
	k.disc(x, 0.05, z, 1.3, 0.1, metal, M.Metal)
end

-- an armchair with rolled arms
function Pieces.armchair(k: Builder, x: number, z: number, yaw: number, color: Color3, legs: Color3?)
	local c = k.sub(x, z, yaw)
	c.box(0, 0.95, 0.1, 3.4, 1.1, 3.0, color, M.Fabric, true)
	c.box(0, 1.66, -0.2, 2.4, 0.42, 2.4, lighter(color, 0.08), M.Fabric)
	c.box(0, 2.55, 1.3, 3.4, 2.1, 0.6, color, M.Fabric, "cover")
	for _, sx in { -1.45, 1.45 } do
		c.box(sx, 1.75, 0.05, 0.5, 0.8, 3.0, color, M.Fabric, "cover")
		c.rod(Vector3.new(sx, 2.2, -1.5), Vector3.new(sx, 2.2, 1.0), 0.62, color, M.Fabric)
	end
	if legs then
		c.box(0, 0.2, 0.1, 3.0, 0.4, 2.6, legs, M.Wood)
	end
end

-- a sofa w studs wide
function Pieces.sofa(k: Builder, x: number, z: number, yaw: number, w: number, color: Color3, pillow: Color3?)
	local c = k.sub(x, z, yaw)
	local d = 3.6
	c.box(0, 0.22, 0.1, w - 0.4, 0.44, d - 0.4, C.BLACK)
	c.box(0, 0.95, 0.1, w, 1.0, d, color, M.Fabric, true)
	c.box(0, 2.25, 1.55, w, 1.9, 0.5, color, M.Fabric, "cover")
	local n = math.max(2, math.floor((w - 1.2) / 2.6))
	local cw = (w - 1.4) / n
	for i = 0, n - 1 do
		local cx = -w / 2 + 0.7 + cw * (i + 0.5)
		c.box(cx, 1.66, -0.15, cw - 0.1, 0.42, d - 1.1, lighter(color, 0.07), M.Fabric)
		c.box(cx, 2.45, 1.05, cw - 0.1, 1.3, 0.55, lighter(color, 0.04), M.Fabric)
	end
	for _, sx in { -1, 1 } do
		c.box(sx * (w / 2 - 0.3), 1.75, 0.1, 0.6, 0.6, d, color, M.Fabric, "cover")
		c.rod(
			Vector3.new(sx * (w / 2 - 0.3), 2.1, -d / 2 + 0.1),
			Vector3.new(sx * (w / 2 - 0.3), 2.1, d / 2 - 0.2),
			0.7,
			color,
			M.Fabric
		)
	end
	if pillow then
		c.part(
			CFrame.new(-w / 2 + 1.5, 2.25, 0.55) * CFrame.Angles(math.rad(-15), 0, math.rad(8)),
			Vector3.new(1.4, 1.2, 0.4),
			pillow,
			M.Fabric
		)
		c.part(
			CFrame.new(w / 2 - 1.5, 2.25, 0.55) * CFrame.Angles(math.rad(-15), 0, math.rad(-8)),
			Vector3.new(1.4, 1.2, 0.4),
			pillow,
			M.Fabric
		)
	end
end

-- a table lamp standing at height y: base, stem, a lit shade
function Pieces.lamp(k: Builder, x: number, y: number, z: number, base: Color3, shade: Color3?)
	k.disc(x, y + 0.08, z, 0.8, 0.16, base, M.Metal)
	k.post(x, z, y + 0.16, y + 1.2, 0.16, base, M.Metal)
	k.post(x, z, y + 1.05, y + 1.85, 1.2, shade or C.GLOW, M.Neon)
end

-- a floor lamp
function Pieces.floorLamp(k: Builder, x: number, z: number, metal: Color3, shade: Color3?)
	k.disc(x, 0.08, z, 1.4, 0.16, metal, M.Metal)
	k.post(x, z, 0.16, 5.6, 0.2, metal, M.Metal)
	k.post(x, z, 5.2, 6.6, 1.7, shade or C.GLOW, M.Neon)
end

-- a potted plant (four kinds: a bush, a snake plant, a little tree, a fern). size scales it
function Pieces.plant(k: Builder, x: number, z: number, rng: Random, size: number?, pot: Color3?)
	local s = size or 1
	local potColor = pot or Kit.pick(rng, { C.TERRA, C.WHITE, rgb(60, 62, 70), rgb(200, 190, 170) })
	local ph = 1.6 * s
	k.post(x, z, 0, ph, 1.9 * s, potColor, M.Slate, true)
	k.post(x, z, ph - 0.25, ph + 0.05, 2.15 * s, potColor:Lerp(Color3.new(0, 0, 0), 0.1), M.Slate)
	k.disc(x, ph - 0.02, z, 1.8 * s, 0.1, rgb(70, 50, 40), M.Ground)
	local green = C.LEAF:Lerp(C.LEAF2, rng:NextNumber())
	local kind = rng:NextInteger(1, 4)
	if kind == 1 then
		k.ball(x, ph + 1.1 * s, z, 2.6 * s, green, M.Grass, "cover")
		k.ball(x + 0.6 * s, ph + 1.9 * s, z + 0.3 * s, 1.9 * s, lighter(green, 0.12), M.Grass)
		k.ball(x - 0.7 * s, ph + 1.6 * s, z - 0.4 * s, 1.6 * s, darker(green, 0.1), M.Grass)
	elseif kind == 2 then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local lean = rng:NextNumber(4, 12)
			k.part(
				CFrame.new(x + math.cos(a) * 0.35 * s, ph + 1.5 * s, z + math.sin(a) * 0.35 * s)
					* CFrame.Angles(0, -a, math.rad(lean)),
				Vector3.new(0.12, rng:NextNumber(2.4, 3.4) * s, 0.5 * s),
				if i % 2 == 0 then green else rgb(120, 160, 70),
				M.Grass
			)
		end
	elseif kind == 3 then
		k.post(x, z, ph, ph + 2.6 * s, 0.25 * s, C.WALNUT, M.Wood)
		k.ball(x, ph + 3.2 * s, z, 2.2 * s, green, M.Grass, "cover")
		k.ball(x + 0.8 * s, ph + 2.6 * s, z - 0.3 * s, 1.5 * s, lighter(green, 0.1), M.Grass)
		k.ball(x - 0.6 * s, ph + 3.9 * s, z + 0.4 * s, 1.4 * s, darker(green, 0.08), M.Grass)
	else
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2 + rng:NextNumber(0, 0.4)
			k.part(
				CFrame.new(x, ph + 0.4 * s, z)
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, 0.5 * s, -0.9 * s)
					* CFrame.Angles(math.rad(-50), 0, 0),
				Vector3.new(0.7 * s, 0.08, 2.6 * s),
				green,
				M.Grass
			)
		end
		k.ball(x, ph + 0.5 * s, z, 1.3 * s, darker(green, 0.15), M.Grass, "cover")
	end
end

-- a monitor on a stand at height y (its screen faces -Z after yaw): kind is what it shows (Kit.screen)
function Pieces.monitor(
	k: Builder,
	x: number,
	y: number,
	z: number,
	yaw: number,
	w: number,
	rng: Random,
	kind: string,
	accent: Color3
)
	local c = k.sub(x, z, yaw)
	local h = w * 0.6
	c.box(0, y + 0.04, 0.1, w * 0.4, 0.08, 0.7, C.BLACK)
	c.box(0, y + h / 2, 0.15, 0.2, h * 0.7, 0.12, C.BLACK)
	local screen = c.box(0, y + 0.5 + h / 2, 0, w, h, 0.14, C.BLACK)
	Kit.screen(Kit.gui(screen, Enum.NormalId.Front, 40, 1.3), rng, kind, accent)
end

-- a row of books standing on a shelf, from x0 to x1 at height y, centred at depth z
function Pieces.books(
	k: Builder,
	x0: number,
	x1: number,
	y: number,
	z: number,
	depth: number,
	hmax: number,
	rng: Random,
	palette: { Color3 }?
)
	local colors = palette
		or {
			rgb(170, 60, 56),
			rgb(56, 100, 160),
			rgb(214, 176, 90),
			rgb(70, 130, 84),
			rgb(130, 80, 150),
			rgb(220, 216, 200),
			rgb(60, 50, 46),
		}
	local x = x0
	while x < x1 - 0.3 do
		local bw = math.min(rng:NextNumber(0.45, 1.3), x1 - x)
		if rng:NextNumber() < 0.1 and x1 - x > 1.5 then
			-- one leaning against the next
			local h = hmax * rng:NextNumber(0.7, 0.9)
			k.part(
				CFrame.new(x + 0.5, y + h / 2 - 0.1, z) * CFrame.Angles(0, 0, math.rad(-20)),
				Vector3.new(0.3, h, depth * 0.9),
				Kit.pick(rng, colors),
				M.SmoothPlastic
			)
			x += 0.9
		else
			local h = hmax * rng:NextNumber(0.68, 1)
			k.box(
				x + bw / 2,
				y + h / 2,
				z,
				bw - 0.04,
				h,
				depth * rng:NextNumber(0.85, 1),
				Kit.pick(rng, colors),
				M.SmoothPlastic
			)
			x += bw
		end
		if rng:NextNumber() < 0.08 then
			x += rng:NextNumber(0.4, 1.0)
		end
	end
end

-- a rug on the floor: a border and its field (or a round one)
function Pieces.rug(
	k: Builder,
	x: number,
	z: number,
	w: number,
	d: number,
	field: Color3,
	border: Color3,
	round: boolean?
)
	if round then
		k.disc(x, 0.03, z, w, 0.06, border, M.Fabric)
		k.disc(x, 0.05, z, w - 0.8, 0.07, field, M.Fabric)
		return
	end
	k.box(x, 0.03, z, w, 0.06, d, border, M.Fabric)
	k.box(x, 0.05, z, w - 0.8, 0.07, d - 0.8, field, M.Fabric)
end

-- a mug or a cup at height y
function Pieces.mug(k: Builder, x: number, y: number, z: number, color: Color3)
	k.post(x, z, y, y + 0.42, 0.34, color, M.SmoothPlastic)
end

-- a painting in a frame (w by h) on a builder's front: on a wall builder, its face is out in the room
function Pieces.picture(
	k: Builder,
	x: number,
	y: number,
	w: number,
	h: number,
	frame: Color3,
	rng: Random,
	style: string?
)
	k.box(x, y, -0.1, w, h, 0.2, frame, M.Wood)
	local canvas = k.box(x, y, -0.22, w - 0.4, h - 0.4, 0.06, C.WHITE, M.SmoothPlastic)
	Kit.painting(Kit.gui(canvas, Enum.NormalId.Front, 30), rng, style)
end

-- a wall light: a small plate and a lit glass
function Pieces.sconce(k: Builder, x: number, y: number, metal: Color3, glow: Color3)
	k.box(x, y - 0.3, -0.06, 0.5, 0.9, 0.12, metal, M.Metal)
	k.box(x, y - 0.1, -0.3, 0.16, 0.16, 0.45, metal, M.Metal)
	k.post(x, -0.55, y, y + 0.7, 0.7, glow, M.Neon)
end

-- a sign on a builder's front: a board with text (glow: lit)
function Pieces.sign(
	k: Builder,
	x: number,
	y: number,
	w: number,
	h: number,
	text: string,
	bg: Color3,
	fg: Color3,
	glow: number?,
	font: Enum.Font?
)
	local board = k.box(x, y, -0.08, w, h, 0.16, bg, M.SmoothPlastic)
	Kit.sign(Kit.gui(board, Enum.NormalId.Front, 32, glow), text, bg, fg, font)
	return board
end

return Pieces
