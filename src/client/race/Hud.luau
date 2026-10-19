--!strict
-- A first, plain HUD (the chalk look comes in phase 4):
--   top:          the race clock ("Roof opens in 3:12"), your floor and the next platform
--   middle:       the crosshair (gun in hand), banners ("Only one can escape!")
--   top right:    the kill feed
--   bottom left:  health; bottom right: weapon and ammo
--   bottom left:  Settings (or P / the controller's View button), above health: the settings panel
-- With the countdown's last seconds ticking, and a chime under each banner.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Platforms = require(ReplicatedStorage.Shared.Platforms)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any
local Audio = require(Common:WaitForChild("Audio")) :: any
local SettingsPanel = require(Common:WaitForChild("SettingsPanel")) :: any

local player = Players.LocalPlayer

local Hud = {}

local INK = Color3.fromRGB(22, 19, 28)
local CHALK = Color3.fromRGB(236, 232, 220)
local RED = Color3.fromRGB(196, 72, 60)

local function label(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	anchor: Vector2,
	textSize: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.AnchorPoint = anchor
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = CHALK
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0.35
	l.Text = ""
	l.Parent = parent
	return l
end

function Hud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RaceHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local clock = label(gui, "Clock", UDim2.fromOffset(500, 34), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0), 26)
	local where = label(gui, "Where", UDim2.fromOffset(500, 24), UDim2.new(0.5, 0, 0, 40), Vector2.new(0.5, 0), 18)
	-- banners have their own layer: they still show while a set piece hides the rest of the HUD
	local top = Instance.new("ScreenGui")
	top.Name = "RaceBanner"
	top.ResetOnSpawn = false
	top.Parent = gui.Parent
	local banner =
		label(top, "Banner", UDim2.fromOffset(800, 50), UDim2.fromScale(0.5, 0.22), Vector2.new(0.5, 0.5), 34)
	banner.TextTransparency = 1
	banner.TextStrokeTransparency = 1

	-- health
	local hpBack = Instance.new("Frame")
	hpBack.Name = "Health"
	hpBack.Size = UDim2.fromOffset(240, 16)
	hpBack.Position = UDim2.new(0, 20, 1, -36)
	hpBack.BackgroundColor3 = INK
	hpBack.BackgroundTransparency = 0.35
	hpBack.BorderSizePixel = 0
	hpBack.Parent = gui
	local hpBar = Instance.new("Frame")
	hpBar.Size = UDim2.fromScale(1, 1)
	hpBar.BackgroundColor3 = CHALK
	hpBar.BorderSizePixel = 0
	hpBar.Parent = hpBack
	local hpText = label(hpBack, "Text", UDim2.fromOffset(240, 20), UDim2.fromOffset(0, -22), Vector2.zero, 16)
	hpText.TextXAlignment = Enum.TextXAlignment.Left

	-- weapon and ammo
	local ammo = label(gui, "Ammo", UDim2.fromOffset(300, 34), UDim2.new(1, -20, 1, -40), Vector2.new(1, 0), 28)
	ammo.TextXAlignment = Enum.TextXAlignment.Right
	local weapon = label(gui, "Weapon", UDim2.fromOffset(300, 20), UDim2.new(1, -20, 1, -62), Vector2.new(1, 0), 16)
	weapon.TextXAlignment = Enum.TextXAlignment.Right

	-- crosshair: four short ticks
	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.BackgroundTransparency = 1
	cross.Size = UDim2.fromOffset(24, 24)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Parent = gui
	for _, t in { { 0, -9, 2, 6 }, { 0, 9, 2, 6 }, { -9, 0, 6, 2 }, { 9, 0, 6, 2 } } do
		local tick = Instance.new("Frame")
		tick.BackgroundColor3 = CHALK
		tick.BorderSizePixel = 0
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, t[1], 0.5, t[2])
		tick.Size = UDim2.fromOffset(t[3], t[4])
		tick.Parent = cross
	end

	-- the kill feed
	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.Size = UDim2.fromOffset(360, 160)
	feed.Position = UDim2.new(1, -16, 0, 70)
	feed.AnchorPoint = Vector2.new(1, 0)
	feed.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = feed
	local order = 0

	Net.event("Feed").OnClientEvent:Connect(function(text: string, kind: string)
		order += 1
		local l = label(feed, "Line", UDim2.fromOffset(360, 22), UDim2.new(), Vector2.zero, 16)
		l.LayoutOrder = order
		l.TextXAlignment = Enum.TextXAlignment.Right
		l.Text = text
		if kind == "win" or kind == "boost" then
			l.TextColor3 = Color3.fromRGB(255, 214, 120)
		end
		local lines = {}
		for _, c in feed:GetChildren() do
			if c:IsA("TextLabel") then
				table.insert(lines, c)
			end
		end
		if #lines > 5 then
			table.sort(lines, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			lines[1]:Destroy()
		end
		task.delay(7, function()
			if l.Parent then
				TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.wait(0.7)
				l:Destroy()
			end
		end)
	end)

	-- the settings: a button (with the cursor out: hold Left Alt), P, or the controller's View button
	local menu = Ui.screen("RaceMenu", 20)
	local settings = SettingsPanel.create(menu)
	local gear = Ui.button(gui, "Settings", function()
		Audio.play("click")
		settings.toggle()
	end)
	gear.Size = UDim2.fromOffset(96, 32)
	gear.Position = UDim2.new(0, 20, 1, -100) -- (above the health bar: the chat has the top left)
	gear.TextSize = 15
	ContextActionService:BindAction("RooftopSettings", function(_, s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			settings.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.P, Enum.KeyCode.ButtonSelect)

	local bannerToken = 0
	Net.event("Notice").OnClientEvent:Connect(function(text: string, kind: string)
		Audio.play("notice")
		bannerToken += 1
		local mine = bannerToken
		banner.Text = text
		banner.TextColor3 = if kind == "throw" or kind == "bad"
			then RED
			elseif kind == "win" then Color3.fromRGB(255, 214, 120)
			else CHALK
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0.35
		task.delay(if kind == "win" then 8 else 3, function()
			if mine == bannerToken then
				TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
					:Play()
			end
		end)
	end)

	-- hit marker: four ticks flick out round the crosshair when your blow lands (yellow: a headshot)
	local marker = Instance.new("Frame")
	marker.Name = "HitMarker"
	marker.BackgroundTransparency = 1
	marker.Size = UDim2.fromOffset(34, 34)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Parent = gui
	local markerScale = Instance.new("UIScale")
	markerScale.Parent = marker
	local ticks = {}
	for _, d in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local t = Instance.new("Frame")
		t.BorderSizePixel = 0
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Size = UDim2.fromOffset(10, 3)
		t.Position = UDim2.new(0.5, d[1] * 11, 0.5, d[2] * 11)
		t.Rotation = d[1] * d[2] * 45
		t.BackgroundTransparency = 1
		t.Parent = marker
		table.insert(ticks, t)
	end
	-- being hit: the screen's edges flash red (and pulse while you're low)
	local vignette = Instance.new("Frame")
	vignette.Name = "Hurt"
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 0
	vignette.Parent = gui
	local edges = {}
	for _, e in { { 0, 0, 1, 0.22, 90 }, { 0, 0.78, 1, 0.22, -90 }, { 0, 0, 0.16, 1, 0 }, { 0.84, 0, 0.16, 1, 180 } } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
		f.Position = UDim2.fromScale(e[1], e[2])
		f.Size = UDim2.fromScale(e[3], e[4])
		f.BackgroundTransparency = 1
		local g = Instance.new("UIGradient")
		g.Rotation = e[5]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = vignette
		table.insert(edges, f)
	end
	local hurtK = 0
	Net.event("HitFx").OnClientEvent
		:Connect(function(_at: Vector3, dmg: number, kind: string, victim: Instance?, attacker: Instance?)
			local me = player.Character
			if me and attacker == me and victim ~= me then
				local color = if kind == "head" then Color3.fromRGB(255, 214, 60) else Color3.fromRGB(255, 255, 255)
				for _, t in ticks do
					t.BackgroundColor3 = color
					t.BackgroundTransparency = 0
					TweenService:Create(t, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
				end
				markerScale.Scale = 0.6
				TweenService:Create(markerScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			elseif me and victim == me and kind ~= "block" then
				hurtK = math.min(1, hurtK + 0.35 + dmg / 60)
			end
		end)

	local state = ReplicatedStorage:WaitForChild("RaceState")
	local hudShown = true
	local lastCount = math.huge
	RunService.RenderStepped:Connect(function()
		-- the intro, the roof opening and the winner's orbit get a clean screen (no HUD, no hotbar)
		local show = not CameraAim.cinematic and player:GetAttribute("Loaded") == true
		if show ~= hudShown then
			hudShown = show
			gui.Enabled = show
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, show)
		end
		local phase = state:GetAttribute("Phase")
		local startAt = state:GetAttribute("StartAt") or 0
		local roofOpen = state:GetAttribute("RoofOpen") == true
		local t = workspace:GetServerTimeNow() - startAt
		-- the last three seconds tick, the start goes "go"
		local count = if phase == "ready" then math.ceil(-t) else 0
		if count ~= lastCount then
			if count >= 1 and count <= 3 then
				Audio.play("tick")
			elseif count == 0 and lastCount == 1 then
				Audio.play("go")
			end
			lastCount = count
		end
		if phase == "ready" then
			clock.Text = `Get ready  {Rules.clock(-t)}`
		elseif phase == "climb" then
			clock.Text = `Roof opens in {Rules.clock(Config.ROOF_OPENS_AFTER - t)}`
		elseif phase == "roof" then
			clock.Text = `The roof is open  ·  {Rules.clock(Config.RACE_LIMIT - t)} left`
		elseif phase == "over" then
			local w = state:GetAttribute("Winner")
			clock.Text = if w and w ~= "" then `{w} got out first` else "Nobody got out"
		elseif phase == "leaving" then
			clock.Text = "Back to the lobby…"
		else
			clock.Text = "Waiting for the race"
		end

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root then
			local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
			local floor = math.clamp(math.floor(feet / Config.FLOOR_HEIGHT + 0.3), 0, Config.FLOORS)
			local line = if floor >= Config.FLOORS then "The roof" else `Floor {floor + 1} / {Config.FLOORS}`
			if (phase == "climb" or phase == "roof") and floor < Config.FLOORS then
				local wait = Platforms.nextArrival(math.max(0, t), floor, roofOpen)
				line ..= if wait <= 0 then "  ·  Platform here" else `  ·  Platform in {math.ceil(wait)}s`
			end
			where.Text = line
			local k = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
			hpBar.Size = UDim2.fromScale(k, 1)
			hpBar.BackgroundColor3 = if k < 0.3 then RED else CHALK
			-- the red edges: a flash when hit, a slow pulse while low
			local low = if k < 0.3 and hum.Health > 0 then 0.25 + 0.15 * math.sin(os.clock() * 5) else 0
			hurtK = math.max(0, hurtK - 1.6 / 60)
			local edge = math.max(hurtK, low)
			for _, f in edges do
				f.BackgroundTransparency = 1 - edge * 0.75
			end
			hpText.Text = if hum.Health <= 0 then "Knocked out" else `{math.ceil(hum.Health)}`
		end

		local tool = char and char:FindFirstChildOfClass("Tool")
		local wname = tool and tool:GetAttribute("Weapon")
		local w = if type(wname) == "string" then Weapons[wname] else nil
		-- the crosshair: wide with a gun, tight while aiming, small with a melee weapon (you swing where it is)
		cross.Visible = w ~= nil and (w.slot == "gun" or CameraAim.mouseLook())
		if w and w.slot == "gun" then
			weapon.Text = w.label
			ammo.Text = if player:GetAttribute("Reloading")
				then "Reloading…"
				else `{player:GetAttribute("Mag") or 0} / {player:GetAttribute("Reserve") or 0}`
			cross.Size = if CameraAim.aiming then UDim2.fromOffset(18, 18) else UDim2.fromOffset(28, 28)
		else
			weapon.Text = if w then w.label else ""
			ammo.Text = ""
			cross.Size = UDim2.fromOffset(12, 12)
		end
	end)
end

return Hud
