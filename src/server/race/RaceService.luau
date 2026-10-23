--!strict
-- One race, start to finish, owned by the server:
--   waiting -> ready (bots fill to 20, five teams of four, each team frozen on its own floor of 1–5) ->
--   climb -> roof (the roof opens at 4:00) -> over (a team got out, or 8:00 passed) -> 15 s celebration
-- Teams (shared/Teams): friends together, everyone else spread out, bots fill the gaps; players are on
-- Roblox's teams too (the player list, team chat). Teammates can't hurt each other. A platform takes its
-- riders up through the roof only if they're all on one team, and then that whole team wins, the ones
-- still inside included.
-- In the live game each race has its own reserved server: the lobby sends a group here (its size rides
-- in the teleport data), the race waits for them all (not forever), runs once, saves everyone's result
-- (server/common/ProfileStore) and sends them all back to the lobby. Anyone who lands in a public race
-- server is sent to the lobby. In Studio (no teleports) the next race starts here instead.
--
-- Clients follow along through attributes on ReplicatedStorage.RaceState:
--   Phase ("waiting" / "ready" / "climb" / "roof" / "over" / "leaving"), StartAt (server time the climb
--   starts), RoofOpen, Winner (the winning team's label, "Red team"; "" if nobody), WinnerTeam (its number,
--   0 if nobody), Race (a number, +1 each race), Skydive ("" / "ready": the pad is out on the roof for the
--   ones who got out, shared/Skydive). Everyone's team, floor and state are in RaceState.Roster
--   (Climbers.publish). Players carry Team; those who got out carry Escaped = true (their body too) and
--   their own Skydive ("flying" / "done").
-- Once the roof is open a knock-out is final: the climber is out of the race (a bot is gone; a player
-- watches the others, client/race/Spectate, and may leave), their player carrying Out = true. With
-- nobody left in, the race ends with no winner.
-- A player who got out gets the skydive: a pad on the roof flings them out over the valley to glide through
-- rings. Nothing restarts by itself: once the race is over the winners explore the roof, take the skydive
-- or ends the game, and everyone else sees the result and goes back to the main screen (the lobby place)
-- when they press, or after a while. In Studio (no lobby) the next race starts when someone presses Play
-- again; in Studio, T (and RooftopDev "win") puts you on the roof as the winner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeamsService = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Teams = require(ReplicatedStorage.Shared.Teams)
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
local winners: { Climber } = {} -- the ones who rode up through the roof (one team)
local winTeam = 0 -- their team: everyone on it wins
local robloxTeams: { Team } = {}
local skipCelebration = false -- (Studio test hook)
local readyPlayers: { [Player]: boolean } = {} -- clients that are running
local gathered = false -- this race's climbers are picked: anyone arriving now joins it as a latecomer
local leaving: { [Player]: boolean } = {} -- pressed to go back to the main screen
local againAsked = false -- (Studio) someone pressed Play again
local LOSER_LINGER = 90 -- seconds after the end before someone who didn't press is sent back anyway
local WINNER_LINGER = 600 -- the ones who got out may explore the roof for this long
local winTime: number? = nil -- race time the winners got out
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
	model:SetAttribute("SpawnedAt", now()) -- (every screen plays them coming to: client/race/Poser)
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

-- out of the race (knocked out after the roof opened): the body goes once it has faded; a bot goes with
-- it, a player stays on the list (their race still counts) and watches the others
local function eliminate(c: Climber)
	c.out = true
	Feed:FireAllClients(`{c.name} is out of the race`, "ko")
	local p = c.player
	if p then
		p:SetAttribute("Out", true)
		Notice:FireClient(p, "You're out: the roof is open, so there's no coming to.", "bad")
	end
	local race = raceNo
	task.delay(Config.KNOCKED_OUT_FOR, function()
		if race ~= raceNo then
			return
		end
		local model = c.model
		Climbers.dropModel(c)
		if p and p.Character == model then
			p.Character = nil
		end
		if model then
			model:Destroy()
		end
		if c.kind == "bot" then
			CombatService.unregister(c)
			Climbers.remove(c)
		end
	end)
end

local function onKnockedOut(c: Climber, _by: Climber?)
	Pickups.dropFrom(c)
	if roofOpen then
		eliminate(c)
		return
	end
	local race = raceNo
	local floor = c.floor
	task.delay(Config.KNOCKED_OUT_FOR, function()
		if race ~= raceNo or finished or c.out or not table.find(Climbers.all(), c) then
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

local function onEscape(riders: { Climber })
	if finished or #riders == 0 then
		return
	end
	finished = true
	winners = riders
	winTeam = riders[1].team
	winTime = RaceService.time()
	for _, c in riders do
		c.escaped = true
	end
end

-- put a climber on a team (a player joins Roblox's team of that colour too)
local function joinTeam(c: Climber, team: number)
	Climbers.setTeam(c, team)
	if c.player then
		c.player.Team = robloxTeams[team]
	end
end

-- save one player's race (once): their stats, and a line for each look it unlocked
local function record(c: Climber)
	local p = c.player
	if not p or recorded[p] then
		return
	end
	recorded[p] = true
	local won = winTeam ~= 0 and c.team == winTeam
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
	Notice:FireAllClients("Only one team can escape!", "throw")
	for _, c in riders do
		Feed:FireAllClients(`{c.name} was thrown off the platform`, "throw")
	end
end

-- one who got out, on the skydive pad: launch them (everyone lays the same rings from the seed); each of
-- them gets one flight
local skydiveRings: { [Player]: number } = {}
local function onSkydive(player: Player, what: unknown, rings: unknown)
	local c = Climbers.forPlayer(player)
	if not c or not c.escaped or state:GetAttribute("Phase") ~= "over" or not c.model or not c.root then
		return
	end
	local sky = player:GetAttribute("Skydive")
	if what == "launch" and sky == nil and state:GetAttribute("Skydive") == "ready" then
		-- on the pad, as this server sees them (a few studs' slack: their own screen is a moment ahead)
		local p = c.root.Position
		local x, y, z = Skydive.padAt()
		local near = Vector3.new(p.X - x, 0, p.Z - z).Magnitude < Skydive.PAD.r + 4
		if not near or math.abs(p.Y - 3 - y) > 6 then
			return
		end
		player:SetAttribute("Skydive", "flying")
		c.model:SetAttribute("Gliding", true)
		local seed = rng:NextInteger(1, 2 ^ 30)
		-- (how many rings this flight has: the trail ends early where the ground leaves no room)
		skydiveRings[player] = #Skydive.launch(x, y + 3, z, 0, seed).rings
		SkydiveEvent:FireAllClients(c.model, x, y + 3, z, 0, seed)
	elseif what == "done" and sky == "flying" then
		player:SetAttribute("Skydive", "done")
		c.model:SetAttribute("Gliding", false)
		local of = skydiveRings[player] or Skydive.RINGS
		local got = if type(rings) == "number" then math.clamp(math.floor(rings), 0, of) else 0
		Feed:FireAllClients(`{c.name} took {got} / {of} rings on the skydive`, "win")
	end
end

-- back to the main screen (the lobby place)
local function goHome(p: Player)
	local lobby = Travel.lobbyPlace()
	if lobby then
		task.spawn(Travel.send, { p }, lobby, false)
	end
end

-- the race is over for this player (they pressed Main screen / End game, or the skydive ended; or they're
-- out of the race and leave rather than watch the rest)
local function onFinish(p: Player, what: unknown)
	if what ~= "leave" then
		return
	end
	local phase = state:GetAttribute("Phase")
	local c = Climbers.forPlayer(p)
	if phase ~= "over" and c and c.out and (phase == "climb" or phase == "roof") then
		if RESERVED then
			goHome(p)
		elseif STUDIO then
			-- (Studio: no lobby to go back to; the next race starts, as Play again does at the end)
			skipCelebration = true
			finished = true
		end
		return
	end
	if phase ~= "over" then
		return
	end
	if RESERVED then
		leaving[p] = true
	else
		againAsked = true
	end
end

-- (Studio) put a player on the roof as the winner (their team wins), to try the end
local function devWin(p: Player)
	local c = Climbers.forPlayer(p)
	local phase = state:GetAttribute("Phase")
	if not c or not c.model or (phase ~= "climb" and phase ~= "roof") then
		return
	end
	c.model:PivotTo(CFrame.new(10, Config.FLOORS * Config.FLOOR_HEIGHT + 3.5, 2))
	onEscape({ c })
end

local function freezeAll(on: boolean)
	for _, c in Climbers.all() do
		c.frozen = on
	end
end

-- Who's friends with whom, asked of Roblox as each player arrives (by the time the race picks its teams
-- the answers are in: it doesn't wait on dozens of web calls). Keyed by the pair's user ids.
local friends: { [string]: boolean } = {}
local asking: { [string]: boolean } = {}
local function pairKey(a: Player, b: Player): string
	return `{math.min(a.UserId, b.UserId)}:{math.max(a.UserId, b.UserId)}`
end
local function askFriends(a: Player, b: Player)
	local key = pairKey(a, b)
	if friends[key] ~= nil or asking[key] then
		return
	end
	asking[key] = true
	task.spawn(function()
		local ok, yes = pcall(function()
			return a:IsFriendsWithAsync(b.UserId)
		end)
		friends[key] = ok and yes == true
		asking[key] = nil
	end)
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
	for _, o in Players:GetPlayers() do
		if o ~= p then
			askFriends(p, o)
		end
	end
	if RESERVED and groupSize == 0 then
		groupSize = Lobby.groupSize(p:GetJoinData().TeleportData)
	end
	local phase = state:GetAttribute("Phase")
	if (phase == "over" or phase == "leaving") and RESERVED then
		-- (the race is already over: nothing to join, straight back to the main screen)
		goHome(p)
	elseif Climbers.forPlayer(p) then
		return -- (already in it)
	elseif phase == "ready" or phase == "climb" or phase == "roof" or (phase == "waiting" and gathered) then
		-- (in Studio, or a straggler: in the live game the lobby sends everyone at once)
		local c = Climbers.add(p.DisplayName, "player", p)
		c.frozen = phase == "ready" or phase == "waiting"
		local counts = table.create(Teams.COUNT, 0)
		for _, o in Climbers.all() do
			if o.team > 0 then
				counts[o.team] += 1
			end
		end
		joinTeam(
			c,
			Teams.forLatecomer(counts, function(a, b)
				return rng:NextInteger(a, b)
			end)
		)
		spawnPlayer(c, Teams.startFloor(c.team))
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

-- which of these players are friends (mostly known already: asked as they arrived; a pair that hasn't
-- answered within a couple of seconds counts as not friends)
local function friendships(players: { Player }): (number, number) -> boolean
	local function pending(): boolean
		local any = false
		for i = 1, #players do
			for j = i + 1, #players do
				if friends[pairKey(players[i], players[j])] == nil then
					askFriends(players[i], players[j])
					any = true
				end
			end
		end
		return any
	end
	local waited = 0
	while pending() and waited < 2.5 do
		waited += task.wait(0.1)
	end
	return function(i: number, j: number): boolean
		return friends[pairKey(players[i], players[j])] == true
	end
end

local function runRace()
	raceNo += 1
	finished, winners, winTeam, roofOpen, startAt, winTime = false, {}, 0, false, math.huge, nil
	gathered = false
	table.clear(skydiveRings)
	table.clear(recorded)
	table.clear(leaving)
	againAsked = false
	state:SetAttribute("Race", raceNo)
	state:SetAttribute("RoofOpen", false)
	state:SetAttribute("Winner", "")
	state:SetAttribute("WinnerTeam", 0)
	state:SetAttribute("StartAt", 0)
	state:SetAttribute("RoofSceneAt", nil)
	state:SetAttribute("Skydive", "")
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Out", nil)
		p:SetAttribute("Escaped", nil)
		p:SetAttribute("Skydive", nil)
	end
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
	local players = Players:GetPlayers()
	local groups = Teams.friendGroups(#players, friendships(players))
	-- (from here on, anyone arriving joins this race as a latecomer: playerAdded)
	for _, p in players do
		table.insert(list, Climbers.add(p.DisplayName, "player", p))
	end
	gathered = true
	-- Studio only: a Workspace attribute TestBots (a number) sets how many bots join, for small tests
	local bots = Rules.botsFor(#list)
	local testBots = workspace:GetAttribute("TestBots")
	if RunService:IsStudio() and type(testBots) == "number" then
		bots = math.clamp(math.floor(testBots), 0, bots)
	end
	-- into teams: friends together, the other players spread out, the bots filling the gaps
	local sizes = table.create(#groups, 0)
	for g, members in groups do
		sizes[g] = #members
	end
	local groupTeams, botTeams = Teams.assign(sizes, bots, function(a, b)
		return rng:NextInteger(a, b)
	end)
	for g, members in groups do
		for j, i in members do
			joinTeam(list[i], groupTeams[g][j])
		end
	end
	for i = 1, bots do
		local c = Bots.create(i)
		joinTeam(c, botTeams[i])
		table.insert(list, c)
	end
	Climbers.publish()
	-- each team on its own floor
	local pending = #list
	for _, c in list do
		c.frozen = true
		task.spawn(function()
			spawn(c, Teams.startFloor(c.team))
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
	gathered = false
	while now() < startAt do
		PlatformService.step(0, false)
		RunService.Heartbeat:Wait()
	end

	freezeAll(false)
	setPhase("climb")
	Notice:FireAllClients("Climb! The first team alone on a platform through the roof wins.", "info")
	while true do
		local t = RaceService.time()
		if not roofOpen and t >= Config.ROOF_OPENS_AFTER then
			roofOpen = true
			state:SetAttribute("RoofOpen", true)
			setPhase("roof")
			tower.openHatch()
			Notice:FireAllClients("The roof is open! Get knocked out now and you're out.", "roof")
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
		-- everyone's out: nobody can win
		if roofOpen then
			local left = 0
			for _, c in Climbers.all() do
				if not c.out then
					left += 1
				end
			end
			if left == 0 then
				break
			end
		end
		RunService.Heartbeat:Wait()
	end

	-- over: everything stops, only the ones who got out move
	PlatformService.freeze()
	freezeAll(true)
	local skydivers = false
	if winTeam ~= 0 then
		local label = Teams.label(winTeam)
		local names = {}
		for _, c in winners do
			c.frozen = false
			table.insert(names, c.name)
			if c.model then
				c.model:SetAttribute("Escaped", true)
			end
			if c.player then
				c.player:SetAttribute("Escaped", true)
				skydivers = true
			end
		end
		state:SetAttribute("WinnerTeam", winTeam)
		state:SetAttribute("Winner", label)
		Notice:FireAllClients(`{label} got out first!`, "win")
		Feed:FireAllClients(
			`{label} got out first ({Rules.clock(RaceService.time())}): {table.concat(names, ", ")}`,
			"win"
		)
	else
		Notice:FireAllClients("Nobody got out.", "over")
	end
	setPhase("over")
	Climbers.publish()
	for _, c in Climbers.all() do
		record(c)
	end
	if skydivers and not skipCelebration then
		-- the winners' roof: the skydive pad comes out
		state:SetAttribute("Skydive", "ready")
		for _, c in winners do
			if c.player then
				Notice:FireClient(c.player, "You got out! Explore the roof, or take the skydive by the sign.", "info")
			end
		end
	end
	if skipCelebration then
		skipCelebration = false
		task.wait(1)
	else
		-- now everyone chooses (client/race/EndScreen): nothing restarts by itself
		local overAt = os.clock()
		local sentAt: { [Player]: number } = {}
		while true do
			if RESERVED then
				for _, p in Players:GetPlayers() do
					local isWinner = p:GetAttribute("Escaped") == true
					local due = leaving[p] or os.clock() - overAt > (if isWinner then WINNER_LINGER else LOSER_LINGER)
					-- (a teleport that didn't take is tried again)
					if due and os.clock() - (sentAt[p] or -math.huge) > 15 then
						sentAt[p] = os.clock()
						goHome(p)
					end
				end
				if #Players:GetPlayers() == 0 then
					break
				end
			elseif againAsked or #Players:GetPlayers() == 0 then
				break
			end
			task.wait(0.25)
		end
	end
	state:SetAttribute("Skydive", "")
	if RESERVED then
		-- (one race per server: it closes once it's empty)
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
	local roster = Instance.new("Folder")
	roster.Name = "Roster"
	roster.Parent = state
	Climbers.publish(roster)
	for n = 1, Teams.COUNT do
		local team = Instance.new("Team")
		team.Name = Teams.NAMES[n]
		team.TeamColor = BrickColor.new(Teams.BRICK[n])
		team.AutoAssignable = false
		team:SetAttribute("Team", n)
		team.Parent = TeamsService
		robloxTeams[n] = team
	end
	-- the roster, a few times a second
	local publishT = 0
	RunService.Heartbeat:Connect(function(dt: number)
		publishT += dt
		if publishT > 0.25 then
			publishT = 0
			Climbers.publish()
		end
	end)

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
	-- player gets out), "restart" the race, "give" the first player a weapon, "ko" knocks someone out (the
	-- first player; "bot": the first bot still up; or a climber's name)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "RooftopDev"
		dev.OnInvoke = function(cmd: string, arg: any)
			if cmd == "skip" and startAt < math.huge then
				startAt -= arg or 0
				state:SetAttribute("StartAt", startAt)
			elseif cmd == "win" then
				-- the first player gets out: on the roof, as the winner
				local p = Players:GetPlayers()[1]
				if p then
					devWin(p)
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
			elseif cmd == "ko" then
				for _, c in Climbers.all() do
					local pick = if arg == nil
						then c.kind == "player"
						elseif arg == "bot" then c.kind == "bot"
						else c.name == arg
					if pick and c.model and not c.fighter.dead then
						CombatService.knockOut(c, nil, "test")
						break
					end
				end
			elseif cmd == "restart" then
				-- end this race at once (no winner, no celebration): the next one starts
				skipCelebration = true
				finished = true
			end
			return { phase = state:GetAttribute("Phase"), t = RaceService.time(), winner = Teams.label(winTeam) }
		end
		dev.Parent = game:GetService("ServerStorage")
		-- the T key's win (Studio only: the server never listens to it in a live game)
		Net.event("Dev").OnServerEvent:Connect(function(p: Player, cmd: unknown)
			if cmd == "win" then
				devWin(p)
			end
		end)
	end
	Net.event("Finish").OnServerEvent:Connect(onFinish)

	Players.PlayerAdded:Connect(playerAdded)
	-- (anyone who arrived while the tower was being built)
	for _, p in Players:GetPlayers() do
		task.spawn(playerAdded, p)
	end
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
