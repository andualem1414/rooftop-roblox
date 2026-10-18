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
		clock = 0.6,
		brightness = 2.4,
		ambient = Color3.fromRGB(46, 40, 78),
		outdoor = Color3.fromRGB(86, 92, 150),
		shiftTop = Color3.fromRGB(150, 175, 255),
		exposure = 0.35,
		envDiffuse = 0.7,
		envSpecular = 0.9,
		fog = {
			density = 0.33,
			offset = 0.2,
			color = Color3.fromRGB(128, 112, 200),
			decay = Color3.fromRGB(70, 42, 120),
			glare = 0.5,
			haze = 1.7,
		},
		stars = 3000,
		moonSize = 20,
		bloom = { intensity = 1, size = 30, threshold = 1.4 },
		grade = { brightness = 0.03, contrast = 0.14, saturation = 0.28, tint = Color3.fromRGB(246, 240, 255) },
		rays = 0.08,
	},
	["Golden Dusk"] = {
		clock = 18.15,
		brightness = 2.6,
		ambient = Color3.fromRGB(70, 52, 60),
		outdoor = Color3.fromRGB(150, 110, 120),
		shiftTop = Color3.fromRGB(255, 180, 120),
		exposure = 0.15,
		envDiffuse = 0.8,
		envSpecular = 0.8,
		fog = {
			density = 0.3,
			offset = 0.25,
			color = Color3.fromRGB(255, 170, 140),
			decay = Color3.fromRGB(150, 80, 120),
			glare = 1.2,
			haze = 2,
		},
		stars = 600,
		moonSize = 11,
		bloom = { intensity = 0.8, size = 26, threshold = 1.5 },
		grade = { brightness = 0.02, contrast = 0.1, saturation = 0.3, tint = Color3.fromRGB(255, 244, 232) },
		rays = 0.12,
	},
	["Moonlit Ink"] = {
		clock = 0.6,
		brightness = 2.0,
		ambient = Color3.fromRGB(30, 34, 52),
		outdoor = Color3.fromRGB(64, 74, 110),
		shiftTop = Color3.fromRGB(169, 193, 255),
		exposure = 0.2,
		envDiffuse = 0.5,
		envSpecular = 0.6,
		fog = {
			density = 0.38,
			offset = 0.1,
			color = Color3.fromRGB(42, 52, 80),
			decay = Color3.fromRGB(17, 26, 48),
			glare = 0.2,
			haze = 2.2,
		},
		stars = 2500,
		moonSize = 16,
		bloom = { intensity = 0.6, size = 24, threshold = 1.8 },
		grade = { brightness = 0, contrast = 0.22, saturation = -0.15, tint = Color3.fromRGB(232, 238, 255) },
		rays = 0.05,
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

	local rays = effect("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = p.rays
	rays.Spread = 0.6
end

return Look
