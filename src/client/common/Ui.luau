--!strict
-- The game's own UI pieces, shared by the lobby and the race: chalk on ink like the loading screen, with
-- the title's red-pink accent. Panels (one open at a time), buttons, sliders and switches. While a panel
-- is open the player's MenuOpen attribute is true, so the race's mouse camera lets go of the cursor.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Ui = {}

Ui.INK = Color3.fromRGB(18, 15, 28)
Ui.SLATE = Color3.fromRGB(34, 28, 52)
Ui.CHALK = Color3.fromRGB(240, 236, 226)
Ui.DIM = Color3.fromRGB(170, 164, 200)
Ui.ACCENT = Color3.fromRGB(255, 90, 170)
Ui.RED = Color3.fromRGB(255, 75, 90)
Ui.GOLD = Color3.fromRGB(255, 214, 120)
Ui.TITLE = Enum.Font.LuckiestGuy
Ui.TEXT = Enum.Font.GothamBold
Ui.BODY = Enum.Font.GothamMedium

local open: Frame? = nil -- the panel showing now

function Ui.screen(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order or 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function Ui.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

function Ui.stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Ui.INK
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function Ui.label(parent: Instance, text: string, size: number, font: Enum.Font?, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, math.ceil(size * 1.35))
	l.Font = font or Ui.TEXT
	l.TextSize = size
	l.TextColor3 = color or Ui.CHALK
	l.TextWrapped = true
	l.RichText = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

-- a chunky button; onClick runs on a click or a tap
function Ui.button(parent: Instance, text: string, onClick: () -> (), color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color or Ui.SLATE
	b.Size = UDim2.fromOffset(160, 44)
	b.Font = Ui.TEXT
	b.TextSize = 18
	b.TextColor3 = Ui.CHALK
	b.Text = text
	Ui.corner(b, 10)
	Ui.stroke(b, Color3.fromRGB(70, 60, 100), 2)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

-- a column that stacks its children top to bottom
function Ui.column(parent: Instance, gap: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function Ui.pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

local function setMenuOpen(on: boolean)
	player:SetAttribute("MenuOpen", on)
end

export type Panel = { frame: Frame, body: ScrollingFrame, show: () -> (), hide: () -> (), toggle: () -> () }

-- a panel in the middle of the screen with a title and a close button; its body scrolls. Only one
-- panel shows at a time; Escape-free: the X (or the button that opened it) closes it.
function Ui.panel(gui: ScreenGui, title: string, width: number?, height: number?): Panel
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.fromOffset(width or 560, height or 460)
	frame.BackgroundColor3 = Ui.INK
	frame.BackgroundTransparency = 0.04
	frame.Visible = false
	Ui.corner(frame, 14)
	Ui.stroke(frame, Ui.ACCENT, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(width or 560, height or 460)
	limit.Parent = frame
	-- never wider or taller than the screen (phones)
	local function fit()
		local view = workspace.CurrentCamera.ViewportSize
		frame.Size = UDim2.fromOffset(math.min(width or 560, view.X - 24), math.min(height or 460, view.Y - 60))
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	frame.Parent = gui

	local head = Ui.label(frame, title, 30, Ui.TITLE)
	head.Position = UDim2.fromOffset(20, 12)
	head.Size = UDim2.new(1, -80, 0, 40)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Ui.SLATE
	close.Font = Ui.TEXT
	close.TextSize = 20
	close.TextColor3 = Ui.CHALK
	close.Text = "X"
	Ui.corner(close, 8)
	close.Parent = frame

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(20, 62)
	body.Size = UDim2.new(1, -40, 1, -76)
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = Ui.DIM
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = frame

	local panel: Panel
	local function hide()
		frame.Visible = false
		if open == frame then
			open = nil
			setMenuOpen(false)
		end
	end
	local function show()
		if open and open ~= frame then
			open.Visible = false
		end
		open = frame
		frame.Visible = true
		setMenuOpen(true)
		local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = frame
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	panel = {
		frame = frame,
		body = body,
		show = show,
		hide = hide,
		toggle = function()
			if frame.Visible then
				hide()
			else
				show()
			end
		end,
	}
	close.Activated:Connect(hide)
	return panel
end

-- close whatever panel is open
function Ui.closeAll()
	if open then
		open.Visible = false
		open = nil
		setMenuOpen(false)
	end
end

-- a row with a name on the left and a slider on the right; onChange gets the new value (snapped to step)
function Ui.slider(
	parent: Instance,
	name: string,
	min: number,
	max: number,
	step: number,
	value: number,
	onChange: (number) -> (),
	format: ((number) -> string)?
): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = parent
	local l = Ui.label(row, name, 17)
	l.Size = UDim2.fromScale(0.4, 1)
	l.TextYAlignment = Enum.TextYAlignment.Center
	local readout = Ui.label(row, "", 16, Ui.BODY, Ui.DIM)
	readout.AnchorPoint = Vector2.new(1, 0)
	readout.Position = UDim2.fromScale(1, 0)
	readout.Size = UDim2.new(0, 56, 1, 0)
	readout.TextXAlignment = Enum.TextXAlignment.Right
	readout.TextYAlignment = Enum.TextYAlignment.Center
	local track = Instance.new("TextButton")
	track.Text = ""
	track.AutoButtonColor = false
	track.BackgroundColor3 = Ui.SLATE
	track.Position = UDim2.new(0.42, 0, 0.5, -5)
	track.Size = UDim2.new(0.58, -70, 0, 10)
	Ui.corner(track, 5)
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Ui.ACCENT
	fill.BorderSizePixel = 0
	Ui.corner(fill, 5)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = Ui.CHALK
	Ui.corner(knob, 11)
	knob.Parent = track

	local function show(v: number)
		local k = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(k, 1)
		knob.Position = UDim2.fromScale(k, 0.5)
		readout.Text = if format then format(v) else tostring(v)
	end
	show(value)
	local dragging = false
	local function set(x: number)
		local k = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local v = min + math.floor((k * (max - min)) / step + 0.5) * step
		v = math.clamp(v, min, max)
		if v ~= value then
			value = v
			show(v)
			onChange(v)
		end
	end
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			set(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
			set(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	return row
end

-- a row with a name and an on / off switch
function Ui.toggle(parent: Instance, name: string, value: boolean, onChange: (boolean) -> ()): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = parent
	local l = Ui.label(row, name, 17)
	l.Size = UDim2.new(1, -90, 1, 0)
	l.TextYAlignment = Enum.TextYAlignment.Center
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.fromScale(1, 0.5)
	b.Size = UDim2.fromOffset(76, 30)
	b.Font = Ui.TEXT
	b.TextSize = 16
	Ui.corner(b, 15)
	b.Parent = row
	local function show()
		b.Text = if value then "On" else "Off"
		b.BackgroundColor3 = if value then Ui.ACCENT else Ui.SLATE
		b.TextColor3 = Ui.CHALK
	end
	show()
	b.Activated:Connect(function()
		value = not value
		show()
		onChange(value)
	end)
	return row
end

return Ui
