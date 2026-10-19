--!strict
-- Things to pick up: weapons and ammo boxes, on platforms and lying on floors. A ProximityPrompt on
-- each one handles E / tap / the controller button; bots take them through Pickups.take.
--   a weapon: swaps with the one you carry in that slot (yours is left in its place); the same weapon
--             again just refills it
--   ammo:     two magazines for the gun you carry
-- Floors get 1–2 ammo boxes each (back 60 s after being taken), and about half the floors have a
-- weapon lying around at the start. Knocked-out climbers drop anything better than the bat / pistol.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Net = require(ReplicatedStorage.Shared.Net)
local Climbers = require(script.Parent.Climbers)
local Tools = require(script.Parent.Tools)
local Tower = require(script.Parent.Parent.Common.Tower)

type Climber = Climbers.Climber

export type Pickup = {
	kind: string, -- a weapon name or "ammo"
	part: BasePart,
	prompt: ProximityPrompt,
	floor: number?, -- lying on this floor (nil: on a platform)
	gone: boolean,
	onTaken: (() -> ())?,
}

local Pickups = {}

local rng = Random.new()
local Cue = Net.event("Cue")
local all: { Pickup } = {}
local folder: Folder
local tower: Tower.Tower

-- the invisible part a pickup hangs on; the weapon itself (the same model as the tool) or an ammo crate
-- lies on it
local HOLDER = Vector3.new(1.2, 0.6, 1.2)

local function labelOf(kind: string): string
	local w = Weapons[kind]
	return if w then w.label else "Ammo"
end

local function roll(): number
	return rng:NextNumber()
end

-- weld every part of a model to the holder, so it moves with it (a platform) or stays put
local function weldAll(holder: BasePart, model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = holder
			w.Part1 = d
			w.Parent = d
		end
	end
end

local function ammoCrate(): Model
	local m = Instance.new("Model")
	local box = Instance.new("Part")
	box.Name = "Crate"
	box.Size = Vector3.new(1.6, 1.0, 1.1)
	box.Color = Color3.fromRGB(72, 96, 58)
	box.Material = Enum.Material.SmoothPlastic
	box.Parent = m
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = Vector3.new(1.64, 0.22, 1.14)
	band.Color = Color3.fromRGB(255, 200, 70)
	band.Material = Enum.Material.Neon
	band.CFrame = CFrame.new(0, 0.18, 0)
	band.Parent = m
	m.PrimaryPart = box
	return m
end

-- what lies on the holder: the weapon's own model, on its side, or an ammo crate
local function visual(kind: string): Model
	if not Weapons[kind] then
		return ammoCrate()
	end
	local tool = Tools.make(kind)
	local m = Instance.new("Model")
	for _, d in tool:GetChildren() do
		d.Parent = m
	end
	tool:Destroy()
	m.PrimaryPart = m:FindFirstChild("Handle") :: BasePart?
	return m
end

local function dress(pk: Pickup)
	local p = pk.part
	p.Name = "Pickup_" .. pk.kind
	local old = p:FindFirstChild("Visual")
	if old then
		old:Destroy()
	end
	local m = visual(pk.kind)
	m.Name = "Visual"
	-- a weapon lies flat (its barrel or blade along the holder), a crate sits on it
	local lie = if Weapons[pk.kind]
		then p.CFrame * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
		else p.CFrame * CFrame.new(0, 0.2, 0)
	m:PivotTo(lie)
	weldAll(p, m)
	m.Parent = p
	local tag = p:FindFirstChild("Tag") :: BillboardGui?
	if tag then
		(tag:FindFirstChild("Text") :: TextLabel).Text = string.upper(labelOf(pk.kind))
	end
	pk.prompt.ObjectText = labelOf(pk.kind)
	pk.prompt.ActionText = if pk.kind == "ammo" then "Take" else "Pick up"
end

-- a new pickup at `cf`; welded to `carrier` (a platform deck) if given, else lying still
function Pickups.spawn(kind: string, cf: CFrame, carrier: BasePart?, floor: number?): Pickup
	local p = Instance.new("Part")
	p.CFrame = cf
	p.Size = HOLDER
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	if carrier then
		p.Anchored = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = carrier
		w.Part1 = p
		w.Parent = p
	else
		p.Anchored = true
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(80, 20)
	tag.StudsOffset = Vector3.new(0, 1.6, 0)
	tag.MaxDistance = 28
	tag.AlwaysOnTop = false
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(235, 230, 215)
	text.TextStrokeTransparency = 0.4
	text.Parent = tag
	tag.Parent = p
	local prompt = Instance.new("ProximityPrompt")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonB -- (X reloads)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	local pk: Pickup = { kind = kind, part = p, prompt = prompt, floor = floor, gone = false, onTaken = nil }
	dress(pk)
	p.Parent = folder
	prompt.Triggered:Connect(function(player: Player)
		local c = Climbers.forPlayer(player)
		if c then
			Pickups.take(c, pk)
		end
	end)
	table.insert(all, pk)
	return pk
end

function Pickups.remove(pk: Pickup)
	if pk.gone then
		return
	end
	pk.gone = true
	pk.part:Destroy()
	local i = table.find(all, pk)
	if i then
		table.remove(all, i)
	end
end

-- a climber takes (or swaps with) a pickup. Returns true if something changed hands.
function Pickups.take(c: Climber, pk: Pickup): boolean
	local f = c.fighter
	if pk.gone or f.dead or c.frozen or not c.root then
		return false
	end
	if (c.root.Position - pk.part.Position).Magnitude > 14 then
		return false -- (the prompt's own range is 9; a little slack for lag)
	end
	if pk.kind == "ammo" then
		if not Combat.addAmmo(f) then
			return false
		end
		Pickups.remove(pk)
		if pk.onTaken then
			pk.onTaken()
		end
		Tools.publish(c)
		if c.player then
			Cue:FireClient(c.player, "pickup")
		end
		return true
	end
	local w = Weapons[pk.kind]
	if not w then
		return false
	end
	local old: string?
	if w.slot == "gun" then
		old = f.gun
		Combat.giveGun(f, pk.kind)
	else
		old = f.melee
		f.melee = pk.kind
	end
	if old and old ~= pk.kind then
		pk.kind = old -- what you carried is left in its place
		dress(pk)
	else
		Pickups.remove(pk)
		if pk.onTaken then
			pk.onTaken()
		end
	end
	Tools.sync(c)
	Tools.publish(c)
	if c.player then
		Cue:FireClient(c.player, "pickup")
	end
	return true
end

-- the nearest pickup a climber could walk to on their floor that `keep` likes (bots)
function Pickups.nearestWhere(c: Climber, maxDist: number, keep: (kind: string) -> boolean): Pickup?
	local root = c.root
	if not root then
		return nil
	end
	local best, bd = nil, maxDist
	for _, pk in all do
		if pk.gone or pk.floor ~= c.floor or not keep(pk.kind) then
			continue
		end
		local d = (pk.part.Position - root.Position).Magnitude
		if d < bd then
			best, bd = pk, d
		end
	end
	return best
end

-- the nearest pickup of a kind (or any) a climber could walk to on their floor (bots)
function Pickups.nearest(c: Climber, maxDist: number, kind: string?): Pickup?
	return Pickups.nearestWhere(c, maxDist, function(k: string): boolean
		return kind == nil or k == kind
	end)
end

-- what a platform carries: a gun, a sword or an ammo box
function Pickups.forPlatform(deck: BasePart, loot: string): Pickup
	local kind = if loot == "gun" then Rules.foundGun(roll) else loot
	local top = deck.CFrame * CFrame.new(0, deck.Size.Y / 2 + 0.35, 0)
	return Pickups.spawn(kind, top * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), deck, nil)
end

-- something left on the floor where a climber went down
function Pickups.drop(kind: string, position: Vector3, floor: number)
	local y = floor * Config.FLOOR_HEIGHT + 0.35
	local pk = Pickups.spawn(
		kind,
		CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0),
		nil,
		floor
	)
	task.delay(Config.DROP_LIFE, function()
		Pickups.remove(pk)
	end)
end

local function floorAmmo(floor: number)
	local spot = tower.randomSpot(floor)
	local pk = Pickups.spawn("ammo", CFrame.new(spot.X, floor * Config.FLOOR_HEIGHT + 0.35, spot.Z), nil, floor)
	pk.onTaken = function()
		task.delay(Config.AMMO_RESPAWN, function()
			if folder.Parent then
				floorAmmo(floor)
			end
		end)
	end
end

-- a fresh race: clear everything, then ammo on every floor and weapons on about half
function Pickups.reset(t: Tower.Tower)
	tower = t
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = workspace
	table.clear(all)
	for floor = 0, Config.FLOORS - 1 do
		for _ = 1, rng:NextInteger(Config.FLOOR_AMMO[1], Config.FLOOR_AMMO[2]) do
			floorAmmo(floor)
		end
		if rng:NextNumber() < Config.FLOOR_WEAPON_CHANCE then
			local kind = Rules.floorWeapon(roll)
			local spot = tower.randomSpot(floor)
			local turn = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
			Pickups.spawn(kind, CFrame.new(spot.X, floor * Config.FLOOR_HEIGHT + 0.35, spot.Z) * turn, nil, floor)
		end
	end
end

-- what a knocked-out climber leaves behind: anything better than the starting bat and pistol
function Pickups.dropFrom(c: Climber)
	local f, root = c.fighter, c.root
	if not root then
		return
	end
	if f.melee ~= "bat" then
		Pickups.drop(f.melee, root.Position + Vector3.new(1, 0, 0), c.floor)
	end
	if f.gun and f.gun ~= "pistol" then
		Pickups.drop(f.gun, root.Position + Vector3.new(-1, 0, 0), c.floor)
	end
end

return Pickups
