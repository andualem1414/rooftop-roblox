--!strict
-- The lobby: the countdown and sending each group into its own race (shared/Lobby has the rules).
--   the first player in starts a 45 s countdown; 20 waiting cuts it to 5 s; at zero everyone in the
--   lobby goes, together, into a fresh reserved race server (the group's size rides along, so the race
--   waits for all of them); anyone arriving meanwhile waits for the next countdown
--   friends: joining a friend from Roblox's friends list lands you in their lobby, so you go together
-- Clients follow along through attributes on ReplicatedStorage.LobbyState: Deadline (server time the group
-- goes, 0: no countdown), Waiting, Status ("waiting" / "counting" / "sending"), Message, Boards (JSON).
-- In Studio teleports don't work: at zero it says so and counts again.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = require(ReplicatedStorage.Shared.Lobby)
local Net = require(ReplicatedStorage.Shared.Net)
local ProfileStore = require(script.Parent.Parent.Common.ProfileStore)
local LookService = require(script.Parent.Parent.Common.LookService)
local Travel = require(script.Parent.Parent.Common.Travel)
local Forecourt = require(script.Parent.Forecourt)

local LobbyService = {}

local SENDING_FOR = 30 -- seconds someone being sent is left out of the count (then they count again)
local BOARDS_EVERY = 60

local state: Folder
local deadline: number? = nil
local sending: { [Player]: number } = {}
local Notice = Net.event("Notice")

local function now(): number
	return workspace:GetServerTimeNow()
end

local function say(text: string)
	state:SetAttribute("Message", text)
	Notice:FireAllClients(text, "info")
end

-- who's waiting for the next race
local function waitingPlayers(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		local since = sending[p]
		if since and os.clock() - since > SENDING_FOR then
			sending[p] = nil -- (their teleport never happened: they wait again)
			since = nil
		end
		if not since then
			table.insert(out, p)
		end
	end
	return out
end

local function go(group: { Player })
	if not Travel.available() then
		say("Teleports don't work in Studio: play the race place to test a race.")
		return
	end
	local race = Travel.racePlace()
	if not race then
		say("The race isn't set up yet.")
		return
	end
	for _, p in group do
		sending[p] = os.clock()
	end
	state:SetAttribute("Status", "sending")
	Notice:FireAllClients("Off to the tower!", "win")
	task.spawn(function()
		if not Travel.send(group, race, true, Lobby.groupData(#group, now())) then
			for _, p in group do
				sending[p] = nil
			end
			say("Couldn't start the race. Trying again…")
		end
	end)
end

local function step()
	local group = waitingPlayers()
	local t = now()
	deadline = Lobby.deadline(t, deadline, #group)
	state:SetAttribute("Waiting", #group)
	state:SetAttribute("Deadline", deadline or 0)
	if state:GetAttribute("Status") ~= "sending" or next(sending) == nil then
		state:SetAttribute("Status", if deadline then "counting" else "waiting")
	end
	if deadline and t >= deadline then
		deadline = nil
		go(group)
	end
end

local function refreshBoards()
	local boards = ProfileStore.readBoards(8)
	Forecourt.showBoards(boards)
	state:SetAttribute("Boards", HttpService:JSONEncode(boards))
end

local function dress(p: Player, char: Model)
	local profile = ProfileStore.load(p)
	LookService.applyWhenLoaded(p, char, profile.look)
end

local function playerAdded(p: Player)
	p.CharacterAdded:Connect(function(char: Model)
		dress(p, char)
	end)
	task.spawn(function()
		ProfileStore.load(p)
		ProfileStore.leaderstats(p)
		if p.Character then
			dress(p, p.Character)
		end
	end)
end

function LobbyService.start()
	state = Instance.new("Folder")
	state.Name = "LobbyState"
	state:SetAttribute("Deadline", 0)
	state:SetAttribute("Waiting", 0)
	state:SetAttribute("Status", "waiting")
	state:SetAttribute("Message", "")
	state:SetAttribute("Boards", "[]")
	state.Parent = ReplicatedStorage

	for _, p in Players:GetPlayers() do
		playerAdded(p)
	end
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(function(p: Player)
		sending[p] = nil
	end)
	-- a new look: a fresh body wearing it (going back to your own avatar needs one anyway)
	ProfileStore.onLookChanged(function(p: Player)
		if p.Parent and not sending[p] then
			p:LoadCharacter()
		end
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(step)
			if not ok then
				warn("[Rooftop] lobby step failed:", err)
			end
			task.wait(0.25)
		end
	end)
	task.spawn(function()
		while true do
			pcall(refreshBoards)
			task.wait(BOARDS_EVERY)
		end
	end)
end

return LobbyService
