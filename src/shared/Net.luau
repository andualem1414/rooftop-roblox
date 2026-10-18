--!strict
-- The RemoteEvents between server and clients, by name. The server makes them; clients wait for them.
--
-- Client -> server (intent only; the server checks everything):
--   Swing(yaw)                     swing the melee weapon in hand toward yaw
--   Shoot(origin, direction, aim)  fire the gun in hand along the camera ray; aim: aiming down sights
--   Guard(on)                      hold up the melee weapon to block
--   Reload()
--   Look(pitch)                    (unreliable, ~15 a second) where you look up / down, so everyone sees
--                                  your arms and head follow it
-- Server -> clients:
--   Knock(velocity)                you were hit: get pushed this way (your client owns your body)
--   ShotFx(model, from, to, kind, weapon)  draw a shot: muzzle flash, streak, impact (kind: "body",
--                                  "wall", "none")
--   SwingFx(model, weapon, side)   a swing started (the arms play it on every screen)
--   HitFx(position, damage, kind, victim, attacker)  a hit landed (kind: "hit", "block", "head")
--   Notice(text, kind)             a banner line for everyone (or one player)
--   Feed(text, kind)               a kill-feed line
--
-- Character attributes the server keeps up to date (for the poses): Aim (pitch, radians), Guard,
-- Reloading.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Swing", "Shoot", "Guard", "Reload", "Knock", "ShotFx", "SwingFx", "HitFx", "Notice", "Feed" }
local UNRELIABLE = { "Look" }

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	folder = if existing and existing:IsA("Folder") then existing else Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in UNRELIABLE do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("UnreliableRemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
