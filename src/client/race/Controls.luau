--!strict
-- What you do, sent to the server as intent (the server decides what really happens):
--   use the tool in hand (click / tap / R2): swing the melee weapon, or fire the gun along the camera ray
--   aim button (right mouse / L2): with a gun, aim over the shoulder; with a melee weapon, guard
--   R / X button: reload
-- Switching weapons is Roblox's backpack: 1 / 2, tapping the slot, or the controller.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)

local player = Players.LocalPlayer

local Swing = Net.event("Swing")
local Shoot = Net.event("Shoot")
local Guard = Net.event("Guard")
local Reload = Net.event("Reload")

local Controls = {}

local lastUse = 0
local aimHeld = false
local guarding = false

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
		local ray = CameraAim.ray()
		Shoot:FireServer(ray.Origin, ray.Direction.Unit, CameraAim.aiming)
	else
		local look = root.CFrame.LookVector
		local yaw = if CameraAim.aiming then CameraAim.yaw() else math.atan2(look.X, look.Z)
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
