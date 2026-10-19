--!strict
-- The weapons as Roblox Tools, so the backpack hotbar (1 / 2, tap, or the controller) switches between
-- your melee weapon and your gun. Models are built from parts here (phase 4 may swap in drawn ones).
-- Each tool carries Weapon (its name) and Slot ("melee" / "gun") attributes; the server reads which one
-- is in hand from the character.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Climbers = require(script.Parent.Climbers)

type Climber = Climbers.Climber

local Tools = {}

-- a bot's other weapon waits here, outside the world (in the world its loose parts would fall away)
local stashes: { [Model]: Folder } = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	return p
end

-- a piece of the model, placed relative to the handle (at the origin) and welded to it
local function piece(tool: Tool, handle: BasePart, p: Part, at: CFrame)
	p.CFrame = at
	p.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
end

local function attachment(handle: BasePart, name: string, pos: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = handle
end

-- a cylinder along Z (Roblox cylinders run along X)
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

-- each gun's accent colour (the client's Fx uses the same ones for its flashes and tracers)
local ACCENT = {
	pistol = Color3.fromRGB(255, 140, 50),
	rifle = Color3.fromRGB(90, 200, 255),
	smg = Color3.fromRGB(170, 255, 90),
	shotgun = Color3.fromRGB(255, 80, 110),
}
local DARK = Color3.fromRGB(34, 34, 40)
local DARKER = Color3.fromRGB(26, 26, 30)
local STEEL = Color3.fromRGB(150, 156, 166)
local BARREL = Color3.fromRGB(60, 60, 66)

-- the guns past the pistol, each from a handful of parts round its grip (the handle). Returns the muzzle's
-- and the ejection port's positions.
local function longGun(tool: Tool, handle: BasePart, name: string, accent: Color3): (Vector3, Vector3)
	local function add(
		n: string,
		size: Vector3,
		at: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	)
		piece(tool, handle, part(n, size, color, material, shape), at)
	end
	if name == "rifle" then
		add("Receiver", Vector3.new(0.34, 0.42, 2.0), CFrame.new(0, 0.5, -0.55), DARK)
		add("Handguard", Vector3.new(0.3, 0.32, 1.1), CFrame.new(0, 0.48, -2.05), DARKER, Enum.Material.Fabric)
		add(
			"Barrel",
			Vector3.new(1.3, 0.16, 0.16),
			CFrame.new(0, 0.55, -3.0) * ALONG_Z,
			BARREL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		add("Stock", Vector3.new(0.26, 0.5, 0.65), CFrame.new(0, 0.38, 0.45), DARK)
		add(
			"Mag",
			Vector3.new(0.22, 0.75, 0.36),
			CFrame.new(0, 0.05, -0.95) * CFrame.Angles(math.rad(12), 0, 0),
			accent
		)
		add("Rail", Vector3.new(0.12, 0.1, 1.3), CFrame.new(0, 0.76, -0.6), STEEL, Enum.Material.Metal)
		add("Stripe", Vector3.new(0.36, 0.06, 1.2), CFrame.new(0, 0.42, -0.6), accent, Enum.Material.Neon)
		add("Sight", Vector3.new(0.1, 0.14, 0.1), CFrame.new(0, 0.88, -0.3), accent, Enum.Material.Neon)
		return Vector3.new(0, 0.55, -3.7), Vector3.new(0.2, 0.62, -0.45)
	elseif name == "smg" then
		add("Body", Vector3.new(0.32, 0.4, 1.35), CFrame.new(0, 0.5, -0.35), DARK)
		add(
			"Barrel",
			Vector3.new(0.45, 0.14, 0.14),
			CFrame.new(0, 0.55, -1.25) * ALONG_Z,
			BARREL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		add("Mag", Vector3.new(0.2, 0.95, 0.28), CFrame.new(0, -0.2, -0.75), accent)
		add("Stock", Vector3.new(0.08, 0.08, 0.7), CFrame.new(0, 0.55, 0.55), STEEL, Enum.Material.Metal)
		add("Butt", Vector3.new(0.08, 0.4, 0.08), CFrame.new(0, 0.38, 0.9), STEEL, Enum.Material.Metal)
		add("Stripe", Vector3.new(0.34, 0.06, 0.9), CFrame.new(0, 0.62, -0.4), accent, Enum.Material.Neon)
		return Vector3.new(0, 0.55, -1.5), Vector3.new(0.18, 0.62, -0.3)
	end
	-- the shotgun: a long barrel over a magazine tube, a pump, a stock
	add("Receiver", Vector3.new(0.32, 0.4, 0.95), CFrame.new(0, 0.5, -0.25), DARK)
	add(
		"Barrel",
		Vector3.new(2.2, 0.2, 0.2),
		CFrame.new(0, 0.62, -1.8) * ALONG_Z,
		BARREL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	add(
		"Tube",
		Vector3.new(1.6, 0.16, 0.16),
		CFrame.new(0, 0.42, -1.5) * ALONG_Z,
		BARREL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	add(
		"Pump",
		Vector3.new(0.32, 0.3, 0.7),
		CFrame.new(0, 0.44, -1.35),
		Color3.fromRGB(120, 80, 50),
		Enum.Material.Wood
	)
	add(
		"Stock",
		Vector3.new(0.28, 0.52, 0.7),
		CFrame.new(0, 0.36, 0.45),
		Color3.fromRGB(120, 80, 50),
		Enum.Material.Wood
	)
	add("Stripe", Vector3.new(0.34, 0.06, 0.8), CFrame.new(0, 0.66, -0.25), accent, Enum.Material.Neon)
	add("Bead", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0.76, -2.85), accent, Enum.Material.Neon)
	return Vector3.new(0, 0.62, -2.95), Vector3.new(0.18, 0.6, -0.25)
end

-- Models are built along -Z from the handle. Grips: a gun's barrel runs along your forearm with its
-- top toward your thumb (an unrotated grip on R15); a bat or sword sticks out of your fist, so its grip
-- is turned -90° about X, offset so your hand sits near the knob.
function Tools.make(name: string): Tool
	local w = Weapons[name]
	local tool = Instance.new("Tool")
	tool.Name = w.label
	tool.CanBeDropped = false
	-- clicks and taps don't fire it by themselves: the race client's Controls decide (holding the
	-- button keeps a full-auto gun firing; on a touch screen only the fire button shoots)
	tool.ManualActivationOnly = true
	tool:SetAttribute("Weapon", name)
	tool:SetAttribute("Slot", w.slot)
	local handle: Part
	if name == "bat" then
		-- ash barrel, a red ring, black taped grip, knob
		handle = part("Handle", Vector3.new(0.32, 0.32, 1.3), Color3.fromRGB(28, 26, 30), Enum.Material.Fabric)
		piece(
			tool,
			handle,
			part(
				"Knob",
				Vector3.new(0.18, 0.46, 0.46),
				Color3.fromRGB(40, 34, 30),
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			),
			CFrame.new(0, 0, 0.7) * ALONG_Z
		)
		piece(
			tool,
			handle,
			part(
				"Taper",
				Vector3.new(1.2, 0.42, 0.42),
				Color3.fromRGB(214, 176, 120),
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			),
			CFrame.new(0, 0, -1.2) * ALONG_Z
		)
		piece(
			tool,
			handle,
			part(
				"Barrel",
				Vector3.new(1.9, 0.58, 0.58),
				Color3.fromRGB(226, 188, 132),
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			),
			CFrame.new(0, 0, -2.65) * ALONG_Z
		)
		piece(
			tool,
			handle,
			part(
				"Ring",
				Vector3.new(0.14, 0.6, 0.6),
				Color3.fromRGB(210, 52, 48),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			),
			CFrame.new(0, 0, -2.0) * ALONG_Z
		)
		piece(
			tool,
			handle,
			part(
				"Cap",
				Vector3.new(0.1, 0.56, 0.56),
				Color3.fromRGB(196, 158, 104),
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			),
			CFrame.new(0, 0, -3.62) * ALONG_Z
		)
		attachment(handle, "TrailA", Vector3.new(0, 0, -1.6))
		attachment(handle, "TrailB", Vector3.new(0, 0, -3.6))
		tool.Grip = CFrame.new(0, 0, 0.35) * CFrame.Angles(math.rad(-90), 0, 0)
	elseif name == "sword" then
		-- wrapped grip, gold guard and pommel, steel blade with a glowing edge
		handle = part("Handle", Vector3.new(0.26, 0.26, 1.0), Color3.fromRGB(34, 28, 36), Enum.Material.Fabric)
		piece(
			tool,
			handle,
			part(
				"Pommel",
				Vector3.new(0.34, 0.34, 0.34),
				Color3.fromRGB(230, 180, 70),
				Enum.Material.Metal,
				Enum.PartType.Ball
			),
			CFrame.new(0, 0, 0.6)
		)
		piece(
			tool,
			handle,
			part("Guard", Vector3.new(1.3, 0.18, 0.22), Color3.fromRGB(230, 180, 70), Enum.Material.Metal),
			CFrame.new(0, 0, -0.58)
		)
		piece(
			tool,
			handle,
			part("Blade", Vector3.new(0.36, 0.08, 3.5), Color3.fromRGB(205, 212, 222), Enum.Material.Metal),
			CFrame.new(0, 0, -2.4)
		)
		piece(
			tool,
			handle,
			part("Edge", Vector3.new(0.06, 0.1, 3.3), Color3.fromRGB(110, 230, 255), Enum.Material.Neon),
			CFrame.new(0.18, 0, -2.45)
		)
		piece(
			tool,
			handle,
			part("Tip", Vector3.new(0.26, 0.08, 0.3), Color3.fromRGB(205, 212, 222), Enum.Material.Metal),
			CFrame.new(0, 0, -4.25) * CFrame.Angles(0, math.rad(45), 0)
		)
		attachment(handle, "TrailA", Vector3.new(0, 0, -1.0))
		attachment(handle, "TrailB", Vector3.new(0, 0, -4.2))
		tool.Grip = CFrame.new(0, 0, 0.2) * CFrame.Angles(math.rad(-90), 0, 0)
	elseif name == "pistol" then -- the handle is the grip; the slide sits above it (+Y) and runs forward (-Z)
		local accent = ACCENT.pistol
		handle = part("Handle", Vector3.new(0.28, 0.72, 0.42), DARK)
		piece(
			tool,
			handle,
			part("Frame", Vector3.new(0.3, 0.26, 1.15), Color3.fromRGB(40, 40, 46)),
			CFrame.new(0, 0.36, -0.3)
		)
		piece(
			tool,
			handle,
			part("Slide", Vector3.new(0.32, 0.26, 1.3), STEEL, Enum.Material.Metal),
			CFrame.new(0, 0.6, -0.36)
		)
		piece(
			tool,
			handle,
			part("Stripe", Vector3.new(0.34, 0.06, 0.9), accent, Enum.Material.Neon),
			CFrame.new(0, 0.52, -0.4)
		)
		piece(
			tool,
			handle,
			part("Barrel", Vector3.new(0.18, 0.2, 0.2), BARREL, Enum.Material.Metal, Enum.PartType.Cylinder),
			CFrame.new(0, 0.58, -1.08) * ALONG_Z
		)
		piece(
			tool,
			handle,
			part("Sight", Vector3.new(0.08, 0.1, 0.1), accent, Enum.Material.Neon),
			CFrame.new(0, 0.78, -0.95)
		)
		piece(tool, handle, part("Mag", Vector3.new(0.24, 0.12, 0.36), accent), CFrame.new(0, -0.38, 0.02))
		attachment(handle, "Muzzle", Vector3.new(0, 0.58, -1.2))
		attachment(handle, "Eject", Vector3.new(0.18, 0.66, -0.3))
		tool.Grip = CFrame.new(0, 0.05, 0)
	else -- the long guns: the grip in your hand, the barrel along your forearm and on past it
		handle = part("Handle", Vector3.new(0.28, 0.72, 0.42), DARK)
		local muzzle, eject = longGun(tool, handle, name, ACCENT[name] or ACCENT.pistol)
		attachment(handle, "Muzzle", muzzle)
		attachment(handle, "Eject", eject)
		tool.Grip = CFrame.new(0, 0.05, 0)
	end
	handle.Parent = tool
	return tool
end

-- the tool of a slot a climber has (in hand or in the backpack)
local function findTool(c: Climber, slot: string): Tool?
	local places: { Instance } = {}
	if c.model then
		table.insert(places, c.model)
		local stash = stashes[c.model]
		if stash then
			table.insert(places, stash)
		end
	end
	if c.player then
		local bp = c.player:FindFirstChildOfClass("Backpack")
		if bp then
			table.insert(places, bp)
		end
	end
	for _, place in places do
		for _, t in place:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("Slot") == slot then
				return t
			end
		end
	end
	return nil
end

-- make the climber's tools match what their fighter carries (after a pickup, a swap, coming to)
function Tools.sync(c: Climber)
	local f = c.fighter
	for _, slot in { "melee", "gun" } do
		local want: string? = if slot == "melee" then f.melee else f.gun
		local have = findTool(c, slot)
		if have and have:GetAttribute("Weapon") == want then
			continue
		end
		local inHand = have ~= nil and have.Parent == c.model
		if have then
			have:Destroy()
		end
		if want then
			local tool = Tools.make(want)
			if c.kind == "player" and c.player and not inHand then
				tool.Parent = c.player:FindFirstChildOfClass("Backpack")
			elseif c.kind == "player" and c.model then
				tool.Parent = c.model -- it replaces the one in hand
			elseif c.model then
				-- bots keep both in a stash and take one in hand (Tools.equip)
				tool.Parent = Tools.stash(c.model)
				if inHand then
					c.fighter.equipped = "none"
				end
			end
		end
	end
end

-- bots: put the weapon of this slot in hand (the other one goes to the bot's stash)
function Tools.equip(c: Climber, slot: "melee" | "gun")
	local hum = c.humanoid
	if not hum or Tools.inHand(c) == slot then
		return
	end
	local tool = findTool(c, slot)
	if tool and c.model then
		-- a bot carries its other weapon on its back (out of the model's hand)
		for _, t in c.model:GetChildren() do
			if t:IsA("Tool") and t ~= tool then
				t.Parent = nil
				t.Parent = Tools.stash(c.model)
			end
		end
		hum:EquipTool(tool)
	end
end

function Tools.stash(model: Model): Folder
	local have = stashes[model]
	if have then
		return have
	end
	local root = ServerStorage:FindFirstChild("BotStashes") or Instance.new("Folder")
	root.Name = "BotStashes"
	root.Parent = ServerStorage
	local f = Instance.new("Folder")
	f.Name = model.Name
	f.Parent = root
	stashes[model] = f
	model.Destroying:Connect(function()
		stashes[model] = nil
		f:Destroy()
	end)
	return f
end

-- which slot is in hand right now
function Tools.inHand(c: Climber): "melee" | "gun" | "none"
	local model = c.model
	if not model then
		return "none"
	end
	local tool = model:FindFirstChildOfClass("Tool")
	if not tool then
		return "none"
	end
	local slot = tool:GetAttribute("Slot")
	if slot == "melee" or slot == "gun" then
		return slot
	end
	return "none"
end

-- the barrel tip of the gun in hand, if there is one
function Tools.muzzle(c: Climber): Vector3?
	local model = c.model
	local tool = model and model:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local m = handle and handle:FindFirstChild("Muzzle")
	if m and m:IsA("Attachment") then
		return m.WorldPosition
	end
	return nil
end

-- what the HUD shows: the player's weapons and ammo, as attributes on the Player
function Tools.publish(c: Climber)
	local p = c.player
	if not p then
		return
	end
	local f = c.fighter
	p:SetAttribute("Melee", f.melee)
	p:SetAttribute("Gun", f.gun or "")
	p:SetAttribute("Mag", f.mag)
	p:SetAttribute("Reserve", f.reserve)
	p:SetAttribute("Reloading", f.reloadT > 0)
	p:SetAttribute("Health", math.floor(f.hp + 0.5))
	p:SetAttribute("Floor", c.floor)
	p:SetAttribute("Knockouts", c.knockouts)
end

-- the starting loadout, as tools
function Tools.ensureLoadout(c: Climber)
	Combat.loadout(c.fighter)
	Tools.sync(c)
end

return Tools
