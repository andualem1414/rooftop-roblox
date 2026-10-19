--!strict
-- Moves the platforms up the shaft on the shared timetable (shared/Platforms), opens and shuts each
-- floor's shaft gate, hands out the loot each platform carries, and applies the roof rule: a platform
-- only takes one climber up through the roof. More than one on it as it leaves the top floor and it
-- throws them all off ("Only one can escape").
--
-- The decks are physical parts pulled along by an AlignPosition, so climbers standing on them ride
-- along smoothly; the server owns them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Platforms = require(ReplicatedStorage.Shared.Platforms)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Climbers = require(script.Parent.Climbers)
local Pickups = require(script.Parent.Pickups)
local Tower = require(script.Parent.Parent.Common.Tower)

type Climber = Climbers.Climber

local FLOORS = Config.FLOORS
local FH = Config.FLOOR_HEIGHT
local PH = Config.PLATFORM_HALF
local T = Config.PLATFORM_THICK
local POOL = 8
local PARK = CFrame.new(0, -3 * FH - 20, 0)

export type Slot = {
	deck: Part,
	align: AlignPosition,
	k: number?, -- the launch it's running (nil: parked)
	level: number,
	stop: number?,
	leaving: number,
	prevStop: number?,
	lastStop: number,
	loot: Pickups.Pickup?,
}

export type Hooks = {
	onEscape: (c: Climber) -> (),
	onThrow: (riders: { Climber }, floor: number) -> (),
}

local PlatformService = {}

local slots: { Slot } = {}
local tower: Tower.Tower
local hooks: Hooks
local rng = Random.new()
local folder: Folder

local function makeDeck(i: number): Slot
	local deck = Instance.new("Part")
	deck.Name = "Platform" .. i
	deck.Size = Vector3.new(PH * 2, T, PH * 2)
	deck.Color = Color3.fromRGB(138, 106, 69)
	deck.Material = Enum.Material.DiamondPlate
	deck.CollisionGroup = "Platform"
	deck.CustomPhysicalProperties = PhysicalProperties.new(20, 1, 0, 1, 1)
	deck.TopSurface = Enum.SurfaceType.Smooth
	deck.Anchored = true
	deck.CFrame = PARK
	local att = Instance.new("Attachment")
	att.Parent = deck
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.ApplyAtCenterOfMass = true
	align.RigidityEnabled = false
	align.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	align.MaxForce = 1e9
	align.MaxVelocity = 80
	align.Responsiveness = 200
	align.Parent = deck
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = att
	orient.RigidityEnabled = true
	orient.CFrame = CFrame.new()
	orient.Parent = deck
	deck.Parent = folder
	return {
		deck = deck,
		align = align,
		k = nil,
		level = -1,
		stop = nil,
		leaving = 0,
		prevStop = nil,
		lastStop = 0,
		loot = nil,
	}
end

function PlatformService.init(t: Tower.Tower, h: Hooks)
	tower = t
	hooks = h
	folder = Instance.new("Folder")
	folder.Name = "Platforms"
	folder.Parent = workspace
	for i = 1, POOL do
		slots[i] = makeDeck(i)
	end
end

local function deckTopY(level: number): number
	return level * FH
end

-- who is standing on this platform
function PlatformService.riders(s: Slot): { Climber }
	local out = {}
	if not s.k then
		return out
	end
	local pos = s.deck.Position
	local top = pos.Y + T / 2
	for _, c in Climbers.all() do
		local root = c.root
		if not root or c.fighter.dead then
			continue
		end
		local feet = Climbers.feetY(c)
		local rel = root.Position - pos
		if
			feet
			and math.abs(rel.X) < PH + 0.6
			and math.abs(rel.Z) < PH + 0.6
			and feet > top - 1.5
			and feet < top + 4
		then
			table.insert(out, c)
		end
	end
	return out
end

-- the platform a climber is riding, if any
function PlatformService.slotOf(c: Climber): Slot?
	for _, s in slots do
		if s.k and table.find(PlatformService.riders(s), c) then
			return s
		end
	end
	return nil
end

-- the platform stopped at a floor right now, if any
function PlatformService.stoppedAt(floor: number): Slot?
	for _, s in slots do
		if s.k and s.stop == floor then
			return s
		end
	end
	return nil
end

local function park(s: Slot)
	s.k = nil
	s.stop = nil
	s.prevStop = nil
	s.deck.Anchored = true
	s.deck.CFrame = PARK
	if s.loot then
		Pickups.remove(s.loot)
		s.loot = nil
	end
end

local function launch(s: Slot, k: number, level: number)
	park(s)
	s.k = k
	s.lastStop = 0
	s.deck.CFrame = CFrame.new(0, deckTopY(level) - T / 2, 0)
	s.deck.Anchored = false
	s.deck:SetNetworkOwner(nil)
	s.loot = Pickups.forPlatform(
		s.deck,
		Rules.platformLoot(function()
			return rng:NextNumber()
		end)
	)
end

-- put climbers off the platform onto a floor, just off the shaft's edge, pushed outward
local function throwOff(riders: { Climber }, floor: number)
	for _, c in riders do
		local model, root = c.model, c.root
		if model and root then
			local spot = tower.ringSpot(floor)
			model:PivotTo(CFrame.lookAt(spot, Vector3.new(0, spot.Y, 0)) * CFrame.Angles(0, math.pi, 0))
			c.fighter.stagger = math.max(c.fighter.stagger, 0.6)
		end
	end
	hooks.onThrow(riders, floor)
end

local function retire(s: Slot)
	-- anyone still on a platform that folds away is left on the floor where it last stopped
	local riders = PlatformService.riders(s)
	if #riders > 0 and s.lastStop < FLOORS then
		for _, c in riders do
			local spot = tower.ringSpot(s.lastStop)
			if c.model then
				c.model:PivotTo(CFrame.new(spot))
			end
		end
	end
	park(s)
end

-- move everything to race time t
function PlatformService.step(t: number, roofOpen: boolean)
	local used: { [Slot]: boolean } = {}
	local open: { [number]: boolean } = {}
	local first, last = Platforms.launchRange(t)
	for k = first, last do
		local st = Platforms.state(Platforms.age(k, t), roofOpen)
		if not st.active then
			continue
		end
		local s = slots[(k % POOL) + 1]
		used[s] = true
		if s.k ~= k then
			launch(s, k, st.level)
		end
		s.prevStop = s.stop
		s.level, s.stop, s.leaving = st.level, st.stop, st.leaving
		if st.stop then
			s.lastStop = st.stop
		end
		s.align.Position = Vector3.new(0, deckTopY(st.level) - T / 2, 0)
		for floor = math.ceil(st.level - 1 + 1e-6), math.floor(st.level + 1 - 1e-6) do
			open[floor] = true
		end
		-- the roof rule, as it leaves the top floor...
		if roofOpen and s.prevStop == FLOORS - 1 and st.stop == nil then
			local riders = PlatformService.riders(s)
			if Rules.escape(#riders) == "throw" then
				throwOff(riders, FLOORS - 1)
			end
		end
		-- ...and as it arrives at the roof (in case someone jumped on on the way)
		if st.stop == FLOORS and s.prevStop ~= FLOORS then
			local riders = PlatformService.riders(s)
			local verdict = Rules.escape(#riders)
			if verdict == "escape" then
				hooks.onEscape(riders[1])
			elseif verdict == "throw" then
				throwOff(riders, FLOORS - 1)
			end
		end
	end
	for _, s in slots do
		if s.k and not used[s] then
			retire(s)
		end
	end
	for floor, gate in tower.gates do
		gate.CanCollide = not open[floor]
	end
end

-- the race is over: everything stops where it is
function PlatformService.freeze()
	for _, s in slots do
		if s.k then
			s.deck.Anchored = true
		end
	end
end

function PlatformService.reset()
	for _, s in slots do
		park(s)
	end
	for _, gate in tower.gates do
		gate.CanCollide = true
	end
end

return PlatformService
