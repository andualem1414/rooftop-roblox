--!strict
-- `lune run tests`: runs every spec and exits non-zero if any failed.
local process = require("@lune/process")
local Test = require("@self/lib/Test")

require("@self/Config.spec")
require("@self/Platforms.spec")
require("@self/Combat.spec")
require("@self/Rules.spec")
require("@self/Valley.spec")
require("@self/Weapons.spec")
require("@self/Progress.spec")
require("@self/Booster.spec")

if not Test.finish() then
	process.exit(1)
end
