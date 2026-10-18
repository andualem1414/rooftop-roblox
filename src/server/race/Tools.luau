--!strict
-- The weapons as Roblox Tools, so the backpack hotbar (1 / 2, tap, or the controller) switches between
-- your melee weapon and your gun. Models are plain parts for now (phase 4 draws them properly).
-- Each tool carries Weapon (its name) and Slot ("melee" / "gun") attributes; the server reads which one
-- is in hand from the character.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Climbers = require(script.Parent.Climbers)

type Climber = Climbers.Climber

local Tools = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- the handle points forward along -Z of the grip, so models are built along Z
function Tools.make(name: string): Tool
	local w = Weapons[name]
	local tool = Instance.new("Tool")
	tool.Name = w.label
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	tool:SetAttribute("Weapon", name)
	tool:SetAttribute("Slot", w.slot)
	local handle: Part
	if name == "bat" then
		handle = part("Handle", Vector3.new(0.35, 0.35, 1.4), Color3.fromRGB(60, 44, 32), Enum.Material.Wood)
		local barrel = part("Barrel", Vector3.new(0.55, 0.55, 2.4), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		barrel.CFrame = handle.CFrame * CFrame.new(0, 0, -1.9)
		barrel.Parent = tool
		weld(handle, barrel)
		tool.Grip = CFrame.new(0, 0, 0.3) * CFrame.Angles(math.rad(-90), 0, 0)
	elseif name == "sword" then
		handle = part("Handle", Vector3.new(0.3, 0.3, 1.1), Color3.fromRGB(40, 36, 34), Enum.Material.Fabric)
		local guard = part("Guard", Vector3.new(1.2, 0.2, 0.2), Color3.fromRGB(120, 120, 126), Enum.Material.Metal)
		guard.CFrame = handle.CFrame * CFrame.new(0, 0, -0.6)
		guard.Parent = tool
		weld(handle, guard)
		local blade = part("Blade", Vector3.new(0.4, 0.1, 3.4), Color3.fromRGB(196, 200, 206), Enum.Material.Metal)
		blade.CFrame = handle.CFrame * CFrame.new(0, 0, -2.4)
		blade.Parent = tool
		weld(handle, blade)
		tool.Grip = CFrame.new(0, 0, 0.2) * CFrame.Angles(math.rad(-90), 0, 0)
	else -- guns
		handle = part("Handle", Vector3.new(0.3, 0.75, 0.45), Color3.fromRGB(38, 38, 42))
		local slide = part("Slide", Vector3.new(0.32, 0.38, 1.3), Color3.fromRGB(52, 52, 58), Enum.Material.Metal)
		slide.CFrame = handle.CFrame * CFrame.new(0, 0.42, -0.35)
		slide.Parent = tool
		weld(handle, slide)
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(0, 0.42, -1.05)
		muzzle.Parent = handle
		tool.Grip = CFrame.new(0, -0.1, 0)
	end
	handle.Parent = tool
	return tool
end

-- the tool of a slot a climber has (in hand or in the backpack)
local function findTool(c: Climber, slot: string): Tool?
	local places: { Instance } = {}
	if c.model then
		table.insert(places, c.model)
		local stash = c.model:FindFirstChild("Stash")
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
				tool.Parent = c.model:FindFirstChild("Stash") or Tools.stash(c.model)
				if inHand then
					c.fighter.equipped = "none"
				end
			end
		end
	end
end

-- bots: put the weapon of this slot in hand
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
				t.Parent = c.model:FindFirstChild("Stash") or Tools.stash(c.model)
			end
		end
		hum:EquipTool(tool)
	end
end

function Tools.stash(model: Model): Folder
	local f = Instance.new("Folder")
	f.Name = "Stash"
	f.Parent = model
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
