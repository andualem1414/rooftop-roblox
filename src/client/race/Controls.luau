--!strict
-- What you do, sent to the server as intent (the server decides what really happens):
--   fire (left mouse / R2 / the touch Fire button): swing the melee weapon, or fire the gun, toward the
--        crosshair; hold it with a full-auto gun (rifle, SMG) and it keeps firing
--   aim (right mouse / L2 / the touch Aim button, which toggles): with a gun, aim (tighter view, steadier
--        shot); with a melee weapon, guard
--   reload (R / X / the touch Reload button)
--   swap weapons (Q / Y / the touch Swap button), or Roblox's backpack: 1 / 2, tapping the slot
--   pick up (E / B / tapping the prompt): the pickups' own ProximityPrompts
-- The tools only fire when this says so (ManualActivationOnly): tapping the world on a phone doesn't
-- shoot, the Fire button does.
local ContextActionService = game:GetService("ContextActionService")
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
local firing = false -- the fire button is held
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
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not w or not root or not hum or hum.Health <= 0 or CameraAim.cinematic then
		return
	end
	-- don't ask faster than the weapon allows (the server checks this too)
	local now = os.clock()
	if now - lastUse < (w.windup + w.strike + w.recover) * 0.97 then
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

local function setFire(on: boolean)
	if on and not firing then
		firing = true
		use()
	elseif not on then
		firing = false
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

-- the other weapon in hand (Q / Y / the touch Swap button)
local function swap()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not hum or not backpack or hum.Health <= 0 then
		return
	end
	local current = toolInHand()
	local want = if current and current:GetAttribute("Slot") == "gun" then "melee" else "gun"
	for _, t in backpack:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Slot") == want then
			hum:EquipTool(t)
			return
		end
	end
end

local function hookTool(tool: Tool)
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
	firing = false
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

-- the on-screen buttons on a touch screen (ContextActionService makes them only there), and the
-- controller's buttons
local function bindButtons()
	local aimToggled = false
	ContextActionService:BindAction("RooftopFire", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			setFire(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setFire(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("RooftopAim", function(_, state: Enum.UserInputState, input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- (on a touch screen it's a switch: holding a button and dragging the view at once is awkward)
			if state == Enum.UserInputState.Begin then
				aimToggled = not aimToggled
				setAim(aimToggled)
			end
		elseif state == Enum.UserInputState.Begin then
			setAim(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setAim(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("RooftopReload", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			Reload:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("RooftopSwap", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			swap()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonY)
	-- round the jump button: fire biggest and nearest the thumb
	local layout = {
		RooftopFire = { "Fire", UDim2.new(1, -95, 1, -205), 78 },
		RooftopAim = { "Aim", UDim2.new(1, -185, 1, -175), 58 },
		RooftopReload = { "Reload", UDim2.new(1, -170, 1, -95), 50 },
		RooftopSwap = { "Swap", UDim2.new(1, -60, 1, -280), 50 },
	}
	for action, l in layout do
		ContextActionService:SetTitle(action, l[1])
		ContextActionService:SetPosition(action, l[2])
		local button = ContextActionService:GetButton(action)
		if button then
			button.Size = UDim2.fromOffset(l[3], l[3])
		end
	end
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
	bindButtons()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAim(true)
		elseif processed then
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			setFire(true)
		elseif input.KeyCode == Enum.KeyCode.R then
			Reload:FireServer()
		elseif input.KeyCode == Enum.KeyCode.Q then
			swap()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setAim(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			setFire(false)
		end
	end)

	-- a full-auto gun keeps firing while the button is held (use() keeps to the gun's rate)
	RunService.RenderStepped:Connect(function()
		if firing then
			local w = weaponInHand()
			if w and w.auto then
				use()
			end
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
