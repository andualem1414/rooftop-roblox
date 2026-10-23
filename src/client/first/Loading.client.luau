--!strict
-- The loading screen (runs first, from ReplicatedFirst). It covers the screen until the world is really
-- there: the game loaded, the tower arrived, the valley's terrain built (here, on this client, while the
-- game downloads), and the camera parked for a moment on the first views so the terrain and the tower
-- are drawn before anyone sees them. Then it marks the player Loaded (the race client tells the server
-- it's ready, and the race waits for that) and fades out as the intro starts (in the lobby: at once). It
-- also covers teleports between the two places.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()
local startedAt = os.clock()

local player = Players.LocalPlayer
local INK = Color3.fromRGB(14, 12, 24)
local CHALK = Color3.fromRGB(240, 236, 226)

local TIPS = {
	"Only one team can escape: the platform through the roof takes your team, and nobody else.",
	"Your teammates glow in your team's colour, even through walls. You can't hurt each other.",
	"The roof opens at 4:00. Be on the top floor when it does.",
	"Low cover you can jump over. Half walls and shelves stop bullets.",
	"Right click aims a gun, or guards with a bat or sword.",
	"Knocked out? You come to a few floors lower. Keep climbing.",
	"The first platform starts at the bottom: the higher you are, the longer it takes to reach you.",
	"Ammo boxes lie on every floor. Platforms carry guns, swords and ammo.",
	"Headshots hit half as hard again.",
	"Booster pads by the shaft fly you up to floor 18. Only until the roof opens.",
}

-- the screen
local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = INK
back.BorderSizePixel = 0
back.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(46, 30, 78), Color3.fromRGB(10, 10, 20))
grad.Rotation = 90
grad.Parent = back

local function label(text: string, size: number, pos: UDim2, font: Enum.Font, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = pos
	l.Size = UDim2.new(0.9, 0, 0, size * 1.3)
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color or CHALK
	l.RichText = true
	l.TextWrapped = true
	l.Text = text
	l.Parent = back
	return l
end

local title = label('R<font color="#ff4b5a">O</font>OFTOP', 96, UDim2.fromScale(0.5, 0.38), Enum.Font.LuckiestGuy)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(10, 8, 18)
stroke.Parent = title
label(
	"Climb. Fight. Get out first.",
	22,
	UDim2.fromScale(0.5, 0.48),
	Enum.Font.GothamBold,
	Color3.fromRGB(200, 190, 230)
)

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.62)
barBack.Size = UDim2.fromOffset(360, 8)
barBack.BackgroundColor3 = Color3.fromRGB(40, 34, 60)
barBack.BorderSizePixel = 0
barBack.Parent = back
Instance.new("UICorner").Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(255, 90, 170)
bar.BorderSizePixel = 0
bar.Parent = barBack
Instance.new("UICorner").Parent = bar
local status = label("Loading…", 18, UDim2.fromScale(0.5, 0.67), Enum.Font.Gotham, Color3.fromRGB(170, 164, 200))
local tip = label(
	TIPS[math.random(1, #TIPS)],
	18,
	UDim2.fromScale(0.5, 0.86),
	Enum.Font.GothamMedium,
	Color3.fromRGB(200, 196, 220)
)

-- the same screen covers the teleport between the lobby and a race (else Roblox's own plain one shows,
-- then this one): a copy is handed over now, while nothing is on its way
pcall(function()
	TeleportService:SetTeleportGui(gui:Clone())
end)

gui.Parent = player:WaitForChild("PlayerGui")

local function progress(k: number, text: string)
	status.Text = text
	TweenService:Create(bar, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(k, 0, 1), 1) }):Play()
end

-- tips change every few seconds while it waits
task.spawn(function()
	while gui.Parent do
		task.wait(4)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- 1. the valley's terrain, built by this client itself (shared/Valley; far quicker than receiving it),
-- started the moment the shared code is here: it's built while the rest of the game is still on its way
-- (the two used to take turns). The camera waits far up in the sky meanwhile: no half-built valley in
-- front of it to draw (11.0 s for the build where it stood, 9.6 s up there, measured as in ValleyTerrain).
progress(0.05, "Loading…")
local shared = ReplicatedStorage:WaitForChild("Shared")
while not workspace.CurrentCamera do
	task.wait()
end
local camera = workspace.CurrentCamera :: Camera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(0, 20000, 0), Vector3.new(0, 30000, 1))
local shaped = false
local loadedYet = false
task.spawn(function()
	local ok, err = pcall(function()
		local ValleyTerrain = require(shared:WaitForChild("ValleyTerrain")) :: any
		while not workspace.Terrain do -- (it comes with the first of the world)
			task.wait()
		end
		ValleyTerrain.build(function(k: number)
			progress(0.1 + 0.6 * k, if loadedYet then "Shaping the valley…" else "Loading…")
		end)
	end)
	if not ok then
		warn("[Rooftop] the valley's terrain:", err)
	end
	shaped = true
end)

-- The game's sounds load in the background from the start, without holding the screen up: the first
-- shot and the countdown's ticks are then heard on time. (As Sound instances: a bare id would be fetched
-- as an image; music streams as it plays.) The tower and the valley have nothing to fetch: plain
-- materials, built-in fonts; preloading them held the screen up 3.6 s for nothing (measured in Studio).
task.spawn(function()
	local ok, sounds = pcall(require, shared:WaitForChild("Sounds"))
	if not ok or type(sounds) ~= "table" then
		return
	end
	local byId: { [string]: Sound } = {}
	local function add(id: any)
		if type(id) == "string" and not byId[id] then
			local s = Instance.new("Sound")
			s.SoundId = id
			byId[id] = s
		end
	end
	for _, cue in sounds do
		if type(cue) == "table" and cue.kind ~= "music" then
			add(cue.id)
			for _, take in (cue.takes or {}) :: { any } do
				add(take.id)
			end
		end
	end
	local list: { Instance } = {}
	for _, s in byId do
		table.insert(list, s)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end)

-- 2. the game itself, the tower and the valley's forest
if not game:IsLoaded() then
	game.Loaded:Wait()
end
loadedYet = true
workspace:WaitForChild("Tower", 60)
local world = workspace:WaitForChild("World", 60)
if world then
	world:WaitForChild("Forest", 30)
end
while not shaped do
	task.wait()
end
progress(0.7, "Lighting the floors…")

-- which place this is (its state comes with the game; a race server just started may take a moment)
local race: Instance?, lobby: Instance? = nil, nil
local looked = 0
while not race and not lobby and looked < 60 do
	race = ReplicatedStorage:FindFirstChild("RaceState")
	lobby = ReplicatedStorage:FindFirstChild("LobbyState")
	if not race and not lobby then
		looked += task.wait(0.1)
	end
end

-- 3. draw it: the camera visits the first views behind the screen, so the terrain, the forest and the
-- tower are built before anyone sees them: in a race the intro's opening shots; in the lobby the main
-- screen's orbit and the forecourt, with the lighting's focus where LobbyUi keeps it (Camera.Focus)
progress(0.75, "Painting the valley…")
local Config = require(shared:WaitForChild("Config")) :: any
local H = Config.FLOORS * Config.FLOOR_HEIGHT -- (the tower's height: where the intro's last shot looks)
local views = if lobby
	then {
		CFrame.lookAt(Vector3.new(math.sin(0.6) * 240, 70, math.cos(0.6) * 240), Vector3.new(0, 110, 0)),
		CFrame.lookAt(Vector3.new(0, 14, 196), Vector3.new(0, 30, 0)),
	}
	else {
		CFrame.lookAt(Vector3.new(0, 8, 260), Vector3.new(0, 40, 0)),
		CFrame.lookAt(Vector3.new(-260, 90, 0), Vector3.new(0, 90, 0)),
		CFrame.lookAt(Vector3.new(0, H + 40, 170), Vector3.new(0, H - 10, 0)),
		CFrame.lookAt(Vector3.new(44, 4, 62), Vector3.new(0, 60, 0)),
		CFrame.lookAt(Vector3.new(-90, 6, 820), Vector3.new(0, 20, 0)),
	}
for i, cf in views do
	camera.CFrame = cf
	if lobby then
		camera.Focus = CFrame.new(0, 5, 150)
	end
	task.wait(0.6)
	progress(0.75 + 0.2 * i / #views, "Painting the valley…")
end

-- 4. ready: the race client may tell the server now; in a race the screen stays up until the intro
-- starts, in the lobby it goes at once (and hands the camera back)
player:SetAttribute("Loaded", true)
if game:GetService("RunService"):IsStudio() then
	print(`[Rooftop] loaded in {string.format("%.1f", os.clock() - startedAt)} s`)
end
if lobby then
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
else
	progress(1, "Waiting for the race…")
	local waited = 0
	while race and waited < 45 do
		local phase = race:GetAttribute("Phase")
		if phase == "ready" or phase == "climb" or phase == "roof" or phase == "over" then
			break
		end
		waited += task.wait(0.1)
	end
end

-- fade out
local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(back, info, { BackgroundTransparency = 1 }):Play()
for _, d in back:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.75)
gui:Destroy()
