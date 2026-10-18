--!strict
-- Shots and hits, drawn on every client: a muzzle flash, a streak from the barrel to where the bullet
-- stopped, a mark where it struck, and damage numbers. Plain shapes for now; the drawn ink style comes
-- in phase 4.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local Fx = {}

local folder: Folder

local function bit(size: Vector3, cf: CFrame, color: Color3, life: number, fadeTo: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(life), { Transparency = 1, Size = size * (fadeTo or 1) }):Play()
	Debris:AddItem(p, life + 0.05)
	return p
end

local function shot(_model: Instance, from: Vector3, to: Vector3, kind: string)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local d = to - from
	if d.Magnitude < 0.05 then
		return
	end
	-- the streak
	bit(Vector3.new(0.08, 0.08, d.Magnitude), CFrame.lookAt(from + d / 2, to), Color3.fromRGB(255, 226, 168), 0.09)
	-- the muzzle flash
	bit(
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(from) * CFrame.Angles(0, 0, math.random() * 6.3),
		Color3.fromRGB(255, 200, 120),
		0.06,
		1.6
	)
	-- where it struck: a dark mark on a wall, a pale burst on a body
	if kind == "wall" then
		local mark = bit(Vector3.new(0.35, 0.35, 0.05), CFrame.lookAt(to, from), Color3.fromRGB(28, 24, 30), 3)
		mark.Material = Enum.Material.SmoothPlastic
		bit(Vector3.new(0.4, 0.4, 0.4), CFrame.new(to), Color3.fromRGB(255, 240, 210), 0.12, 2)
	elseif kind == "body" then
		bit(Vector3.new(0.6, 0.6, 0.6), CFrame.new(to), Color3.fromRGB(240, 236, 250), 0.15, 2.2)
	end
end

local function hit(at: Vector3, dmg: number, kind: string)
	if typeof(at) ~= "Vector3" then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 30)
	gui.StudsOffset = Vector3.new(0, 1, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(dmg)
	label.TextColor3 = if kind == "head"
		then Color3.fromRGB(255, 210, 90)
		elseif kind == "block" then Color3.fromRGB(170, 175, 190)
		else Color3.fromRGB(245, 240, 230)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = anchor
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.85)
end

function Fx.init()
	folder = Instance.new("Folder")
	folder.Name = "Fx"
	folder.Parent = workspace
	Net.event("ShotFx").OnClientEvent:Connect(shot)
	Net.event("HitFx").OnClientEvent:Connect(hit)
end

return Fx
