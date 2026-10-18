--!strict
-- One race, start to finish, owned by the server:
--   waiting -> ready (everyone frozen on floors 1–5, bots fill to 20) -> climb -> roof (the roof opens
--   at 4:00) -> over (someone got out alone, or 8:00 passed) -> 15 s celebration
-- After that the players go back to the lobby (phase 3); until the lobby exists, and always in Studio,
-- the next race starts here.
--
-- Clients follow along through attributes on ReplicatedStorage.RaceState:
--   Phase ("waiting" / "ready" / "climb" / "roof" / "over"), StartAt (server time the climb starts),
--   RoofOpen, Winner (name, "" if nobody), Race (a number, +1 each race)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Net = require(ReplicatedStorage.Shared.Net)
local Climbers = require(script.Parent.Climbers)
local Tools = require(script.Parent.Tools)
local Pickups = require(script.Parent.Pickups)
local PlatformService = require(script.Parent.PlatformService)
local CombatService = require(script.Parent.CombatService)
local Bots = require(script.Parent.Bots)
local Tower = require(script.Parent.Tower)

type Climber = Climbers.Climber

local RaceService = {}

local tower: Tower.Tower
local state: Folder
local rng = Random.new()
local raceNo = 0
local startAt = math.huge
local roofOpen = false
local finished = false
local winner: Climber? = nil

local Notice = Net.event("Notice")
local Feed = Net.event("Feed")

local function now(): number
	return workspace:GetServerTimeNow()
end

function RaceService.time(): number
	return now() - startAt
end

local function setPhase(phase: string)
	state:SetAttribute("Phase", phase)
end

-- everything a fresh body needs, for players and bots alike
local function setup(c: Climber, model: Model)
	Climbers.setModel(c, model)
	CombatService.register(c)
	local hum = c.humanoid
	if not hum then
		return
	end
	hum.BreakJointsOnDeath = false
	-- climbers don't trip over or climb walls (a player's own client sets this for its body too)
	for _, s in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing } do
		hum:SetStateEnabled(s, false)
	end
	hum.MaxHealth = Config.MAX_HP
	hum.Health = Config.MAX_HP
	hum.UseJumpPower = false
	hum.JumpHeight = Config.JUMP_HEIGHT
	hum.WalkSpeed = Config.WALK_SPEED
	Combat.revive(c.fighter)
	c.fighter.equipped = "none"
	c.knockedAt = nil
	Tools.sync(c)
	Tools.publish(c)
	hum.Died:Connect(function()
		-- (the fighter state decides knock-outs; this catches anything else, like falling apart)
		if c.model == model and not c.fighter.dead then
			CombatService.knockOut(c, nil, "humanoid died")
		end
	end)
end

local function spawnPlayer(c: Climber, floor: number)
	local p = c.player
	if not p or not p.Parent then
		return
	end
	local ok, err = pcall(function()
		p:LoadCharacterAsync()
	end)
	local char = p.Character
	if not ok or not char then
		warn("[Rooftop] couldn't spawn", p.Name, err)
		return
	end
	setup(c, char)
	local spot = tower.randomSpot(floor)
	char:PivotTo(CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
end

local function spawn(c: Climber, floor: number)
	if c.kind == "player" then
		spawnPlayer(c, floor)
	else
		Bots.spawn(c, floor)
	end
end

local function onKnockedOut(c: Climber, _by: Climber?)
	Pickups.dropFrom(c)
	local race = raceNo
	local floor = c.floor
	task.delay(Config.KNOCKED_OUT_FOR, function()
		if race ~= raceNo or finished or not table.find(Climbers.all(), c) then
			return
		end
		local to = Rules.comeToFloor(floor, function(a, b)
			return rng:NextInteger(a, b)
		end)
		spawn(c, to)
		if c.player then
			Notice:FireClient(c.player, `You came to on floor {to + 1}`, "bad")
		end
	end)
end

local function onEscape(c: Climber)
	if finished then
		return
	end
	finished = true
	winner = c
end

local function onThrow(riders: { Climber }, _floor: number)
	Notice:FireAllClients("Only one can escape!", "throw")
	for _, c in riders do
		Feed:FireAllClients(`{c.name} was thrown off the platform`, "throw")
	end
end

local function freezeAll(on: boolean)
	for _, c in Climbers.all() do
		c.frozen = on
	end
end

local function playerAdded(p: Player)
	local phase = state:GetAttribute("Phase")
	if phase == "ready" or phase == "climb" or phase == "roof" then
		-- (in Studio, or a straggler: in the live game the lobby sends everyone at once)
		local c = Climbers.add(p.DisplayName, "player", p)
		c.frozen = phase == "ready"
		spawnPlayer(c, Rules.startFloor(rng:NextInteger(1, 5)))
	end
end

local function playerRemoving(p: Player)
	local c = Climbers.forPlayer(p)
	if c then
		CombatService.unregister(c)
		Climbers.remove(c) -- gone: one climber fewer (no bot takes their place)
	end
end

local function shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function runRace()
	raceNo += 1
	finished, winner, roofOpen, startAt = false, nil, false, math.huge
	state:SetAttribute("Race", raceNo)
	state:SetAttribute("RoofOpen", false)
	state:SetAttribute("Winner", "")
	state:SetAttribute("StartAt", 0)
	setPhase("waiting")
	while #Players:GetPlayers() == 0 do
		task.wait(0.5)
	end
	-- give Studio's other test clients a moment to arrive (phase 3: wait for the lobby's whole group)
	task.wait(if RunService:IsStudio() then 2 else 5)

	-- a clean tower
	for _, c in Climbers.all() do
		CombatService.unregister(c)
	end
	Climbers.clear()
	Bots.clear()
	tower.closeHatch()
	PlatformService.reset()
	Pickups.reset(tower)

	local list: { Climber } = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, Climbers.add(p.DisplayName, "player", p))
	end
	for i = 1, Rules.botsFor(#list) do
		table.insert(list, Bots.create(i))
	end
	shuffle(list)
	local pending = #list
	for i, c in list do
		c.frozen = true
		task.spawn(function()
			spawn(c, Rules.startFloor(i))
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 10 do
		waited += task.wait(0.1)
	end

	startAt = now() + Config.GET_READY
	state:SetAttribute("StartAt", startAt)
	setPhase("ready")
	Notice:FireAllClients("Get ready", "info")
	while now() < startAt do
		PlatformService.step(0, false)
		RunService.Heartbeat:Wait()
	end

	freezeAll(false)
	setPhase("climb")
	Notice:FireAllClients("Climb! The first one alone on a platform through the roof wins.", "info")
	while true do
		local t = RaceService.time()
		if not roofOpen and t >= Config.ROOF_OPENS_AFTER then
			roofOpen = true
			state:SetAttribute("RoofOpen", true)
			setPhase("roof")
			tower.openHatch()
			Notice:FireAllClients("The roof is open!", "roof")
		end
		PlatformService.step(t, roofOpen)
		if finished or t >= Config.RACE_LIMIT then
			break
		end
		RunService.Heartbeat:Wait()
	end

	-- over: everything stops, only the winner moves
	PlatformService.freeze()
	freezeAll(true)
	local w = winner
	if w then
		w.frozen = false
		state:SetAttribute("Winner", w.name)
		Notice:FireAllClients(`{w.name} got out first!`, "win")
		Feed:FireAllClients(`{w.name} got out first ({Rules.clock(RaceService.time())})`, "win")
	else
		Notice:FireAllClients("Nobody got out.", "over")
	end
	setPhase("over")
	task.wait(Config.CELEBRATION)
end

function RaceService.start(t: Tower.Tower)
	tower = t
	state = Instance.new("Folder")
	state.Name = "RaceState"
	state.Parent = ReplicatedStorage
	setPhase("waiting")

	PlatformService.init(tower, { onEscape = onEscape, onThrow = onThrow })
	CombatService.init({ onKnockedOut = onKnockedOut })
	Bots.init({
		tower = tower,
		time = RaceService.time,
		roofOpen = function()
			return roofOpen
		end,
		setup = setup,
	})
	Bots.prepare()

	-- Studio only: a test hook to skip the race clock ahead (`RooftopDev:Invoke("skip", seconds)`)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "RooftopDev"
		dev.OnInvoke = function(cmd: string, arg: number?)
			if cmd == "skip" and startAt < math.huge then
				startAt -= arg or 0
				state:SetAttribute("StartAt", startAt)
			end
			return { phase = state:GetAttribute("Phase"), t = RaceService.time(), winner = winner and winner.name }
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)

	task.spawn(function()
		while true do
			local ok, err = pcall(runRace)
			if not ok then
				warn("[Rooftop] race failed:", err)
				task.wait(3)
			end
		end
	end)
end

return RaceService
