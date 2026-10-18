--!strict
-- The lobby client: countdown, leaderboards, looks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Version")) :: any

print(`[Rooftop] lobby client up for {Players.LocalPlayer.Name}, v{Version}`)
