--!strict
-- The race client: input, camera, poses, HUD, effects and set pieces. It only sends intent; the server
-- decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)
local Audio = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Audio")) :: any
local CameraAim = require(script.Parent.CameraAim)
local Poser = require(script.Parent.Poser)
local Fx = require(script.Parent.Fx)
local Controls = require(script.Parent.Controls)
local Cutaway = require(script.Parent.Cutaway)
local Sightline = require(script.Parent.Sightline)
local Hud = require(script.Parent.Hud)
local Cinematic = require(script.Parent.Cinematic)
local Ambience = require(script.Parent.Ambience)
local BoostPad = require(script.Parent.BoostPad)
local SkydiveFlight = require(script.Parent.SkydiveFlight)
local EndScreen = require(script.Parent.EndScreen)
local Spectate = require(script.Parent.Spectate)

Audio.init()
CameraAim.init()
Poser.init()
Fx.init()
Controls.init()
Cutaway.init()
Sightline.init()
Hud.init()
Ambience.init()
Cinematic.init()
BoostPad.init()
SkydiveFlight.init()
EndScreen.init()
Spectate.init()

-- once the loading screen has everything in place, tell the server we're ready (the race doesn't count
-- down until everyone's client is)
task.spawn(function()
	while Players.LocalPlayer:GetAttribute("Loaded") ~= true do
		task.wait(0.1)
	end
	require(ReplicatedStorage.Shared.Net).event("Ready"):FireServer()
end)

print(`[Rooftop] race client up for {Players.LocalPlayer.Name}, v{Version}`)
