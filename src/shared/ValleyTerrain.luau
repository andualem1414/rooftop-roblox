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
	local voxelled = false
	for i, f in fills do
		if Valley.voxelled(f) then
			-- the mountains, written tile by tile where their first fill would have been (Valley.voxels)
			if not voxelled then
				voxelled = true
				for _, t in Valley.tiles() do
					local mats, occs = Valley.voxels(t, Enum.Material :: any)
					local corner = Vector3.new(t.x, t.y, t.z)
					T:WriteVoxels(Region3.new(corner, corner + Vector3.new(t.nx, t.ny, t.nz) * 4), 4, mats, occs)
					breathe(i)
				end
			end
		elseif f.op == "block" then
			T:FillBlock(
				CFrame.new(f.x, f.y, f.z) * CFrame.Angles(0, f.yaw, 0),
				Vector3.new(f.sx, f.sy, f.sz),
				material(f.mat)
			)
		elseif f.op == "ball" then
			T:FillBall(Vector3.new(f.x, f.y, f.z), f.sx, material(f.mat))
		elseif f.op == "cylinder" then
			T:FillCylinder(CFrame.new(f.x, f.y, f.z), f.sx, f.sy, material(f.mat))
		end
		breathe(i)
	end
	if progress then
		progress(1)
	end
end

return ValleyTerrain
