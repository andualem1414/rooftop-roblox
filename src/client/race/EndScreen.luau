--!strict
-- The end of a race, on this client (nothing restarts by itself: server/race/RaceService waits for these):
--   still inside (your team won, another did, or nobody got out): a card with which team got out, how
--     your own climb went (the highest floor you reached, your knock-outs) and a button back to the main
--     screen (the lobby place); in Studio, where there's no lobby, the button is Play again and starts
--     the next race
--   got out: a strip along the bottom: explore the roof, take the skydive from the pad by the sign, or End
--     game (the button, G, or the controller's Y); the skydive itself ends on its own card (SkydiveFlight)
--   Studio only: T while racing puts you on the roof as the winner, to try all of this
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Common = script.Parent.Parent:WaitForChild("Common")
local Ui = require(Common:WaitForChild("Ui")) :: any
local Audio = require(Common:WaitForChild("Audio")) :: any

local player = Players.LocalPlayer
local STUDIO = RunService:IsStudio()

local EndScreen = {}

local function leave(button: TextButton?)
	Audio.play("click")
	if button then
		button.Text = if STUDIO then "Starting…" else "Going back…"
		button.Active = false
	end
	Net.event("Finish"):FireServer("leave")
end

function EndScreen.init()
	local state = ReplicatedStorage:WaitForChild("RaceState")
	local gui = Ui.screen("RaceEnd", 25)

	-- lost: the card
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -110)
	card.Size = UDim2.fromOffset(460, 190)
	card.BackgroundColor3 = Ui.INK
	card.BackgroundTransparency = 0.1
	card.Visible = false
	Ui.corner(card, 14)
	Ui.stroke(card, Ui.ACCENT, 2)
	card.Parent = gui
	local title = Ui.label(card, "", 30, Ui.TITLE)
	title.Position = UDim2.fromOffset(0, 14)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local sub = Ui.label(card, "", 16, Ui.BODY, Ui.DIM)
	sub.Position = UDim2.fromOffset(20, 56)
	sub.Size = UDim2.new(1, -40, 0, 22)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	local mine = Ui.label(card, "", 15, Ui.TEXT, Ui.GOLD)
	mine.Position = UDim2.fromOffset(20, 82)
	mine.Size = UDim2.new(1, -40, 0, 22)
	mine.TextXAlignment = Enum.TextXAlignment.Center
	local home = Ui.button(card, if STUDIO then "Play again" else "Main screen", function() end, Ui.ACCENT)
	home.AnchorPoint = Vector2.new(0.5, 1)
	home.Position = UDim2.new(0.5, 0, 1, -16)
	home.Size = UDim2.fromOffset(220, 48)
	home.Activated:Connect(function()
		leave(home)
	end)

	-- won: the strip
	local strip = Instance.new("Frame")
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -100)
	strip.Size = UDim2.fromOffset(620, 64)
	strip.BackgroundColor3 = Ui.INK
	strip.BackgroundTransparency = 0.2
	strip.Visible = false
	Ui.corner(strip, 12)
	strip.Parent = gui
	local tip =
		Ui.label(strip, "You got out! Explore the roof, or take the skydive from the pad by the sign.", 15, Ui.BODY)
	tip.Position = UDim2.fromOffset(16, 0)
	tip.Size = UDim2.new(1, -200, 1, 0)
	tip.TextYAlignment = Enum.TextYAlignment.Center
	local endGame = Ui.button(strip, "End game (G)", function() end, Ui.ACCENT)
	endGame.AnchorPoint = Vector2.new(1, 0.5)
	endGame.Position = UDim2.new(1, -10, 0.5, 0)
	endGame.Size = UDim2.fromOffset(170, 44)
	endGame.Activated:Connect(function()
		leave(endGame)
	end)

	-- Studio: T wins now (not while typing in the chat)
	if STUDIO then
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			local phase = state:GetAttribute("Phase")
			if not processed and input.KeyCode == Enum.KeyCode.T and (phase == "climb" or phase == "roof") then
				Audio.play("click")
				Net.event("Dev"):FireServer("win")
			end
		end)
	end

	local bound = false
	local function bindEnd(on: boolean)
		if on == bound then
			return
		end
		bound = on
		if on then
			ContextActionService:BindActionAtPriority("RooftopEndGame", function(_, s: Enum.UserInputState)
				if s == Enum.UserInputState.Begin and strip.Visible then
					leave(endGame)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
		else
			ContextActionService:UnbindAction("RooftopEndGame")
		end
	end

	local shownFor = -1
	local function refresh()
		local phase = state:GetAttribute("Phase")
		local winner = state:GetAttribute("Winner")
		local sky = player:GetAttribute("Skydive")
		if phase ~= "over" then
			card.Visible = false
			strip.Visible = false
			bindEnd(false)
			if player:GetAttribute("MenuOpen") == true and shownFor >= 0 then
				player:SetAttribute("MenuOpen", false)
			end
			shownFor = -1
			return
		end
		local race = (state:GetAttribute("Race") :: number?) or 0
		local winTeam = state:GetAttribute("WinnerTeam")
		local ourTeam = type(winTeam) == "number" and winTeam ~= 0 and winTeam == player:GetAttribute("Team")
		if player:GetAttribute("Escaped") == true then
			-- (the skydive has its own screen while it flies)
			strip.Visible = sky ~= "flying" and sky ~= "done"
			card.Visible = false
			bindEnd(strip.Visible)
		elseif shownFor ~= race then
			shownFor = race
			title.Text = if ourTeam
				then "YOUR TEAM GOT OUT"
				elseif type(winner) == "string" and winner ~= "" then `{string.upper(winner)} GOT OUT`
				else "NOBODY GOT OUT"
			sub.Text = if ourTeam
				then "You win: it counts as an escape for the whole team."
				else "Better luck next climb."
			local highest = (player:GetAttribute("Highest") :: number?) or 0
			local kos = (player:GetAttribute("Knockouts") :: number?) or 0
			local reached = if highest >= Config.FLOORS then "the roof" else `floor {highest + 1}`
			mine.Text = `Your climb: up to {reached}  ·  {kos} knock-out{if kos == 1 then "" else "s"}`
			home.Text = if STUDIO then "Play again" else "Main screen"
			home.Active = true
			-- (a moment to see the winner first)
			task.delay(3, function()
				if state:GetAttribute("Phase") == "over" and shownFor == race then
					card.Visible = true
					player:SetAttribute("MenuOpen", true) -- (the cursor, to press it)
				end
			end)
		end
	end
	for _, a in { "Phase", "Winner", "WinnerTeam" } do
		state:GetAttributeChangedSignal(a):Connect(refresh)
	end
	for _, a in { "Escaped", "Skydive" } do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()
end

return EndScreen
