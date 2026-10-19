--!strict
-- The race HUD, chalk on ink like the lobby and the menus (client/common/Ui):
--   top:          a plate with the race clock ("Roof opens in 3:12"), your floor and the next platform
--   middle:       the crosshair (gun in hand), banners ("Only one can escape!")
--   top right:    the kill feed
--   bottom left:  health; bottom right: a plate with the weapon and ammo (top right on a touch screen,
--                 where the thumb buttons aren't)
--   bottom left:  Settings (or P / the controller's View button), above health: the settings panel
-- With the countdown's last seconds ticking, and a chime under each banner.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
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

	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local function plate(name: string, size: UDim2, pos: UDim2, anchor: Vector2): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = size
		f.Position = pos
		f.AnchorPoint = anchor
		f.BackgroundColor3 = INK
		f.BackgroundTransparency = 0.3
		f.BorderSizePixel = 0
		Ui.corner(f, 12)
		f.Parent = gui
		return f
	end
	local top = plate("Plate", UDim2.fromOffset(440, 64), UDim2.new(0.5, 0, 0, 6), Vector2.new(0.5, 0))
	local clock = label(top, "Clock", UDim2.new(1, 0, 0, 34), UDim2.new(0.5, 0, 0, 3), Vector2.new(0.5, 0), 26)
	clock.Font = Ui.TITLE
	local where = label(top, "Where", UDim2.new(1, 0, 0, 22), UDim2.new(0.5, 0, 0, 37), Vector2.new(0.5, 0), 16)
	where.Font = Ui.BODY
	where.TextColor3 = Ui.DIM
	where.TextStrokeTransparency = 1
	-- banners have their own layer: they still show while a set piece hides the rest of the HUD
	local layer = Instance.new("ScreenGui")
	layer.Name = "RaceBanner"
	layer.ResetOnSpawn = false
	layer.Parent = gui.Parent
	local banner =
		label(layer, "Banner", UDim2.fromOffset(900, 56), UDim2.fromScale(0.5, 0.22), Vector2.new(0.5, 0.5), 40)
	banner.Font = Ui.TITLE
	banner.TextStrokeColor3 = Color3.fromRGB(10, 8, 18)
	banner.TextTransparency = 1
	banner.TextStrokeTransparency = 1

	-- health
	local hpBack = Instance.new("Frame")
	hpBack.Name = "Health"
	hpBack.Size = UDim2.fromOffset(240, 14)
	hpBack.Position = UDim2.new(0, 20, 1, -30)
	hpBack.BackgroundColor3 = INK
	hpBack.BackgroundTransparency = 0.25
	hpBack.BorderSizePixel = 0
	Ui.corner(hpBack, 7)
	Ui.stroke(hpBack, INK, 2)
	hpBack.Parent = gui
	local hpBar = Instance.new("Frame")
	hpBar.Size = UDim2.fromScale(1, 1)
	hpBar.BackgroundColor3 = CHALK
	hpBar.BorderSizePixel = 0
	Ui.corner(hpBar, 7)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 186, 176))
	shine.Parent = hpBar
	hpBar.Parent = hpBack
	local hpText = label(hpBack, "Text", UDim2.fromOffset(240, 24), UDim2.fromOffset(2, -28), Vector2.zero, 22)
	hpText.Font = Ui.TITLE
	hpText.TextXAlignment = Enum.TextXAlignment.Left

	-- weapon and ammo
	local arms = plate(
		"Arms",
		UDim2.fromOffset(210, 66),
		if touch then UDim2.new(1, -16, 0, 6) else UDim2.new(1, -16, 1, -14),
		if touch then Vector2.new(1, 0) else Vector2.new(1, 1)
	)
	local weapon = label(arms, "Weapon", UDim2.new(1, -24, 0, 20), UDim2.new(1, -12, 0, 6), Vector2.new(1, 0), 15)
	weapon.TextXAlignment = Enum.TextXAlignment.Right
	weapon.TextColor3 = Ui.DIM
	weapon.TextStrokeTransparency = 1
	local ammo = label(arms, "Ammo", UDim2.new(1, -24, 0, 36), UDim2.new(1, -12, 0, 24), Vector2.new(1, 0), 30)
	ammo.Font = Ui.TITLE
	ammo.TextXAlignment = Enum.TextXAlignment.Right

	-- crosshair: four short ticks round a dot. The gap shows how true a shot goes: the gun's own spread,
	-- tighter while aiming, blooming out with the kick while you fire and settling back; small and tight
	-- with a melee weapon (you swing where it is)
	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.BackgroundTransparency = 1
	cross.Size = UDim2.fromOffset(64, 64)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Parent = gui
	local crossTicks: { { frame: Frame, dir: Vector2 } } = {}
	for _, d in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		local tick = Instance.new("Frame")
		tick.BackgroundColor3 = CHALK
		tick.BorderSizePixel = 0
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Size = if d.X == 0 then UDim2.fromOffset(2, 6) else UDim2.fromOffset(6, 2)
		Ui.stroke(tick, INK, 1)
		tick.Parent = cross
		table.insert(crossTicks, { frame = tick, dir = d })
	end
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = CHALK
	dot.BorderSizePixel = 0
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(2, 2)
	dot.Parent = cross
	local crossGap = 9

	-- the kill feed
	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.Size = UDim2.fromOffset(380, 200)
	feed.Position = UDim2.new(1, -16, 0, if touch then 80 else 70)
	feed.AnchorPoint = Vector2.new(1, 0)
	feed.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = feed
	local order = 0

	Net.event("Feed").OnClientEvent:Connect(function(text: string, kind: string)
		order += 1
		-- a chalk line on its own ink tab
		local l = label(feed, "Line", UDim2.fromOffset(0, 26), UDim2.new(), Vector2.zero, 15)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.BackgroundColor3 = INK
		l.BackgroundTransparency = 0.3
		l.TextStrokeTransparency = 1
		Ui.corner(l, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = l
		l.LayoutOrder = order
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
				TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
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
	RunService.RenderStepped:Connect(function(dt: number)
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
			hurtK = math.max(0, hurtK - 1.6 * dt)
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
		local wantGap
		if w and w.slot == "gun" then
			weapon.Text = w.label
			local reloading = player:GetAttribute("Reloading") == true
			ammo.Text = if reloading
				then "Reloading…"
				else `{player:GetAttribute("Mag") or 0} / {player:GetAttribute("Reserve") or 0}`
			local spread = w.spread * 130 * (if CameraAim.aiming then 0.35 else 1)
			local bloom = math.min(16, CameraAim.kickAmount() * 380)
			local moving = if root
				then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				else 0
			wantGap = 4 + spread + bloom + math.clamp(moving / 16, 0, 1) * 3 + (if reloading then 6 else 0)
		else
			-- a melee weapon: its name, big, where the ammo goes
			weapon.Text = if w then "Melee" else ""
			ammo.Text = if w then w.label else ""
			wantGap = 4
		end
		-- (it opens at once and closes smoothly)
		crossGap = if wantGap > crossGap then wantGap else crossGap + (wantGap - crossGap) * math.min(1, dt * 14)
		for _, ct in crossTicks do
			ct.frame.Position = UDim2.new(0.5, ct.dir.X * crossGap, 0.5, ct.dir.Y * crossGap)
		end
		arms.Visible = w ~= nil
	end)
end

return Hud
