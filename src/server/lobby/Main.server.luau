--!strict
-- The lobby server: the forecourt in front of the tower, the countdown, and sending each group
-- of up to 20 into its own reserved race server (phase 3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Version")) :: any

print(`[Rooftop] lobby server up, v{Version}`)
