--!strict
-- The race client: input, camera, poses, HUD and effects. It only sends intent; the server decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)
local CameraAim = require(script.Parent.CameraAim)
local Poser = require(script.Parent.Poser)
local Fx = require(script.Parent.Fx)
local Controls = require(script.Parent.Controls)
local Cutaway = require(script.Parent.Cutaway)
local Hud = require(script.Parent.Hud)

CameraAim.init()
Poser.init()
Fx.init()
Controls.init()
Cutaway.init()
Hud.init()

print(`[Rooftop] race client up for {Players.LocalPlayer.Name}, v{Version}`)
