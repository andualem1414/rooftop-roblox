--!strict
-- The RemoteEvents between server and clients, by name. The server makes them; clients wait for them.
--
-- Client -> server (intent only; the server checks everything):
--   Swing(yaw)                     swing the melee weapon in hand toward yaw
--   Shoot(origin, direction, aim)  fire the gun in hand along the camera ray; aim: aiming down sights
--   Guard(on)                      hold up the melee weapon to block
--   Reload()
-- Server -> clients:
--   Knock(velocity)                you were hit: get pushed this way (your client owns your body)
--   ShotFx(model, from, to, kind)  draw a shot: muzzle flash, streak, impact (kind: "body", "wall", "none")
--   HitFx(position, damage, kind)  a hit landed here (kind: "hit", "block", "head")
--   Notice(text, kind)             a banner line for everyone (or one player)
--   Feed(text, kind)               a kill-feed line

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Swing", "Shoot", "Guard", "Reload", "Knock", "ShotFx", "HitFx", "Notice", "Feed" }

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
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
