--!strict
-- Builds the valley's terrain on this client from the shared recipe (Valley.luau). Run by the loading
-- screen: terrain built locally is there in a second or two, where a server's terrain would take far
-- longer to reach each player. The server never touches the terrain.
local Valley = require(script.Parent.Valley)

local ValleyTerrain = {}

-- (lighter than a real night's: the valley should read under the moon, without more light that would
-- wash out the rooms: shared/Look)
local COLORS = {
	Grass = Color3.fromRGB(72, 122, 92),
	LeafyGrass = Color3.fromRGB(62, 108, 86),
	Ground = Color3.fromRGB(112, 88, 74),
	Rock = Color3.fromRGB(122, 116, 150),
	Slate = Color3.fromRGB(102, 98, 128),
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
	-- A frame now and then (a script may not run for ~10 s without one), but seldom: every frame in
	-- between, Roblox works the terrain changed so far into collision and meshes, and the next fills
	-- change the same chunks again. Measured in Studio (wall clock, the lobby's loading screen): a frame
	-- every 1/20 s of work took 13.3 s to build, every 0.25 s 11.0 s, every second 8.6 s; none at all
	-- 5.4 s, but the work it put off then slowed the next steps by 2.4 s.
	local since = os.clock()
	local function breathe(i: number)
		if os.clock() - since > 1 then
			if progress then
				progress(i / #fills)
			end
			task.wait()
			since = os.clock()
		end
	end
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
		elseif f.op == "replace" and f.from then
			-- (only where that material can be: Valley.regions)
			for _, b in Valley.regions(fills, i) do
				local region = Region3.new(Vector3.new(b.x0, b.y0, b.z0), Vector3.new(b.x1, b.y1, b.z1))
				T:ReplaceMaterial(region:ExpandToGrid(4), 4, material(f.from), material(f.mat))
				breathe(i)
			end
		end
		breathe(i)
	end
	if progress then
		progress(1)
	end
end

return ValleyTerrain
