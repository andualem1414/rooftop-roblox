--!strict
-- The booster on this client (shared/Booster has the rules, server/race/BoostService checks them):
--   the choices: stand on a booster pad and trigger its prompt (F, D-pad up, or tap it): a panel offers
--            +1, +3, +5 and +10 floors, each with where it takes you and its price (or "1 credit" for a
--            boost you've already bought; "Free test" in Studio while the products aren't set up). A size
--            that would pass floor 18, or any once the roof is open, is greyed out with the reason.
--   the flight: when the server says go, this client flies your body up the shaft (it owns it): up off the
--            pad, over the shaft, up, and out onto the new floor's pad, touching nothing on the way
--            (the Boosting collision group). Everyone sees the jets (Fx) and the pose (Poser).
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Booster = require(ReplicatedStorage.Shared.Booster)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any
local Audio = require(Common:WaitForChild("Audio")) :: any

local player = Players.LocalPlayer
local STUDIO = RunService:IsStudio()

local BoostPad = {}

local prices: { [number]: number } = {} -- size -> Robux (once looked up)
local flyingUntil = 0
local open: { [number]: boolean } = {} -- the sizes that can be taken right now

local function credits(size: number): number
	local raw = player:GetAttribute("Profile")
	if type(raw) ~= "string" then
		return 0
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(data) == "table" and type(data.credits) == "table" then
		local n = data.credits[tostring(size)]
		return if type(n) == "number" then n else 0
	end
	return 0
end

local function price(size: number): number?
	local id = Booster.PRODUCTS[size]
	if not id or id == 0 then
		return nil
	end
	if prices[size] == nil then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
		end)
		if ok and info and type(info.PriceInRobux) == "number" then
			prices[size] = info.PriceInRobux
		end
	end
	return prices[size]
end

-- the floor your feet are on (as the server counts it: Climbers.sync)
local function myFloor(): number?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not hum then
		return nil
	end
	local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	return math.clamp(math.floor(feet / Config.FLOOR_HEIGHT + 0.3), 0, Config.FLOORS)
end

---------------------------------------------------------------- the flight

local function fly(to: number, seconds: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hum or not root then
		return
	end
	flyingUntil = os.clock() + seconds
	-- touch nothing on the way (the old groups come back after)
	local groups: { [BasePart]: string } = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			groups[d] = d.CollisionGroup
			d.CollisionGroup = "Boosting"
		end
	end
	hum.PlatformStand = true
	local start = root.Position
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.PreSimulation:Connect(function()
		local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
		local x, y, z = Booster.flightAt(k, start.X, start.Y, start.Z, to)
		if root.Parent then
			root.CFrame = CFrame.new(x, y, z) * root.CFrame.Rotation
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		if k >= 1 then
			conn:Disconnect()
			for part, g in groups do
				if part.Parent then
					part.CollisionGroup = g
				end
			end
			hum.PlatformStand = false
			Audio.play("land", root)
		end
	end)
	Audio.play("boost", root)
	Audio.play("boostWhoosh", root)
end

---------------------------------------------------------------- the choices

function BoostPad.init()
	local gui = Ui.screen("BoostMenu", 22)
	local panel = Ui.panel(gui, "Booster", 560, 300)
	local body = panel.body
	local hint = Ui.label(body, "", 15, Ui.BODY, Ui.DIM)
	hint.LayoutOrder = 0
	Ui.column(body, 10)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 150)
	row.LayoutOrder = 1
	row.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -8, 1, 0)
	grid.CellPadding = UDim2.fromOffset(8, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row

	local buttons: { [number]: TextButton } = {}
	local function choose(size: number)
		if not open[size] then
			return -- (greyed out)
		end
		Audio.play("click")
		panel.hide()
		Net.event("Boost"):FireServer(size)
	end
	for i, size in Booster.SIZES do
		local b = Ui.button(row, "", function()
			choose(size)
		end)
		b.LayoutOrder = i
		b.RichText = true
		b.TextSize = 16
		b.TextWrapped = true
		buttons[size] = b
	end

	local state = ReplicatedStorage:WaitForChild("RaceState")
	local function refresh(): boolean
		local floor = myFloor()
		if not floor then
			return false
		end
		local phase = (state:GetAttribute("Phase") :: string?) or ""
		local t = workspace:GetServerTimeNow() - ((state:GetAttribute("StartAt") :: number?) or 0)
		hint.Text =
			`You're on floor {floor + 1}. Fly up the shaft: boosts go up to floor {Booster.MAX_FLOOR + 1}, until the roof opens.`
		local first: TextButton? = nil
		for _, size in Booster.SIZES do
			local b = buttons[size]
			local ok, why = Booster.canBoost(floor, size, phase, t)
			local cost: string
			if credits(size) > 0 then
				cost = `{credits(size)} credit{if credits(size) == 1 then "" else "s"}`
			elseif price(size) then
				cost = `R$ {price(size)}`
			elseif STUDIO then
				cost = "Free test"
			else
				cost = "Not on sale"
				ok = false
			end
			local note = if ok
				then `to floor {floor + size + 1}`
				elseif why == "floor" then `past floor {Booster.MAX_FLOOR + 1}`
				elseif why == "roof" then "roof is open"
				else "not now"
			b.Text =
				`<font size="30" face="LuckiestGuy">+{size}</font>\nfloor{if size == 1 then "" else "s"}\n<font color="#ffc95c">{cost}</font>\n<font size="13">{note}</font>`
			open[size] = ok
			b.AutoButtonColor = ok
			b.BackgroundColor3 = if ok then Ui.SLATE else Ui.INK
			b.TextTransparency = if ok then 0 else 0.55
			if ok and not first then
				first = b
			end
		end
		-- a controller: start on the first boost you can take
		if first and UserInputService:GetLastInputType().Name:find("Gamepad") then
			GuiService.SelectedObject = first
		end
		return true
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "Booster" and os.clock() > flyingUntil and refresh() then
			panel.show()
		end
	end)
	-- walk off the pad, or the race moves on: the panel closes
	RunService.Heartbeat:Connect(function()
		if not panel.frame.Visible then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local floor = myFloor()
		if not root or not floor then
			panel.hide()
			return
		end
		local x, _, z = Booster.pad(floor)
		if Vector3.new(root.Position.X - x, 0, root.Position.Z - z).Magnitude > Booster.REACH + 3 then
			panel.hide()
		end
	end)
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		if panel.frame.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Profile"):Connect(function()
		if panel.frame.Visible then
			refresh()
		end
	end)

	Net.event("Boost").OnClientEvent:Connect(function(_from: number, to: number, seconds: number)
		if type(to) == "number" and type(seconds) == "number" then
			panel.hide()
			fly(to, seconds)
		end
	end)
end

return BoostPad
