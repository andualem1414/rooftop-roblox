--!strict
-- Keeping you in sight, on your own screen, whichever camera has the view (the mouse camera or Roblox's
-- own on touch and controllers):
--   furniture, crates and the roof's props between the camera and you turn see-through (a ghost: only on
--   your screen, LocalTransparencyModifier), a whole piece at a time, and come back once you've moved on;
--   so do those the camera ends up inside
--   the building itself (walls, floors, glass) never fades: the camera keeps in front of it (CameraAim, or
--   Roblox's Zoom occlusion). Should it still hide you, you show through it as a silhouette: your ink
--   outline goes on top of everything, with a pale fill
-- Never anyone else: a climber behind a wall stays hidden. Floors cut away above you stay the Cutaway's.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraAim = require(script.Parent.CameraAim)
local Cutaway = require(script.Parent.Cutaway)

local player = Players.LocalPlayer

local Sightline = {}

local GHOST = 0.8 -- how see-through a prop in the way gets (1 = gone)
local FADE_IN, FADE_OUT = 9, 4 -- 1/s: it clears out of the way fast and comes back gently
local NEAR_CAMERA = 1.6 -- studs: a prop this close to the camera fades too (the camera may be inside it)
local INK = Color3.fromRGB(22, 19, 28)
local CHALK = Color3.fromRGB(236, 232, 220)

type Ghost = { parts: { BasePart }, k: number, want: boolean }

local ghosts: { [Instance]: Ghost } = {}
local silhouette = 0 -- 0 (seen) .. 1 (hidden behind a wall: outline on top)

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
local nearParams = OverlapParams.new()
nearParams.FilterType = Enum.RaycastFilterType.Exclude

-- what never blocks the view of you: climbers, and everything drawn for show
local function skipList(): { Instance }
	local skip: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, name in { "Bots", "Pickups", "Fx", "Platforms", "Ambience", "Skydive" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	return skip
end

local function partsOf(target: Instance): { BasePart }
	if target:IsA("BasePart") then
		return { target }
	end
	local out = {}
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function wantGhost(target: Instance)
	local g = ghosts[target]
	if not g then
		g = { parts = partsOf(target), k = 0, want = true }
		ghosts[target] = g
	end
	g.want = true
end

-- Look along one line from the camera to a point on you: ghost the props in the way. Returns true if the
-- building itself hides that point.
local function look(from: Vector3, to: Vector3, skip: { Instance }): boolean
	local d = to - from
	for _ = 1, 6 do
		castParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(from, d, castParams)
		if not hit then
			return false
		end
		local part = hit.Instance
		local target = if part:IsA("BasePart") then Cutaway.ghostOf(part) else nil
		if target then
			wantGhost(target)
			table.insert(skip, target)
		elseif part:IsA("BasePart") and (part.Transparency > 0.5 or part.LocalTransparencyModifier > 0.5) then
			table.insert(skip, part) -- (glass, a floor cut away)
		else
			return true
		end
	end
	return false
end

local function setGhost(g: Ghost, amount: number)
	for _, p in g.parts do
		-- (a prop on a floor that's cut away is the Cutaway's: it stays hidden)
		if p.Parent and not Cutaway.hides(p) then
			p.LocalTransparencyModifier = amount
		end
	end
end

local function clearAll()
	for target, g in ghosts do
		setGhost(g, 0)
		ghosts[target] = nil
	end
end

-- your ink outline (client/race/Fx): on top of everything while you're hidden, with a pale fill
local function showSilhouette(char: Model, k: number)
	local ink = char:FindFirstChild("Ink")
	if not ink or not ink:IsA("Highlight") then
		return
	end
	if k > 0.02 then
		ink.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		ink.FillColor = CHALK
		ink.FillTransparency = 1 - 0.3 * k
		ink.OutlineColor = INK:Lerp(CHALK, k)
		ink.OutlineTransparency = 0.1 + 0.25 * k
	elseif ink.DepthMode ~= Enum.HighlightDepthMode.Occluded then
		ink.DepthMode = Enum.HighlightDepthMode.Occluded
		ink.FillTransparency = 1
		ink.OutlineColor = INK
		ink.OutlineTransparency = 0.1
	end
end

local function step(dt: number)
	for _, g in ghosts do
		g.want = false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hidden = 0
	local active = char ~= nil
		and hum ~= nil
		and hum.Health > 0
		and not CameraAim.cinematic
		and player:GetAttribute("Loaded") == true
	if active and char then
		local camPos = workspace.CurrentCamera.CFrame.Position
		local skip = skipList()
		-- three points on you: head, chest, hips
		for _, name in { "Head", "UpperTorso", "LowerTorso" } do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") and look(camPos, p.Position, table.clone(skip)) then
				hidden += 1
			end
		end
		-- props round the camera itself (a ray starting inside one doesn't see it)
		nearParams.FilterDescendantsInstances = skip
		for _, part in workspace:GetPartBoundsInRadius(camPos, NEAR_CAMERA, nearParams) do
			local target = Cutaway.ghostOf(part)
			if target then
				wantGhost(target)
			end
		end
	end
	-- fade each ghost toward where it wants to be; forget it once it's solid again
	for target, g in ghosts do
		local was = g.k
		if g.want then
			g.k = math.min(1, g.k + dt * FADE_IN)
		else
			g.k = math.max(0, g.k - dt * FADE_OUT)
		end
		if g.k ~= was or g.want then
			setGhost(g, g.k * GHOST)
		end
		if g.k <= 0 and not g.want then
			ghosts[target] = nil
		end
	end
	-- the silhouette: two of the three points hidden by the building (one is just a corner in the way)
	local want = if hidden >= 2 then 1 else 0
	silhouette += (want - silhouette) * math.min(1, dt * (if want > silhouette then 10 else 5))
	if char then
		showSilhouette(char, silhouette)
	end
end

function Sightline.init()
	-- after the camera has moved for this frame (CameraAim, Roblox's camera, the set pieces' focus)
	RunService:BindToRenderStep("RooftopSightline", Enum.RenderPriority.Camera.Value + 3, step)
	-- a new body: nothing ghosted, no silhouette left over
	player.CharacterAdded:Connect(function()
		clearAll()
		silhouette = 0
	end)
end

return Sightline
