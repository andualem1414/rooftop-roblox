--!strict
-- The settings panel (the lobby's Settings button, the race's gear or P / the controller's View button):
-- music and effects volume, mouse sensitivity, camera shake, damage numbers. Changes apply at once and are
-- kept with your profile (ClientSettings).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Ui = require(script.Parent.Ui)
local ClientSettings = require(script.Parent.ClientSettings)

local SettingsPanel = {}

local function percent(v: number): string
	return `{math.floor(v * 100 + 0.5)}%`
end

function SettingsPanel.create(gui: ScreenGui): Ui.Panel
	local panel = Ui.panel(gui, "Settings", 520, 420)
	local body = panel.body
	Ui.column(body, 6)
	local function build()
		for _, c in body:GetChildren() do
			if c:IsA("Frame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local s = ClientSettings.get()
		local rows: { Instance } = {
			Ui.slider(body, "Music", 0, 1, 0.05, s.music, function(v)
				ClientSettings.set("music", v)
			end, percent),
			Ui.slider(body, "Effects", 0, 1, 0.05, s.effects, function(v)
				ClientSettings.set("effects", v)
			end, percent),
			Ui.slider(
				body,
				"Mouse sensitivity",
				Settings.SENSITIVITY[1],
				Settings.SENSITIVITY[2],
				0.05,
				s.sensitivity,
				function(v)
					ClientSettings.set("sensitivity", v)
				end,
				function(v)
					return string.format("%.2f×", v)
				end
			),
			Ui.toggle(body, "Camera shake", s.shake, function(v)
				ClientSettings.set("shake", v)
			end),
			Ui.toggle(body, "Damage numbers", s.numbers, function(v)
				ClientSettings.set("numbers", v)
			end),
		}
		local note = Ui.label(
			body,
			"Kept with your profile: they follow you into every race. Roblox's own camera sensitivity (in the Roblox menu) applies too.",
			14,
			Ui.BODY,
			Ui.DIM
		)
		table.insert(rows, note)
		for i, r in rows do
			(r :: any).LayoutOrder = i
		end
	end
	build()
	-- (the profile can arrive after the panel is built)
	panel.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.frame.Visible then
			build()
		end
	end)
	return panel
end

return SettingsPanel
