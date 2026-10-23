--!strict
-- Your team, on your screen (shared/Teams; who is on which team and how they're doing comes from the
-- server's roster, RaceState.Roster: server/race/Climbers publish):
--   teammates: their ink outline (client/race/Fx) turns your team's colour and shows through walls, with
--     their name over their head in that colour (Roblox's own name tag is hidden for them)
--   everyone else: a small chip of their team's colour over their head, only where you can see them
--   the HUD's team panel (Teammates.panel): your team's name and each member's floor, or Down / Out /
--     Got out
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Teams = require(ReplicatedStorage.Shared.Teams)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any

local player = Players.LocalPlayer

local Teammates = {}

local INK = Color3.fromRGB(22, 19, 28)
local REFRESH = 0.25

local function color(team: number): Color3
	local rgb = Teams.RGB[team]
	return if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else Ui.DIM
end

local function myTeam(): number
	local t = player:GetAttribute("Team")
	return if type(t) == "number" then t else 0
end

-- the roster's entries, by team (yours first in the panel), each with its body
type Entry = { name: string, team: number, floor: number, state: string, userId: number, body: Model? }
local function entries(roster: Instance): { Entry }
	local out: { Entry } = {}
	for _, e in roster:GetChildren() do
		local body = e:FindFirstChild("Body") :: ObjectValue?
		local model = body and body.Value
		table.insert(out, {
			name = (e:GetAttribute("Name") :: string?) or e.Name,
			team = (e:GetAttribute("Team") :: number?) or 0,
			floor = (e:GetAttribute("Floor") :: number?) or 0,
			state = (e:GetAttribute("State") :: string?) or "up",
			userId = (e:GetAttribute("UserId") :: number?) or 0,
			body = if model and model:IsA("Model") then model else nil,
		})
	end
	return out
end

---------------------------------------------------------------- over their heads

local tags: { [Model]: BillboardGui } = {}

local function tagFor(model: Model, ally: boolean, team: number, name: string): BillboardGui?
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local tag = tags[model]
	if tag and tag:GetAttribute("Ally") ~= ally then
		tag:Destroy()
		tag = nil
	end
	if not tag then
		local b = Instance.new("BillboardGui")
		b.Name = "TeamTag"
		b:SetAttribute("Ally", ally)
		b.Adornee = head
		b.LightInfluence = 0
		b.ResetOnSpawn = false
		if ally then
			b.Size = UDim2.fromOffset(160, 26)
			b.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
			b.AlwaysOnTop = true
			b.MaxDistance = math.huge
			local l = Instance.new("TextLabel")
			l.Name = "Name"
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Font = Ui.TEXT
			l.TextSize = 15
			l.TextStrokeColor3 = INK
			l.TextStrokeTransparency = 0.2
			l.Parent = b
		else
			b.Size = UDim2.fromOffset(18, 6)
			b.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
			b.AlwaysOnTop = false
			b.MaxDistance = 40 * Config.M
			local chip = Instance.new("Frame")
			chip.Name = "Chip"
			chip.Size = UDim2.fromScale(1, 1)
			chip.BorderSizePixel = 0
			Ui.corner(chip, 3)
			Ui.stroke(chip, INK, 1)
			chip.Parent = b
		end
		b.Parent = player:WaitForChild("PlayerGui")
		tags[model] = b
		tag = b
	end
	local t = tag :: BillboardGui
	local label = t:FindFirstChild("Name") :: TextLabel?
	if label then
		label.Text = name
		label.TextColor3 = color(team)
	end
	local chip = t:FindFirstChild("Chip") :: Frame?
	if chip then
		chip.BackgroundColor3 = color(team)
	end
	return t
end

-- a teammate's ink outline in the team's colour, on top of walls; anyone else's back to plain ink
local function outline(model: Model, ally: boolean, team: number)
	local ink = model:FindFirstChild("Ink")
	if not ink or not ink:IsA("Highlight") then
		return
	end
	local want = if ally then color(team) else INK
	local depth = if ally then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	if ink.OutlineColor ~= want then
		ink.OutlineColor = want
	end
	if ink.DepthMode ~= depth then
		ink.DepthMode = depth
	end
end

local function refreshMarks(roster: Instance)
	local mine = myTeam()
	local seen: { [Model]: boolean } = {}
	for _, e in entries(roster) do
		local model = e.body
		if not model or model == player.Character or not model.Parent then
			continue
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local ally = mine ~= 0 and e.team == mine
		local up = e.state == "up" or e.state == "escaped"
		seen[model] = true
		outline(model, ally and up, e.team)
		local tag = tagFor(model, ally, e.team, e.name)
		if tag then
			tag.Enabled = up and e.team ~= 0
		end
		if hum then
			-- (a teammate's name is on our own tag)
			local display = if ally
				then Enum.HumanoidDisplayDistanceType.None
				else Enum.HumanoidDisplayDistanceType.Viewer
			if hum.DisplayDistanceType ~= display then
				hum.DisplayDistanceType = display
			end
		end
	end
	for model, tag in tags do
		if not seen[model] then
			tag:Destroy()
			tags[model] = nil
		end
	end
end

---------------------------------------------------------------- the HUD's team panel

local ROW = 22

-- the team panel, on the HUD's own ScreenGui (it hides with the HUD in set pieces)
function Teammates.panel(gui: ScreenGui)
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local plate = Instance.new("Frame")
	plate.Name = "Team"
	plate.Size = UDim2.fromOffset(220, 30 + Config.TEAM_SIZE * ROW + 8)
	-- above Settings and health (the chat has the top left); on a touch screen, where the stick isn't
	plate.AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1)
	plate.Position = if touch then UDim2.fromOffset(16, 60) else UDim2.new(0, 20, 1, -112)
	plate.BackgroundColor3 = INK
	plate.BackgroundTransparency = 0.3
	plate.BorderSizePixel = 0
	plate.Visible = false
	Ui.corner(plate, 12)
	plate.Parent = gui
	local title = Ui.label(plate, "", 20, Ui.TITLE)
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.TextWrapped = false
	local rows: { { dot: Frame, name: TextLabel, status: TextLabel, frame: Frame } } = {}
	local function row(i: number)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Position = UDim2.fromOffset(12, 32 + (i - 1) * ROW)
		f.Size = UDim2.new(1, -24, 0, ROW)
		f.Parent = plate
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.fromScale(0, 0.5)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BorderSizePixel = 0
		Ui.corner(dot, 5)
		dot.Parent = f
		local name = Ui.label(f, "", 14, Ui.TEXT)
		name.Position = UDim2.fromOffset(18, 0)
		name.Size = UDim2.new(1, -96, 1, 0)
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextYAlignment = Enum.TextYAlignment.Center
		local status = Ui.label(f, "", 13, Ui.BODY, Ui.DIM)
		status.AnchorPoint = Vector2.new(1, 0)
		status.Position = UDim2.fromScale(1, 0)
		status.Size = UDim2.new(0, 78, 1, 0)
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.TextYAlignment = Enum.TextYAlignment.Center
		status.TextWrapped = false
		rows[i] = { dot = dot, name = name, status = status, frame = f }
		return rows[i]
	end

	local roster = ReplicatedStorage:WaitForChild("RaceState"):WaitForChild("Roster")
	task.spawn(function()
		while gui.Parent do
			local mine = myTeam()
			local team: { Entry } = {}
			if mine ~= 0 then
				for _, e in entries(roster) do
					if e.team == mine then
						table.insert(team, e)
					end
				end
			end
			-- you first, then the others by name
			table.sort(team, function(a, b)
				local ma, mb = a.userId == player.UserId, b.userId == player.UserId
				if ma ~= mb then
					return ma
				end
				return a.name < b.name
			end)
			plate.Visible = #team > 0
			plate.Size = UDim2.fromOffset(220, 30 + math.max(#team, 1) * ROW + 8)
			title.Text = string.upper(Teams.label(mine))
			title.TextColor3 = color(mine)
			for i, e in team do
				local r = rows[i] or row(i)
				r.frame.Visible = true
				local up = e.state == "up" or e.state == "escaped"
				r.dot.BackgroundColor3 = color(mine)
				r.dot.BackgroundTransparency = if up then 0 else 0.7
				r.name.Text = if e.userId == player.UserId then `{e.name} (you)` else e.name
				r.name.TextColor3 = if up then Ui.CHALK else Ui.DIM
				r.status.Text = if e.state == "escaped"
					then "Got out"
					elseif e.state == "down" then "Down"
					elseif e.state == "out" then "Out"
					elseif e.state == "gone" then "Left"
					elseif e.floor >= Config.FLOORS then "The roof"
					else `Floor {e.floor + 1}`
				r.status.TextColor3 = if e.state == "escaped" then Ui.GOLD elseif up then Ui.DIM else Ui.RED
			end
			for i = #team + 1, #rows do
				rows[i].frame.Visible = false
			end
			task.wait(REFRESH)
		end
	end)
end

function Teammates.init()
	local roster = ReplicatedStorage:WaitForChild("RaceState"):WaitForChild("Roster")
	task.spawn(function()
		while true do
			local ok, err = pcall(refreshMarks, roster)
			if not ok then
				warn("[Rooftop] team marks:", err)
			end
			task.wait(REFRESH)
		end
	end)
end

return Teammates
