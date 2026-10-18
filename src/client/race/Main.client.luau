--!strict
-- The race client: input, camera, poses, HUD, effects and set pieces. It only sends intent; the server
-- decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)
local CameraAim = require(script.Parent.CameraAim)
local Poser = require(script.Parent.Poser)
local Fx = require(script.Parent.Fx)
local Controls = require(script.Parent.Controls)
local Cutaway = require(script.Parent.Cutaway)
local Hud = require(script.Parent.Hud)
local Cinematic = require(script.Parent.Cinematic)
local Ambience = require(script.Parent.Ambience)

CameraAim.init()
Poser.init()
Fx.init()
Controls.init()
Cutaway.init()
Hud.init()
Ambience.init()
Cinematic.init()

-- tell the server we're running (the race doesn't count down until everyone's client is)
require(ReplicatedStorage.Shared.Net).event("Ready"):FireServer()

print(`[Rooftop] race client up for {Players.LocalPlayer.Name}, v{Version}`)
