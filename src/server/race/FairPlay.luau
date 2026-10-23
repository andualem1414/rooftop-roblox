--!strict
-- Keeping the climb honest. Each player's client moves their own body (Roblox hands every client its
-- character), so a cheat could fly or teleport up the tower, onto the top-floor platform, or through the
-- roof. Ten times a second this shows the rule (shared/FairClimb: up a floor only on a platform you got
-- onto fair, or boosting; with room to spare for crouching, landings and lag) what the server sees of
-- each player, and puts anyone it says "back" where they last were fair. Nobody's checked once they've
-- got out (the roof, the skydive), outside the race, or across a new body (the server set it down: a
-- race's start, coming to). Bots are moved by the server: never checked.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FairClimb = require(ReplicatedStorage.Shared.FairClimb)
local Climbers = require(script.Parent.Climbers)
local PlatformService = require(script.Parent.PlatformService)

type Climber = Climbers.Climber

local FairPlay = {}

local EVERY = 0.1 -- seconds between checks
local STUDIO = RunService:IsStudio()

type Watch = {
	model: Model,
	climb: FairClimb.State,
	good: CFrame, -- where they last were fair (their root)
	highest: number, -- their highest floor then
}
local watching: { [Climber]: Watch } = {}

-- how high a platform's deck is now (nil: parked)
local function topOf(slot: any): number?
	local s = slot :: PlatformService.Slot
	if not s.k then
		return nil
	end
	return s.deck.Position.Y + s.deck.Size.Y / 2
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
			local feet = Climbers.feetY(c)
			if c.kind ~= "player" or not model or not root or not feet or c.escaped or c.fighter.dead then
				watching[c] = nil
				continue
			end
			local w = watching[c]
			if not w or w.model ~= model or not live then
				watching[c] =
					{ model = model, climb = FairClimb.start(feet, now), good = root.CFrame, highest = c.highest }
				continue
			end
			local verdict = FairClimb.step(w.climb, {
				feet = feet,
				now = now,
				on = PlatformService.slotOf(c),
				boosting = model:GetAttribute("Boosting") == true,
				topOf = topOf,
			})
			if verdict == "back" then
				-- up the tower without a platform or a boost: back where they last were fair
				if STUDIO then
					print(`[Rooftop] {c.name} went up a floor without a platform or a boost: put back`)
				end
				local lift = root.Position.Y - feet
				model:PivotTo(w.good)
				root.AssemblyLinearVelocity = Vector3.zero
				c.highest = w.highest -- (the floor they cheated up to doesn't count on their stats)
				FairClimb.putBack(w.climb, w.good.Position.Y - lift, now)
			else
				w.good = root.CFrame
				w.highest = c.highest
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
