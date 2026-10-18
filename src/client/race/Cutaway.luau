--!strict
-- The floors above you are cut away (like the original), so the camera looks down into your floor from
-- above. Only on your screen: each client hides the floors above its own player, and anyone or
-- anything up there (pickup labels included). Parts that reach the client late are hidden as they
-- arrive, so this holds even with instance streaming on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local FH = Config.FLOOR_HEIGHT

local Cutaway = {}

local shown = math.huge -- the highest floor shown (everything above it is hidden)
local saved: { [BasePart]: number } = {} -- hidden parts' own transparency

local function setPart(d: Instance, hidden: boolean)
	if d:IsA("BasePart") then
		if hidden then
			if saved[d] == nil then
				saved[d] = d.Transparency
			end
			d.Transparency = 1
		elseif saved[d] ~= nil then
			d.Transparency = saved[d]
			saved[d] = nil
		end
	elseif d:IsA("PointLight") then
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

local function apply(top: number)
	shown = top
	local tower = workspace:FindFirstChild("Tower")
	if not tower then
		return
	end
	for _, m in tower:GetChildren() do
		local f = m:GetAttribute("Floor")
		if type(f) == "number" then
			for _, d in m:GetDescendants() do
				setPart(d, f > top)
			end
		end
	end
end

-- people, pickups and platforms above the cut aren't drawn either, nor their labels
local function hideAbove(cutY: number)
	local function each(model: Instance)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if d.Position.Y > cutY then 1 else 0
			elseif d:IsA("BillboardGui") then
				local at = d.Parent
				d.Enabled = not (at and at:IsA("BasePart") and at.Position.Y > cutY)
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			each(p.Character)
		end
	end
	for _, name in { "Bots", "Pickups" } do
		local f = workspace:FindFirstChild(name)
		if f then
			each(f)
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

local function watch(tower: Instance)
	table.clear(saved)
	shown = math.huge
	tower.DescendantAdded:Connect(function(d)
		if shown == math.huge then
			return
		end
		local f = floorOf(d)
		if f and f > shown then
			setPart(d, true)
		end
	end)
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

	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local top = Config.FLOORS
		if root and hum and hum.Health > 0 then
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
