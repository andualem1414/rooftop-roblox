--!strict
-- A player's settings, kept with their profile (server/common/ProfileStore) so they follow them from the
-- lobby into every race: music and effects volume, mouse sensitivity (on top of Roblox's own), camera
-- shake and the floating damage numbers. sanitize() takes whatever a client or the data store sent and
-- returns sane values.

export type Settings = {
	music: number, -- 0..1
	effects: number, -- 0..1
	sensitivity: number, -- 0.3..2.5, times Roblox's own mouse sensitivity
	shake: boolean,
	numbers: boolean,
}

local Settings = {}

Settings.SENSITIVITY = { 0.3, 2.5 }

function Settings.defaults(): Settings
	return { music = 0.5, effects = 0.8, sensitivity = 1, shake = true, numbers = true }
end

local function num(v: any, lo: number, hi: number, fallback: number): number
	if type(v) ~= "number" or v ~= v then
		return fallback
	end
	return math.clamp(v, lo, hi)
end

function Settings.sanitize(raw: any): Settings
	local d = Settings.defaults()
	if type(raw) ~= "table" then
		return d
	end
	return {
		music = num(raw.music, 0, 1, d.music),
		effects = num(raw.effects, 0, 1, d.effects),
		sensitivity = num(raw.sensitivity, Settings.SENSITIVITY[1], Settings.SENSITIVITY[2], d.sensitivity),
		shake = if type(raw.shake) == "boolean" then raw.shake else d.shake,
		numbers = if type(raw.numbers) == "boolean" then raw.numbers else d.numbers,
	}
end

return table.freeze(Settings)
