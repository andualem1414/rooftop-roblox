--!strict
-- The race server: owns the race, the platforms, health, hits and the win.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Tower = require(script.Parent.Tower)
local RaceService = require(script.Parent.RaceService)

CollisionGroups.init()
local tower = Tower.build()
RaceService.start(tower)

print(`[Rooftop] race server up, v{Version}`)
