--!strict
-- Your settings on this client (shared/Settings): read from your profile (the server publishes it as the
-- Profile attribute), changed by the settings panel, sent back to be saved (a moment after the last
-- change). Anyone interested listens to ClientSettings.changed.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer

local ClientSettings = {}

local current: Settings.Settings = Settings.defaults()
local touched = false -- changed here since the profile arrived (the profile mustn't undo it)
local saveToken = 0
local changedEvent = Instance.new("BindableEvent")
ClientSettings.changed = changedEvent.Event

function ClientSettings.get(): Settings.Settings
	return current
end

function ClientSettings.set(key: string, value: any)
	local raw = table.clone(current) :: any
	raw[key] = value
	current = Settings.sanitize(raw)
	touched = true
	changedEvent:Fire(current)
	saveToken += 1
	local mine = saveToken
	task.delay(1, function()
		if mine == saveToken then
			Net.event("SaveSettings"):FireServer(current)
		end
	end)
end

local function fromProfile()
	local raw = player:GetAttribute("Profile")
	if type(raw) ~= "string" or touched then
		return
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(data) == "table" then
		current = Settings.sanitize(data.settings)
		changedEvent:Fire(current)
	end
end

fromProfile()
player:GetAttributeChangedSignal("Profile"):Connect(fromProfile)

return ClientSettings
