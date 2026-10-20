--!strict
-- The floors above you are cut away (like the original), so the camera looks down into your floor from
-- above. Only on your screen: each client hides the floors above its own player, and anyone or
-- anything up there (pickup labels included). Parts that reach the client late are hidden as they
-- arrive, so this holds even with instance streaming on.
-- The outer wall between the camera and you is cut away too, like the original's dollhouse view, but only
-- one wall (the floors are big here): the one on the camera's side of you, kept until another is clearly
-- more so (no flicker at a corner). The camera then stays out past it (client/race/CameraAim).
-- While you watch someone else (out of the race: client/race/Spectate) all of this follows them.
-- Hidden floors are only not drawn (LocalTransparencyModifier): to the lighting they're still there,
-- like the original's invisible-but-shadowing ceiling. Making them truly transparent changed the
-- building's shape for the lighting, which took seconds to catch up: rooms started dark.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local FH = Config.FLOOR_HEIGHT

local Cutaway = {}

local shown = math.huge -- the highest floor shown (everything above it is hidden)
local suspended = false -- a set piece wants the whole tower shown
Cutaway.focus = nil :: Model? -- whose floor is shown (nil: your own body); Spectate sets the one you watch

local function setPart(d: Instance, hidden: boolean)
	if d:IsA("BasePart") then
		d.LocalTransparencyModifier = if hidden then 1 else 0
	elseif d:IsA("Light") or d:IsA("SurfaceGui") then
		-- (a light up there would shine down through the floors; painted numbers don't hide with
		-- their part)
		d.Enabled = not hidden
	end
end

-- the floor a part of the tower belongs to (its FloorNN model's Floor attribute)
local function floorOf(d: Instance): number?
	local node = d.Parent
	while node and node ~= workspace do
		local f = node:GetAttribute("Floor")
		if type(f) == "number" then
			return f
		end
		node = node.Parent
	end
	return nil
end

-- each floor's parts, lights and painted numbers (gathered once, kept up as parts arrive or go), and
-- whether the floor is hidden now: a new cut only touches the floors that change side
local floors: { [number]: { [Instance]: boolean } } = {}
local hiddenFloors: { [number]: boolean } = {}
-- each floor's outer walls, by side ("+x", "-x", "+z", "-z": server/common/Tower tags the parts)
local sides: { [number]: { [string]: { [BasePart]: boolean } } } = {}
local cutFloor: number?, cutSide: string? = nil, nil

local function showSide(f: number, side: string, cut: boolean)
	local set = sides[f] and sides[f][side]
	if not set then
		return
	end
	local hide = cut or hiddenFloors[f] == true
	for p in set do
		p.LocalTransparencyModifier = if hide then 1 else 0
	end
end

-- cut away this wall (nil: none), putting the last one back
local function setCut(f: number?, side: string?)
	if f == cutFloor and side == cutSide then
		return
	end
	if cutFloor and cutSide then
		showSide(cutFloor, cutSide, false)
	end
	cutFloor, cutSide = f, side
	if f and side then
		showSide(f, side, true)
	end
end

local function apply(top: number)
	shown = top
	for f, items in floors do
		local hidden = f > top
		if (hiddenFloors[f] or false) ~= hidden then
			hiddenFloors[f] = hidden
			for d in items do
				setPart(d, hidden)
			end
		end
	end
	if cutFloor and cutSide then
		showSide(cutFloor, cutSide, true) -- (a floor shown again comes back whole: keep its cut)
	end
end

-- people, pickups and platforms above the cut aren't drawn either, nor their labels. Most of them sit
-- wholly below the cut (or above it) tick after tick: those are left alone until they cross it, or
-- something is added to them.
type Seen = { side: string, dirty: boolean }
local seen: { [Instance]: Seen } = setmetatable({}, { __mode = "k" }) :: any
local REACH = 6 -- studs a pickup's model and label reach from its holder

local function setAll(model: Instance, cutY: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if d.Position.Y > cutY then 1 else 0
		elseif d:IsA("BillboardGui") then
			local at = d.Parent
			d.Enabled = not (at and at:IsA("BasePart") and at.Position.Y > cutY)
		end
	end
end

local function hideAbove(cutY: number)
	local function each(model: Instance)
		local low, high
		if model:IsA("Model") then
			local cf, size = model:GetBoundingBox()
			local r = size.Magnitude / 2 -- (however it's turned)
			low, high = cf.Position.Y - r, cf.Position.Y + r
		elseif model:IsA("BasePart") then
			low, high = model.Position.Y - REACH, model.Position.Y + REACH
		else
			setAll(model, cutY)
			return
		end
		local side = if high < cutY then "below" elseif low > cutY then "above" else "across"
		local s = seen[model]
		if not s then
			s = { side = "", dirty = true }
			seen[model] = s
			model.DescendantAdded:Connect(function()
				s.dirty = true
			end)
		end
		if side ~= "across" and side == s.side and not s.dirty then
			return
		end
		s.side, s.dirty = side, false
		setAll(model, cutY)
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			each(p.Character)
		end
	end
	for _, name in { "Bots", "Pickups" } do
		local f = workspace:FindFirstChild(name)
		if f then
			for _, m in f:GetChildren() do
				each(m)
			end
		end
	end
	-- a platform goes by its deck's top: it fades out as it rises into your ceiling (and one stopped at
	-- the floor above, sitting in your ceiling's hole, isn't drawn)
	local platforms = workspace:FindFirstChild("Platforms")
	if platforms then
		local ceiling = cutY - 0.5 -- the underside of the slab above you
		for _, deck in platforms:GetChildren() do
			if deck:IsA("BasePart") then
				local top = deck.Position.Y + deck.Size.Y / 2
				-- fully faded once its top reaches the floor above (ceiling + SLAB), starting 3 studs before
				deck.LocalTransparencyModifier = math.clamp((top - (ceiling - 3)) / (3 + Config.SLAB), 0, 1)
			end
		end
	end
end

local function track(f: number, items: { [Instance]: boolean }, d: Instance)
	if d:IsA("BasePart") or d:IsA("Light") or d:IsA("SurfaceGui") then
		items[d] = true
	end
	local side = d:GetAttribute("Side")
	if d:IsA("BasePart") and type(side) == "string" then
		local bySide = sides[f] or {}
		sides[f] = bySide
		local set = bySide[side] or {}
		bySide[side] = set
		set[d] = true
	end
end

local function watch(tower: Instance)
	shown = math.huge
	table.clear(floors)
	table.clear(hiddenFloors)
	table.clear(sides)
	cutFloor, cutSide = nil, nil
	for _, m in tower:GetChildren() do
		local f = m:GetAttribute("Floor")
		if type(f) == "number" then
			local items = floors[f] or {}
			floors[f] = items
			for _, d in m:GetDescendants() do
				track(f, items, d)
			end
		end
	end
	tower.DescendantAdded:Connect(function(d)
		local f = floorOf(d)
		if not f then
			return
		end
		local items = floors[f] or {}
		floors[f] = items
		track(f, items, d)
		if items[d] and hiddenFloors[f] then
			setPart(d, true)
		end
	end)
	tower.DescendantRemoving:Connect(function(d)
		local f = floorOf(d)
		local items = f and floors[f]
		if items then
			items[d] = nil
		end
		local side = d:GetAttribute("Side")
		local set = f and type(side) == "string" and sides[f] and sides[f][side]
		if set then
			set[d :: BasePart] = nil
		end
	end)
end

-- is this part of the tower on a floor that's cut away right now?
function Cutaway.hides(d: Instance): boolean
	local f = floorOf(d)
	return f ~= nil and hiddenFloors[f] == true
end

-- the building's own shell: walls, floors, glass and trim are never ghosted (client/race/Sightline)
local SHELL = {
	Slab = true,
	Wall = true,
	Skin = true,
	Glass = true,
	Lip = true,
	LipGlow = true,
	Parapet = true,
	Hatch = true,
	ShaftGate = true,
	CrateFence = true,
	Baseboard = true,
	Band = true,
	FloorPaint = true,
	Pit = true,
}

-- What may turn see-through when it stands between the camera and you (client/race/Sightline), and the
-- camera may pass through (client/race/CameraAim): a piece of furniture (the whole piece), a loose crate,
-- or one of the roof's props. nil for the building itself and anything outside it.
function Cutaway.ghostOf(part: BasePart): Instance?
	if SHELL[part.Name] then
		return nil
	end
	if part.CollisionGroup == "Crates" then
		return part
	end
	local node: Instance? = part
	while node and node ~= workspace do
		local parent = node.Parent
		if parent and parent.Name == "Furniture" then
			return node -- (one piece: a Model under the floor's Furniture)
		elseif parent and parent.Name == "Roof" and parent:GetAttribute("Floor") ~= nil then
			return node -- (the roof's units, the water tower, the sign...)
		end
		node = parent
	end
	return nil
end

-- show the whole tower for a while (the intro's opening shot, the roof opening, the win)
function Cutaway.suspend(on: boolean)
	suspended = on
end

function Cutaway.init()
	local tower = workspace:FindFirstChild("Tower")
	if tower then
		watch(tower)
	end
	-- a rebuilt tower starts fully shown
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "Tower" then
			watch(c)
		end
	end)

	-- the wall on the camera's side of you (every frame: the camera swings fast)
	RunService.RenderStepped:Connect(function()
		local char = Cutaway.focus or player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if suspended or not root or shown >= Config.FLOORS then
			setCut(nil, nil)
			return
		end
		local cam = workspace.CurrentCamera.CFrame.Position
		local v = Vector3.new(cam.X - root.Position.X, 0, cam.Z - root.Position.Z)
		if v.Magnitude < 0.5 then
			return -- (straight above: keep what's cut)
		end
		v = v.Unit
		local dots = { ["+x"] = v.X, ["-x"] = -v.X, ["+z"] = v.Z, ["-z"] = -v.Z }
		local best, bd = nil, 0.2
		for side, d in dots do
			if d > bd then
				best, bd = side, d
			end
		end
		if cutSide and cutFloor == shown and dots[cutSide] > 0.2 and dots[cutSide] > bd - 0.25 then
			best = cutSide
		end
		setCut(if best then shown else nil, best)
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local char = Cutaway.focus or player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local top = Config.FLOORS
		if suspended then
			top = Config.FLOORS
		elseif root and hum and hum.Health > 0 then
			local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
			top = math.clamp(math.floor(feet / FH + 0.3), 0, Config.FLOORS)
		elseif shown ~= math.huge then
			top = shown -- (knocked out: keep the view until you come to)
		end
		if top ~= shown then
			apply(top)
		end
		hideAbove(if top >= Config.FLOORS then math.huge else (top + 1) * FH - Config.SLAB + 0.5)
	end)
end

return Cutaway
