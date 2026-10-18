--!strict
-- The race server: owns the round, the platforms, health, hits and the win (phase 2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Version = require(Shared:WaitForChild("Version")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any

print(`[Rooftop] race server up, v{Version}: {Config.FLOORS} floors, roof opens after {Config.ROOF_OPENS_AFTER} s`)
