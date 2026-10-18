--!strict
-- The race client: input, camera, HUD and effects. It only sends intent; the server decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)
local CameraAim = require(script.Parent.CameraAim)
local Controls = require(script.Parent.Controls)
local Cutaway = require(script.Parent.Cutaway)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)

CameraAim.init()
Controls.init()
Cutaway.init()
Fx.init()
Hud.init()

print(`[Rooftop] race client up for {Players.LocalPlayer.Name}, v{Version}`)
