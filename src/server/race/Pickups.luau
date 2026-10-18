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
local Climbers = require(script.Parent.Climbers)
local Tools = require(script.Parent.Tools)
local Tower = require(script.Parent.Tower)

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

local GUNS = { "pistol" } -- every gun that can turn up (more in phase 3)
local rng = Random.new()
local all: { Pickup } = {}
local folder: Folder
local tower: Tower.Tower

local LOOKS = {
	ammo = { size = Vector3.new(1.6, 1.1, 1.1), color = Color3.fromRGB(72, 96, 58), text = "AMMO" },
	sword = { size = Vector3.new(0.4, 0.2, 4.4), color = Color3.fromRGB(196, 200, 206), text = "SWORD" },
	bat = { size = Vector3.new(0.55, 0.55, 3.8), color = Color3.fromRGB(150, 110, 70), text = "BAT" },
	pistol = { size = Vector3.new(0.35, 0.8, 1.4), color = Color3.fromRGB(45, 45, 50), text = "PISTOL" },
}

local function labelOf(kind: string): string
	local w = Weapons[kind]
	return if w then w.label else "Ammo"
end

local function dress(pk: Pickup)
	local look = LOOKS[pk.kind] or LOOKS.ammo
	local p = pk.part
	p.Size = look.size
	p.Color = look.color
	p.Name = "Pickup_" .. pk.kind
	local tag = p:FindFirstChild("Tag") :: BillboardGui?
	if tag then
		(tag:FindFirstChild("Text") :: TextLabel).Text = look.text
	end
	pk.prompt.ObjectText = labelOf(pk.kind)
	pk.prompt.ActionText = if pk.kind == "ammo" then "Take" else "Pick up"
end

-- a new pickup at `cf`; welded to `carrier` (a platform deck) if given, else lying still
function Pickups.spawn(kind: string, cf: CFrame, carrier: BasePart?, floor: number?): Pickup
	local p = Instance.new("Part")
	p.CFrame = cf
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
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
	tag.MaxDistance = 40
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
	return true
end

-- the nearest pickup a climber could walk to on their floor (bots)
function Pickups.nearest(c: Climber, maxDist: number, kind: string?): Pickup?
	local root = c.root
	if not root then
		return nil
	end
	local best, bd = nil, maxDist
	for _, pk in all do
		if pk.gone or pk.floor ~= c.floor or (kind and pk.kind ~= kind) then
			continue
		end
		local d = (pk.part.Position - root.Position).Magnitude
		if d < bd then
			best, bd = pk, d
		end
	end
	return best
end

-- what a platform carries: a gun, a sword or an ammo box
function Pickups.forPlatform(deck: BasePart, loot: string): Pickup
	local kind = if loot == "gun" then GUNS[rng:NextInteger(1, #GUNS)] else loot
	local top = deck.CFrame * CFrame.new(0, deck.Size.Y / 2 + 0.7, 0)
	return Pickups.spawn(kind, top * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0), deck, nil)
end

-- something left on the floor where a climber went down
function Pickups.drop(kind: string, position: Vector3, floor: number)
	local y = floor * Config.FLOOR_HEIGHT + 0.6
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
	local pk = Pickups.spawn("ammo", CFrame.new(spot.X, floor * Config.FLOOR_HEIGHT + 0.6, spot.Z), nil, floor)
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
			local kind = if rng:NextNumber() < 0.5 then "sword" else GUNS[rng:NextInteger(1, #GUNS)]
			local spot = tower.randomSpot(floor)
			Pickups.spawn(kind, CFrame.new(spot.X, floor * Config.FLOOR_HEIGHT + 0.6, spot.Z), nil, floor)
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
