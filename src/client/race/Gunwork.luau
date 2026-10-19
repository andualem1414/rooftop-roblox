--!strict
-- The guns' moving parts, drawn on each client (client/race/Poser says when):
--   the pistol's slide snaps back with every shot; the shotgun's pump is racked after one
--   a reload: the magazine leaves the gun and drops (it bounces on the floor), a fresh one comes from the
--   belt in the other hand and goes in; the shotgun is fed shells, one at a time
-- The real parts are welded to the gun (server/race/Tools), so a local double stands in for each one while
-- it moves (the real part hidden on this screen meanwhile, put back when it's done). Doubles live in the
-- tool, so they go with it, and they copy the gun's cut-away (client/race/Cutaway) from its handle.
local Debris = game:GetService("Debris")

local Gunwork = {}

type Double = {
	tool: Instance,
	orig: BasePart?, -- the real part it stands in for (nil: an extra, like a shell)
	part: BasePart,
	offset: CFrame, -- where it sits: on the gun (from the handle), or in a hand (from the grip)
	back: number, -- slid back along the gun this far (studs)
	hand: BasePart?, -- held in this hand instead of on the gun
	shown: boolean,
	origT: number,
}

local doubles: { [Instance]: { [string]: Double } } = setmetatable({}, { __mode = "k" }) :: any
local SHELL_COLOR = Color3.fromRGB(196, 52, 48)

local function handleOf(tool: Instance): BasePart?
	local h = tool:FindFirstChild("Handle")
	return if h and h:IsA("BasePart") then h else nil
end

local function realPart(tool: Instance, name: string): BasePart?
	local p = tool:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function bare(p: BasePart)
	for _, c in p:GetChildren() do
		c:Destroy() -- (its weld: a double is placed by hand, every frame)
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
end

-- the double standing in for one of the tool's parts (`name`), or an extra ("Shell"); nil if the gun has none
local function doubleOf(tool: Instance, name: string): Double?
	local set = doubles[tool]
	if not set then
		set = {}
		doubles[tool] = set
	end
	local d = set[name]
	if d and d.part.Parent then
		return d
	end
	local handle = handleOf(tool)
	if not handle then
		return nil
	end
	local orig: BasePart? = nil
	local part: BasePart
	if name == "Shell" then
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Cylinder
		s.Size = Vector3.new(0.3, 0.13, 0.13)
		s.Color = SHELL_COLOR
		s.Material = Enum.Material.SmoothPlastic
		part = s
	else
		orig = realPart(tool, name)
		if not orig then
			return nil
		end
		part = (orig :: BasePart):Clone()
	end
	bare(part)
	part.Name = name .. "Double"
	part.Transparency = 1
	part.Parent = tool
	local made: Double = {
		tool = tool,
		orig = orig,
		part = part,
		offset = if orig then handle.CFrame:ToObjectSpace(orig.CFrame) else CFrame.identity,
		back = 0,
		hand = nil,
		shown = false,
		origT = if orig then orig.Transparency else 0,
	}
	set[name] = made
	return made
end

local function show(d: Double, on: boolean)
	if on == d.shown then
		return
	end
	d.shown = on
	local orig = d.orig
	if on then
		if orig then
			d.origT = orig.Transparency
			orig.Transparency = 1
		end
		d.part.Transparency = d.origT
	else
		d.part.Transparency = 1
		if orig then
			orig.Transparency = d.origT
		end
	end
end

-- slide one of the gun's parts back along it (studs toward you), or let it home (0)
function Gunwork.shift(tool: Instance, name: string, back: number)
	local d = doubleOf(tool, name)
	if not d then
		return
	end
	d.back = back
	d.hand = nil
	show(d, back > 0.01)
end

-- the magazine (or a shell) in a hand, held at the hand's grip; nil hand: put away
function Gunwork.hold(tool: Instance, name: string, hand: BasePart?)
	local d = doubleOf(tool, name)
	if not d then
		return
	end
	d.hand = hand
	d.back = 0
	if name == "Shell" then
		d.part.Transparency = if hand then 0 else 1
		d.shown = hand ~= nil
	elseif hand then
		-- (the real one stays hidden while it's out of the gun: magOut)
		d.part.Transparency = d.origT
		d.shown = true
	else
		d.part.Transparency = 1
		d.shown = false
	end
end

-- the magazine comes out: hidden in the gun, and an empty one drops from it to the floor
function Gunwork.magOut(tool: Instance, drop: boolean)
	local mag = realPart(tool, "Mag")
	if not mag or mag:GetAttribute("Out") == true then
		return
	end
	-- (the double that comes back in the other hand, made while the real one still shows: it copies that)
	doubleOf(tool, "Mag")
	mag:SetAttribute("Out", true)
	mag:SetAttribute("OutT", mag.Transparency)
	if drop and mag.Transparency < 1 and mag.LocalTransparencyModifier < 1 then
		local fx = workspace:FindFirstChild("Fx")
		local empty = mag:Clone()
		for _, c in empty:GetChildren() do
			c:Destroy()
		end
		empty.Name = "EmptyMag"
		empty.Anchored = false
		empty.CanCollide = true
		empty.CanQuery = false
		empty.CanTouch = false
		empty.Massless = false
		empty.CollisionGroup = "Debris" -- (it bounces on the floor, never off a climber)
		empty.CFrame = mag.CFrame
		empty.Parent = fx or workspace
		empty.AssemblyLinearVelocity = mag.CFrame.UpVector * -6 + Vector3.new(0, -2, 0)
		empty.AssemblyAngularVelocity = Vector3.new(math.random() * 8 - 4, math.random() * 8 - 4, 0)
		Debris:AddItem(empty, 4)
	end
	mag.Transparency = 1
end

-- the fresh magazine goes in: the gun's own shows again
function Gunwork.magIn(tool: Instance)
	local mag = realPart(tool, "Mag")
	if not mag or mag:GetAttribute("Out") ~= true then
		return
	end
	local t = mag:GetAttribute("OutT")
	mag.Transparency = if type(t) == "number" then t else 0
	mag:SetAttribute("Out", nil)
	mag:SetAttribute("OutT", nil)
	Gunwork.hold(tool, "Mag", nil)
end

-- everything back as the gun was built (a reload cut short, the gun put away, a knock-out)
function Gunwork.reset(tool: Instance)
	Gunwork.magIn(tool)
	local set = doubles[tool]
	if set then
		for _, d in set do
			d.hand = nil
			d.back = 0
			if d.orig then
				show(d, false)
			else
				d.part.Transparency = 1
				d.shown = false
			end
		end
	end
end

-- the doubles follow their guns and hands (call once a frame, after everything has moved)
function Gunwork.render()
	for tool, set in doubles do
		local handle = handleOf(tool)
		if not handle or not tool.Parent then
			doubles[tool] = nil
			continue
		end
		for _, d in set do
			if not d.shown or not d.part.Parent then
				continue
			end
			local hand = d.hand
			if hand and hand.Parent then
				local grip = hand:FindFirstChild(string.gsub(hand.Name, "Hand", "") .. "GripAttachment")
				local at = if grip and grip:IsA("Attachment") then grip.WorldCFrame else hand.CFrame
				-- held in the fist: a magazine sticks out past the thumb (the grip's Y), a shell lies across the
				-- palm (its X)
				d.part.CFrame = at * CFrame.new(0, if d.orig then 0.2 else 0, 0)
			else
				d.part.CFrame = handle.CFrame * d.offset * CFrame.new(0, 0, d.back)
			end
			d.part.LocalTransparencyModifier = handle.LocalTransparencyModifier
		end
	end
end

return Gunwork
