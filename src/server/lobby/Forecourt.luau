--!strict
-- The lobby's forecourt: a lit plaza at the end of the walkway in front of the tower (server/common/World
-- builds the tower's foot, the walkway and the valley; this adds the plaza). Players arrive here and wait
-- for the next race:
--   the countdown board  over the walkway, facing the plaza ("NEXT RACE 0:32", how many are waiting);
--                        each client writes the time on it from LobbyState (client/lobby/LobbyUi)
--   leaderboards         three boards on the plaza's sides (most escapes, most knock-outs, fastest escape),
--                        written by the server every minute
--   the rules board      how a race goes, in a few lines
--   lamps, benches, kerbs, and the spawn in the middle
--   an invisible fence round it all: you can roam the plaza but not walk, jump or fall off it (only
--                        climbers bump into it, and LobbyService makes the bodies here climbers)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Shared.Progress)
local CollisionGroups = require(script.Parent.Parent.Common.CollisionGroups)

local Forecourt = {}

local Z0, Z1 = 114, 178 -- the plaza runs from the walkway's end out along the valley
local X = 44 -- half its width
local ZC = (Z0 + Z1) / 2
local G = 0.6 -- the plaza's surface: just above the valley's dirt track, which runs on under it

local CONCRETE = Color3.fromRGB(128, 124, 136)
local CONCRETE_DARK = Color3.fromRGB(92, 88, 102)
local WARM = Color3.fromRGB(255, 190, 120)
local INK = Color3.fromRGB(20, 16, 32)
local CHALK = Color3.fromRGB(240, 236, 226)
local ACCENT = Color3.fromRGB(255, 90, 170)

local folder: Model
local boardLists: { [string]: Frame } = {}

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or folder
	return p
end

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

local function text(parent: Instance, s: string, size: number, font: Enum.Font, color: Color3, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size)
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = s
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

-- a board on two posts facing `facing` (a unit vector on the ground); returns the SurfaceGui's page
local function board(name: string, at: Vector3, facing: Vector3, w: number, h: number, lift: number): Frame
	local cf = CFrame.lookAt(at + Vector3.new(0, lift + h / 2, 0), at + Vector3.new(0, lift + h / 2, 0) + facing)
	local slab = part(name, Vector3.new(w, h, 0.6), cf, INK, Enum.Material.SmoothPlastic)
	part(name .. "Frame", Vector3.new(w + 0.8, h + 0.8, 0.4), cf * CFrame.new(0, 0, 0.2), CONCRETE_DARK)
	for _, sx in { -1, 1 } do
		local post = cf * CFrame.new(sx * (w / 2 - 1), -(h / 2 + lift / 2), 0.4)
		part(name .. "Post", Vector3.new(0.8, lift, 0.8), post, CONCRETE_DARK)
	end
	local glow = part(
		name .. "Glow",
		Vector3.new(w, 0.3, 0.3),
		cf * CFrame.new(0, h / 2 + 0.4, -0.4),
		ACCENT,
		Enum.Material.Neon
	)
	light(glow, ACCENT, 14, 0.8)
	local g = Instance.new("SurfaceGui")
	g.Name = "Screen"
	g.Face = Enum.NormalId.Front
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 24
	local page = Instance.new("Frame")
	page.Name = "Page"
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.05, 0)
	pad.PaddingBottom = UDim.new(0.04, 0)
	pad.Parent = page
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = page
	g.Parent = slab
	return page
end

local function lamp(x: number, z: number)
	part("LampPost", Vector3.new(0.7, 12, 0.7), CFrame.new(x, G + 6, z), CONCRETE_DARK, Enum.Material.Metal)
	local head = part("LampHead", Vector3.new(2.2, 1, 2.2), CFrame.new(x, G + 12.3, z), WARM, Enum.Material.Neon)
	light(head, WARM, 34, 1.6)
end

local function bench(x: number, z: number, yaw: number)
	local cf = CFrame.new(x, G, z) * CFrame.Angles(0, yaw, 0)
	part("Bench", Vector3.new(8, 0.5, 2.2), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(120, 84, 56), Enum.Material.Wood)
	part(
		"BenchBack",
		Vector3.new(8, 2, 0.4),
		cf * CFrame.new(0, 2.8, 1),
		Color3.fromRGB(120, 84, 56),
		Enum.Material.Wood
	)
	for _, sx in { -3.2, 3.2 } do
		part("BenchLeg", Vector3.new(0.5, 1.6, 2), cf * CFrame.new(sx, 0.8, 0), CONCRETE_DARK, Enum.Material.Metal)
	end
end

function Forecourt.build()
	local old = workspace:FindFirstChild("Forecourt")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Model")
	folder.Name = "Forecourt"
	folder:SetAttribute("Floor", -1)
	folder.Parent = workspace

	-- the plaza, its kerb and a ring of lamps
	part("Plaza", Vector3.new(2 * X, 1.6, Z1 - Z0), CFrame.new(0, G - 0.8, ZC), CONCRETE, Enum.Material.Concrete)
	part("PlazaInlay", Vector3.new(30, 0.06, 30), CFrame.new(0, G + 0.03, ZC + 4), CONCRETE_DARK, Enum.Material.Slate)
	for _, sx in { -1, 1 } do
		part("Kerb", Vector3.new(1.2, 0.8, Z1 - Z0), CFrame.new(sx * (X + 0.6), G + 0.1, ZC), CONCRETE_DARK)
	end
	part("Kerb", Vector3.new(2 * X + 2.4, 0.8, 1.2), CFrame.new(0, G + 0.1, Z1 + 0.6), CONCRETE_DARK)
	-- the fence: round the kerbs' outer edges, and across the walkway where it meets the plaza
	CollisionGroups.fence(folder, -X - 1.2, X + 1.2, Z0, Z1 + 1.2, G - 2, G + 40)
	for _, z in { Z0 + 10, ZC, Z1 - 8 } do
		lamp(-X + 2, z)
		lamp(X - 2, z)
	end
	bench(-X + 6, ZC + 18, math.rad(90))
	bench(X - 6, ZC + 18, math.rad(-90))
	bench(-16, Z1 - 4, 0)
	bench(16, Z1 - 4, 0)

	-- where you arrive (no force field: there's no fighting here)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Arrive"
	spawn.Anchored = true
	spawn.Size = Vector3.new(20, 1, 14)
	spawn.CFrame = CFrame.new(0, G - 0.45, ZC + 12)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = folder

	-- the countdown, over the walkway where it meets the plaza, facing the plaza
	local page = board("Countdown", Vector3.new(0, G, Z0 - 2), Vector3.new(0, 0, 1), 26, 9, 9)
	local title = text(page, "NEXT RACE", 70, Enum.Font.LuckiestGuy, CHALK, 1)
	title.Name = "Title"
	local clock = text(page, "–", 80, Enum.Font.LuckiestGuy, ACCENT, 2)
	clock.Name = "Clock"
	local waiting = text(page, "", 34, Enum.Font.GothamBold, CHALK, 3)
	waiting.Name = "Waiting"

	-- the leaderboards and the rules
	local spots = {
		{ id = "wins", at = Vector3.new(-X + 1, G, ZC - 14), facing = Vector3.new(1, 0, 0) },
		{ id = "knockouts", at = Vector3.new(-X + 1, G, ZC + 4), facing = Vector3.new(1, 0, 0) },
		{ id = "bestTime", at = Vector3.new(X - 1, G, ZC - 14), facing = Vector3.new(-1, 0, 0) },
	}
	for _, b in Progress.BOARDS do
		for _, s in spots do
			if s.id == b.id then
				local p = board("Board_" .. b.id, s.at, s.facing, 14, 12, 3)
				text(p, string.upper(b.title), 40, Enum.Font.LuckiestGuy, CHALK, 0)
				local rows = Instance.new("Frame")
				rows.Name = "Rows"
				rows.BackgroundTransparency = 1
				rows.Size = UDim2.new(1, 0, 1, -50)
				rows.LayoutOrder = 1
				rows.Parent = p
				local l = Instance.new("UIListLayout")
				l.SortOrder = Enum.SortOrder.LayoutOrder
				l.Parent = rows
				boardLists[b.id] = rows
			end
		end
	end
	local rules = board("Rules", Vector3.new(X - 1, G, ZC + 4), Vector3.new(-1, 0, 0), 14, 12, 3)
	text(rules, "HOW IT GOES", 40, Enum.Font.LuckiestGuy, CHALK, 0)
	for i, line in
		{
			"20 climbers race up a 20-floor tower.",
			"Ride the platforms up the shaft.",
			"Fight your way past the others.",
			"The roof opens at 4:00.",
			"Only one can escape:",
			"be alone on a platform",
			"through the roof to win.",
		}
	do
		text(rules, line, 26, Enum.Font.GothamBold, if i == 5 then ACCENT else CHALK, i)
	end
	Forecourt.showBoards({})
end

-- write the leaderboards' rows (from ProfileStore.readBoards)
function Forecourt.showBoards(data: { { id: string, rows: { { name: string, value: string } } } })
	for id, rows in boardLists do
		for _, c in rows:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local found = nil
		for _, b in data do
			if b.id == id then
				found = b
			end
		end
		local list = if found then found.rows else {}
		if #list == 0 then
			local empty = Instance.new("Frame")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 30)
			text(empty, "No one yet. Be the first!", 30, Enum.Font.GothamMedium, CHALK, 0).Size = UDim2.fromScale(1, 1)
			empty.Parent = rows
		end
		for i, row in list do
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.Size = UDim2.new(1, 0, 0, 30)
			f.LayoutOrder = i
			local name = text(f, `{i}. {row.name}`, 30, Enum.Font.GothamBold, if i == 1 then ACCENT else CHALK, 0)
			name.Size = UDim2.fromScale(0.72, 1)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local value = text(f, row.value, 30, Enum.Font.GothamBold, CHALK, 0)
			value.Size = UDim2.fromScale(0.28, 1)
			value.Position = UDim2.fromScale(0.72, 0)
			value.TextXAlignment = Enum.TextXAlignment.Right
			f.Parent = rows
		end
	end
end

return Forecourt
