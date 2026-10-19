--!strict
-- Builds the valley's terrain on this client from the shared recipe (Valley.luau). Run by the loading
-- screen: terrain built locally is there in a second or two, where a server's terrain would take far
-- longer to reach each player. The server never touches the terrain.
local Valley = require(script.Parent.Valley)

local ValleyTerrain = {}

local COLORS = {
	Grass = Color3.fromRGB(56, 96, 74),
	LeafyGrass = Color3.fromRGB(48, 84, 70),
	Ground = Color3.fromRGB(92, 70, 60),
	Rock = Color3.fromRGB(104, 98, 130),
	Slate = Color3.fromRGB(84, 80, 108),
	Snow = Color3.fromRGB(226, 234, 255),
	Mud = Color3.fromRGB(60, 50, 46),
}

local function material(name: string): Enum.Material
	return (Enum.Material :: any)[name]
end

-- progress(k): 0..1 as it goes (optional)
function ValleyTerrain.build(progress: ((number) -> ())?)
	local T = workspace.Terrain
	T:Clear()
	for name, color in COLORS do
		T:SetMaterialColor(material(name), color)
	end
	T.WaterColor = Color3.fromRGB(40, 64, 120)
	T.WaterReflectance = 1
	T.WaterTransparency = 0.35
	T.WaterWaveSize = 0.08
	T.WaterWaveSpeed = 6
	local fills = Valley.fills()
	for i, f in fills do
		if f.op == "block" then
			T:FillBlock(
				CFrame.new(f.x, f.y, f.z) * CFrame.Angles(0, f.yaw, 0),
				Vector3.new(f.sx, f.sy, f.sz),
				material(f.mat)
			)
		elseif f.op == "ball" then
			T:FillBall(Vector3.new(f.x, f.y, f.z), f.sx, material(f.mat))
		elseif f.op == "cylinder" then
			T:FillCylinder(CFrame.new(f.x, f.y, f.z), f.sx, f.sy, material(f.mat))
		elseif f.op == "replace" and f.from and f.y0 and f.y1 then
			-- (a region can only be so big: done in tiles)
			local TILE = 400
			for x = -1600, 1600 - TILE, TILE do
				for z = -1600, 1600 - TILE, TILE do
					for y = f.y0, f.y1 - 1, 200 do
						local region =
							Region3.new(Vector3.new(x, y, z), Vector3.new(x + TILE, math.min(y + 200, f.y1), z + TILE))
						T:ReplaceMaterial(region:ExpandToGrid(4), 4, material(f.from), material(f.mat))
					end
				end
				task.wait()
			end
		end
		if i % 12 == 0 then
			if progress then
				progress(i / #fills)
			end
			task.wait()
		end
	end
	if progress then
		progress(1)
	end
end

return ValleyTerrain
