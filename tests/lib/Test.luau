--!strict
-- A tiny test library for Lune: describe / it / expect. Runs the pure game logic in
-- src/shared outside Roblox (`lune run tests`).

local Test = {}

local passed, failed = 0, 0
local prefix = ""

function Test.describe(name: string, body: () -> ())
	local outer = prefix
	prefix = outer .. name .. " > "
	body()
	prefix = outer
end

function Test.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL {prefix}{name}\n     {err}`)
	end
end

local function show(v: any): string
	return if type(v) == "string" then `"{v}"` else tostring(v)
end

function Test.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error(`expected {show(expected)}, got {show(actual)}`, 2)
			end
		end,
		toBeNear = function(expected: number, tolerance: number?)
			if math.abs(actual - expected) > (tolerance or 1e-6) then
				error(`expected about {expected}, got {actual}`, 2)
			end
		end,
		toBeTruthy = function()
			if not actual then
				error(`expected something truthy, got {show(actual)}`, 2)
			end
		end,
	}
end

-- prints the totals; returns true if everything passed
function Test.finish(): boolean
	print(`{passed} passed, {failed} failed`)
	return failed == 0
end

return Test
