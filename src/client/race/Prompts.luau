--!strict
-- The pick-up and booster prompts, drawn small (the prompts are Custom style: server/race/Pickups,
-- BoostService): a little ink pill over the thing, its key in a chalk chip and one line, "Pick up Rifle",
-- "Take Ammo", "Boost up", fading in as you come near. The keys still work as Roblox's own prompts do
-- (E / F, the controller's B / D-pad up); on a touch screen the pill is the button. Over a pickup the pill
-- takes the place of its name tag while it shows.
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any

local player = Players.LocalPlayer

local Prompts = {}

local FADE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACK = 0.3 -- the pill's ink, see-through this much
-- the controller's buttons, as they're printed
local PAD = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	DPadUp = "↑",
	DPadDown = "↓",
	DPadLeft = "←",
	DPadRight = "→",
}

local function keyText(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType): string
	if input == Enum.ProximityPromptInputType.Gamepad then
		return PAD[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	elseif input == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function lineOf(prompt: ProximityPrompt): string
	-- the booster's object is the pad itself: "Boost up" says it
	if prompt.Name == "Booster" or prompt.ObjectText == "" then
		return prompt.ActionText
	end
	return `{prompt.ActionText} <font color="#ffd678">{prompt.ObjectText}</font>`
end

local function show(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType): () -> ()
	local touch = input == Enum.ProximityPromptInputType.Touch
	local holder = prompt.Parent
	local size = if touch then 16 else 14
	local tall = if touch then 36 else 26

	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt"
	gui.Adornee = if holder and holder:IsA("BasePart") then holder else nil
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(300, tall + 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, if prompt.Name == "Booster" then 2.8 else 1.5, 0)
	gui.Active = touch
	-- (no limit of its own: it shows exactly while Roblox shows the prompt. A billboard's MaxDistance is
	-- from the camera, which sits well behind you: the prompt's reach plus a little drew it only zoomed in)
	gui.MaxDistance = math.huge

	local pill = Instance.new(if touch then "TextButton" else "Frame") :: GuiObject
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(0, tall)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Ui.INK
	pill.BackgroundTransparency = 1
	if pill:IsA("TextButton") then
		pill.Text = ""
		pill.AutoButtonColor = false
	end
	Ui.corner(pill, math.floor(tall / 2))
	local edge = Instance.new("UIStroke")
	edge.Color = Ui.CHALK
	edge.Thickness = 1
	edge.Transparency = 1
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pill
	pill.Parent = gui

	-- the key, in a chalk chip
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.LayoutOrder = 1
	key.Size = UDim2.fromOffset(0, tall - 8)
	key.AutomaticSize = Enum.AutomaticSize.X
	key.BackgroundColor3 = Ui.CHALK
	key.BackgroundTransparency = 1
	key.Font = Ui.TEXT
	key.TextSize = size - 2
	key.TextColor3 = Ui.INK
	key.TextTransparency = 1
	key.Text = keyText(prompt, input)
	Ui.corner(key, 6)
	local keyPad = Instance.new("UIPadding")
	keyPad.PaddingLeft = UDim.new(0, 7)
	keyPad.PaddingRight = UDim.new(0, 7)
	keyPad.Parent = key
	key.Parent = pill

	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.LayoutOrder = 2
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromOffset(0, tall)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Font = Ui.TEXT
	text.TextSize = size
	text.TextColor3 = Ui.CHALK
	text.TextTransparency = 1
	text.RichText = true
	text.Text = lineOf(prompt)
	text.Parent = pill

	-- (a pickup's own name tag steps aside meanwhile: its text, as client/race/Cutaway switches the tag
	-- itself on and off by floor)
	local tag = holder and holder:FindFirstChild("Tag")
	local tagText = tag and tag:FindFirstChild("Text")
	if tagText and tagText:IsA("GuiObject") then
		tagText.Visible = false
	end
	gui.Parent = player:WaitForChild("PlayerGui")

	TweenService:Create(pill, FADE, { BackgroundTransparency = BACK }):Play()
	TweenService:Create(edge, FADE, { Transparency = 0.82 }):Play()
	TweenService:Create(key, FADE, { BackgroundTransparency = 0.05, TextTransparency = 0 }):Play()
	TweenService:Create(text, FADE, { TextTransparency = 0 }):Play()

	-- what it says can change while it shows (a weapon swapped for the one you carried)
	local changed = prompt.Changed:Connect(function(property: string)
		if property == "ActionText" or property == "ObjectText" then
			text.Text = lineOf(prompt)
		end
	end)
	local pressed: RBXScriptConnection? = nil
	if pill:IsA("TextButton") then
		pressed = pill.Activated:Connect(function()
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
	end
	return function()
		changed:Disconnect()
		if pressed then
			pressed:Disconnect()
		end
		if tagText and tagText:IsA("GuiObject") and tagText.Parent then
			tagText.Visible = true
		end
		gui:Destroy()
	end
end

function Prompts.init()
	local hide: { [ProximityPrompt]: () -> () } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local old = hide[prompt]
		if old then
			old()
		end
		hide[prompt] = show(prompt, input)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local h = hide[prompt]
		hide[prompt] = nil
		if h then
			h()
		end
	end)
end

return Prompts
