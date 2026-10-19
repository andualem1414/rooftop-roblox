--!strict
-- The loading screen (runs first, from ReplicatedFirst). It covers the screen until the world is really
-- there: the game loaded, the tower arrived, the valley's terrain built (here, on this client), their
-- content preloaded, and the camera
-- parked for a moment on the intro's opening views behind the screen so the terrain and the tower are
-- drawn before anyone sees them. Then it marks the player Loaded (the race client tells the server it's
-- ready, and the race waits for that) and fades out as the intro starts (in the lobby: at once).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local INK = Color3.fromRGB(14, 12, 24)
local CHALK = Color3.fromRGB(240, 236, 226)

local TIPS = {
	"Only one can escape: the platform through the roof takes one climber, alone.",
	"The roof opens at 4:00. Be on the top floor when it does.",
	"Low cover you can jump over. Half walls and shelves stop bullets.",
	"Right click aims a gun, or guards with a bat or sword.",
	"Knocked out? You come to a few floors lower. Keep climbing.",
	"Ammo boxes lie on every floor. Platforms carry guns, swords and ammo.",
	"Headshots hit half as hard again.",
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

-- 1. the game itself
progress(0.1, "Loading…")
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- 2. the tower and the valley
progress(0.3, "Building the tower…")
local tower = workspace:WaitForChild("Tower", 60)
local world = workspace:WaitForChild("World", 60)
if world then
	world:WaitForChild("Forest", 30)
end

-- 3. the valley: this client builds the terrain itself (shared/Valley; far quicker than receiving it)
progress(0.4, "Shaping the valley…")
local shared = ReplicatedStorage:WaitForChild("Shared")
local ValleyTerrain = require(shared:WaitForChild("ValleyTerrain")) :: any
ValleyTerrain.build(function(k: number)
	progress(0.4 + 0.2 * k, "Shaping the valley…")
end)

-- 4. their content (fonts, textures)
progress(0.6, "Lighting the floors…")
local toLoad: { Instance } = {}
for _, inst in { tower, world } do
	if inst then
		table.insert(toLoad, inst)
	end
end
pcall(function()
	ContentProvider:PreloadAsync(toLoad)
end)

-- 5. draw it: the camera visits the intro's opening views behind the screen, so the terrain, the forest
-- and the tower are built before anyone sees them
progress(0.75, "Painting the valley…")
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
local H = 192
local views = {
	CFrame.lookAt(Vector3.new(0, 8, 260), Vector3.new(0, 40, 0)),
	CFrame.lookAt(Vector3.new(-260, 90, 0), Vector3.new(0, 90, 0)),
	CFrame.lookAt(Vector3.new(0, H + 40, 170), Vector3.new(0, H - 10, 0)),
	CFrame.lookAt(Vector3.new(44, 4, 62), Vector3.new(0, 60, 0)),
	CFrame.lookAt(Vector3.new(-90, 6, 820), Vector3.new(0, 20, 0)),
}
for i, cf in views do
	camera.CFrame = cf
	task.wait(0.6)
	progress(0.75 + 0.2 * i / #views, "Painting the valley…")
end

-- 6. ready: the race client may tell the server now; in a race the screen stays up until the intro
-- starts, in the lobby it goes at once (and hands the camera back)
local race: Instance?, lobby: Instance? = nil, nil
local looked = 0
while not race and not lobby and looked < 60 do
	race = ReplicatedStorage:FindFirstChild("RaceState")
	lobby = ReplicatedStorage:FindFirstChild("LobbyState")
	if not race and not lobby then
		looked += task.wait(0.1)
	end
end
player:SetAttribute("Loaded", true)
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
