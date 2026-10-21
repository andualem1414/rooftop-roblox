--!strict
-- The lobby server: the forecourt in front of the tower, the countdown, and sending each group of up to 20
-- into its own reserved race server. The tower and the valley are the race's own (server/common), so the
-- lobby looks out on the very tower you're about to climb.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Version = require(ReplicatedStorage.Shared.Version)
local Look = require(ReplicatedStorage.Shared.Look)
local CollisionGroups = require(script.Parent.Parent.Common.CollisionGroups)
local Tower = require(script.Parent.Parent.Common.Tower)
local World = require(script.Parent.Parent.Common.World)
local ProfileStore = require(script.Parent.Parent.Common.ProfileStore)
local Travel = require(script.Parent.Parent.Common.Travel)
local Purchases = require(script.Parent.Parent.Common.Purchases)
local Net = require(ReplicatedStorage.Shared.Net)
local Forecourt = require(script.Parent.Forecourt)
local LobbyService = require(script.Parent.LobbyService)

CollisionGroups.init()
ProfileStore.init()
Travel.init()
-- (a boost bought in a race but only confirmed now, here: it waits as a credit for the next race)
Purchases.init(function(player: Player, size: number)
	Net.event("Notice"):FireClient(player, `Boost +{size} saved for your next race.`, "info")
end)

-- the look; in Studio a Workspace attribute LookPreset switches it live (as in the race)
local function look()
	local preset = workspace:GetAttribute("LookPreset")
	Look.apply(if RunService:IsStudio() and type(preset) == "string" then preset else nil)
end
look()
workspace:GetAttributeChangedSignal("LookPreset"):Connect(look)

Tower.build({ interiors = false }) -- (seen only from out on the forecourt: no furniture)
World.build()
Forecourt.build()
LobbyService.start()

print(`[Rooftop] lobby server up, v{Version}`)
