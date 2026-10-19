--!strict
-- The lobby's screens:
--   the main screen (first, and whenever you come back from a race): the title over a slow orbit of the
--     tower, Play, and How to play · Looks · Stats · Leaderboards · Settings. Play puts you on the
--     forecourt for the next race (server/lobby/LobbyService)
--   the forecourt:
--   top:     the countdown to the next race and how many are waiting (also written on the big board over
--            the walkway); banners ("Off to the tower!")
--   left:    How to play · Looks · Stats · Leaderboards · Settings
--   panels:  the rules and the controls; the wardrobe (wear any look you've unlocked; the locked ones show
--            how to get them); your stats; the leaderboards; the settings
-- Follows ReplicatedStorage.LobbyState (server/lobby/LobbyService) and your Profile attribute.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Looks = require(ReplicatedStorage.Shared.Looks)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Version = require(ReplicatedStorage.Shared.Version)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any
local Audio = require(Common:WaitForChild("Audio")) :: any
local SettingsPanel = require(Common:WaitForChild("SettingsPanel")) :: any

local player = Players.LocalPlayer

local LobbyUi = {}

type ProfileView = { stats: Progress.Stats, look: string, saved: boolean, credits: { [string]: number } }

local function profile(): ProfileView
	local raw = player:GetAttribute("Profile")
	local out: ProfileView = { stats = Progress.newStats(), look = Looks.DEFAULT, saved = false, credits = {} }
	if type(raw) ~= "string" then
		return out
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(data) == "table" then
		local p = Progress.sanitize(data)
		out.stats = p.stats
		out.look = if type(data.look) == "string" then data.look else p.look
		out.saved = data.saved == true
		out.credits = p.credits
	end
	return out
end

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

---------------------------------------------------------------- panels

local function howToPlay(gui: ScreenGui)
	local panel = Ui.panel(gui, "How to play", 600, 500)
	local body = panel.body
	Ui.column(body, 6)
	local lines = {
		{ "The race", Ui.ACCENT, 20 },
		{ `{Config.CLIMBERS} climbers start on floors 1–5 of a {Config.FLOORS}-floor tower.`, nil, 16 },
		{ "Platforms rise up the shaft in the middle: ride them up. They stop at every floor.", nil, 16 },
		{ "Fight the others with the bat, a sword or a gun. Knocked out? You come to a few floors lower.", nil, 16 },
		{
			"The roof opens at 4:00. Only one can escape: be alone on a platform as it rises through the roof.",
			nil,
			16,
		},
		{ "Two or more on it, and it throws everyone off.", nil, 16 },
		{ "Guns and ammo", Ui.ACCENT, 20 },
		{
			"Everyone starts with a bat and a pistol. Rifles, SMGs and shotguns ride the platforms and lie on floors.",
			nil,
			16,
		},
		{
			"Ammo boxes lie on every floor. Headshots hit half as hard again. A guard stops blows, not bullets.",
			nil,
			16,
		},
		{ "Boosters", Ui.ACCENT, 20 },
		{
			"A glowing pad beside the shaft on each floor flies you up 1, 3, 5 or 10 floors (no higher than floor 18, and only until the roof opens). F, D-pad up, or tap it.",
			nil,
			16,
		},
		{ "Keyboard and mouse", Ui.ACCENT, 20 },
		{ "WASD move · Space jump · click fire / swing (hold for full auto) · right click aim / guard", nil, 16 },
		{ "R reload · Q or 1 / 2 swap weapons · E pick up · P settings · hold Left Alt for the cursor", nil, 16 },
		{ "Touch", Ui.ACCENT, 20 },
		{ "The Fire, Aim, Reload and Swap buttons by the jump button; tap a weapon's prompt to pick it up.", nil, 16 },
		{ "Controller", Ui.ACCENT, 20 },
		{ "R2 fire · L2 aim / guard · X reload · Y swap · B pick up · View settings", nil, 16 },
	}
	for i, l in lines do
		local label = Ui.label(body, l[1], l[3], if l[2] then Ui.TEXT else Ui.BODY, l[2] or Ui.CHALK)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.LayoutOrder = i
	end
	return panel
end

local function hexColor(s: string?, fallback: Color3): Color3
	if not s then
		return fallback
	end
	local ok, c = pcall(Color3.fromHex, s)
	return if ok then c else fallback
end

local function wardrobe(gui: ScreenGui)
	local panel = Ui.panel(gui, "Looks", 680, 520)
	local body = panel.body
	local function build()
		clear(body)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(196, 170)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = body
		local me = profile()
		for i, look in Looks.LIST do
			local unlocked = Looks.isUnlocked(look, me.stats)
			local wearing = me.look == look.id
			local card = Instance.new("Frame")
			card.LayoutOrder = i
			card.BackgroundColor3 = Ui.SLATE
			card.BackgroundTransparency = if unlocked then 0 else 0.4
			Ui.corner(card, 10)
			Ui.stroke(card, if wearing then Ui.ACCENT else Color3.fromRGB(60, 50, 90), if wearing then 3 else 1)
			Ui.pad(card, 10)
			card.Parent = body
			local name = Ui.label(card, look.name, 18, Ui.TEXT, if unlocked then Ui.CHALK else Ui.DIM)
			name.Size = UDim2.new(1, 0, 0, 24)
			-- the outfit's colours
			local swatches = Instance.new("Frame")
			swatches.BackgroundTransparency = 1
			swatches.Position = UDim2.fromOffset(0, 30)
			swatches.Size = UDim2.new(1, 0, 0, 36)
			swatches.Parent = card
			local row = Instance.new("UIListLayout")
			row.FillDirection = Enum.FillDirection.Horizontal
			row.Padding = UDim.new(0, 6)
			row.Parent = swatches
			if look.id == Looks.DEFAULT then
				local own = Ui.label(swatches, "Just you, as you are", 15, Ui.BODY, Ui.DIM)
				own.Size = UDim2.fromScale(1, 1)
			else
				for _, c in { look.top, look.sleeve, look.pants, look.boots, look.hatColor, look.extraColor } do
					if c then
						local sw = Instance.new("Frame")
						sw.Size = UDim2.fromOffset(26, 26)
						sw.BackgroundColor3 = hexColor(c, Ui.SLATE)
						Ui.corner(sw, 13)
						Ui.stroke(sw, Ui.INK, 2)
						sw.Parent = swatches
					end
				end
			end
			local extra = {}
			if look.hat then
				table.insert(extra, look.hat)
			end
			if look.extra then
				table.insert(extra, look.extra)
			end
			if look.kneepads then
				table.insert(extra, "kneepads")
			end
			local what = Ui.label(card, table.concat(extra, " · "), 13, Ui.BODY, Ui.DIM)
			what.Position = UDim2.fromOffset(0, 70)
			what.Size = UDim2.new(1, 0, 0, 18)
			if unlocked then
				local b = Ui.button(card, if wearing then "Wearing" else "Wear", function()
					if not wearing then
						Audio.play("click")
						Net.event("SetLook"):FireServer(look.id)
					end
				end, if wearing then Ui.ACCENT else nil)
				b.AnchorPoint = Vector2.new(0, 1)
				b.Position = UDim2.fromScale(0, 1)
				b.Size = UDim2.new(1, 0, 0, 36)
			else
				local how = Ui.label(card, `Locked: {look.how}`, 14, Ui.BODY, Ui.DIM)
				how.Position = UDim2.fromOffset(0, 94)
				how.Size = UDim2.new(1, 0, 0, 36)
				local bar = Instance.new("Frame")
				bar.AnchorPoint = Vector2.new(0, 1)
				bar.Position = UDim2.fromScale(0, 1)
				bar.Size = UDim2.new(1, 0, 0, 8)
				bar.BackgroundColor3 = Ui.INK
				Ui.corner(bar, 4)
				bar.Parent = card
				local fill = Instance.new("Frame")
				fill.Size = UDim2.fromScale(Looks.progress(look, me.stats), 1)
				fill.BackgroundColor3 = Ui.ACCENT
				Ui.corner(fill, 4)
				fill.Parent = bar
			end
		end
	end
	panel.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.frame.Visible then
			build()
		end
	end)
	player:GetAttributeChangedSignal("Profile"):Connect(function()
		if panel.frame.Visible then
			build()
		end
	end)
	return panel
end

local function statsPanel(gui: ScreenGui)
	local panel = Ui.panel(gui, "Your stats", 460, 400)
	local body = panel.body
	local function build()
		clear(body)
		Ui.column(body, 8)
		local me = profile()
		local s = me.stats
		local rows = {
			{ "Races played", tostring(s.rounds) },
			{ "Escapes (wins)", tostring(s.wins) },
			{ "Climbers knocked out", tostring(s.knockouts) },
			{
				"Highest floor",
				if s.highestFloor > Config.FLOORS
					then "The roof"
					elseif s.highestFloor > 0 then tostring(s.highestFloor)
					else "–",
			},
			{
				"Fastest escape",
				if s.bestTime then Progress.boardText("bestTime", math.floor(s.bestTime * 10 + 0.5)) else "–",
			},
		}
		for i, r in rows do
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.Size = UDim2.new(1, 0, 0, 34)
			f.LayoutOrder = i
			f.Parent = body
			local k = Ui.label(f, r[1], 18, Ui.BODY)
			k.Size = UDim2.fromScale(0.65, 1)
			local v = Ui.label(f, r[2], 20, Ui.TEXT, Ui.ACCENT)
			v.Size = UDim2.fromScale(0.35, 1)
			v.Position = UDim2.fromScale(0.65, 0)
			v.TextXAlignment = Enum.TextXAlignment.Right
		end
		-- boosts bought and not used yet (they wait for any booster pad in a race)
		local held = {}
		for _, size in { 1, 3, 5, 10 } do
			local n = me.credits[tostring(size)]
			if n and n > 0 then
				table.insert(held, `+{size} ×{n}`)
			end
		end
		if #held > 0 then
			local b = Ui.label(body, `Boost credits: {table.concat(held, ",  ")}`, 16, Ui.TEXT, Ui.GOLD)
			b.LayoutOrder = 50
		end
		if not me.saved then
			local note = Ui.label(body, "Your progress isn't being saved on this server.", 14, Ui.BODY, Ui.DIM)
			note.LayoutOrder = 99
		end
	end
	panel.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.frame.Visible then
			build()
		end
	end)
	return panel
end

local function boardsPanel(gui: ScreenGui, state: Instance)
	local panel = Ui.panel(gui, "Leaderboards", 640, 480)
	local body = panel.body
	local function build()
		clear(body)
		local cols = Instance.new("UIGridLayout")
		cols.CellSize = UDim2.new(1 / 3, -8, 0, 380)
		cols.CellPadding = UDim2.fromOffset(8, 8)
		cols.Parent = body
		local ok, boards = pcall(HttpService.JSONDecode, HttpService, (state:GetAttribute("Boards") :: string?) or "[]")
		if not ok or type(boards) ~= "table" then
			boards = {}
		end
		for _, b in Progress.BOARDS do
			local col = Instance.new("Frame")
			col.BackgroundColor3 = Ui.SLATE
			Ui.corner(col, 10)
			Ui.pad(col, 8)
			Ui.column(col, 4)
			col.Parent = body
			local t = Ui.label(col, b.title, 16, Ui.TEXT, Ui.ACCENT)
			t.LayoutOrder = 0
			local rows = {}
			for _, got in boards do
				if type(got) == "table" and got.id == b.id and type(got.rows) == "table" then
					rows = got.rows
				end
			end
			if #rows == 0 then
				Ui.label(col, "No one yet.", 14, Ui.BODY, Ui.DIM).LayoutOrder = 1
			end
			for i, r in rows do
				local l = Ui.label(col, `{i}. {r.name}  <font color="#ff5aaa">{r.value}</font>`, 14, Ui.BODY)
				l.LayoutOrder = i
				l.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end
	end
	panel.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.frame.Visible then
			build()
		end
	end)
	state:GetAttributeChangedSignal("Boards"):Connect(function()
		if panel.frame.Visible then
			build()
		end
	end)
	return panel
end

---------------------------------------------------------------- the screen

function LobbyUi.init()
	local state = ReplicatedStorage:WaitForChild("LobbyState")
	local gui = Ui.screen("Lobby", 5)

	-- the countdown
	local top = Instance.new("Frame")
	top.BackgroundColor3 = Ui.INK
	top.BackgroundTransparency = 0.25
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(380, 76)
	Ui.corner(top, 12)
	top.Parent = gui
	local clock = Ui.label(top, "", 32, Ui.TITLE)
	clock.TextXAlignment = Enum.TextXAlignment.Center
	clock.Position = UDim2.fromOffset(0, 4)
	clock.Size = UDim2.new(1, 0, 0, 40)
	local sub = Ui.label(top, "", 15, Ui.BODY, Ui.DIM)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.Position = UDim2.fromOffset(0, 46)
	sub.Size = UDim2.new(1, 0, 0, 22)

	-- banners
	local banner = Ui.label(gui, "", 30, Ui.TITLE, Ui.GOLD)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(800, 44)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.3
	banner.TextTransparency = 1
	local token = 0
	Net.event("Notice").OnClientEvent:Connect(function(text: string)
		token += 1
		local mine = token
		Audio.play("notice")
		banner.Text = text
		banner.TextTransparency = 0
		task.delay(4, function()
			if mine == token then
				TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			end
		end)
	end)

	-- the buttons and their panels
	local menu = Ui.screen("LobbyMenu", 20)
	local panels = {
		{ "How to play", howToPlay(menu) },
		{ "Looks", wardrobe(menu) },
		{ "Stats", statsPanel(menu) },
		{ "Leaderboards", boardsPanel(menu, state) },
		{ "Settings", SettingsPanel.create(menu) },
	}
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, 16, 0.5, 0)
	side.Size = UDim2.fromOffset(170, 6 * 52)
	side.Parent = gui
	Ui.column(side, 8)
	for i, p in panels do
		local b = Ui.button(side, p[1], function()
			Audio.play("click")
			p[2].toggle()
		end)
		b.LayoutOrder = i
	end

	---------------------------------------------------------------- the main screen
	local onMenu = true
	local title = Ui.screen("MainMenu", 15)
	title.IgnoreGuiInset = true
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Ui.INK
	shade.BorderSizePixel = 0
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.45, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = shade
	shade.Parent = title
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 48, 0.5, 0)
	column.Size = UDim2.fromOffset(360, 560)
	column.Parent = title
	Ui.column(column, 10)
	local name = Ui.label(column, 'R<font color="#ff4b5a">O</font>OFTOP', 84, Ui.TITLE)
	name.Size = UDim2.new(1, 0, 0, 100)
	name.LayoutOrder = 1
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 4
	nameStroke.Color = Color3.fromRGB(10, 8, 18)
	nameStroke.Parent = name
	local tag = Ui.label(column, "Climb. Fight. Get out first.", 20, Ui.TEXT, Ui.DIM)
	tag.LayoutOrder = 2
	local gap = Instance.new("Frame")
	gap.BackgroundTransparency = 1
	gap.Size = UDim2.fromOffset(10, 14)
	gap.LayoutOrder = 3
	gap.Parent = column

	local function showMenu(on: boolean)
		onMenu = on
		title.Enabled = on
		gui.Enabled = not on
		Ui.closeAll()
	end
	local play = Ui.button(column, "PLAY", function()
		Audio.play("go")
		Net.event("Lobby"):FireServer("play")
		showMenu(false)
	end, Ui.ACCENT)
	play.Size = UDim2.fromOffset(260, 62)
	play.Font = Ui.TITLE
	play.TextSize = 34
	play.LayoutOrder = 4
	for i, p in panels do
		local b = Ui.button(column, p[1], function()
			Audio.play("click")
			p[2].toggle()
		end)
		b.Size = UDim2.fromOffset(220, 42)
		b.LayoutOrder = 4 + i
	end
	local menuVersion = Ui.label(title, `v{Version}`, 12, Ui.BODY, Ui.DIM)
	menuVersion.AnchorPoint = Vector2.new(1, 1)
	menuVersion.Position = UDim2.new(1, -10, 1, -6)
	menuVersion.Size = UDim2.fromOffset(120, 16)
	menuVersion.TextXAlignment = Enum.TextXAlignment.Right

	-- the forecourt's way back to the main screen
	local back = Ui.button(side, "Main screen", function()
		Audio.play("click")
		Net.event("Lobby"):FireServer("menu")
		showMenu(true)
	end)
	back.LayoutOrder = 99

	-- the main screen's camera: a slow orbit of the tower; the lighting kept ready on the forecourt, where
	-- Play puts you (Camera.Focus)
	local orbitT = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not onMenu or player:GetAttribute("Loaded") ~= true then
			return
		end
		orbitT += dt
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local a = orbitT * 0.05 + 0.6
		local pos = Vector3.new(math.sin(a) * 240, 70 + math.sin(orbitT * 0.11) * 20, math.cos(a) * 240)
		cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, 110, 0))
		cam.Focus = CFrame.new(0, 5, 150)
	end)
	-- a body on the forecourt: the camera follows it
	local function follow(char: Model)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and not onMenu then
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum :: Humanoid
		end
	end
	player.CharacterAdded:Connect(follow)
	showMenu(true)

	local version = Ui.label(gui, `Rooftop v{Version}`, 12, Ui.BODY, Ui.DIM)
	version.AnchorPoint = Vector2.new(1, 1)
	version.Position = UDim2.new(1, -10, 1, -6)
	version.Size = UDim2.fromOffset(160, 16)
	version.TextXAlignment = Enum.TextXAlignment.Right

	-- the countdown, on the screen and on the board; the last five seconds tick
	local lastShown = -1
	RunService.RenderStepped:Connect(function()
		local deadline = (state:GetAttribute("Deadline") :: number?) or 0
		local waiting = (state:GetAttribute("Waiting") :: number?) or 0
		local status = state:GetAttribute("Status")
		local left = math.max(0, deadline - workspace:GetServerTimeNow())
		local big, small
		if status == "sending" then
			big, small = "Off to the tower!", "Hold tight…"
		elseif deadline > 0 then
			big = `Next race in {Rules.clock(left)}`
			small = `{waiting} waiting · up to {Config.CLIMBERS} go together · bots fill the rest`
			local s = math.ceil(left)
			if s ~= lastShown then
				lastShown = s
				-- (only for those on the forecourt: the main screen isn't going anywhere)
				if s >= 1 and s <= 5 and not onMenu then
					Audio.play("tick")
				end
			end
		else
			big, small = "Waiting for climbers", "The countdown starts when someone's here"
		end
		clock.Text = big
		sub.Text = small
		local board = workspace:FindFirstChild("Forecourt")
		local countdown = board and board:FindFirstChild("Countdown")
		local screen = countdown and countdown:FindFirstChild("Screen")
		local page = screen and screen:FindFirstChild("Page")
		if page then
			local c = page:FindFirstChild("Clock") :: TextLabel?
			local w = page:FindFirstChild("Waiting") :: TextLabel?
			if c then
				c.Text = if status == "sending" then "GO!" elseif deadline > 0 then Rules.clock(left) else "–"
			end
			if w then
				w.Text = `{waiting} waiting`
			end
		end
	end)

	Audio.music("lobbyMusic")
end

return LobbyUi
