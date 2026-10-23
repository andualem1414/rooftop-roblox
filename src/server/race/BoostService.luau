--!strict
-- The boosters (shared/Booster has the rules): a glowing pad on the walkway beside the shaft on every floor
-- up to 17. Its prompt (F / D-pad up / a tap) opens the boost choices on the client; the client asks for a
-- size and the server checks everything again: on the pad, alive, not frozen, the race climbing, the roof
-- not open, the new floor no higher than 18. Then it spends a boost credit (bought with Robux: a purchase
-- dialog opens if there's none), or in Studio, while the products aren't set up, gives a free test boost.
-- The flight: the climber's own client flies the body up the shaft (smooth, and their client owns it);
-- the server makes them untouchable and unable to attack meanwhile, shows the jets on everyone's screen
-- (the Boosting attribute), says so in the feed, and puts them on the new floor if they aren't there when
-- it's over. Bots never boost.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Booster = require(ReplicatedStorage.Shared.Booster)
local Net = require(ReplicatedStorage.Shared.Net)
local Climbers = require(script.Parent.Climbers)
local Tower = require(script.Parent.Parent.Common.Tower)
local ProfileStore = require(script.Parent.Parent.Common.ProfileStore)
local Purchases = require(script.Parent.Parent.Common.Purchases)

type Climber = Climbers.Climber

export type Context = {
	tower: Tower.Tower,
	time: () -> number, -- race time
	phase: () -> string,
}

local BoostService = {}

local STUDIO = RunService:IsStudio()
local GOLD = Color3.fromRGB(255, 200, 90)
local ASKED_FOR = 120 -- seconds a purchase still counts as the boost asked for (after that: a saved credit)

local ctx: Context
local asked: { [Player]: { size: number, at: number } } = {}
local flying: { [Climber]: boolean } = {}
local BoostEvent = Net.event("Boost")
local Notice = Net.event("Notice")
local Feed = Net.event("Feed")
local Cue = Net.event("Cue")

-- a pad on a floor, part of that floor's model (so it's cut away with the floor)
local function buildPad(floor: number, parent: Instance)
	local x, y, z = Booster.pad(floor)
	local r = Booster.PAD_R
	local model = Instance.new("Model")
	model.Name = "Booster"
	local function disc(name: string, size: Vector3, dy: number, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.CFrame = CFrame.new(x, y + dy, z) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		return p
	end
	local base =
		disc("Base", Vector3.new(0.3, r * 2 + 0.6, r * 2 + 0.6), 0.15, Color3.fromRGB(40, 38, 46), Enum.Material.Metal)
	disc("Ring", Vector3.new(0.34, r * 2, r * 2), 0.17, GOLD, Enum.Material.Neon)
	disc(
		"Core",
		Vector3.new(0.38, r * 2 - 0.9, r * 2 - 0.9),
		0.19,
		Color3.fromRGB(30, 26, 40),
		Enum.Material.SmoothPlastic
	)
	-- a launch pad (two flat bars for an arrow read as a clock's hands from above): a lit inner ring, a
	-- column of light going up, gold sparks rising off it, and its name over it
	disc("InnerRing", Vector3.new(0.4, r * 1.1, r * 1.1), 0.2, GOLD, Enum.Material.Neon)
	disc(
		"InnerCore",
		Vector3.new(0.44, r * 1.1 - 0.5, r * 1.1 - 0.5),
		0.22,
		Color3.fromRGB(30, 26, 40),
		Enum.Material.SmoothPlastic
	)
	local beam = disc("Beam", Vector3.new(7, r * 1.5, r * 1.5), 3.7, GOLD, Enum.Material.Neon)
	beam.Transparency = 0.86
	beam.CastShadow = false
	local emitter = Instance.new("Part")
	emitter.Name = "Sparks"
	emitter.Size = Vector3.new(r * 1.3, 0.1, r * 1.3)
	emitter.CFrame = CFrame.new(x, y + 0.3, z)
	emitter.Transparency = 1
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Parent = model
	local sparks = Instance.new("ParticleEmitter")
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(0.8, 1.3)
	sparks.Speed = NumberRange.new(5, 9)
	sparks.SpreadAngle = Vector2.new(4, 4)
	sparks.Color = ColorSequence.new(GOLD)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparks.Parent = emitter
	local sign = Instance.new("BillboardGui")
	sign.Name = "Label"
	sign.Size = UDim2.fromOffset(150, 34)
	sign.StudsOffset = Vector3.new(0, 7.5, 0)
	sign.MaxDistance = 90
	sign.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = GOLD
	text.TextStrokeTransparency = 0.3
	text.Text = "BOOST UP"
	text.Parent = sign
	sign.Parent = emitter
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = base
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Booster"
	prompt.ActionText = "Boost up"
	prompt.ObjectText = "Booster"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.DPadUp
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Booster.REACH + 2
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- (drawn small by each client: client/race/Prompts)
	prompt:SetAttribute("Floor", floor)
	prompt.Parent = base
	model.Parent = parent
end

-- is this climber standing on the pad of the floor they're on?
local function onPad(c: Climber): boolean
	local root = c.root
	if not root then
		return false
	end
	local x, y, z = Booster.pad(c.floor)
	local d = Vector3.new(root.Position.X - x, 0, root.Position.Z - z).Magnitude
	return d <= Booster.REACH and math.abs(root.Position.Y - 3 - y) < 4
end

-- may this climber boost this many floors right now? (false and a line to show them if not)
local function check(c: Climber, size: number): (boolean, string?)
	if c.kind ~= "player" or c.frozen or c.fighter.dead or flying[c] or not c.model then
		return false, nil
	end
	if not onPad(c) then
		return false, "Stand on the booster pad to boost."
	end
	local ok, why = Booster.canBoost(c.floor, size, ctx.phase(), ctx.time())
	if ok then
		return true, nil
	elseif why == "floor" then
		return false, `Boosts go no higher than floor {Booster.MAX_FLOOR + 1}.`
	elseif why == "roof" then
		return false, "Boosts are closed: the roof is open."
	end
	return false, nil
end

local function fly(c: Climber, size: number)
	local p, model = c.player, c.model
	if not p or not model then
		return
	end
	local from = c.floor
	local to = from + size
	local seconds = Booster.flightTime(size)
	flying[c] = true
	local f = c.fighter
	f.invuln = math.max(f.invuln, seconds + 0.6)
	f.stagger = math.max(f.stagger, seconds)
	f.atk = nil
	f.blocking = false
	model:SetAttribute("Boosting", true)
	BoostEvent:FireClient(p, from, to, seconds)
	Feed:FireAllClients(`{c.name} boosted up {size} floor{if size == 1 then "" else "s"}`, "boost")
	task.delay(seconds + 0.25, function()
		flying[c] = nil
		if model.Parent then
			model:SetAttribute("Boosting", false)
		end
		-- (their client flies them; if they aren't on the new floor now, put them there)
		if c.model == model and not c.fighter.dead then
			Climbers.sync()
			if c.floor ~= to then
				local x, y, z = Booster.pad(to)
				model:PivotTo(CFrame.new(x, y + 3, z))
			end
		end
	end)
end

-- spend a credit on a boost now (if it's still allowed), else keep it
local function spendAndFly(c: Climber, size: number): boolean
	local ok = check(c, size)
	if ok and ProfileStore.spendCredit(c.player :: Player, size) then
		fly(c, size)
		return true
	end
	return false
end

local function onAsk(player: Player, size: unknown)
	local c = Climbers.forPlayer(player)
	if not c or not Booster.isSize(size) then
		return
	end
	local n = size :: number
	local ok, why = check(c, n)
	if not ok then
		if why then
			Notice:FireClient(player, why, "bad")
		end
		return
	end
	if ProfileStore.credits(player, n) > 0 then
		spendAndFly(c, n)
	elseif Purchases.promptBoost(player, n) then
		asked[player] = { size = n, at = os.clock() }
	elseif STUDIO then
		-- (Studio, products not set up: a free test boost, to try the feel)
		fly(c, n)
	else
		Notice:FireClient(player, "Boosts aren't on sale yet.", "bad")
	end
end

-- a boost was bought: fly now if it's the one they asked for and they still may, else it waits as a credit
function BoostService.onCredit(player: Player, size: number)
	local a = asked[player]
	asked[player] = nil
	local c = Climbers.forPlayer(player)
	if a and a.size == size and os.clock() - a.at < ASKED_FOR and c and spendAndFly(c, size) then
		return
	end
	Cue:FireClient(player, "pickup")
	Notice:FireClient(player, `Boost +{size} saved: use it on any booster pad.`, "info")
end

function BoostService.init(context: Context)
	ctx = context
	for floor = 0, Booster.MAX_FLOOR - 1 do
		local model = ctx.tower.floors[floor]
		if model then
			buildPad(floor, model)
		end
	end
	BoostEvent.OnServerEvent:Connect(onAsk)
	Players.PlayerRemoving:Connect(function(p: Player)
		asked[p] = nil
	end)
end

-- a new race: nobody is mid-flight
function BoostService.reset()
	table.clear(flying)
	table.clear(asked)
end

return BoostService
