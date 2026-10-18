--!strict
-- The floors above you are cut away (like the original), so the camera looks down into your floor from
-- above. Only on your screen: each client hides the floors above its own player, and anyone or
-- anything up there.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local FH = Config.FLOOR_HEIGHT

local Cutaway = {}

local shown = math.huge -- the highest floor shown (everything above it is hidden)
local saved: { [BasePart]: number } = {} -- hidden parts' own transparency

local function setFloor(model: Model, hidden: boolean)
	for _, d in model:GetDescendants() do
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
end

local function apply(top: number)
	local tower = workspace:FindFirstChild("Tower")
	if not tower then
		return
	end
	for _, m in tower:GetChildren() do
		local f = m:GetAttribute("Floor")
		if m:IsA("Model") and type(f) == "number" then
			setFloor(m, f > top)
		end
	end
	shown = top
end

-- people, pickups and platforms above the cut aren't drawn either
local function hideAbove(cutY: number)
	local function each(model: Instance)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if d.Position.Y > cutY then 1 else 0
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			each(p.Character)
		end
	end
	for _, name in { "Bots", "Pickups", "Platforms" } do
		local f = workspace:FindFirstChild(name)
		if f then
			each(f)
		end
	end
end

function Cutaway.init()
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
	-- a rebuilt tower (a new server or a fresh race) starts fully shown
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "Tower" then
			table.clear(saved)
			shown = math.huge
		end
	end)
end

return Cutaway
