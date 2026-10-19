--!strict
-- The lobby client: the countdown, the menus (how to play, looks, stats, leaderboards, settings) and the
-- music.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Version")) :: any
local Audio = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("Audio")) :: any
local LobbyUi = require(script.Parent.LobbyUi)

Audio.init()
LobbyUi.init()

print(`[Rooftop] lobby client up for {Players.LocalPlayer.Name}, v{Version}`)
