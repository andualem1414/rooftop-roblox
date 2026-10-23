--!strict
-- Keeping the climb honest. Each player's client moves their own body (Roblox hands every client its
-- character), so a cheat could fly or teleport up the tower, onto the top-floor platform, or through the
-- roof. The only ways up are a platform and a boost, so a player may only go up one floor at a time, and
-- only while riding a platform (or just after: stepping off at a stop) or boosting (and just after:
-- the landing); anything else puts them straight back where they last were fair and square. Going down
-- is always fine (a fall, the shaft, coming to lower). Nobody's checked once they've got out (the roof,
-- the skydive), outside the race, or across a new body (the server set it down: a race's start, coming
-- to). Bots are moved by the server: never checked.
--   floors here count from a body's feet reaching the next floor's surface (a little under it), so
--   standing on tall furniture never looks like the floor above
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Climbers = require(script.Parent.Climbers)
local PlatformService = require(script.Parent.PlatformService)

type Climber = Climbers.Climber

local FairPlay = {}

local EVERY = 0.1 -- seconds between checks
local GRACE = 1.5 -- seconds a ride or a boost still counts after it (a stop, a landing)
local STUDIO = RunService:IsStudio()

type Watch = { model: Model, floor: number, good: CFrame, highest: number, rodeAt: number, boostAt: number }
local watching: { [Climber]: Watch } = {}

local function floorOf(c: Climber): number?
	local feet = Climbers.feetY(c)
	if not feet then
		return nil
	end
	return math.clamp(math.floor(feet / Config.FLOOR_HEIGHT + 0.05), 0, Config.FLOORS)
end

-- phase(): the race's phase (RaceState's Phase)
function FairPlay.init(phase: () -> string)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < EVERY then
			return
		end
		acc = 0
		local p = phase()
		local live = p == "ready" or p == "climb" or p == "roof"
		local now = os.clock()
		for _, c in Climbers.all() do
			local model, root = c.model, c.root
			local floor = floorOf(c)
			if c.kind ~= "player" or not model or not root or not floor or c.escaped or c.fighter.dead then
				watching[c] = nil
				continue
			end
			local w = watching[c]
			if not w or w.model ~= model or not live then
				watching[c] = {
					model = model,
					floor = floor,
					good = root.CFrame,
					highest = c.highest,
					rodeAt = -math.huge,
					boostAt = -math.huge,
				}
				continue
			end
			if PlatformService.slotOf(c) then
				w.rodeAt = now
			end
			if model:GetAttribute("Boosting") == true then
				w.boostAt = now
			end
			local up = floor - w.floor
			if up <= 0 or now - w.boostAt < GRACE or (up == 1 and now - w.rodeAt < GRACE) then
				w.floor = floor
				w.good = root.CFrame
				w.highest = c.highest
			else
				-- up the tower without a platform or a boost: back where they were
				if STUDIO then
					print(`[Rooftop] {c.name} went up {up} floor(s) without a platform or a boost: put back`)
				end
				model:PivotTo(w.good)
				root.AssemblyLinearVelocity = Vector3.zero
				c.highest = w.highest -- (the floor they cheated up to doesn't count on their stats)
			end
		end
		for c in watching do
			if not table.find(Climbers.all(), c) then
				watching[c] = nil
			end
		end
	end)
end

return FairPlay
