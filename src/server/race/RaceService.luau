--!strict
-- One race, start to finish, owned by the server:
--   waiting -> ready (everyone frozen on floors 1–5, bots fill to 20) -> climb -> roof (the roof opens
--   at 4:00) -> over (someone got out alone, or 8:00 passed) -> 15 s celebration
-- In the live game each race has its own reserved server: the lobby sends a group here (its size rides
-- in the teleport data), the race waits for them all (not forever), runs once, saves everyone's result
-- (server/common/ProfileStore) and sends them all back to the lobby. Anyone who lands in a public race
-- server is sent to the lobby. In Studio (no teleports) the next race starts here instead.
--
-- Clients follow along through attributes on ReplicatedStorage.RaceState:
--   Phase ("waiting" / "ready" / "climb" / "roof" / "over" / "leaving"), StartAt (server time the climb
--   starts), RoofOpen, Winner (name, "" if nobody), Race (a number, +1 each race), Skydive ("" / "ready" /
--   "flying" / "done": the winner's skydive, shared/Skydive)
-- A player who wins gets the skydive: a pad on the roof flings them out over the valley to glide through
-- rings; the celebration lasts until they land (at most Skydive.MAX_TIME after the launch).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Lobby = require(ReplicatedStorage.Shared.Lobby)
local Skydive = require(ReplicatedStorage.Shared.Skydive)
local Net = require(ReplicatedStorage.Shared.Net)
local Climbers = require(script.Parent.Climbers)
local CollisionGroups = require(script.Parent.Parent.Common.CollisionGroups)
local ProfileStore = require(script.Parent.Parent.Common.ProfileStore)
local LookService = require(script.Parent.Parent.Common.LookService)
local Travel = require(script.Parent.Parent.Common.Travel)
local Tools = require(script.Parent.Tools)
local Pickups = require(script.Parent.Pickups)
local PlatformService = require(script.Parent.PlatformService)
local CombatService = require(script.Parent.CombatService)
local Bots = require(script.Parent.Bots)
local BoostService = require(script.Parent.BoostService)
local Purchases = require(script.Parent.Parent.Common.Purchases)
local Tower = require(script.Parent.Parent.Common.Tower)

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
local skipCelebration = false -- (Studio test hook)
local readyPlayers: { [Player]: boolean } = {} -- clients that are running
local winTime: number? = nil -- race time the winner got out
local recorded: { [Player]: boolean } = {} -- this race's result is saved for them

local STUDIO = RunService:IsStudio()
-- a reserved server the lobby made for one group (the live game); else Studio, or a stray public server
local RESERVED = not STUDIO and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local groupSize = 0 -- how many the lobby sent (from their teleport data)

local Notice = Net.event("Notice")
local Feed = Net.event("Feed")
local SkydiveEvent = Net.event("Skydive")

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
	CollisionGroups.climber(model)
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
	-- their look, once their avatar has loaded
	task.spawn(function()
		local profile = ProfileStore.load(p)
		LookService.applyWhenLoaded(p, char, profile.look)
	end)
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
	winTime = RaceService.time()
end

-- save one player's race (once): their stats, and a line for each look it unlocked
local function record(c: Climber)
	local p = c.player
	if not p or recorded[p] then
		return
	end
	recorded[p] = true
	local won = winner == c
	local result = {
		won = won,
		time = if won then winTime else nil,
		knockouts = c.knockouts,
		highestFloor = c.highest + 1,
	}
	task.spawn(function()
		local unlocked = ProfileStore.recordRound(p, result)
		for _, look in unlocked do
			if p.Parent then
				Notice:FireClient(p, `New look unlocked: {look.name}!`, "win")
				task.wait(3)
			end
		end
	end)
end

local function onThrow(riders: { Climber }, _floor: number)
	Notice:FireAllClients("Only one can escape!", "throw")
	for _, c in riders do
		Feed:FireAllClients(`{c.name} was thrown off the platform`, "throw")
	end
end

-- the winner on the skydive pad: launch them (everyone lays the same rings from the seed)
local skydiveAt = 0
local function onSkydive(player: Player, what: unknown, rings: unknown)
	local c = Climbers.forPlayer(player)
	if not c or c ~= winner or state:GetAttribute("Phase") ~= "over" or not c.model or not c.root then
		return
	end
	local sky = state:GetAttribute("Skydive")
	if what == "launch" and sky == "ready" then
		local p = c.root.Position
		local x, y, z = Skydive.padAt()
		if not Skydive.onPad(p.X, p.Z) or math.abs(p.Y - 3 - y) > 6 then
			return
		end
		skydiveAt = os.clock()
		state:SetAttribute("Skydive", "flying")
		c.model:SetAttribute("Gliding", true)
		SkydiveEvent:FireAllClients(c.model, x, y + 3, z, 0, rng:NextInteger(1, 2 ^ 30))
	elseif what == "done" and sky == "flying" then
		state:SetAttribute("Skydive", "done")
		c.model:SetAttribute("Gliding", false)
		local got = if type(rings) == "number" then math.clamp(math.floor(rings), 0, Skydive.RINGS) else 0
		Feed:FireAllClients(`{c.name} took {got} / {Skydive.RINGS} rings on the skydive`, "win")
	end
end

local function freezeAll(on: boolean)
	for _, c in Climbers.all() do
		c.frozen = on
	end
end

local function playerAdded(p: Player)
	task.spawn(ProfileStore.load, p)
	if not STUDIO and not RESERVED then
		-- a public race server: races start from the lobby
		local lobby = Travel.lobbyPlace()
		if lobby then
			Travel.send({ p }, lobby, false)
			return
		end
	end
	if RESERVED and groupSize == 0 then
		groupSize = Lobby.groupSize(p:GetJoinData().TeleportData)
	end
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
	local phase = state:GetAttribute("Phase")
	if c and (phase == "climb" or phase == "roof" or phase == "over") then
		record(c) -- (left mid-race: it still counts as a race played)
	end
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
	finished, winner, roofOpen, startAt, winTime = false, nil, false, math.huge, nil
	table.clear(recorded)
	state:SetAttribute("Race", raceNo)
	state:SetAttribute("RoofOpen", false)
	state:SetAttribute("Winner", "")
	state:SetAttribute("StartAt", 0)
	state:SetAttribute("RoofSceneAt", nil)
	state:SetAttribute("Skydive", "")
	setPhase("waiting")
	while #Players:GetPlayers() == 0 do
		task.wait(0.5)
	end
	if RESERVED then
		-- the whole group the lobby sent (not forever: stragglers join a race under way)
		local waited = 0
		while not Lobby.groupReady(#Players:GetPlayers(), groupSize, waited) do
			waited += task.wait(0.25)
		end
	else
		-- give Studio's other test clients a moment to arrive
		task.wait(if STUDIO then 2 else 5)
	end

	-- a clean tower
	for _, c in Climbers.all() do
		CombatService.unregister(c)
	end
	Climbers.clear()
	Bots.clear()
	tower.closeHatch()
	BoostService.reset()
	PlatformService.reset()
	Pickups.reset(tower)

	local list: { Climber } = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, Climbers.add(p.DisplayName, "player", p))
	end
	-- Studio only: a Workspace attribute TestBots (a number) sets how many bots join, for small tests
	local bots = Rules.botsFor(#list)
	local testBots = workspace:GetAttribute("TestBots")
	if RunService:IsStudio() and type(testBots) == "number" then
		bots = math.clamp(math.floor(testBots), 0, bots)
	end
	for i = 1, bots do
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

	-- wait for every player's client to have loaded (a slow loader shouldn't miss the intro), at most 45 s
	local waitedReady = 0
	while waitedReady < 45 do
		local all = true
		for _, p in Players:GetPlayers() do
			if not readyPlayers[p] then
				all = false
			end
		end
		if all then
			break
		end
		waitedReady += task.wait(0.2)
	end
	startAt = now() + Config.GET_READY
	state:SetAttribute("StartAt", startAt)
	setPhase("ready")
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
			-- everyone stops for a moment to watch it open (every camera goes to the roof)
			state:SetAttribute("RoofSceneAt", now())
			freezeAll(true)
			local race = raceNo
			task.delay(Config.ROOF_SCENE, function()
				if race == raceNo and not finished then
					freezeAll(false)
				end
			end)
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
	for _, c in Climbers.all() do
		record(c)
	end
	if w and w.player and not skipCelebration then
		-- the winner's skydive: the pad comes out; once they launch, the celebration lasts until they land
		state:SetAttribute("Skydive", "ready")
		Notice:FireClient(w.player, "Skydive! Step on the pad by the sign.", "info")
	end
	if skipCelebration then
		skipCelebration = false
		task.wait(1)
	else
		local t0 = os.clock()
		while true do
			local sky = state:GetAttribute("Skydive")
			if sky == "flying" then
				if os.clock() - skydiveAt > Skydive.MAX_TIME + 3 then
					break
				end
			elseif os.clock() - t0 >= Config.CELEBRATION then
				break
			end
			task.wait(0.2)
		end
		if state:GetAttribute("Skydive") == "done" then
			task.wait(3) -- (a moment to land and look around)
		end
	end
	state:SetAttribute("Skydive", "")
	if RESERVED then
		-- back to the lobby, everyone together; anyone a teleport misses is sent again
		local lobby = Travel.lobbyPlace()
		setPhase("leaving")
		Notice:FireAllClients("Back to the lobby…", "info")
		while lobby do
			Travel.send(Players:GetPlayers(), lobby, false)
			task.wait(15)
			if #Players:GetPlayers() == 0 then
				break
			end
		end
		-- (the server closes once it's empty)
		while true do
			task.wait(60)
		end
	end
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
	BoostService.init({
		tower = tower,
		time = RaceService.time,
		phase = function(): string
			return (state:GetAttribute("Phase") :: string?) or "waiting"
		end,
	})
	Purchases.init(BoostService.onCredit)

	-- Studio only: test hooks (`RooftopDev:Invoke(...)`): "skip" seconds of the race clock, "win" (the first
	-- player gets out), "restart" the race, "give" the first player a weapon
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "RooftopDev"
		dev.OnInvoke = function(cmd: string, arg: any)
			if cmd == "skip" and startAt < math.huge then
				startAt -= arg or 0
				state:SetAttribute("StartAt", startAt)
			elseif cmd == "win" then
				-- the first player gets out (to see the celebration)
				local p = Players:GetPlayers()[1]
				local c = p and Climbers.forPlayer(p)
				if c then
					onEscape(c)
				end
			elseif cmd == "give" and type(arg) == "string" then
				-- the first player gets a weapon (`RooftopDev:Invoke("give", "rifle")`)
				local p = Players:GetPlayers()[1]
				local c = p and Climbers.forPlayer(p)
				local w = Weapons[arg]
				if c and w then
					if w.slot == "gun" then
						Combat.giveGun(c.fighter, arg)
					else
						c.fighter.melee = arg
					end
					Tools.sync(c)
					Tools.publish(c)
				end
			elseif cmd == "restart" then
				-- end this race at once (no winner, no celebration): the next one starts
				skipCelebration = true
				finished = true
			end
			return { phase = state:GetAttribute("Phase"), t = RaceService.time(), winner = winner and winner.name }
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(function(p: Player)
		readyPlayers[p] = nil
		playerRemoving(p)
	end)
	Net.event("Ready").OnServerEvent:Connect(function(p: Player)
		readyPlayers[p] = true
	end)
	SkydiveEvent.OnServerEvent:Connect(onSkydive)

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
