--!strict
-- The race client: input, camera, HUD and effects. It only sends intent; the server decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Version")) :: any

print(`[Rooftop] race client up for {Players.LocalPlayer.Name}, v{Version}`)
