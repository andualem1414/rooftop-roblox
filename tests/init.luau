--!strict
-- `lune run tests`: runs every spec and exits non-zero if any failed.
local process = require("@lune/process")
local Test = require("@self/lib/Test")

require("@self/Config.spec")

if not Test.finish() then
	process.exit(1)
end
