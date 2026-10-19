--!strict
-- The lighting and colour grade: sky, moon, mist, bloom, colour. One of a few presets, set by the server
-- (Lighting replicates). In Studio, a Workspace attribute LookPreset switches between them, live.
--   "Neon Night"  (default) the original's moonlit night, made colourful: a deep purple-blue sky full
--                 of stars and a big moon, violet mist on the horizon, neon and lamps that glow
--   "Golden Dusk" the sun just down: warm orange and pink haze
--   "Moonlit Ink" closest to the original: cold blue moonlight, muted colours, strong contrast
-- How the light is shared out (measured in Studio, 2026-10-19):
--   LightingStyle is Realistic (set here: the old Technology property is deprecated): lamps and muzzle
--   flashes light their surroundings at once, where the Soft style built them up over a couple of
--   seconds after the camera moved.
--   The floors above you are cut away (client/race/Cutaway), so your room is under the open sky: it gets
--   the same moonlight and ambient as the valley. Roblox takes a second to notice a spot went from covered
--   to open, so most of the light is in Ambient (everywhere) and little in OutdoorAmbient (open sky only):
--   the room doesn't flash from dark to bright when the race starts. The rooms' own lamps are soft accents.
--   The valley reads brighter through its ground colours (shared/ValleyTerrain) and a brighter horizon
--   (the mist), not through more light, which would wash out the pale rooms.
--   Bloom only catches neon (threshold 2.6), not pale walls under the moon.
local Lighting = game:GetService("Lighting")

export type Preset = {
	clock: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	shiftTop: Color3,
	exposure: number,
	envDiffuse: number,
	envSpecular: number,
	fog: { density: number, offset: number, color: Color3, decay: Color3, glare: number, haze: number },
	stars: number,
	moonSize: number,
	bloom: { intensity: number, size: number, threshold: number },
	grade: { brightness: number, contrast: number, saturation: number, tint: Color3 },
	rays: number,
}

local Look = {}

Look.DEFAULT = "Neon Night"

Look.PRESETS = {
	["Neon Night"] = {
		clock = 0.4,
		brightness = 2.4,
		ambient = Color3.fromRGB(74, 76, 108),
		outdoor = Color3.fromRGB(46, 50, 74),
		shiftTop = Color3.fromRGB(150, 170, 230),
		exposure = 0.15,
		envDiffuse = 0.35,
		envSpecular = 0.4,
		fog = {
			density = 0.15,
			offset = 0.4,
			color = Color3.fromRGB(104, 112, 166),
			decay = Color3.fromRGB(56, 58, 104),
			glare = 0.25,
			haze = 0.7,
		},
		stars = 3000,
		moonSize = 16,
		bloom = { intensity = 0.4, size = 22, threshold = 2.6 },
		grade = { brightness = 0.02, contrast = 0.08, saturation = 0.12, tint = Color3.fromRGB(248, 246, 255) },
		rays = 0.04,
	},
	["Golden Dusk"] = {
		clock = 18.0,
		brightness = 1.8,
		ambient = Color3.fromRGB(88, 70, 76),
		outdoor = Color3.fromRGB(52, 40, 44),
		shiftTop = Color3.fromRGB(255, 170, 110),
		exposure = 0.05,
		envDiffuse = 0.35,
		envSpecular = 0.5,
		fog = {
			density = 0.22,
			offset = 0.3,
			color = Color3.fromRGB(220, 150, 130),
			decay = Color3.fromRGB(110, 70, 100),
			glare = 0.6,
			haze = 1.0,
		},
		stars = 600,
		moonSize = 11,
		bloom = { intensity = 0.35, size = 20, threshold = 2.6 },
		grade = { brightness = 0, contrast = 0.08, saturation = 0.12, tint = Color3.fromRGB(255, 246, 236) },
		rays = 0.06,
	},
	["Moonlit Ink"] = {
		clock = 0.4,
		brightness = 2.0,
		ambient = Color3.fromRGB(60, 64, 90),
		outdoor = Color3.fromRGB(36, 40, 58),
		shiftTop = Color3.fromRGB(169, 193, 255),
		exposure = 0.05,
		envDiffuse = 0.3,
		envSpecular = 0.3,
		fog = {
			density = 0.28,
			offset = 0.25,
			color = Color3.fromRGB(40, 48, 74),
			decay = Color3.fromRGB(16, 22, 40),
			glare = 0.05,
			haze = 1.0,
		},
		stars = 2500,
		moonSize = 16,
		bloom = { intensity = 0.3, size = 18, threshold = 2.8 },
		grade = { brightness = 0, contrast = 0.16, saturation = -0.15, tint = Color3.fromRGB(232, 238, 255) },
		rays = 0.02,
	},
} :: { [string]: Preset }

-- the one effect of a class under Lighting (made if missing)
local function effect<T>(className: string): T
	local e = Lighting:FindFirstChildOfClass(className)
	if not e then
		e = Instance.new(className)
		e.Name = "Rooftop" .. className
		e.Parent = Lighting
	end
	return e :: any
end

function Look.apply(name: string?)
	local p = Look.PRESETS[name or Look.DEFAULT] or Look.PRESETS[Look.DEFAULT]
	pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Realistic
		Lighting.PrioritizeLightingQuality = true
	end)
	Lighting.ClockTime = p.clock
	Lighting.Brightness = p.brightness
	Lighting.Ambient = p.ambient
	Lighting.OutdoorAmbient = p.outdoor
	Lighting.ColorShift_Top = p.shiftTop
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.ExposureCompensation = p.exposure
	Lighting.EnvironmentDiffuseScale = p.envDiffuse
	Lighting.EnvironmentSpecularScale = p.envSpecular
	Lighting.GeographicLatitude = 28
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000

	local fog = effect("Atmosphere") :: Atmosphere
	fog.Density = p.fog.density
	fog.Offset = p.fog.offset
	fog.Color = p.fog.color
	fog.Decay = p.fog.decay
	fog.Glare = p.fog.glare
	fog.Haze = p.fog.haze

	local sky = effect("Sky") :: Sky
	sky.StarCount = p.stars
	sky.MoonAngularSize = p.moonSize
	sky.SunAngularSize = 14
	sky.CelestialBodiesShown = true

	local bloom = effect("BloomEffect") :: BloomEffect
	bloom.Intensity = p.bloom.intensity
	bloom.Size = p.bloom.size
	bloom.Threshold = p.bloom.threshold

	local grade = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	grade.Brightness = p.grade.brightness
	grade.Contrast = p.grade.contrast
	grade.Saturation = p.grade.saturation
	grade.TintColor = p.grade.tint

	-- (Studio's Baseplate template brings a depth-of-field blur: not wanted)
	for _, e in Lighting:GetChildren() do
		if e:IsA("DepthOfFieldEffect") or e:IsA("BlurEffect") then
			e.Enabled = false
		end
	end

	local rays = effect("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = p.rays
	rays.Spread = 0.6
end

return Look
