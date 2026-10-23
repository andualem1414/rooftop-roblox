--!strict
-- Never stuck for good (there's no reset: a knock-out is the only way down). Your client moves your body,
-- so it watches it: held a direction for a while and got nowhere, and boxed in or wedged (shared/Unstuck
-- says), you're set down on the nearest spot with room for you, on the same floor. Not while riding a
-- platform (the shaft's sides hem you in there), boosting, gliding, crouched, in a set piece or frozen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Unstuck = require(ReplicatedStorage.Shared.Unstuck)
local CameraAim = require(script.Parent.CameraAim)

local player = Players.LocalPlayer

local Unstick = {}

local EVERY = 0.25 -- seconds between looks
local AFTER = 1.5 -- seconds of trying to move and getting nowhere
local SHAFT = Config.SHAFT_HALF + 1

-- what isn't in the way: every body, the effects, the pickups, the platforms
local function skipList(): { Instance }
	local skip: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, name in { "Bots", "Fx", "Pickups", "Platforms", "Ambience", "Skydive" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	return skip
end

function Unstick.init()
	local acc, tried = 0, 0
	local last: Vector3? = nil
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < EVERY then
			return
		end
		acc = 0
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			not char
			or not hum
			or not root
			or hum.Health <= 0
			or hum.WalkSpeed <= 0
			or CameraAim.cinematic
			or char:GetAttribute("Boosting") == true
			or char:GetAttribute("Gliding") == true
			or char:GetAttribute("Crouch") ~= nil -- (down under something low: that's hiding, not stuck)
		then
			tried, last = 0, nil
			return
		end
		local p = root.Position
		local onDeck = math.abs(p.X) < SHAFT and math.abs(p.Z) < SHAFT
		local moved = if last then Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude else math.huge
		last = p
		-- (a body that's moving at all, even slowly crouched, isn't stuck)
		if onDeck or hum.MoveDirection.Magnitude < 0.3 or moved > 0.5 then
			tried = 0
			return
		end
		tried += EVERY
		if tried < AFTER then
			return
		end
		tried = 0
		local skip = skipList()
		if Unstuck.trapped(root, hum, skip) then
			local cf = Unstuck.freeSpot(root, hum, skip)
			if cf then
				root.AssemblyLinearVelocity = Vector3.zero
				char:PivotTo(cf)
			end
		end
	end)
end

return Unstick
