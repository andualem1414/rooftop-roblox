--!strict
-- Moving players between the two places: the lobby sends a group into a fresh reserved race server, the
-- race sends everyone back to the lobby. Teleports fail now and then: each is tried a few times, and a
-- player whose teleport fails after it started (TeleportInitFailed) is sent again on their own to the
-- same server (create.roblox.com/docs/projects/teleport). Teleports don't work in Studio.
--   place ids: shared/Places, or (while those are 0) looked up by name: the place with "Race" in its
--   name is the race, the other one the lobby
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Places = require(ReplicatedStorage.Shared.Places)

local Travel = {}

local found: { lobby: number?, race: number? }? = nil
-- where each player was last sent (a straggler's retry goes to the same reserved server, with the same data)
local sentTo: { [Player]: { code: string?, data: { [string]: any }? } } = setmetatable({}, { __mode = "k" }) :: any

-- the experience's places by name (once)
local function lookUp(): { lobby: number?, race: number? }
	if found then
		return found
	end
	local out: { lobby: number?, race: number? } = {}
	local ok, err = pcall(function()
		local pages = AssetService:GetGamePlacesAsync()
		while true do
			for _, place in pages:GetCurrentPage() do
				if string.find(string.lower(place.Name), "race", 1, true) then
					out.race = out.race or place.PlaceId
				else
					out.lobby = out.lobby or place.PlaceId
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn("[Rooftop] couldn't list the experience's places:", err)
	end
	found = out
	return out
end

function Travel.racePlace(): number?
	return if Places.RACE ~= 0 then Places.RACE else lookUp().race
end

function Travel.lobbyPlace(): number?
	return if Places.LOBBY ~= 0 then Places.LOBBY else lookUp().lobby
end

-- Teleports don't work in Studio
function Travel.available(): boolean
	return not RunService:IsStudio()
end

-- send players to a place. reserve: into a fresh reserved server, all together. data: teleport data
-- (the client can read it). Returns true once the teleport started.
function Travel.send(players: { Player }, placeId: number, reserve: boolean, data: { [string]: any }?): boolean
	if #players == 0 then
		return true
	end
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = reserve
	if data then
		options:SetTeleportData(data)
	end
	for i = 1, Config.TELEPORT_TRIES do
		local ok, result = pcall(function()
			return TeleportService:TeleportAsync(placeId, players, options)
		end)
		if ok then
			local code = result and (result :: any).ReservedServerAccessCode
			for _, p in players do
				sentTo[p] = { code = if type(code) == "string" and code ~= "" then code else nil, data = data }
			end
			return true
		end
		warn(`[Rooftop] teleport failed (try {i}):`, result)
		task.wait(i * 1.5)
	end
	return false
end

function Travel.init()
	-- a teleport that started but failed for one player: try them again (Flooded: wait longer)
	local tries: { [Player]: number } = {}
	TeleportService.TeleportInitFailed:Connect(
		function(
			player: Player,
			result: Enum.TeleportResult,
			message: string,
			placeId: number,
			_options: TeleportOptions?
		)
			local n = (tries[player] or 0) + 1
			tries[player] = n
			warn(`[Rooftop] teleport of {player.Name} failed ({result.Name}): {message}`)
			if n > Config.TELEPORT_TRIES then
				return
			end
			if result ~= Enum.TeleportResult.Failure and result ~= Enum.TeleportResult.Flooded then
				return
			end
			task.wait(if result == Enum.TeleportResult.Flooded then 15 else 1.5)
			if not player.Parent then
				return
			end
			-- on their own, to the server the rest went to
			local sent = sentTo[player]
			local options = Instance.new("TeleportOptions")
			if sent and sent.code then
				options.ReservedServerAccessCode = sent.code
			end
			if sent and sent.data then
				options:SetTeleportData(sent.data)
			end
			pcall(function()
				TeleportService:TeleportAsync(placeId, { player }, options)
			end)
		end
	)
end

return Travel
