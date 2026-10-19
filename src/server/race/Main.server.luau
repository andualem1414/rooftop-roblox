--!strict
-- The race server: builds the world and owns the race, the platforms, health, hits and the win.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Version = require(ReplicatedStorage.Shared.Version)
local Look = require(ReplicatedStorage.Shared.Look)
local CollisionGroups = require(script.Parent.Parent.Common.CollisionGroups)
local Tower = require(script.Parent.Parent.Common.Tower)
local World = require(script.Parent.Parent.Common.World)
local ProfileStore = require(script.Parent.Parent.Common.ProfileStore)
local Travel = require(script.Parent.Parent.Common.Travel)
local RaceService = require(script.Parent.RaceService)

CollisionGroups.init()
ProfileStore.init()
Travel.init()

-- the look; in Studio a Workspace attribute LookPreset ("Neon Night", "Golden Dusk", "Moonlit Ink")
-- switches it live
local function look()
	local preset = workspace:GetAttribute("LookPreset")
	Look.apply(if RunService:IsStudio() and type(preset) == "string" then preset else nil)
end
look()
workspace:GetAttributeChangedSignal("LookPreset"):Connect(look)

local tower = Tower.build()
World.build()
RaceService.start(tower)

print(`[Rooftop] race server up, v{Version}`)
