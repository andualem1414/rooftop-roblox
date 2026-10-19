--!strict
-- The camera: a third-person shooter camera over your right shoulder.
--   With a mouse it's our own camera: the mouse always turns the view (the cursor is hidden and the
--   crosshair stays in the middle), you face where the camera looks, the wheel zooms, and the camera
--   slides in front of walls rather than through them (ignoring the floors cut away above you). Right
--   mouse / L2 aims: the view tightens over the shoulder and the shot steadies. The cursor comes back
--   while a menu, the chat or a text box is open, or while Left Alt is held.
--   On a touch screen or with a controller it's Roblox's own camera (drag / right stick to look); with a
--   gun in hand you face where it looks, and shots go through the crosshair in the middle.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")

local CameraAim = {}
CameraAim.aiming = false
CameraAim.cinematic = false -- a set piece (Cinematic.luau) has the camera

local SHOULDER = Vector3.new(1.9, 0.4, 0) -- right, up (studs, in the camera's frame)
local AIM_SHOULDER = Vector3.new(2.2, 0.6, 0)
local EYE = 1.6 -- the point the camera circles, above the root
local ZOOM_MIN, ZOOM_MAX, ZOOM_START, AIM_ZOOM = 6, 24, 12, 7
local PITCH_MIN, PITCH_MAX = math.rad(-75), math.rad(65)
local TURN = 0.0032 -- radians per pixel of mouse movement (times Roblox's sensitivity setting)

local yaw, pitch = 0, math.rad(-18)
local zoom, zoomGoal = ZOOM_START, ZOOM_START
local shoulder = Vector3.zero
local locked = false
local mouseMode = false
local lastChar: Model? = nil
local wasLocked = false
local kickPitch = 0 -- recoil: the view jumps up and settles most of the way back
local shakeAmt = 0 -- being hit (or hitting): a short tremble
local rng = Random.new()

-- a gun's kick: the view jumps up by `rad`, and part of it stays (you pull the aim back down)
function CameraAim.kick(rad: number)
	kickPitch += rad
	pitch = math.clamp(pitch + rad * 0.35, PITCH_MIN, PITCH_MAX)
end

-- a short tremble (0..1-ish)
function CameraAim.shake(amount: number)
	shakeAmt = math.max(shakeAmt, amount)
end

local function shakeRot(dt: number): CFrame
	kickPitch *= math.exp(-dt * 14)
	shakeAmt *= math.exp(-dt * 9)
	local s = shakeAmt * 0.03
	return CFrame.Angles(kickPitch + rng:NextNumber(-s, s), rng:NextNumber(-s, s), rng:NextNumber(-s, s) * 0.5)
end

-- true while the mouse steers the camera
function CameraAim.mouseLook(): boolean
	return locked
end

function CameraAim.set(on: boolean)
	CameraAim.aiming = on
end

-- the ray through the crosshair, in the middle of the screen (mouse, touch and controller alike)
function CameraAim.ray(): Ray
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

-- true with a gun in hand: on a touch screen or a controller you then face where the camera looks
local function gunInHand(char: Model): boolean
	local tool = char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("Slot") == "gun"
end

-- the camera's heading (yaw) on the ground
function CameraAim.yaw(): number
	local look = workspace.CurrentCamera.CFrame.LookVector
	return math.atan2(look.X, look.Z)
end

local function cursorWanted(): boolean
	return GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() ~= nil
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
end

local function usingMouse(): boolean
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return false
	end
	return UserInputService.MouseEnabled
end

-- where the camera can be: pulled in front of anything solid between you and it. Parts you can see
-- through (the cut-away floors, glass) and parts nobody bumps into don't count.
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.RespectCanCollide = true
local function clearTo(from: Vector3, to: Vector3, skip: { Instance }): Vector3
	local d = to - from
	for _ = 1, 6 do
		castParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(from, d, castParams)
		if not hit then
			return to
		end
		local part = hit.Instance
		if part:IsA("BasePart") and (part.Transparency > 0.5 or part.LocalTransparencyModifier > 0.5) then
			table.insert(skip, part)
		else
			return hit.Position - d.Unit * 0.6
		end
	end
	return to
end

local function others(): { Instance }
	local skip: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, name in { "Bots", "Pickups", "Fx", "Platforms" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	return skip
end

-- a new body: start looking the way it faces
local function adopt(char: Model, root: BasePart)
	if char ~= lastChar then
		lastChar = char
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = math.rad(-18)
	end
end

-- where the camera sits behind your shoulder right now (kept clear of walls), or nil without a body
local function resting(root: BasePart): CFrame
	local rot = CFrame.fromOrientation(pitch, yaw, 0)
	local eye = root.Position + Vector3.new(0, EYE, 0)
	local skip = others()
	local side = clearTo(eye, eye + rot:VectorToWorldSpace(shoulder), skip)
	local pos = clearTo(side, side + rot:VectorToWorldSpace(Vector3.new(0, 0, zoom)), skip)
	return CFrame.new(pos) * rot
end

function CameraAim.restingCFrame(): CFrame?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return nil
	end
	adopt(char, root)
	if shoulder.Magnitude < 0.1 then
		shoulder = SHOULDER
	end
	return resting(root)
end

local function update(dt: number)
	if player:GetAttribute("Loaded") ~= true then
		wasLocked = false
		return -- (the loading screen has the camera)
	end
	if CameraAim.cinematic then
		wasLocked = false
		UserInputService.MouseIconEnabled = false
		return
	end
	local camera = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	mouseMode = usingMouse()
	if not mouseMode or not hum or not root then
		locked = false
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
		if hum and root and char and hum.Health > 0 and gunInHand(char) then
			-- a gun in hand: face where the camera looks (strafing), so the gun points at the crosshair
			hum.AutoRotate = false
			local look = camera.CFrame.LookVector
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		elseif hum then
			hum.AutoRotate = true
		end
		-- (Roblox's own camera: the tremble goes on top of its view)
		if shakeAmt > 0.01 or kickPitch > 0.001 then
			camera.CFrame *= shakeRot(dt)
		end
		return
	end
	adopt(char, root)

	locked = hum.Health > 0 and not cursorWanted()
	UserInputService.MouseBehavior = if locked then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not locked -- (the crosshair takes its place)
	-- the frame the mouse locks, its "movement" is the cursor's jump to the middle of the screen: ignore it
	-- (and any single absurd jump), or the view flips up at the sky
	local justLocked = locked and not wasLocked
	wasLocked = locked
	if locked then
		local delta = UserInputService:GetMouseDelta()
		if justLocked or delta.Magnitude > 250 then
			delta = Vector2.zero
		end
		local sens = TURN * math.max(0.1, gameSettings.MouseSensitivity)
		yaw -= delta.X * sens
		pitch = math.clamp(pitch - delta.Y * sens, PITCH_MIN, PITCH_MAX)
	end

	local wantZoom = if CameraAim.aiming then AIM_ZOOM else zoomGoal
	zoom += (wantZoom - zoom) * math.min(1, dt * 12)
	local wantShoulder = if CameraAim.aiming then AIM_SHOULDER else SHOULDER
	shoulder = shoulder:Lerp(wantShoulder, math.min(1, dt * 14))

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = resting(root) * shakeRot(dt)
	camera.Focus = CFrame.new(root.Position + Vector3.new(0, EYE, 0))

	-- you face where the camera looks (your client owns your body)
	if hum.Health > 0 then
		hum.AutoRotate = false
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end
end

function CameraAim.init()
	RunService:BindToRenderStep("RooftopCamera", Enum.RenderPriority.Camera.Value + 1, update)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			zoomGoal = math.clamp(zoomGoal - input.Position.Z * 2, ZOOM_MIN, ZOOM_MAX)
		end
	end)
end

return CameraAim
