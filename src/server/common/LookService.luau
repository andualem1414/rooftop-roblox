--!strict
-- Puts a look (shared/Looks) on a character: the outfit's colours on the body (top, sleeves, gloves,
-- trousers, boots), the avatar's own clothing taken off, and a hat and extras built from parts, welded on
-- at the body's own attachments so they sit right on any R15 avatar. Your face, skin and hair stay
-- yours (a hood or a beanie hides the hair). "Your avatar" changes nothing; going back to it needs a fresh
-- character (the lobby respawns you).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Looks = require(ReplicatedStorage.Shared.Looks)

type Look = Looks.Look

local LookService = {}

-- avatar items a look replaces: clothing (classic and layered), and hats / hair / back items when the look
-- brings its own
local CLOTHES = {
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.DressSkirt] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
}

local function hex(s: string?, fallback: Color3): Color3
	if not s then
		return fallback
	end
	local ok, c = pcall(Color3.fromHex, s)
	return if ok then c else fallback
end

local function attachmentCF(model: Model, partName: string, name: string): CFrame?
	local p = model:FindFirstChild(partName)
	local a = p and p:FindFirstChild(name)
	if a and a:IsA("Attachment") then
		return a.WorldCFrame
	end
	return nil
end

-- a piece of the look, welded to a body part
local function bit(
	folder: Folder,
	to: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	p.Parent = folder
	return p
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) turned upright
local FORWARD = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis turned to point forward (Z)

local function hat(model: Model, folder: Folder, look: Look)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or not look.hat then
		return
	end
	local hs = head.Size
	local c = head.CFrame
	local color = hex(look.hatColor, Color3.fromRGB(60, 60, 70))
	local accent = hex(look.accent, color)
	local kind = look.hat
	if kind == "cap" then
		bit(
			folder,
			head,
			"Cap",
			Vector3.new(hs.X * 1.06, hs.Y * 0.62, hs.Z * 1.06),
			c * CFrame.new(0, hs.Y * 0.3, 0),
			color,
			Enum.PartType.Ball
		)
		bit(
			folder,
			head,
			"Bill",
			Vector3.new(hs.X * 0.78, 0.08, hs.Z * 0.5),
			c * CFrame.new(0, hs.Y * 0.28, -hs.Z * 0.62),
			color
		)
	elseif kind == "beanie" then
		bit(
			folder,
			head,
			"Beanie",
			Vector3.new(hs.X * 1.1, hs.Y * 0.8, hs.Z * 1.1),
			c * CFrame.new(0, hs.Y * 0.32, 0),
			color,
			Enum.PartType.Ball
		)
		bit(
			folder,
			head,
			"Cuff",
			Vector3.new(hs.Y * 0.18, hs.X * 1.12, hs.Z * 1.12),
			c * CFrame.new(0, hs.Y * 0.16, 0) * VERTICAL,
			color,
			Enum.PartType.Cylinder
		)
		bit(
			folder,
			head,
			"Pompom",
			Vector3.new(0.42, 0.42, 0.42),
			c * CFrame.new(0, hs.Y * 0.78, 0),
			accent,
			Enum.PartType.Ball
		)
	elseif kind == "hood" then
		-- a shell over the top and back of the head, open in front
		bit(folder, head, "Hood", hs * 1.32, c * CFrame.new(0, hs.Y * 0.08, hs.Z * 0.26), color, Enum.PartType.Ball)
	elseif kind == "bandana" or kind == "headband" then
		local h = if kind == "bandana" then hs.Y * 0.3 else hs.Y * 0.14
		bit(
			folder,
			head,
			"Band",
			Vector3.new(h, hs.X * 1.06, hs.Z * 1.06),
			c * CFrame.new(0, hs.Y * 0.22, 0) * VERTICAL,
			color,
			Enum.PartType.Cylinder
		)
		if kind == "bandana" then
			bit(folder, head, "Knot", Vector3.new(0.3, 0.3, 0.3), c * CFrame.new(0, hs.Y * 0.2, hs.Z * 0.55), color)
			bit(
				folder,
				head,
				"Tails",
				Vector3.new(0.22, 0.45, 0.06),
				c * CFrame.new(0.06, hs.Y * 0.0, hs.Z * 0.58),
				color
			)
		end
	elseif kind == "goggles" then
		bit(
			folder,
			head,
			"Strap",
			Vector3.new(hs.Y * 0.12, hs.X * 1.05, hs.Z * 1.05),
			c * CFrame.new(0, hs.Y * 0.3, 0) * VERTICAL,
			color,
			Enum.PartType.Cylinder
		)
		for _, side in { -1, 1 } do
			local at = c * CFrame.new(side * hs.X * 0.2, hs.Y * 0.32, -hs.Z * 0.52) * FORWARD
			bit(
				folder,
				head,
				"Lens",
				Vector3.new(0.16, 0.34, 0.34),
				at,
				Color3.fromRGB(120, 200, 220),
				Enum.PartType.Cylinder,
				Enum.Material.Glass
			)
			bit(
				folder,
				head,
				"Rim",
				Vector3.new(0.12, 0.4, 0.4),
				at * CFrame.new(0.03, 0, 0),
				accent,
				Enum.PartType.Cylinder,
				Enum.Material.Metal
			)
		end
	end
end

local function extras(model: Model, folder: Folder, look: Look)
	local torso = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local ts = torso.Size
	local color = hex(look.extraColor, Color3.fromRGB(80, 70, 60))
	local accent = hex(look.accent, color)
	if look.extra == "backpack" then
		local back = attachmentCF(model, "UpperTorso", "BodyBackAttachment")
			or torso.CFrame * CFrame.new(0, 0, ts.Z / 2)
		bit(folder, torso, "Pack", Vector3.new(ts.X * 0.7, ts.Y * 0.8, 0.5), back * CFrame.new(0, -0.05, 0.27), color)
		bit(
			folder,
			torso,
			"Flap",
			Vector3.new(ts.X * 0.72, ts.Y * 0.28, 0.54),
			back * CFrame.new(0, ts.Y * 0.26, 0.28),
			accent
		)
		for _, side in { -1, 1 } do
			bit(
				folder,
				torso,
				"Strap",
				Vector3.new(0.14, ts.Y * 0.9, 0.06),
				torso.CFrame * CFrame.new(side * ts.X * 0.24, 0, -ts.Z * 0.51),
				accent
			)
		end
	elseif look.extra == "satchel" and lower and lower:IsA("BasePart") then
		local ls = lower.Size
		bit(
			folder,
			lower,
			"Satchel",
			Vector3.new(0.3, 0.75, 0.9),
			lower.CFrame * CFrame.new(ls.X * 0.62, -0.1, 0),
			color
		)
		bit(
			folder,
			torso,
			"Strap",
			Vector3.new(0.14, ts.Y * 1.45, 0.06),
			torso.CFrame * CFrame.new(0, 0, -ts.Z * 0.52) * CFrame.Angles(0, 0, math.rad(-38)),
			accent
		)
	elseif look.extra == "scarf" then
		local neck = attachmentCF(model, "UpperTorso", "NeckAttachment") or torso.CFrame * CFrame.new(0, ts.Y / 2, 0)
		bit(
			folder,
			torso,
			"Scarf",
			Vector3.new(0.38, ts.X * 0.62, ts.Z * 1.18),
			neck * CFrame.new(0, -0.12, 0) * VERTICAL,
			color,
			Enum.PartType.Cylinder
		)
		bit(
			folder,
			torso,
			"Tail",
			Vector3.new(0.3, 0.85, 0.1),
			neck * CFrame.new(-ts.X * 0.18, -0.55, -ts.Z * 0.56),
			color
		)
	end
	if look.kneepads then
		for _, side in { "Left", "Right" } do
			local leg = model:FindFirstChild(side .. "LowerLeg")
			local knee = attachmentCF(model, side .. "LowerLeg", side .. "KneeRigAttachment")
			if leg and leg:IsA("BasePart") and knee then
				local s = leg.Size
				bit(
					folder,
					leg,
					"Kneepad",
					Vector3.new(s.X * 0.95, 0.42, 0.18),
					knee * CFrame.new(0, -0.12, -s.Z * 0.55),
					accent
				)
			end
		end
	end
end

-- put a look on a character (call it once the avatar has loaded)
function LookService.apply(model: Model, id: string?)
	local old = model:FindFirstChild("Look")
	if old then
		old:Destroy()
	end
	local look = Looks.byId(id)
	if not look or look.id == Looks.DEFAULT then
		return
	end
	-- off with the avatar's clothing (and what the look's own hat or pack replaces)
	for _, d in model:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("Accessory") then
			local t = d.AccessoryType
			local hides = CLOTHES[t]
				or (look.hat ~= nil and t == Enum.AccessoryType.Hat)
				or ((look.hat == "hood" or look.hat == "beanie") and t == Enum.AccessoryType.Hair)
				or (look.extra == "backpack" and t == Enum.AccessoryType.Back)
				or (look.extra == "scarf" and t == Enum.AccessoryType.Neck)
			if hides then
				d:Destroy()
			end
		end
	end
	local head = model:FindFirstChild("Head")
	local skin = if head and head:IsA("BasePart") then head.Color else Color3.fromRGB(226, 187, 152)
	local top = hex(look.top, Color3.fromRGB(90, 90, 100))
	local sleeve = hex(look.sleeve, top)
	local pants = hex(look.pants, Color3.fromRGB(40, 42, 48))
	local colors: { [string]: Color3 } = {
		UpperTorso = top,
		LowerTorso = pants,
		LeftUpperArm = sleeve,
		RightUpperArm = sleeve,
		LeftLowerArm = sleeve,
		RightLowerArm = sleeve,
		LeftHand = hex(look.gloves, skin),
		RightHand = hex(look.gloves, skin),
		LeftUpperLeg = pants,
		RightUpperLeg = pants,
		LeftLowerLeg = pants,
		RightLowerLeg = pants,
		LeftFoot = hex(look.boots, pants),
		RightFoot = hex(look.boots, pants),
	}
	for name, color in colors do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = color
			if p:IsA("MeshPart") then
				-- (an avatar body with a painted texture would hide the colour)
				pcall(function()
					(p :: MeshPart).TextureID = ""
				end)
			end
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Look"
	hat(model, folder, look)
	extras(model, folder, look)
	folder.Parent = model
end

-- wait (a little) for a player's avatar to finish loading, then put the look on
function LookService.applyWhenLoaded(player: Player, model: Model, id: string?)
	local t = 0
	while not player:HasAppearanceLoaded() and t < 4 do
		t += task.wait(0.1)
	end
	if model.Parent then
		LookService.apply(model, id)
	end
end

return LookService
