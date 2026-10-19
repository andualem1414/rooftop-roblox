--!strict
-- The RemoteEvents between server and clients, by name. The server makes them; clients wait for them.
--
-- Client -> server (intent only; the server checks everything):
--   Swing(yaw)                     swing the melee weapon in hand toward yaw
--   Shoot(origin, direction, aim)  fire the gun in hand along the camera ray; aim: aiming down sights
--   Guard(on)                      hold up the melee weapon to block
--   Reload()
--   Look(pitch, aiming)            (unreliable, ~15 a second) where you look up / down, and whether you aim
--                                  down the sights, so everyone sees your arms and head follow it
--   Ready()                        this client's scripts are running (the race waits for it)
--   SetLook(id)                    wear this look (if your stats unlock it)
--   SaveSettings(settings)         keep these settings with your profile
--   Boost(size)                    boost up this many floors from the booster pad you stand on
--   Skydive("launch")              the winner stepped on the skydive pad
--   Skydive("done", rings)         the winner's flight is over, with this many rings taken
--   Finish("leave")                the race is over for me: back to the main screen (Studio: play again)
--   Dev("win")                     Studio only: put me on the roof as the winner
--   Lobby("play" / "menu")         the lobby: join the next race from the main screen, or leave it
-- Server -> clients:
--   Knock(velocity)                you were hit: get pushed this way (your client owns your body)
--   ShotFx(model, from, to, kind, weapon)  draw a shot: muzzle flash, streak, impact (kind: "body",
--                                  "wall", "none")
--   SwingFx(model, weapon, side)   a swing started (the arms play it on every screen)
--   HitFx(position, damage, kind, victim, attacker, weapon)  a hit landed (kind: "hit", "block", "head")
--   Notice(text, kind)             a banner line for everyone (or one player)
--   Feed(text, kind)               a kill-feed line
--   Cue(name, position?)           play a sound cue (shared/Sounds) for everyone, or one player
--   Boost(from, to, seconds)       your boost starts: fly from floor `from` to `to` (shared/Booster)
--   Skydive(model, x, y, z, yaw, seed)  the winner launched off the pad (everyone lays the same rings)
--
-- Character attributes the server keeps up to date (for the poses): Aim (pitch, radians), ADS (aiming down
-- the sights), Guard, Reloading, SpawnedAt (server time the body was set down: it comes to), Boosting,
-- Gliding, Escaped (the winner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Swing",
	"Shoot",
	"Guard",
	"Reload",
	"Ready",
	"Knock",
	"ShotFx",
	"SwingFx",
	"HitFx",
	"Notice",
	"Feed",
	"SetLook",
	"SaveSettings",
	"Cue",
	"Boost",
	"Skydive",
	"Finish",
	"Dev",
	"Lobby",
}
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
