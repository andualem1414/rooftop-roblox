--!strict
-- Players' saved profiles (shared/Progress): stats, the look they wear and their settings, in a
-- DataStore, plus the leaderboards in OrderedDataStores. Both places use it: the lobby shows the
-- leaderboards and changes your look and settings; the race adds each race's result.
--   the profile:   loaded when a player joins (and published to their client as the Profile attribute, a
--                  JSON string); a race's result is added with UpdateAsync on what's stored, so two servers
--                  never undo each other
--   settings:      sent by the client (SaveSettings), cleaned up, written at most every few seconds
--   looks:         asked for by the client (SetLook), worn only if the stats unlock it
--   leaderboards:  most escapes, most knock-outs, fastest escape (in tenths of a second)
-- In Studio without "Enable Studio Access to API Services" the stores fail: profiles then live only as
-- long as the server (and say so once in Output).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Progress = require(ReplicatedStorage.Shared.Progress)
local Looks = require(ReplicatedStorage.Shared.Looks)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Net = require(ReplicatedStorage.Shared.Net)

type Profile = Progress.Profile

local ProfileStore = {}

local STORE = "Profiles_v1"
local SETTINGS_EVERY = 8 -- seconds between writes of changed settings
local STUDIO = RunService:IsStudio()

local store: DataStore? = nil
local boards: { [string]: OrderedDataStore } = {}
local offline = false
local profiles: { [Player]: Profile } = {}
local fromStore: { [Player]: boolean } = {} -- loaded from the store (else: never write over it)
local dirty: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}
local lookListeners: { (Player, string) -> () } = {}
local names: { [number]: string } = {}

local function key(userId: number): string
	return "p_" .. userId
end

-- the stores, once (they fail in Studio without API access: then everything stays in memory)
local function open(): boolean
	if offline then
		return false
	end
	if store then
		return true
	end
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(STORE)
		for _, b in Progress.BOARDS do
			boards[b.id] = DataStoreService:GetOrderedDataStore(b.id .. "_v1")
		end
	end)
	if not ok then
		offline = true
		warn("[Rooftop] saved data is off (no data stores here):", err)
	end
	return ok
end

-- try a store call a few times (they can fail now and then); false and the error if it never worked
local function try<T>(what: string, fn: () -> T, tries: number?): (boolean, any)
	local last: any = nil
	for i = 1, tries or 3 do
		local ok, r = pcall(fn)
		if ok then
			return true, r
		end
		last = r
		-- in Studio a failure is almost always "no API access" (or an unpublished place): no use trying
		-- again, and no use waiting for it every time
		if STUDIO then
			if not offline then
				offline = true
				warn("[Rooftop] saved data is off in this Studio session:", r)
			end
			return false, r
		end
		task.wait(i)
	end
	warn(`[Rooftop] {what} failed:`, last)
	return false, last
end

-- the profile as the client sees it (the Profile attribute on the Player)
local function publish(player: Player)
	local p = profiles[player]
	if not p or not player.Parent then
		return
	end
	local s = p.stats
	player:SetAttribute(
		"Profile",
		HttpService:JSONEncode({
			stats = {
				rounds = s.rounds,
				wins = s.wins,
				knockouts = s.knockouts,
				highestFloor = s.highestFloor,
				bestTime = s.bestTime or 0,
			},
			look = p.look,
			settings = p.settings,
			credits = p.credits,
			saved = not offline,
		})
	)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local wins = ls:FindFirstChild("Escapes") :: IntValue?
		local kos = ls:FindFirstChild("KOs") :: IntValue?
		if wins then
			wins.Value = s.wins
		end
		if kos then
			kos.Value = s.knockouts
		end
	end
end

-- the player's profile (loads it the first time; a fresh one if the store can't be reached)
function ProfileStore.load(player: Player): Profile
	while loading[player] do
		task.wait(0.1)
	end
	local have = profiles[player]
	if have then
		return have
	end
	loading[player] = true
	local p = Progress.newProfile()
	if open() and store then
		local ok, raw = try("loading a profile", function()
			return (store :: DataStore):GetAsync(key(player.UserId))
		end)
		if ok then
			p = Progress.sanitize(raw)
			fromStore[player] = true
		end
	end
	profiles[player] = p
	loading[player] = nil
	publish(player)
	return p
end

function ProfileStore.get(player: Player): Profile?
	return profiles[player]
end

-- change what's stored with fn (on top of what's there now), keep the result
local function update(player: Player, what: string, fn: (Profile) -> Profile): Profile?
	if not open() or not store or not fromStore[player] then
		-- no store (or it couldn't be read): just this session
		local p = profiles[player]
		if p then
			profiles[player] = fn(p)
		end
		return profiles[player]
	end
	local ok, result = try(what, function()
		return (store :: DataStore):UpdateAsync(key(player.UserId), function(old: any): any
			return fn(Progress.sanitize(old))
		end)
	end)
	if ok and result then
		local p = Progress.sanitize(result)
		profiles[player] = p
		return p
	end
	return nil
end

-- a race is over for this player: add it to their stats. Returns the looks it unlocked.
function ProfileStore.recordRound(player: Player, r: Progress.Result): { Looks.Look }
	local before = (profiles[player] or ProfileStore.load(player)).stats
	local p = update(player, "saving a race", function(old: Profile): Profile
		old.stats = Progress.applyRound(old.stats, r)
		return old
	end)
	if not p then
		-- (the store failed: still count it for this session)
		local cur = profiles[player]
		if cur then
			cur.stats = Progress.applyRound(cur.stats, r)
			p = cur
		end
	end
	if not p then
		return {}
	end
	publish(player)
	-- the leaderboards
	if not offline and fromStore[player] then
		for _, b in Progress.BOARDS do
			local v = Progress.boardValue(b.id, p.stats)
			local ods = boards[b.id]
			if v and ods and v ~= Progress.boardValue(b.id, before) then
				task.spawn(try, "a leaderboard", function()
					ods:SetAsync(tostring(player.UserId), v)
				end, 2)
			end
		end
	end
	return Looks.newlyUnlocked(before, p.stats)
end

-- a purchase handed out as a boost credit, once per purchase id (Roblox can report one purchase more than
-- once). Returns ok (it's saved, now or before: Roblox may count the purchase as done) and fresh (it was
-- handed out just now). In a live game a profile that couldn't be read is never written over: not ok.
function ProfileStore.grantPurchase(player: Player, purchaseId: string, size: number): (boolean, boolean)
	ProfileStore.load(player)
	if not STUDIO and not fromStore[player] then
		return false, false
	end
	local fresh = false
	local p = update(player, "saving a purchase", function(old: Profile): Profile
		fresh = Progress.grant(old, purchaseId, size)
		return old
	end)
	if not p then
		return false, false
	end
	publish(player)
	return true, fresh
end

-- use one boost credit of a size. Returns true if there was one (and it's gone now).
function ProfileStore.spendCredit(player: Player, size: number): boolean
	local p = profiles[player]
	if not p or (p.credits[tostring(size)] or 0) <= 0 then
		return false
	end
	local spent = false
	local saved = update(player, "using a boost credit", function(old: Profile): Profile
		spent = Progress.spend(old, size)
		return old
	end)
	if saved then
		publish(player)
	end
	return saved ~= nil and spent
end

-- how many credits of a size the player has
function ProfileStore.credits(player: Player, size: number): number
	local p = profiles[player]
	return if p then p.credits[tostring(size)] or 0 else 0
end

-- wear a look (if the stats unlock it). Returns true if it changed.
function ProfileStore.setLook(player: Player, id: string): boolean
	local p = profiles[player]
	local look = Looks.byId(id)
	if not p or not look or not Looks.isUnlocked(look, p.stats) or p.look == id then
		return false
	end
	p.look = id
	publish(player)
	task.spawn(update, player, "saving a look", function(old: Profile): Profile
		if Looks.isUnlocked(look, old.stats) then
			old.look = id
		end
		return old
	end)
	for _, fn in lookListeners do
		task.spawn(fn, player, id)
	end
	return true
end

-- someone changed their look (the lobby dresses them again)
function ProfileStore.onLookChanged(fn: (Player, string) -> ())
	table.insert(lookListeners, fn)
end

function ProfileStore.setSettings(player: Player, raw: any)
	local p = profiles[player]
	if not p then
		return
	end
	p.settings = Settings.sanitize(raw)
	dirty[player] = true
	publish(player)
end

local function flushSettings(player: Player)
	if not dirty[player] then
		return
	end
	dirty[player] = nil
	local p = profiles[player]
	if not p then
		return
	end
	local s = p.settings
	update(player, "saving settings", function(old: Profile): Profile
		old.settings = s
		return old
	end)
end

-- Escapes and KOs in Roblox's player list
function ProfileStore.leaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in { "Escapes", "KOs" } do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = player
	publish(player)
end

-- the leaderboards' top rows: { { id, title, rows = { { name, value } } } } (empty without the stores)
export type Board = { id: string, title: string, rows: { { name: string, value: string } } }
function ProfileStore.readBoards(top: number): { Board }
	local out: { Board } = {}
	if not open() then
		return out
	end
	local want: { number } = {}
	local raw: { [string]: { { key: string, value: number } } } = {}
	for _, b in Progress.BOARDS do
		local ods = boards[b.id]
		local ok, page = try("reading a leaderboard", function()
			return ods:GetSortedAsync(b.ascending, top):GetCurrentPage()
		end, 1)
		raw[b.id] = if ok then page else {}
		for _, row in raw[b.id] do
			local id = tonumber(row.key)
			if id and not names[id] then
				table.insert(want, id)
			end
		end
	end
	if #want > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(want)
		end)
		if ok then
			for _, info in infos do
				names[info.Id] = info.DisplayName
			end
		end
	end
	for _, b in Progress.BOARDS do
		local rows = {}
		for _, row in raw[b.id] do
			local id = tonumber(row.key)
			table.insert(rows, {
				name = (id and names[id]) or "?",
				value = Progress.boardText(b.id, row.value),
			})
		end
		table.insert(out, { id = b.id, title = b.title, rows = rows })
	end
	return out
end

function ProfileStore.init()
	Net.event("SetLook").OnServerEvent:Connect(function(player: Player, id: unknown)
		if type(id) == "string" and #id < 40 then
			ProfileStore.setLook(player, id)
		end
	end)
	Net.event("SaveSettings").OnServerEvent:Connect(function(player: Player, raw: unknown)
		if type(raw) == "table" then
			ProfileStore.setSettings(player, raw)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		flushSettings(player)
		profiles[player] = nil
		fromStore[player] = nil
		dirty[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SETTINGS_EVERY)
			for player in dirty do
				task.spawn(flushSettings, player)
			end
		end
	end)
	game:BindToClose(function()
		for player in dirty do
			flushSettings(player)
		end
	end)
end

return ProfileStore
