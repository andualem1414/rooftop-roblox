--!strict
-- A first, plain HUD (the chalk look comes in phase 4):
--   top:          the race clock ("Roof opens in 3:12"), your floor and the next platform
--   middle:       the crosshair (gun in hand), banners ("Only one can escape!")
--   top right:    the kill feed
--   bottom left:  health; bottom right: weapon and ammo
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Platforms = require(ReplicatedStorage.Shared.Platforms)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)

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
	local banner =
		label(gui, "Banner", UDim2.fromOffset(800, 50), UDim2.fromScale(0.5, 0.28), Vector2.new(0.5, 0.5), 34)
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
		if kind == "win" then
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

	local bannerToken = 0
	Net.event("Notice").OnClientEvent:Connect(function(text: string, kind: string)
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

	local state = ReplicatedStorage:WaitForChild("RaceState")
	RunService.RenderStepped:Connect(function()
		local phase = state:GetAttribute("Phase")
		local startAt = state:GetAttribute("StartAt") or 0
		local roofOpen = state:GetAttribute("RoofOpen") == true
		local t = workspace:GetServerTimeNow() - startAt
		if phase == "ready" then
			clock.Text = `Get ready  {Rules.clock(-t)}`
		elseif phase == "climb" then
			clock.Text = `Roof opens in {Rules.clock(Config.ROOF_OPENS_AFTER - t)}`
		elseif phase == "roof" then
			clock.Text = `The roof is open  ·  {Rules.clock(Config.RACE_LIMIT - t)} left`
		elseif phase == "over" then
			local w = state:GetAttribute("Winner")
			clock.Text = if w and w ~= "" then `{w} got out first` else "Nobody got out"
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
			hpText.Text = if hum.Health <= 0 then "Knocked out" else `{math.ceil(hum.Health)}`
		end

		local tool = char and char:FindFirstChildOfClass("Tool")
		local wname = tool and tool:GetAttribute("Weapon")
		local w = if type(wname) == "string" then Weapons[wname] else nil
		if w and w.slot == "gun" then
			weapon.Text = w.label
			ammo.Text = if player:GetAttribute("Reloading")
				then "Reloading…"
				else `{player:GetAttribute("Mag") or 0} / {player:GetAttribute("Reserve") or 0}`
			cross.Visible = true
			cross.Size = if CameraAim.aiming then UDim2.fromOffset(18, 18) else UDim2.fromOffset(28, 28)
		else
			weapon.Text = if w then w.label else ""
			ammo.Text = ""
			cross.Visible = false
		end
	end)
end

return Hud
