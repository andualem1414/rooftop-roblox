--!strict
-- The camera: Roblox's own third-person camera, plus over-the-shoulder aiming while the aim button is
-- held with a gun in hand (right mouse / L2): the view tightens behind your right shoulder, the mouse is
-- locked to the crosshair in the middle, and you face where the camera looks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local CameraAim = {}
CameraAim.aiming = false

local AIM_OFFSET = Vector3.new(2.2, 0.8, 0)
local AIM_ZOOM = 9
local normalZoom = { min = player.CameraMinZoomDistance, max = player.CameraMaxZoomDistance }
local offset = Vector3.zero

function CameraAim.set(on: boolean)
	if CameraAim.aiming == on then
		return
	end
	CameraAim.aiming = on
	if on then
		normalZoom.min, normalZoom.max = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
		player.CameraMinZoomDistance = AIM_ZOOM
		player.CameraMaxZoomDistance = AIM_ZOOM
	else
		player.CameraMaxZoomDistance = normalZoom.max
		player.CameraMinZoomDistance = normalZoom.min
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- the ray through the middle of the screen (aiming) or under the mouse / finger (not aiming)
function CameraAim.ray(): Ray
	local camera = workspace.CurrentCamera
	if CameraAim.aiming or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local size = camera.ViewportSize
		return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	local m = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(m.X, m.Y)
end

-- the camera's heading (yaw) on the ground
function CameraAim.yaw(): number
	local look = workspace.CurrentCamera.CFrame.LookVector
	return math.atan2(look.X, look.Z)
end

function CameraAim.init()
	RunService:BindToRenderStep("RooftopAim", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root then
			return
		end
		local want = if CameraAim.aiming then AIM_OFFSET else Vector3.zero
		offset = offset:Lerp(want, math.min(1, dt * 14))
		hum.CameraOffset = offset
		if CameraAim.aiming then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			hum.AutoRotate = false
			local look = workspace.CurrentCamera.CFrame.LookVector
			local p = root.Position
			root.CFrame = CFrame.lookAt(p, p + Vector3.new(look.X, 0, look.Z))
		else
			hum.AutoRotate = true
		end
	end)
end

return CameraAim
