--!strict
-- Out of the race (knocked out after the roof opened: server/race/RaceService marks your player Out): you
-- watch the climbers still in, players first, then the bots, until the race ends or you leave.
--   switch:  Prev / Next (or ← / →, Q / E, the controller's L1 / R1); when the one you watch goes down,
--            on to the next
--   look:    Roblox's own camera orbits them (drag to look round, the wheel zooms: client/race/CameraAim),
--            and the floors and the wall in the way are cut away round them as round you (Cutaway)
--   leave:   back to the main screen (in Studio, with no lobby to go to: the next race starts)
-- Once the race is over the end card (EndScreen) takes over; the camera stays on whoever you watched.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local CameraAim = require(script.Parent.CameraAim)
local Cutaway = require(script.Parent.Cutaway)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any
local Audio = require(Common:WaitForChild("Audio")) :: any

local player = Players.LocalPlayer
local STUDIO = RunService:IsStudio()
local START_AFTER = 2 -- seconds: your own knock-out plays out first

local Spectate = {}

local function alive(model: Instance?): boolean
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and model:FindFirstChild("HumanoidRootPart") ~= nil
end

-- the climbers still in: your team first, players before bots, each by name
local function candidates(): { Model }
	local people, bots = {}, {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if p ~= player and char and p:GetAttribute("Out") ~= true and alive(char) then
			table.insert(people, char)
		end
	end
	local folder = workspace:FindFirstChild("Bots")
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and alive(m) then
				table.insert(bots, m)
			end
		end
	end
	local function byName(a: Model, b: Model): boolean
		return a.Name < b.Name
	end
	table.sort(people, byName)
	table.sort(bots, byName)
	for _, m in bots do
		table.insert(people, m)
	end
	local mine = player:GetAttribute("Team")
	local ours, theirs = {}, {}
	for _, m in people do
		table.insert(if mine ~= nil and m:GetAttribute("Team") == mine then ours else theirs, m)
	end
	for _, m in theirs do
		table.insert(ours, m)
	end
	return ours
end

local function nameOf(model: Model): string
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p.DisplayName
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return if hum and hum.DisplayName ~= "" then hum.DisplayName else model.Name
end

function Spectate.init()
	local state = ReplicatedStorage:WaitForChild("RaceState")
	local gui = Ui.screen("RaceSpectate", 22)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -96)
	panel.Size = UDim2.fromOffset(540, 112)
	panel.BackgroundColor3 = Ui.INK
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	Ui.corner(panel, 14)
	Ui.stroke(panel, Ui.RED, 2)
	panel.Parent = gui
	local title = Ui.label(panel, "YOU'RE OUT", 24, Ui.TITLE, Ui.RED)
	title.Position = UDim2.fromOffset(0, 8)
	title.Size = UDim2.new(1, 0, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local watchingLine = Ui.label(panel, "", 16, Ui.BODY, Ui.CHALK)
	watchingLine.Position = UDim2.fromOffset(20, 38)
	watchingLine.Size = UDim2.new(1, -40, 0, 20)
	watchingLine.TextXAlignment = Enum.TextXAlignment.Center

	local target: Model? = nil
	local active = false
	local outAt = math.huge

	local function show(m: Model?)
		target = m
		CameraAim.watching = m
		Cutaway.focus = m
		local list = candidates()
		if m then
			local i = table.find(list, m) or 0
			watchingLine.Text = `Watching <b>{nameOf(m)}</b>  ·  {i} / {#list} still in`
		else
			watchingLine.Text = "Nobody left to watch"
		end
	end

	-- the next (step 1) or previous (-1) climber still in, from the one you watch
	local function step(dir: number)
		local list = candidates()
		if #list == 0 then
			show(nil)
			return
		end
		local i = if target then table.find(list, target) else nil
		if not i then
			show(list[1])
			return
		end
		show(list[(i - 1 + dir) % #list + 1])
	end

	local prev = Ui.button(panel, "< Prev", function()
		Audio.play("click")
		step(-1)
	end)
	prev.AnchorPoint = Vector2.new(0, 1)
	prev.Position = UDim2.new(0, 16, 1, -12)
	prev.Size = UDim2.fromOffset(130, 40)
	local nextB = Ui.button(panel, "Next >", function()
		Audio.play("click")
		step(1)
	end)
	nextB.AnchorPoint = Vector2.new(0, 1)
	nextB.Position = UDim2.new(0, 156, 1, -12)
	nextB.Size = UDim2.fromOffset(130, 40)
	local leave = Ui.button(panel, if STUDIO then "Play again" else "Main screen", function() end, Ui.ACCENT)
	leave.AnchorPoint = Vector2.new(1, 1)
	leave.Position = UDim2.new(1, -16, 1, -12)
	leave.Size = UDim2.fromOffset(200, 40)
	leave.Activated:Connect(function()
		Audio.play("click")
		leave.Text = if STUDIO then "Starting…" else "Going back…"
		leave.Active = false
		Net.event("Finish"):FireServer("leave")
	end)

	local function bind(on: boolean)
		if on then
			ContextActionService:BindAction(
				"RooftopSpectate",
				function(_, s: Enum.UserInputState, input: InputObject)
					if s == Enum.UserInputState.Begin then
						local k = input.KeyCode
						local back = k == Enum.KeyCode.Left or k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonL1
						step(if back then -1 else 1)
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				Enum.KeyCode.Left,
				Enum.KeyCode.Right,
				Enum.KeyCode.Q,
				Enum.KeyCode.E,
				Enum.KeyCode.ButtonL1,
				Enum.KeyCode.ButtonR1
			)
		else
			ContextActionService:UnbindAction("RooftopSpectate")
		end
	end

	local function stop()
		if not active then
			return
		end
		active = false
		panel.Visible = false
		bind(false)
		target = nil
		CameraAim.watching = nil
		Cutaway.focus = nil
		-- back to your own body (a new race)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if hum and camera then
			camera.CameraSubject = hum
		end
	end

	player:GetAttributeChangedSignal("Out"):Connect(function()
		if player:GetAttribute("Out") == true then
			outAt = os.clock()
		else
			outAt = math.huge
			stop()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if player:GetAttribute("Out") ~= true then
			return
		end
		if not active and os.clock() - outAt >= START_AFTER then
			active = true
			leave.Text = if STUDIO then "Play again" else "Main screen"
			leave.Active = true
			bind(true)
			step(0)
		end
		if not active then
			return
		end
		-- the one you watch went down: on to the next one still in
		if not alive(target) then
			step(1)
		else
			show(target) -- (the count of those still in changes)
		end
		local phase = state:GetAttribute("Phase")
		panel.Visible = phase == "climb" or phase == "roof"
	end)
end

return Spectate
