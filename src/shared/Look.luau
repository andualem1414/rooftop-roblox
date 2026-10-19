--!strict
-- The lighting and colour grade: sky, moon, mist, bloom, colour. One of a few presets, set by the server
-- (Lighting replicates). In Studio, a Workspace attribute LookPreset switches between them, live.
--   "Neon Night"  (default) the original's moonlit night, made colourful: a deep purple-blue sky full
--                 of stars and a big moon, violet mist on the horizon, neon and lamps that glow
--   "Golden Dusk" the sun just down: warm orange and pink haze
--   "Moonlit Ink" closest to the original: cold blue moonlight, muted colours, strong contrast
-- (Lighting.Technology = Future is set by hand in Studio: see CLAUDE.md.)
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
		brightness = 2.2,
		ambient = Color3.fromRGB(36, 34, 54),
		outdoor = Color3.fromRGB(88, 96, 140),
		shiftTop = Color3.fromRGB(150, 170, 230),
		exposure = 0.1,
		envDiffuse = 0.55,
		envSpecular = 0.5,
		fog = {
			density = 0.18,
			offset = 0.4,
			color = Color3.fromRGB(84, 94, 144),
			decay = Color3.fromRGB(40, 40, 80),
			glare = 0.15,
			haze = 0.4,
		},
		stars = 3000,
		moonSize = 16,
		bloom = { intensity = 0.45, size = 22, threshold = 2.0 },
		grade = { brightness = 0.02, contrast = 0.08, saturation = 0.12, tint = Color3.fromRGB(248, 246, 255) },
		rays = 0.04,
	},
	["Golden Dusk"] = {
		clock = 18.0,
		brightness = 1.6,
		ambient = Color3.fromRGB(44, 36, 40),
		outdoor = Color3.fromRGB(110, 86, 92),
		shiftTop = Color3.fromRGB(255, 170, 110),
		exposure = 0,
		envDiffuse = 0.5,
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
		bloom = { intensity = 0.35, size = 20, threshold = 2.2 },
		grade = { brightness = 0, contrast = 0.08, saturation = 0.12, tint = Color3.fromRGB(255, 246, 236) },
		rays = 0.06,
	},
	["Moonlit Ink"] = {
		clock = 0.4,
		brightness = 1.8,
		ambient = Color3.fromRGB(28, 30, 44),
		outdoor = Color3.fromRGB(70, 80, 116),
		shiftTop = Color3.fromRGB(169, 193, 255),
		exposure = 0,
		envDiffuse = 0.45,
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
		bloom = { intensity = 0.3, size = 18, threshold = 2.4 },
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
