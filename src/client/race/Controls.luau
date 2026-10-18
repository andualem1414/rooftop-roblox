--!strict
-- What you do, sent to the server as intent (the server decides what really happens):
--   use the tool in hand (click / tap / R2): swing the melee weapon, or fire the gun, toward the crosshair
--   aim button (right mouse / L2): with a gun, aim (tighter view, steadier shot); with a melee weapon, guard
--   R / X button: reload
-- Switching weapons is Roblox's backpack: 1 / 2, tapping the slot, or the controller.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)
local Fx = require(script.Parent.Fx)
local Poser = require(script.Parent.Poser)

local player = Players.LocalPlayer

local Swing = Net.event("Swing")
local Shoot = Net.event("Shoot")
local Guard = Net.event("Guard")
local Reload = Net.event("Reload")
local Look = Net.unreliable("Look")

local Controls = {}

local lastUse = 0
local aimHeld = false
local guarding = false
-- your swings alternate forehand / backhand when one follows the last within the combo window (as the
-- server counts them in shared/Combat), so your own arms can start the right one at once
local COMBO_WINDOW = 0.45
local lastSwing = { at = -math.huge, total = 0, side = -1 }

local function toolInHand(): Tool?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Tool")
end

local function weaponInHand(): Weapons.Weapon?
	local tool = toolInHand()
	local name = tool and tool:GetAttribute("Weapon")
	return if type(name) == "string" then Weapons[name] else nil
end

local function use()
	local w = weaponInHand()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not w or not root then
		return
	end
	-- don't ask faster than the weapon allows (the server checks this too)
	local now = os.clock()
	if now - lastUse < (w.windup + w.strike + w.recover) * 0.9 then
		return
	end
	lastUse = now
	if w.slot == "gun" then
		-- a round in the gun: the kick and the flash show at once (the server decides what it hits)
		local mag = player:GetAttribute("Mag")
		if type(mag) == "number" and mag > 0 and player:GetAttribute("Reloading") ~= true then
			Fx.ownShot(w)
		end
		local ray = CameraAim.ray()
		Shoot:FireServer(ray.Origin, ray.Direction.Unit, CameraAim.aiming)
	else
		local look = root.CFrame.LookVector
		-- toward the crosshair when the mouse steers the camera; else the way you face
		local yaw = if CameraAim.aiming or CameraAim.mouseLook() then CameraAim.yaw() else math.atan2(look.X, look.Z)
		local total = w.windup + w.strike + w.recover
		local side = if now - (lastSwing.at + lastSwing.total) < COMBO_WINDOW then -lastSwing.side else 1
		lastSwing.at, lastSwing.total, lastSwing.side = now, total, side
		Poser.predictSwing(w.name, side)
		Swing:FireServer(yaw)
	end
end

local function setAim(on: boolean)
	aimHeld = on
	local w = weaponInHand()
	local isGun = w ~= nil and w.slot == "gun"
	CameraAim.set(on and isGun)
	local guard = on and w ~= nil and w.slot == "melee"
	if guard ~= guarding then
		guarding = guard
		Guard:FireServer(guard)
	end
end

local function hookTool(tool: Tool)
	tool.Activated:Connect(use)
	-- switching weapons while holding the aim button: aim / guard follow the new one
	tool.Equipped:Connect(function()
		setAim(aimHeld)
	end)
	tool.Unequipped:Connect(function()
		task.defer(function()
			setAim(aimHeld)
		end)
	end)
end

local function hookCharacter(char: Model)
	CameraAim.set(false)
	guarding = false
	-- you don't trip over or climb walls (your client owns your body, so it decides this)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		for _, s in
			{ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing }
		do
			hum:SetStateEnabled(s, false)
		end
	end
	for _, t in char:GetChildren() do
		if t:IsA("Tool") and not t:GetAttribute("Hooked") then
			t:SetAttribute("Hooked", true)
			hookTool(t)
		end
	end
	char.ChildAdded:Connect(function(t)
		if t:IsA("Tool") and not t:GetAttribute("Hooked") then
			t:SetAttribute("Hooked", true)
			hookTool(t)
		end
	end)
end

function Controls.init()
	-- no "reset character": a knock-out is the only way down
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
				break
			end
			task.wait(0.5)
		end
	end)

	if player.Character then
		hookCharacter(player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
			setAim(true)
		elseif processed then
			return
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
			Reload:FireServer()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
			setAim(false)
		end
	end)

	-- where you look up / down, for everyone's view of your arms and head (about 15 times a second)
	local sent, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt: number)
		acc += dt
		if acc < 1 / 15 then
			return
		end
		acc = 0
		local pitch = math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y, -1, 1))
		if math.abs(pitch - sent) > 0.01 then
			sent = pitch
			Look:FireServer(pitch)
		end
	end)

	-- you were hit: your client owns your body, so it takes the push
	Net.event("Knock").OnClientEvent:Connect(function(v: Vector3)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and typeof(v) == "Vector3" then
			root.AssemblyLinearVelocity += v
		end
	end)
end

return Controls
