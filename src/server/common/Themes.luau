--!strict
-- What each floor is: 20 themes, bottom to top. Each has its own finishes (floor, walls, trims, window
-- frames), its colours and lamps, a plan that places its furniture by design (server/common/Props has the
-- pieces), extra pieces dropped wherever they fit, and its dressing: what's painted on the floor and hung
-- on the walls (signs, paintings, wall lights, pipes, mirrors).
-- The room: walls' room faces at ±34.95 studs, the walkway round the shaft clear to ±11.9. The painted
-- floor number takes the (-x, +z) corner and, up to floor 17, the booster pad sits at the shaft's (+x, +z)
-- corner: a plan just tries its spots and whatever doesn't fit is left out.
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

export type Theme = Kit.Theme
type Planner = Kit.Planner
type Room = Kit.Room
type Builder = Kit.Builder

local rgb = Kit.rgb
local M = Enum.Material
local C = Pieces.C
local Q = math.pi / 2
local SIDES = { "+x", "-x", "+z", "-z" }

local Themes = {}

---------------------------------------------------------------- dressing helpers

-- something on each stretch of wall between windows that nothing stands against, with this chance
local function onPillars(room: Room, chance: number, fn: (k: Builder, side: string, u: number, n: number) -> ())
	local n = 0
	for _, side in SIDES do
		for _, u in room.pillars do
			if room.free(side, u, 2.6) and room.rng:NextNumber() < chance then
				n += 1
				fn(room.wall(side, u), side, u, n)
			end
		end
	end
end

-- a framed painting with a small lamp over it
local function gallery(room: Room, chance: number, frame: Color3, lamp: Color3?)
	onPillars(room, chance, function(k)
		Pieces.picture(k, 0, 5.0, 3.2, 2.6, frame, room.rng)
		if lamp then
			k.box(0, 6.75, -0.25, 1.4, 0.18, 0.5, lamp, M.Metal)
			k.box(0, 6.62, -0.45, 1.2, 0.06, 0.3, rgb(255, 240, 210), M.Neon)
		end
	end)
end

-- a pair of wall lights
local function sconces(room: Room, chance: number, metal: Color3, glow: Color3)
	onPillars(room, chance, function(k)
		Pieces.sconce(k, -1.3, 5.6, metal, glow)
		Pieces.sconce(k, 1.3, 5.6, metal, glow)
	end)
end

-- a printed sign on a wall
local function sign(
	room: Room,
	side: string,
	u: number,
	y: number,
	w: number,
	h: number,
	text: string,
	bg: Color3,
	fg: Color3,
	glow: number?,
	font: Enum.Font?
)
	Pieces.sign(room.wall(side, u), 0, y, w, h, text, bg, fg, glow, font)
end

-- a neon sign: glowing letters, no board
local function neon(
	room: Room,
	side: string,
	u: number,
	y: number,
	w: number,
	h: number,
	text: string,
	color: Color3,
	font: Enum.Font?
)
	local k = room.wall(side, u)
	local board = k.box(0, y, -0.1, w, h, 0.1, color, M.SmoothPlastic)
	board.Transparency = 1
	local art = Kit.gui(board, Enum.NormalId.Front, 30, 3)
	local t = Kit.text(art, text, 0, 0, 1, 1, Pieces.lighter(color, 0.35), font or Enum.Font.LuckiestGuy, color)
	t.TextStrokeTransparency = 0
end

-- the first free stretch of wall from a list of (side, u)
local function firstFree(room: Room, spots: { { any } }): (string?, number)
	for _, s in spots do
		if room.free(s[1], s[2], 2.6) then
			return s[1], s[2]
		end
	end
	return nil, 0
end

-- a round wall clock
local function clock(room: Room, side: string, u: number, y: number)
	local k = room.wall(side, u)
	k.face(0, y, -0.1, 1.9, 0.2, C.DARK, M.Metal)
	k.face(0, y, -0.2, 1.6, 0.04, C.WHITE)
	k.part(
		CFrame.new(0, y + 0.3, -0.25)
			* CFrame.Angles(0, 0, math.rad(room.rng:NextNumber(0, 360)))
			* CFrame.new(0, 0.25, 0),
		Vector3.new(0.08, 0.55, 0.04),
		C.BLACK
	)
	k.part(
		CFrame.new(0, y, -0.26) * CFrame.Angles(0, 0, math.rad(room.rng:NextNumber(0, 360))) * CFrame.new(0, 0.3, 0),
		Vector3.new(0.06, 0.65, 0.04),
		C.BLACK
	)
end

-- a striped zone painted on the floor
local function hatch(room: Room, x: number, z: number, w: number, d: number, stripe: Color3, ground: Color3)
	local p = room.floor.box(x, 0.025, z, w, 0.05, d, ground, M.SmoothPlastic)
	local art = Kit.gui(p, Enum.NormalId.Top, 6)
	for i = -10, 20 do
		local s = Kit.rect(art, i * 0.07, -0.5, 0.025, 2, stripe)
		s.Rotation = 45
	end
end

-- a pattern drawn over the floor, in eight squares round the walkway (the middle one is the walkway)
local function floorPattern(room: Room, draw: (art: Frame) -> ())
	for _, x in { -24, 0, 24 } do
		for _, z in { -24, 0, 24 } do
			if x ~= 0 or z ~= 0 then
				local p = room.floor.box(x, 0.02, z, 24, 0.03, 24, C.WHITE, M.SmoothPlastic)
				p.Transparency = 1
				draw(Kit.gui(p, Enum.NormalId.Top, 8))
			end
		end
	end
end

-- flat splashes of paint, oil or water on open floor
local function splats(room: Room, n: number, colors: { Color3 }, size: number)
	for _ = 1, n do
		for _ = 1, 10 do
			local x, z = room.rng:NextNumber(-32, 32), room.rng:NextNumber(-32, 32)
			local d = room.rng:NextNumber(0.6, 1.6) * size
			if room.open(x - d, x + d, z - d, z + d) then
				room.floor.disc(x, 0.012, z, d, 0.02, Kit.pick(room.rng, colors))
				if room.rng:NextNumber() < 0.6 then
					room.floor.disc(
						x + room.rng:NextNumber(-1, 1) * d * 0.6,
						0.013,
						z + room.rng:NextNumber(-1, 1) * d * 0.6,
						d * 0.4,
						0.02,
						Kit.pick(room.rng, colors)
					)
				end
				break
			end
		end
	end
end

-- a fire extinguisher on its bracket, with its sign
local function extinguisher(room: Room, side: string, u: number)
	local k = room.wall(side, u)
	k.post(0, -0.45, 1.2, 3.0, 0.7, rgb(200, 30, 36), M.Metal)
	k.post(0, -0.45, 3.0, 3.3, 0.3, C.BLACK, M.Metal)
	k.box(0, 2.2, -0.08, 0.9, 0.2, 0.16, C.DARK, M.Metal)
	Pieces.sign(k, 0, 4.4, 1.2, 0.8, "FIRE", rgb(200, 30, 36), C.WHITE)
end

-- pipes along the top of every wall, elbows at the corners, a few valves
local function pipes(room: Room, runs: { { y: number, d: number, color: Color3 } })
	local face = room.inner
	for _, r in runs do
		local out = face - r.d / 2 - 0.15
		for _, side in SIDES do
			local k = room.wall(side, 0)
			k.rod(
				Vector3.new(-out, r.y, -r.d / 2 - 0.15),
				Vector3.new(out, r.y, -r.d / 2 - 0.15),
				r.d,
				r.color,
				M.Metal
			)
			for _, u in room.pillars do
				if room.rng:NextNumber() < 0.15 then
					-- (a valve: its wheel hangs under the pipe)
					k.disc(u, r.y - r.d / 2 - 0.3, -r.d / 2 - 0.15, r.d * 1.8, 0.12, rgb(200, 40, 40), M.Metal)
					k.post(u, -r.d / 2 - 0.15, r.y - r.d / 2 - 0.3, r.y, 0.15, C.STEEL, M.Metal)
				end
			end
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				room.floor.ball(sx * out, r.y, sz * out, r.d * 1.25, r.color, M.Metal)
			end
		end
	end
end

-- cable trays along the top of the walls
local function cableTrays(room: Room, color: Color3, cables: { Color3 })
	for _, side in SIDES do
		local k = room.wall(side, 0)
		local half = room.inner - 0.8
		k.box(0, 7.7, -0.55, half * 2, 0.12, 0.9, color, M.Metal)
		k.box(0, 7.85, -1.0, half * 2, 0.3, 0.06, color, M.Metal)
		for i, c in cables do
			k.rod(
				Vector3.new(-half, 7.86, -0.3 - i * 0.22),
				Vector3.new(half, 7.86, -0.3 - i * 0.22),
				0.18,
				c,
				M.Rubber
			)
		end
	end
end

-- a rug under each placed piece of these names
local function rugsUnder(room: Room, names: { [string]: boolean }, field: Color3, border: Color3, pad: number)
	for _, p in room.placed do
		if names[p.name] then
			local x, z = (p.x0 + p.x1) / 2, (p.z0 + p.z1) / 2
			Pieces.rug(room.floor, x, z, p.x1 - p.x0 + pad, p.z1 - p.z0 + pad, field, border)
		end
	end
end

local function shuffled<T>(rng: Random, list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- the turn that faces a piece's front away from (cx, cz) when it stands at (x, z)
local function facingAway(x: number, z: number, cx: number, cz: number): number
	local dx, dz = x - cx, z - cz
	return math.atan2(-dx, -dz)
end

---------------------------------------------------------------- the floors

local LIST: { Theme } = {}

-- 1 · the lobby: marble, a reception desk under the building's name, lounges, palms, columns, a directory
table.insert(LIST, {
	name = "Lobby",
	floor = rgb(228, 222, 210),
	floorMat = M.Marble,
	border = { color = rgb(62, 66, 64), mat = M.Marble },
	walk = { color = rgb(190, 164, 120), mat = M.Marble },
	wall = rgb(236, 226, 208),
	wallMat = M.Plaster,
	lower = rgb(118, 80, 56),
	lowerMat = M.Wood,
	trim = rgb(84, 56, 40),
	trimMat = M.Wood,
	frame = rgb(54, 44, 36),
	accent = rgb(255, 196, 90),
	accent2 = rgb(130, 50, 56),
	light = rgb(255, 214, 160),
	props = { { "plant", 2, 3 } },
	plan = function(p: Planner)
		p.put("reception", 0, -26, math.pi)
		p.put("directory", 0, 15, 0)
		p.put("lounge", 24, -4, Q)
		p.put("lounge", -24, -4, -Q)
		for _, at in { { 30, -30 }, { -30, -30 }, { 30, 30 } } do
			p.put("palm", at[1], at[2], 0)
		end
		for _, at in { { 18, -18 }, { -18, -18 }, { 20, 20 } } do
			p.put("column", at[1], at[2], 0)
		end
		p.put("bench", -6, 31, 0)
		p.put("bench", 8, 31, 0)
		p.put("bench", 31, 13, Q)
	end,
	dress = function(room: Room)
		-- the building's name on the wall behind the desk
		local k = room.wall("-z", 0)
		k.box(0, 5.4, -0.15, 13, 3.4, 0.3, rgb(40, 34, 30), M.Wood)
		local board = k.box(0, 5.4, -0.32, 12.4, 2.8, 0.06, rgb(40, 34, 30), M.Wood)
		local art = Kit.gui(board, Enum.NormalId.Front, 30, 1.6)
		Kit.text(art, "ROOFTOP", 0.05, 0.05, 0.9, 0.62, room.th.accent, Enum.Font.LuckiestGuy)
		Kit.text(art, "TOWER  ·  EST. 1926", 0.15, 0.7, 0.7, 0.2, rgb(236, 226, 208), Enum.Font.GothamBold)
		-- a compass star set into the marble in front of the desk
		local f = room.floor
		f.disc(0, 0.03, -16, 6, 0.05, room.th.border and room.th.border.color or C.DARK, M.Marble)
		f.disc(0, 0.05, -16, 5.3, 0.05, room.th.floor, M.Marble)
		f.part(
			CFrame.new(0, 0.07, -16) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(3.4, 0.05, 3.4),
			room.th.accent2,
			M.Marble
		)
		f.part(CFrame.new(0, 0.08, -16), Vector3.new(2.4, 0.05, 2.4), rgb(200, 164, 100), M.Marble)
		f.disc(0, 0.09, -16, 0.9, 0.05, rgb(200, 164, 100), M.Metal)
		gallery(room, 0.5, rgb(190, 150, 80))
		sconces(room, 0.7, rgb(190, 150, 80), rgb(255, 222, 170))
	end,
})

-- 2 · the car park: bays painted along the walls, cars parked in them, striped columns, a barrier
table.insert(LIST, {
	name = "Parking",
	floor = rgb(86, 88, 94),
	floorMat = M.Asphalt,
	walk = { color = rgb(152, 148, 140), mat = M.Concrete },
	wall = rgb(182, 180, 172),
	wallMat = M.Concrete,
	lower = rgb(182, 180, 172),
	lowerMat = M.Concrete,
	trim = rgb(240, 190, 40),
	trimMat = M.SmoothPlastic,
	frame = rgb(60, 62, 70),
	accent = rgb(255, 210, 60),
	accent2 = rgb(60, 140, 220),
	light = rgb(255, 200, 120),
	props = { { "cones", 1, 2 }, { "crate", 2, 3 } },
	plan = function(p: Planner)
		local bays = {}
		for _, side in SIDES do
			for _, u in { -22.5, -13.5, -4.5, 4.5, 13.5, 22.5 } do
				table.insert(bays, { side, u })
			end
		end
		local parked = 0
		local want = p.rng:NextInteger(7, 10)
		for _, b in shuffled(p.rng, bays) do
			if parked >= want then
				break
			end
			if p.against("car", b[1], b[2], 0.4) then
				parked += 1
			end
		end
		for _, at in { { 17.5, -17.5 }, { -17.5, -17.5 }, { 19.5, 19.5 }, { -17.5, 13 } } do
			p.put("hazardpillar", at[1], at[2], 0, 0.5)
		end
		p.put("paystation", -14, -14, Q)
		p.put("boomgate", 0, -16.5, 0, 0.5)
	end,
	dress = function(room: Room)
		local white = rgb(232, 230, 220)
		-- the bays' lines, from the wall out across the car's length
		for _, side in SIDES do
			for _, u in room.pillars do
				if u ~= 0 and math.abs(u) < 30 then
					room.wall(side, u).box(0, 0.02, -7.5, 0.3, 0.04, 14, white)
				end
			end
		end
		-- a stop at the head of each bay with a car in it, and oil under some
		for _, pl in room.placed do
			if pl.name == "car" then
				local back = pl.cf * CFrame.new(0, 0, 5.4)
				Kit.part(
					room.model,
					back * CFrame.new(0, 0.2, 0),
					Vector3.new(4.2, 0.4, 0.7),
					room.th.accent,
					M.Concrete
				)
			end
		end
		splats(room, 6, { rgb(40, 40, 44), rgb(50, 48, 52) }, 1.6)
		-- the lane's arrows, round the shaft
		for _, side in SIDES do
			local k = room.wall(side, 0)
			for _, x in { -6, 6 } do
				local arrow = k.sub(x, -18.5, Q)
				arrow.box(0, 0.02, 0.4, 0.8, 0.04, 3.6, white)
				for _, s in { -1, 1 } do
					arrow.part(
						CFrame.new(s * 0.55, 0.02, -1.55) * CFrame.Angles(0, s * math.rad(-40), 0),
						Vector3.new(0.7, 0.04, 2.0),
						white
					)
				end
			end
		end
		local side, u = firstFree(room, { { "-x", -9 }, { "+x", -9 }, { "-z", 18 } })
		if side then
			sign(room, side, u, 6.6, 3.2, 1.0, "EXIT  ➜", rgb(30, 140, 70), C.WHITE, 1.6)
		end
		onPillars(room, 0.25, function(k)
			k.box(0, 4.5, -0.04, 4.6, 1.2, 0.06, room.th.accent, M.SmoothPlastic)
		end)
	end,
})

-- 3 · the warehouse: pallet racking along the walls, a forklift, loads on pallets, painted lanes
table.insert(LIST, {
	name = "Warehouse",
	floor = rgb(150, 146, 138),
	floorMat = M.Concrete,
	walk = { color = rgb(210, 176, 60), mat = M.Concrete },
	wall = rgb(150, 98, 74),
	wallMat = M.Brick,
	lower = rgb(150, 98, 74),
	lowerMat = M.Brick,
	trim = rgb(64, 68, 76),
	trimMat = M.Metal,
	frame = rgb(50, 54, 60),
	accent = rgb(255, 150, 40),
	accent2 = rgb(50, 100, 190),
	light = rgb(255, 200, 140),
	props = { { "pallet", 4, 6 }, { "crate", 4, 6 }, { "palletjack", 1, 1 } },
	plan = function(p: Planner)
		for _, u in { -21, -7, 7, 21 } do
			p.against("palletrack", "-z", u, 1)
		end
		for _, u in { -21, -7 } do
			p.against("palletrack", "+x", u, 1)
		end
		p.against("palletrack", "-x", -21, 1)
		p.put("forklift", -20, -2, if p.rng:NextNumber() < 0.5 then 0 else Q)
	end,
	dress = function(room: Room)
		local yellow = rgb(250, 200, 40)
		local f = room.floor
		-- lanes in front of the racking
		f.box(0, 0.02, -28.2, 60, 0.04, 0.35, yellow)
		f.box(28.2, 0.02, -12, 0.35, 0.04, 34, yellow)
		hatch(room, 26, 22, 12, 10, yellow, rgb(60, 60, 64))
		local stencil = f.box(26, 0.03, 22, 10, 0.04, 3, yellow)
		stencil.Transparency = 1
		Kit.text(Kit.gui(stencil, Enum.NormalId.Top, 12), "LOADING BAY", 0, 0, 1, 1, C.WHITE, Enum.Font.GothamBlack)
		local side, u = firstFree(room, { { "+z", -9 }, { "-x", 9 }, { "+x", 9 } })
		if side then
			extinguisher(room, side, u)
		end
		local side2, u2 = firstFree(room, { { "+z", 27 }, { "+x", 27 } })
		if side2 then
			sign(room, side2, u2, 5.2, 3.6, 1.6, "WAREHOUSE B", rgb(30, 32, 40), yellow, 0, Enum.Font.GothamBlack)
		end
	end,
})

-- 4 · the laundrette: rows of machines, a folding table, carts, a checkered floor and a neon sign
table.insert(LIST, {
	name = "Laundry",
	floor = rgb(232, 236, 236),
	floorMat = M.CeramicTiles,
	walk = { color = rgb(170, 200, 206), mat = M.CeramicTiles },
	wall = rgb(176, 222, 224),
	wallMat = M.Plaster,
	lower = rgb(238, 242, 242),
	lowerMat = M.CeramicTiles,
	trim = rgb(70, 100, 120),
	trimMat = M.SmoothPlastic,
	frame = rgb(60, 80, 96),
	accent = rgb(70, 230, 230),
	accent2 = rgb(255, 140, 180),
	light = rgb(200, 250, 255),
	props = { { "laundrycart", 2, 3 }, { "plant", 1, 2 }, { "crate", 1, 2 } },
	plan = function(p: Planner)
		for i = 0, 4 do
			p.against("washstack", "-z", -26 + i * 3.6, 0.1)
			p.against("washstack", "-z", 11.6 + i * 3.6, 0.1)
		end
		p.against("soapvend", "-z", 0, 0.3)
		for i = 0, 4 do
			p.against("washer", "+x", -27 + i * 3.6, 0.1)
		end
		p.against("seats", "+x", 4, 1)
		p.against("seats", "+z", 2, 1)
		p.put("foldtable", -22, -10, Q)
		p.put("foldtable", 22, 22, 0)
	end,
	dress = function(room: Room)
		-- black and white tiles
		floorPattern(room, function(art)
			for cx = 0, 9 do
				for cz = 0, 9 do
					if (cx + cz) % 2 == 0 then
						Kit.rect(art, cx / 10, cz / 10, 0.1, 0.1, rgb(40, 44, 52))
					end
				end
			end
		end)
		neon(room, "-x", -18, 7.8, 9, 1.3, "LAUNDROMAT", room.th.accent)
		neon(room, "+z", 22, 7.8, 7, 1.2, "OPEN 24 HRS", room.th.accent2)
		local side, u = firstFree(room, { { "-x", -27 }, { "-x", 0 }, { "+z", -9 } })
		if side then
			sign(
				room,
				side,
				u,
				5.0,
				3.2,
				2.2,
				"WASH  3.50\nDRY    2.00",
				rgb(30, 40, 60),
				room.th.accent,
				1.2,
				Enum.Font.Code
			)
		end
		local side2, u2 = firstFree(room, { { "+z", 9 }, { "-x", 9 }, { "+x", 27 } })
		if side2 then
			clock(room, side2, u2, 5.2)
		end
	end,
})

-- 5 · the gym: a boxing ring, treadmills at the windows, benches, a power rack, dumbbells, punch bags
table.insert(LIST, {
	name = "Gym",
	floor = rgb(176, 120, 76),
	floorMat = M.WoodPlanks,
	border = { color = rgb(44, 44, 50), mat = M.Rubber },
	walk = { color = rgb(48, 48, 54), mat = M.Rubber },
	wall = rgb(228, 230, 234),
	wallMat = M.Plaster,
	lower = rgb(228, 230, 234),
	lowerMat = M.Plaster,
	trim = rgb(210, 50, 60),
	trimMat = M.SmoothPlastic,
	frame = rgb(40, 40, 46),
	accent = rgb(255, 60, 70),
	accent2 = rgb(240, 240, 240),
	light = rgb(255, 190, 180),
	props = { { "kettlebells", 1, 2 }, { "plant", 1, 1 } },
	plan = function(p: Planner)
		p.put("ring", 23, -14, 0)
		for i = 0, 3 do
			p.put("treadmill", -27 + i * 5, -30.6, 0, 0.5)
		end
		p.put("powerrack", -26, -5, Q)
		p.put("weightbench", -16, -16, 0)
		p.put("weightbench", -16, 2, 0)
		p.against("dumbbells", "-x", 9, 1)
		p.put("punchbag", 4, -26, 0)
		p.put("punchbag", 10, -26, 0)
		p.against("lockers", "+z", 0, 1)
		p.against("lockers", "+z", 11, 1)
		p.put("bench", 5, 27.5, 0)
		p.against("watercooler", "+x", 12, 1)
	end,
	dress = function(room: Room)
		-- rubber mats under the weights
		rugsUnder(room, { weightbench = true, dumbbells = true }, rgb(40, 40, 46), rgb(30, 30, 34), 2)
		local mottos =
			{ "NO PAIN\nNO GAIN", "PUSH\nHARDER", "BEAST\nMODE", "ONE MORE\nREP", "STRONGER\nTODAY", "NEVER\nQUIT" }
		local n = 0
		onPillars(room, 0.45, function(k)
			n += 1
			local poster = k.box(0, 5.0, -0.06, 3, 3.6, 0.06, C.BLACK)
			local art = Kit.gui(poster, Enum.NormalId.Front, 30)
			Kit.rect(art, 0, 0, 1, 1, if n % 2 == 0 then room.th.accent else rgb(24, 24, 28))
			Kit.rect(art, 0.06, 0.05, 0.88, 0.06, if n % 2 == 0 then C.WHITE else room.th.accent)
			Kit.text(art, mottos[(n - 1) % #mottos + 1], 0.06, 0.2, 0.88, 0.6, C.WHITE, Enum.Font.LuckiestGuy)
		end)
		-- mirrors over the dumbbells
		for _, pl in room.placed do
			if pl.name == "dumbbells" then
				local k = room.wall("-x", (pl.z0 + pl.z1) / 2)
				local mirror = k.box(0, 5.2, -0.08, 8.8, 3.6, 0.1, rgb(190, 200, 214), M.Glass)
				mirror.Reflectance = 0.5
				k.box(0, 5.2, -0.04, 9.1, 3.9, 0.06, C.DARK, M.Metal)
			end
		end
		local side, u = firstFree(room, { { "+x", 27 }, { "-z", 18 }, { "+x", -27 } })
		if side then
			clock(room, side, u, 5.4)
		end
	end,
})

-- 6 · the offices: desk pods under screens, a meeting table, filing, a printer, a whiteboard
table.insert(LIST, {
	name = "Offices",
	floor = rgb(98, 110, 130),
	floorMat = M.Carpet,
	border = { color = rgb(70, 78, 94), mat = M.Carpet },
	walk = { color = rgb(200, 182, 150), mat = M.WoodPlanks },
	wall = rgb(228, 232, 238),
	wallMat = M.Plaster,
	lower = rgb(228, 232, 238),
	lowerMat = M.Plaster,
	trim = rgb(250, 250, 252),
	trimMat = M.SmoothPlastic,
	frame = rgb(70, 76, 90),
	accent = rgb(110, 190, 255),
	accent2 = rgb(70, 86, 120),
	light = rgb(220, 236, 255),
	props = { { "plant", 3, 4 } },
	plan = function(p: Planner)
		p.put("deskpod", -20, -23.5, 0)
		p.put("deskpod", 0, -23.5, 0)
		p.put("meeting", 24, -2, Q)
		p.put("whiteboard", 24, 10.5, math.pi)
		p.put("deskpod", -23, 2, Q)
		p.against("filing", "-z", 22, 1)
		p.against("filing", "+x", -24, 1)
		p.against("printer", "+x", 21, 1)
		p.against("watercooler", "+z", 26, 1)
		p.put("armchairs", 6, 26, math.pi)
	end,
	dress = function(room: Room)
		-- the work areas' carpet, a shade lighter
		for _, pl in room.placed do
			if pl.name == "deskpod" or pl.name == "meeting" then
				room.floor.box(
					(pl.x0 + pl.x1) / 2,
					0.03,
					(pl.z0 + pl.z1) / 2,
					pl.x1 - pl.x0 + 2,
					0.05,
					pl.z1 - pl.z0 + 2,
					Pieces.lighter(room.th.floor, 0.18),
					M.Carpet
				)
			end
		end
		gallery(room, 0.35, C.DARK)
		local side, u = firstFree(room, { { "+z", -9 }, { "-x", -9 }, { "-z", 27 } })
		if side then
			clock(room, side, u, 5.4)
		end
		local side2, u2 = firstFree(room, { { "+z", 18 }, { "+x", 0 }, { "-x", 0 } })
		if side2 then
			sign(room, side2, u2, 5.2, 4, 1.4, "ROOFTOP CO.", room.th.accent2, C.WHITE, 0.8)
		end
	end,
})

-- 7 · the canteen: a serving counter under its menu, fridges and vending machines, tables and benches
table.insert(LIST, {
	name = "Canteen",
	floor = rgb(228, 208, 178),
	floorMat = M.CeramicTiles,
	border = { color = rgb(178, 98, 66), mat = M.CeramicTiles },
	walk = { color = rgb(200, 176, 146), mat = M.CeramicTiles },
	wall = rgb(248, 230, 202),
	wallMat = M.Plaster,
	lower = rgb(214, 122, 78),
	lowerMat = M.CeramicTiles,
	trim = rgb(110, 64, 44),
	trimMat = M.Wood,
	frame = rgb(90, 60, 44),
	accent = rgb(255, 120, 60),
	accent2 = rgb(70, 160, 120),
	light = rgb(255, 214, 170),
	props = { { "plant", 2, 3 } },
	plan = function(p: Planner)
		p.against("servery", "-z", 0, 0.5)
		p.against("glassfridge", "-z", -11.5, 0.2)
		p.against("glassfridge", "-z", -16, 0.2)
		p.against("vending", "-z", 11.5, 0.2)
		p.against("vending", "-z", 16, 0.2)
		for _, x in { 17, 27 } do
			for _, z in { -14, -3, 8 } do
				p.put("dining", x, z, 0)
				p.put("dining", -x, z, 0)
			end
		end
		p.put("longtable", 9, 26, 0)
		p.put("longtable", 25, 26, 0)
		p.against("bins", "+x", 18, 1)
	end,
	dress = function(room: Room)
		-- the menu over the counter
		local k = room.wall("-z", 0)
		local board = k.box(0, 6.1, -0.45, 11, 2.8, 0.2, rgb(30, 30, 34))
		local art = Kit.gui(board, Enum.NormalId.Front, 30, 1.3)
		Kit.text(art, "TODAY'S MENU", 0.05, 0.04, 0.9, 0.22, room.th.accent, Enum.Font.LuckiestGuy)
		local dishes = {
			"BURGER   5.50",
			"PIZZA SLICE   3.00",
			"NOODLE BOX   4.80",
			"SALAD BOWL   4.20",
			"FRIES   2.00",
			"SMOOTHIE   3.50",
		}
		for i, d in dishes do
			local col = if i <= 3 then 0 else 1
			local row = (i - 1) % 3
			local t = Kit.text(art, d, 0.06 + col * 0.47, 0.32 + row * 0.21, 0.42, 0.16, C.WHITE, Enum.Font.GothamBold)
			t.TextXAlignment = Enum.TextXAlignment.Left
		end
		for _, x in { -5, 5 } do
			k.rod(Vector3.new(x, 7.5, -0.45), Vector3.new(x, 8.55, -0.1), 0.06, C.STEEL, M.Metal)
		end
		gallery(room, 0.3, room.th.trim)
		local side, u = firstFree(room, { { "+x", -27 }, { "-x", -9 }, { "+z", 0 } })
		if side then
			clock(room, side, u, 5.4)
		end
	end,
})

-- 8 · the server room: rows of racks facing over their aisles, cooling units, a desk of screens
table.insert(LIST, {
	name = "Server Room",
	floor = rgb(150, 156, 168),
	floorMat = M.SmoothPlastic,
	walk = { color = rgb(66, 70, 82), mat = M.DiamondPlate },
	wall = rgb(46, 50, 62),
	wallMat = M.Plaster,
	lower = rgb(46, 50, 62),
	lowerMat = M.Plaster,
	trim = rgb(26, 28, 36),
	trimMat = M.Metal,
	frame = rgb(30, 32, 40),
	accent = rgb(60, 255, 170),
	accent2 = rgb(70, 140, 255),
	light = rgb(120, 255, 220),
	props = {},
	plan = function(p: Planner)
		for _, x in { -9, 9 } do
			p.put("rackrow", x, -16, 0, 1)
			p.put("rackrow", x, -26.5, math.pi, 1)
		end
		p.put("rackrow", -2, 24, 0, 1)
		p.put("rackrow", 22, 24, 0, 1)
		p.against("crac", "-x", -20, 1)
		p.against("crac", "-x", -6, 1)
		p.against("ups", "+x", -20, 1)
		p.against("firetanks", "-x", 8, 1)
		p.put("nocdesk", 24, 0, -Q)
	end,
	dress = function(room: Room)
		-- the raised floor's tiles
		floorPattern(room, function(art)
			for i = 0, 10 do
				Kit.rect(art, i / 10 - 0.003, 0, 0.006, 1, rgb(90, 96, 108))
				Kit.rect(art, 0, i / 10 - 0.003, 1, 0.006, rgb(90, 96, 108))
			end
			for _ = 1, 6 do
				local cx, cz = room.rng:NextInteger(0, 9), room.rng:NextInteger(0, 9)
				Kit.rect(art, cx / 10 + 0.01, cz / 10 + 0.01, 0.08, 0.08, rgb(110, 130, 160))
			end
		end)
		cableTrays(room, rgb(120, 126, 136), { rgb(240, 200, 50), rgb(60, 120, 230) })
		local side, u = firstFree(room, { { "+z", -9 }, { "-z", 27 }, { "+x", 9 } })
		if side then
			sign(room, side, u, 5.0, 3.6, 1.6, "AUTHORISED\nPERSONNEL ONLY", rgb(200, 30, 36), C.WHITE, 0.8)
		end
		neon(room, "-z", 0, 7.8, 8, 1.2, "DATA CENTRE 08", room.th.accent, Enum.Font.Code)
	end,
})

-- 9 · the greenhouse: raised beds under pink grow lights, fruit trees, a fountain, a gravel path
table.insert(LIST, {
	name = "Greenhouse",
	floor = rgb(168, 150, 126),
	floorMat = M.Slate,
	border = { color = rgb(96, 72, 52), mat = M.Ground },
	walk = { color = rgb(196, 186, 166), mat = M.Pebble },
	wall = rgb(226, 240, 230),
	wallMat = M.Plaster,
	lower = rgb(226, 240, 230),
	lowerMat = M.Plaster,
	trim = rgb(250, 252, 250),
	trimMat = M.SmoothPlastic,
	frame = rgb(240, 244, 240),
	accent = rgb(255, 80, 220),
	accent2 = rgb(255, 130, 170),
	light = rgb(255, 170, 240),
	props = { { "plant", 3, 4 }, { "wheelbarrow", 1, 1 } },
	plan = function(p: Planner)
		p.put("fountain", 0, -23, 0)
		for _, x in { -21, 21 } do
			p.put("raisedbed", x, -27, 0)
			p.put("raisedbed", x, -17, 0)
		end
		p.put("raisedbed", 25, 4, Q)
		p.put("raisedbed", -25, 2, Q)
		p.put("raisedbed", 2, 26, 0)
		for _, at in { { 31.5, -31.5 }, { -31.5, -31.5 }, { 30, 30 }, { -11, 30 } } do
			p.put("fruittree", at[1], at[2], 0, 1)
		end
		p.against("pottingbench", "+x", 18, 1)
	end,
	dress = function(room: Room)
		-- stepping stones from the walkway to the fountain
		for i = 0, 2 do
			room.floor.disc(room.rng:NextNumber(-0.6, 0.6), 0.04, -13 - i * 1.6, 1.4, 0.06, rgb(200, 192, 176), M.Slate)
		end
		-- vines climbing the walls
		onPillars(room, 0.5, function(k)
			for _, x in { -0.9, 0.9 } do
				k.box(x, 4.6, -0.08, 0.12, 6.8, 0.08, rgb(120, 90, 60), M.Wood)
			end
			for i = 0, 5 do
				k.blob(
					room.rng:NextNumber(-1.4, 1.4),
					1.6 + i * 1.05,
					-0.3,
					room.rng:NextNumber(1.0, 1.6),
					0.9,
					0.5,
					if i % 2 == 0 then C.LEAF else C.LEAF2,
					M.Grass
				)
			end
			if room.rng:NextNumber() < 0.5 then
				k.ball(room.rng:NextNumber(-1, 1), room.rng:NextNumber(3, 6), -0.5, 0.4, room.th.accent2, M.Fabric)
			end
		end)
		local side, u = firstFree(room, { { "-z", 0 }, { "+z", 18 }, { "-x", -9 } })
		if side then
			sign(
				room,
				side,
				u,
				7.8,
				5.6,
				1.1,
				"THE GREENHOUSE",
				rgb(110, 76, 50),
				rgb(250, 236, 200),
				0,
				Enum.Font.Fantasy
			)
		end
	end,
})

-- 10 · the library: bookcases along the walls and in stacks, reading tables with green lamps, a nook
table.insert(LIST, {
	name = "Library",
	floor = rgb(122, 46, 50),
	floorMat = M.Carpet,
	border = { color = rgb(112, 76, 52), mat = M.WoodPlanks },
	walk = { color = rgb(132, 92, 62), mat = M.WoodPlanks },
	wall = rgb(216, 198, 166),
	wallMat = M.Plaster,
	lower = rgb(98, 64, 44),
	lowerMat = M.Wood,
	trim = rgb(70, 44, 30),
	trimMat = M.Wood,
	frame = rgb(60, 40, 30),
	accent = rgb(255, 190, 90),
	accent2 = rgb(110, 40, 44),
	light = rgb(255, 210, 150),
	props = { { "plant", 1, 2 } },
	plan = function(p: Planner)
		for _, u in { -20, -8, 8, 20 } do
			p.against("bookcase", "-z", u, 0.5)
		end
		p.against("bookcase", "+x", -20, 0.5)
		p.put("stack", -22, -19, 0)
		p.put("stack", -22, -8, 0)
		p.put("readtable", 19, -18, 0)
		p.put("readtable", 22.5, -1, Q)
		p.put("nook", 25, 25, 0)
		p.put("libdesk", 0, 20, 0)
		p.put("globe", -9, 23, 0)
	end,
	dress = function(room: Room)
		rugsUnder(room, { readtable = true }, rgb(150, 110, 70), rgb(70, 40, 30), 1)
		gallery(room, 0.4, rgb(170, 130, 60), rgb(170, 130, 60))
		sconces(room, 0.8, rgb(170, 130, 60), rgb(255, 214, 160))
		local side, u = firstFree(room, { { "+z", 18 }, { "-x", -9 }, { "+x", 9 } })
		if side then
			sign(room, side, u, 5.2, 3, 1.2, "QUIET PLEASE", rgb(60, 40, 30), rgb(240, 220, 170), 0, Enum.Font.Garamond)
		end
	end,
})

-- 11 · the arcade: rows of cabinets, a pool table, air hockey, claw machines, a racer, a dance machine
table.insert(LIST, {
	name = "Arcade",
	floor = rgb(46, 28, 80),
	floorMat = M.Carpet,
	border = { color = rgb(26, 16, 48), mat = M.Carpet },
	walk = { color = rgb(30, 24, 46), mat = M.SmoothPlastic },
	wall = rgb(38, 26, 66),
	wallMat = M.Plaster,
	lower = rgb(38, 26, 66),
	lowerMat = M.Plaster,
	trim = rgb(110, 36, 170),
	trimMat = M.Neon,
	frame = rgb(30, 20, 50),
	accent = rgb(255, 60, 220),
	accent2 = rgb(60, 220, 255),
	light = rgb(220, 120, 255),
	props = {},
	plan = function(p: Planner)
		for i = 0, 7 do
			p.against("arcade", "-z", -14 + i * 4, 0.2)
		end
		for i = 0, 3 do
			p.against("arcade", "+x", -26 + i * 4, 0.2)
		end
		p.put("pooltable", -24, -12, 0)
		p.put("airhockey", 21, 3, 0)
		p.against("prizes", "+z", 24, 1)
		p.put("claw", 14, 24, 0)
		p.put("claw", 26, 18, 0)
		p.put("racer", 1, 26, 0)
		p.put("dance", -10, 27, 0)
		p.put("claw", -24, 4, 0)
	end,
	dress = function(room: Room)
		-- the carpet's neon confetti
		local colors = { room.th.accent, room.th.accent2, rgb(255, 230, 80), rgb(120, 255, 120) }
		for _ = 1, 26 do
			for _ = 1, 6 do
				local x, z = room.rng:NextNumber(-33, 33), room.rng:NextNumber(-33, 33)
				if room.open(x - 1, x + 1, z - 1, z + 1) then
					local c = Kit.pick(room.rng, colors):Lerp(Color3.new(0, 0, 0), 0.45)
					if room.rng:NextNumber() < 0.5 then
						room.floor.disc(x, 0.02, z, room.rng:NextNumber(0.5, 0.9), 0.03, c, M.Neon)
					else
						room.floor.part(
							CFrame.new(x, 0.02, z) * CFrame.Angles(0, room.rng:NextNumber(0, math.pi), 0),
							Vector3.new(room.rng:NextNumber(0.2, 0.3), 0.03, room.rng:NextNumber(0.9, 1.6)),
							c,
							M.Neon
						)
					end
					break
				end
			end
		end
		neon(room, "-x", -16, 7.8, 7, 1.3, "GAME ON", room.th.accent)
		neon(room, "+z", -2, 7.8, 8, 1.2, "HIGH SCORE", room.th.accent2)
		neon(room, "-x", 6, 7.8, 7, 1.2, "INSERT COIN", rgb(255, 230, 80), Enum.Font.Arcade)
		-- zigzags of neon on the walls
		onPillars(room, 0.6, function(k, _side, _u, n)
			local c = if n % 2 == 0 then room.th.accent else room.th.accent2
			for i = 0, 2 do
				k.part(
					CFrame.new(0, 3.9 + i * 0.95, -0.06) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 35 else -35)),
					Vector3.new(1.6, 0.14, 0.06),
					c,
					M.Neon
				)
			end
		end)
	end,
})

-- 12 · the hotel: beds with their nightstands and rugs, wardrobes, a TV, armchairs, a luggage trolley
table.insert(LIST, {
	name = "Hotel",
	floor = rgb(138, 44, 62),
	floorMat = M.Carpet,
	border = { color = rgb(196, 156, 90), mat = M.Carpet },
	walk = { color = rgb(110, 32, 46), mat = M.Carpet },
	wall = rgb(236, 222, 198),
	wallMat = M.Plaster,
	lower = rgb(116, 78, 54),
	lowerMat = M.Wood,
	trim = rgb(200, 164, 100),
	trimMat = M.SmoothPlastic,
	frame = rgb(90, 64, 46),
	accent = rgb(255, 200, 100),
	accent2 = rgb(60, 96, 116),
	light = rgb(255, 220, 170),
	props = { { "trolley", 1, 1 }, { "roomservice", 1, 1 }, { "plant", 2, 3 } },
	plan = function(p: Planner)
		for _, u in { -20, 0, 20 } do
			p.against("suite", "-z", u, 0.5)
		end
		p.against("suite", "+x", -14, 0.5)
		p.against("wardrobe", "-z", 10, 0.5)
		p.against("wardrobe", "-z", -10, 0.5)
		p.against("tvconsole", "+x", 4, 1)
		p.against("writingdesk", "+z", 4, 1)
		p.put("armchairs", -23, 2, -Q)
		p.put("armchairs", 23, 24, math.pi)
	end,
	dress = function(room: Room)
		gallery(room, 0.4, rgb(190, 150, 80))
		sconces(room, 0.7, rgb(190, 150, 80), rgb(255, 222, 170))
		-- a runner down the corridor side
		room.floor.box(-26, 0.03, -2, 3.4, 0.05, 30, rgb(196, 156, 90), M.Carpet)
		room.floor.box(-26, 0.05, -2, 2.6, 0.05, 29.2, rgb(90, 30, 40), M.Carpet)
	end,
})

-- 13 · the boiler room: two big boilers, tanks, pumps, a control panel, pipes along every wall
table.insert(LIST, {
	name = "Boiler Room",
	floor = rgb(86, 80, 76),
	floorMat = M.DiamondPlate,
	walk = { color = rgb(200, 160, 40), mat = M.DiamondPlate },
	wall = rgb(126, 78, 62),
	wallMat = M.Brick,
	lower = rgb(126, 78, 62),
	lowerMat = M.Brick,
	trim = rgb(60, 56, 54),
	trimMat = M.Metal,
	frame = rgb(50, 46, 44),
	accent = rgb(255, 110, 40),
	accent2 = rgb(255, 200, 60),
	light = rgb(255, 150, 80),
	props = { { "drums", 2, 3 }, { "crate", 2, 3 } },
	plan = function(p: Planner)
		p.put("boiler", -22, -20, 0)
		p.put("boiler", 22, -20, 0)
		p.put("vtank", -25, 4, 0)
		p.put("vtank", 25, 2, 0)
		p.put("vtank", 0, -27, 0)
		p.put("pump", -9, -24, 0)
		p.put("pump", 9, -24, 0)
		p.against("gauges", "+z", 6, 1)
		p.against("workbench", "+z", 22, 1)
	end,
	dress = function(room: Room)
		pipes(
			room,
			{ { y = 7.45, d = 0.6, color = rgb(70, 110, 80) }, { y = 8.15, d = 0.45, color = rgb(170, 60, 44) } }
		)
		for _, pl in room.placed do
			if pl.name == "boiler" then
				hatch(
					room,
					(pl.x0 + pl.x1) / 2,
					(pl.z0 + pl.z1) / 2,
					pl.x1 - pl.x0 + 2.4,
					pl.z1 - pl.z0 + 2.4,
					rgb(250, 200, 40),
					rgb(30, 30, 32)
				)
			end
		end
		local side, u = firstFree(room, { { "-z", -9 }, { "-x", 9 }, { "+x", 9 } })
		if side then
			sign(room, side, u, 5.0, 3.4, 1.8, "DANGER\nHIGH PRESSURE", rgb(250, 200, 40), C.BLACK, 0)
		end
		splats(room, 4, { rgb(50, 46, 44) }, 1.4)
	end,
})

-- 14 · the art studio: easels round a model's dais, sculptures, paint tables, canvases, a gallery wall
table.insert(LIST, {
	name = "Art Studio",
	floor = rgb(214, 196, 168),
	floorMat = M.WoodPlanks,
	walk = { color = rgb(170, 152, 128), mat = M.WoodPlanks },
	wall = rgb(250, 248, 242),
	wallMat = M.Plaster,
	lower = rgb(250, 248, 242),
	lowerMat = M.Plaster,
	trim = rgb(60, 60, 64),
	trimMat = M.SmoothPlastic,
	frame = rgb(40, 40, 44),
	accent = rgb(255, 90, 90),
	accent2 = rgb(80, 160, 255),
	light = rgb(255, 245, 230),
	props = { { "easel", 1, 2 }, { "plant", 1, 2 } },
	plan = function(p: Planner)
		local cx, cz = -21, -21
		p.put("modelstand", cx, cz, 0)
		for i = 0, 3 do
			local a = i * Q + math.pi / 4
			local x, z = cx + math.cos(a) * 9, cz + math.sin(a) * 9
			p.put("easel", x, z, facingAway(x, z, cx, cz), 0.5)
		end
		for _, at in { { 19, -26 }, { 27, -18 }, { 19, -10 }, { 27, -2 } } do
			p.put("plinth", at[1], at[2], 0, 1)
		end
		p.put("painttable", -23, 3, Q)
		p.put("worktable", 20, 22, 0)
		p.against("canvases", "+x", 14, 1)
		p.against("canvases", "-z", 2, 1)
	end,
	dress = function(room: Room)
		splats(room, 16, {
			rgb(230, 60, 60),
			rgb(60, 140, 240),
			rgb(250, 210, 60),
			rgb(80, 190, 110),
			rgb(160, 90, 200),
			rgb(30, 30, 34),
		}, 0.9)
		gallery(room, 0.85, C.DARK, C.DARK)
		-- a drop cloth under the paint table
		for _, pl in room.placed do
			if pl.name == "painttable" or pl.name == "modelstand" then
				room.floor.part(
					CFrame.new((pl.x0 + pl.x1) / 2, 0.03, (pl.z0 + pl.z1) / 2)
						* CFrame.Angles(0, room.rng:NextNumber(-0.2, 0.2), 0),
					Vector3.new(pl.x1 - pl.x0 + 3, 0.04, pl.z1 - pl.z0 + 3),
					rgb(236, 232, 220),
					M.Fabric
				)
			end
		end
	end,
})

-- 15 · the lab: island benches of glassware, glowing specimen tubes, a fume hood, freezers, a console
table.insert(LIST, {
	name = "Lab",
	floor = rgb(226, 234, 238),
	floorMat = M.CeramicTiles,
	border = { color = rgb(70, 92, 106), mat = M.CeramicTiles },
	walk = { color = rgb(196, 208, 214), mat = M.CeramicTiles },
	wall = rgb(234, 242, 246),
	wallMat = M.Plaster,
	lower = rgb(206, 224, 230),
	lowerMat = M.CeramicTiles,
	trim = rgb(80, 100, 112),
	trimMat = M.SmoothPlastic,
	frame = rgb(70, 90, 100),
	accent = rgb(90, 255, 140),
	accent2 = rgb(90, 200, 255),
	light = rgb(210, 255, 235),
	props = { { "plant", 1, 1 } },
	plan = function(p: Planner)
		p.put("labbench", -19, -21, 0)
		p.put("labbench", 19, -21, 0)
		p.put("labbench", -23, -3, Q)
		for _, at in { { 0, -27 }, { 26, 1 }, { 25, 26 }, { -26, 12 } } do
			p.put("specimen", at[1], at[2], 0)
		end
		p.against("fumehood", "-z", -27, 1)
		p.against("chemcab", "-z", 27, 1)
		p.against("freezer", "+x", 14, 0.5)
		p.against("freezer", "+x", 18.9, 0.5)
		p.put("console", 12, 24, 0)
	end,
	dress = function(room: Room)
		for _, pl in room.placed do
			if pl.name == "specimen" then
				local x, z = (pl.x0 + pl.x1) / 2, (pl.z0 + pl.z1) / 2
				room.floor.disc(x, 0.02, z, 6.4, 0.03, rgb(250, 200, 40))
				room.floor.disc(x, 0.03, z, 5.8, 0.03, room.th.floor, M.CeramicTiles)
			end
		end
		local signs = {
			{ "BIOHAZARD", rgb(250, 200, 40), C.BLACK },
			{ "LASER IN USE", rgb(200, 30, 36), C.WHITE },
			{ "EYE WASH", rgb(30, 150, 80), C.WHITE },
			{ "AUTHORISED\nSTAFF ONLY", rgb(40, 80, 160), C.WHITE },
		}
		local n = 0
		onPillars(room, 0.35, function(k)
			n += 1
			if n <= #signs then
				local s = signs[n]
				Pieces.sign(k, 0, 5.0, 2.8, 1.6, s[1] :: string, s[2] :: Color3, s[3] :: Color3)
			end
		end)
		local side, u = firstFree(room, { { "+z", -9 }, { "-x", -9 } })
		if side then
			local k = room.wall(side, u)
			local board = k.box(0, 5.2, -0.08, 4.4, 2.8, 0.1, C.WHITE)
			local art = Kit.gui(board, Enum.NormalId.Front, 30)
			Kit.text(art, "E = mc²", 0.05, 0.05, 0.6, 0.3, rgb(30, 60, 160), Enum.Font.PermanentMarker)
			Kit.text(art, "C₆H₁₂O₆ + 6O₂", 0.05, 0.4, 0.8, 0.22, rgb(200, 40, 40), Enum.Font.PermanentMarker)
			Kit.text(art, "?!", 0.7, 0.65, 0.25, 0.3, rgb(30, 130, 60), Enum.Font.PermanentMarker)
			k.box(0, 5.2, -0.04, 4.6, 3.0, 0.06, C.STEEL, M.Metal)
		end
	end,
})

-- 16 · the nightclub: a DJ booth and speaker stacks over a lit dance floor under a lighting rig, a bar,
-- booths, high tables
table.insert(LIST, {
	name = "Nightclub",
	floor = rgb(26, 22, 36),
	floorMat = M.Glass,
	walk = { color = rgb(40, 34, 56), mat = M.SmoothPlastic },
	wall = rgb(28, 22, 42),
	wallMat = M.Plaster,
	lower = rgb(28, 22, 42),
	lowerMat = M.Plaster,
	trim = rgb(150, 20, 96),
	trimMat = M.Neon,
	frame = rgb(20, 16, 30),
	accent = rgb(255, 40, 160),
	accent2 = rgb(40, 200, 255),
	light = rgb(255, 80, 200),
	props = { { "hightable", 2, 3 } },
	plan = function(p: Planner)
		p.against("djbooth", "-z", 0, 0.1)
		p.put("truss", 0, -20.3, 0, 0.1)
		p.put("speaker", -8.5, -32, 0, 0.1)
		p.put("speaker", 8.5, -32, 0, 0.1)
		p.against("barlux", "+x", -16, 1)
		p.put("booth", -25, -6, -Q)
		p.put("booth", -25, 6, -Q)
		p.put("booth", 6, 27, 0)
		p.put("hightable", 20, 8, 0)
		p.put("hightable", 26, 22, 0)
	end,
	dress = function(room: Room)
		neon(room, "+z", 18, 7.8, 10, 1.4, "ROOFTOP CLUB", room.th.accent)
		neon(room, "-x", -18, 7.8, 6, 1.2, "DANCE", room.th.accent2)
		onPillars(room, 0.8, function(k, _side, _u, n)
			local c = if n % 2 == 0 then room.th.accent else room.th.accent2
			k.box(-1.6, 4.9, -0.06, 0.16, 3.6, 0.08, c:Lerp(Color3.new(0, 0, 0), 0.3), M.Neon)
			k.box(1.6, 4.9, -0.06, 0.16, 3.6, 0.08, c:Lerp(Color3.new(0, 0, 0), 0.3), M.Neon)
		end)
	end,
})

-- 17 · the building site: scaffolding, a new wall going up, a cement mixer, sand, steel, a work light
table.insert(LIST, {
	name = "Construction",
	floor = rgb(162, 158, 150),
	floorMat = M.Concrete,
	walk = { color = rgb(136, 132, 126), mat = M.Concrete },
	wall = rgb(198, 194, 184),
	wallMat = M.Concrete,
	lower = rgb(198, 194, 184),
	lowerMat = M.Concrete,
	trim = rgb(150, 146, 140),
	trimMat = M.Concrete,
	frame = rgb(90, 90, 94),
	accent = rgb(255, 200, 40),
	accent2 = rgb(255, 140, 40),
	light = rgb(255, 230, 170),
	props = { { "crate", 3, 4 }, { "barrier", 1, 2 }, { "cones", 1, 2 }, { "bricks", 1, 2 }, { "blocks", 1, 1 } },
	plan = function(p: Planner)
		p.put("scaffold", -20, -31.5, 0, 0.5)
		p.put("scaffold", 4, -31.5, 0, 0.5)
		p.put("scaffold", 31.5, -8, Q, 0.5)
		p.put("framing", -20, -16, 0)
		p.put("framing", 20, 22, Q)
		p.put("mixer", 20, -18, 0)
		p.put("sandpile", 26, -27, 0)
		p.put("ibeams", -26, 4, 0)
		p.put("rebar", -15, 6, 0)
		p.put("worklight", -12, -22, 0)
		p.put("worklight", 12, -24, 0)
		p.put("porta", 30, 30, 0)
		p.against("toolchest", "+z", 2, 1)
	end,
	dress = function(room: Room)
		-- plastic sheeting over some windows
		for _, side in SIDES do
			for _, u in room.windows do
				if room.rng:NextNumber() < 0.12 and room.free(side, u, 2.4) then
					local k = room.wall(side, u)
					local sheet = k.box(0, 5.1, -0.35, 4.6, 4.4, 0.04, rgb(236, 240, 244), M.SmoothPlastic)
					sheet.Transparency = 0.35
				end
			end
		end
		splats(room, 8, { rgb(140, 136, 130), rgb(176, 172, 164) }, 2.2)
		-- spray-painted marks
		for _ = 1, 4 do
			local x, z = room.rng:NextNumber(-30, 30), room.rng:NextNumber(-30, 30)
			if room.open(x - 1, x + 1, z - 1, z + 1) then
				for _, a in { 45, -45 } do
					room.floor.part(
						CFrame.new(x, 0.02, z) * CFrame.Angles(0, math.rad(a), 0),
						Vector3.new(0.25, 0.03, 1.8),
						room.th.accent2,
						M.SmoothPlastic
					)
				end
			end
		end
		local side, u = firstFree(room, { { "-x", -9 }, { "+z", -9 }, { "+x", 9 } })
		if side then
			local k = room.wall(side, u)
			k.face(0, 5.2, -0.1, 2.6, 0.12, rgb(30, 90, 190))
			local board = k.box(0, 5.2, -0.18, 1.8, 1.2, 0.02, rgb(30, 90, 190))
			board.Transparency = 1
			Kit.text(
				Kit.gui(board, Enum.NormalId.Front, 40),
				"HARD HAT\nAREA",
				0,
				0,
				1,
				1,
				C.WHITE,
				Enum.Font.GothamBlack
			)
		end
		local side2, u2 = firstFree(room, { { "+z", 9 }, { "-z", 18 }, { "-x", 0 } })
		if side2 then
			sign(room, side2, u2, 5.0, 3.6, 1.8, "DANGER\nSITE WORKS", rgb(250, 200, 40), C.BLACK, 0)
		end
	end,
})

-- 18 · the archive: rows of steel shelving, filing cabinets, a vault door, a map chest, a reader
table.insert(LIST, {
	name = "Archive",
	floor = rgb(172, 178, 186),
	floorMat = M.SmoothPlastic,
	border = { color = rgb(122, 130, 142), mat = M.SmoothPlastic },
	walk = { color = rgb(132, 140, 152), mat = M.SmoothPlastic },
	wall = rgb(198, 206, 218),
	wallMat = M.Plaster,
	lower = rgb(198, 206, 218),
	lowerMat = M.Plaster,
	trim = rgb(80, 90, 110),
	trimMat = M.SmoothPlastic,
	frame = rgb(70, 80, 96),
	accent = rgb(120, 170, 255),
	accent2 = rgb(90, 110, 150),
	light = rgb(210, 225, 255),
	props = { { "boxstack", 2, 3 }, { "bookcart", 1, 1 } },
	plan = function(p: Planner)
		for _, x in { -18, 0, 18 } do
			p.put("archshelf", x, -17, 0, 1.5)
			p.put("archshelf", x, -26, 0, 1.5)
		end
		p.against("vault", "+x", 0, 1)
		p.against("filing", "-x", -20, 1)
		p.against("filing", "-x", -8, 1)
		p.put("mapcab", 22, 22, 0)
		p.against("readdesk", "+z", 6, 1)
	end,
	dress = function(room: Room)
		local side, u = firstFree(room, { { "-z", 0 }, { "+z", 18 }, { "-x", 9 } })
		if side then
			sign(room, side, u, 7.8, 6, 1.1, "ARCHIVE · RESTRICTED", rgb(40, 50, 70), room.th.accent, 0.8)
		end
		local side2, u2 = firstFree(room, { { "+z", -9 }, { "+x", 18 }, { "-x", 0 } })
		if side2 then
			clock(room, side2, u2, 5.4)
		end
		local side3, u3 = firstFree(room, { { "+x", -27 }, { "+z", 27 } })
		if side3 then
			extinguisher(room, side3, u3)
		end
	end,
})

-- 19 · the penthouse: a sofa round a glass table by the fireplace, a grand piano, a bar, dinner for six,
-- an aquarium, sculptures
table.insert(LIST, {
	name = "Penthouse",
	floor = rgb(48, 42, 56),
	floorMat = M.Marble,
	border = { color = rgb(176, 140, 80), mat = M.Marble },
	walk = { color = rgb(70, 62, 82), mat = M.Marble },
	wall = rgb(72, 60, 90),
	wallMat = M.Plaster,
	lower = rgb(72, 60, 90),
	lowerMat = M.Plaster,
	trim = rgb(200, 160, 80),
	trimMat = M.Metal,
	frame = rgb(40, 34, 48),
	accent = rgb(255, 200, 80),
	accent2 = rgb(160, 90, 255),
	light = rgb(255, 210, 150),
	props = { { "plinth", 1, 2 }, { "plant", 2, 3 } },
	plan = function(p: Planner)
		p.against("fireplace", "-z", -22, 1)
		p.put("sectional", -22, -19.5, 0)
		p.put("grandpiano", 22, -22, 0)
		p.against("barlux", "+x", 4, 1)
		p.put("diningset", -23, 5, Q)
		p.against("aquarium", "+z", 22, 1)
		p.put("palm", 30.5, -30.5, 0, 0.5)
		p.put("palm", -2, 30, 0)
	end,
	dress = function(room: Room)
		gallery(room, 0.55, rgb(200, 160, 80), rgb(200, 160, 80))
		sconces(room, 0.6, rgb(200, 160, 80), rgb(255, 214, 160))
	end,
})

-- 20 · the machine room: the lift's hoists, a generator, a transformer, control cabinets, cable drums
table.insert(LIST, {
	name = "Machine Room",
	floor = rgb(66, 68, 76),
	floorMat = M.DiamondPlate,
	walk = { color = rgb(200, 170, 40), mat = M.DiamondPlate },
	wall = rgb(98, 102, 112),
	wallMat = M.Metal,
	lower = rgb(98, 102, 112),
	lowerMat = M.Metal,
	trim = rgb(240, 190, 40),
	trimMat = M.SmoothPlastic,
	frame = rgb(50, 52, 58),
	accent = rgb(255, 50, 50),
	accent2 = rgb(255, 200, 40),
	light = rgb(255, 130, 110),
	props = { { "spool", 1, 2 }, { "crate", 3, 4 } },
	plan = function(p: Planner)
		p.put("hoist", -20, -21, 0)
		p.put("hoist", 20, -21, 0)
		p.put("generator", -24, 6, 0)
		p.put("transformer", 24, 2, 0)
		p.against("controlcab", "-z", 0, 1)
		p.against("controlcab", "+z", 20, 1)
		p.against("fanunit", "+x", 20, 1)
	end,
	dress = function(room: Room)
		for _, pl in room.placed do
			if pl.name == "hoist" or pl.name == "transformer" then
				hatch(
					room,
					(pl.x0 + pl.x1) / 2,
					(pl.z0 + pl.z1) / 2,
					pl.x1 - pl.x0 + 1.6,
					pl.z1 - pl.z0 + 1.6,
					rgb(250, 200, 40),
					rgb(30, 30, 32)
				)
			end
		end
		cableTrays(room, rgb(140, 146, 156), { rgb(30, 30, 34), rgb(200, 40, 40) })
		local side, u = firstFree(room, { { "-x", -9 }, { "+z", -9 }, { "+x", -9 } })
		if side then
			sign(room, side, u, 5.0, 3.4, 1.8, "DANGER\nHIGH VOLTAGE", rgb(250, 200, 40), C.BLACK, 0)
		end
		local side2, u2 = firstFree(room, { { "-z", 18 }, { "-x", 9 }, { "+z", 0 } })
		if side2 then
			local k = room.wall(side2, u2)
			k.box(0, 4.6, -0.3, 1.2, 1.2, 0.6, rgb(250, 200, 40), M.Metal)
			k.face(0, 4.6, -0.65, 0.8, 0.2, rgb(220, 30, 30), M.SmoothPlastic)
			Pieces.sign(k, 0, 5.8, 2.2, 0.5, "EMERGENCY STOP", rgb(220, 30, 30), C.WHITE)
		end
	end,
})

Themes.LIST = LIST

function Themes.forFloor(i: number): Theme
	return LIST[(i % #LIST) + 1]
end

return Themes
