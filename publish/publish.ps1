# Publishes the game from this repo: checks the code, then builds and uploads the places straight to Roblox
# (Open Cloud, through `rojo upload`), live for new servers. No Studio needed.
#
#   powershell -ExecutionPolicy Bypass -File publish\publish.ps1            # both places
#   powershell -ExecutionPolicy Bypass -File publish\publish.ps1 -Place race
#
# The Open Cloud key is read from the environment variable ROBLOX_PUBLISH_KEY (set once for the Windows user,
# see publish/RELEASE.md → "Publishing from the terminal"). It is never printed, logged or written to a file.
# The place ids come from src/shared/Places.luau.
param(
	[ValidateSet("both", "lobby", "race")]
	[string]$Place = "both",
	# skip the tests, lint and format check (not recommended)
	[switch]$SkipChecks
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$bin = Join-Path $env:USERPROFILE ".rokit\bin"
if (Test-Path $bin) { $env:PATH = "$bin;$env:PATH" }

# the Rooftop experience (Creator Hub → Rooftop: the number in the address)
$universe = "10771906434"

# the key: this terminal's environment, or the user's saved variable (set after this terminal started)
$key = $env:ROBLOX_PUBLISH_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("ROBLOX_PUBLISH_KEY", "User") }
if (-not $key) {
	Write-Host "No ROBLOX_PUBLISH_KEY set. See publish/RELEASE.md -> 'Publishing from the terminal'." -ForegroundColor Red
	exit 1
}

$places = Get-Content "src\shared\Places.luau" -Raw
$ids = @{
	lobby = [regex]::Match($places, "LOBBY\s*=\s*(\d+)").Groups[1].Value
	race = [regex]::Match($places, "RACE\s*=\s*(\d+)").Groups[1].Value
}
$targets = if ($Place -eq "both") { @("race", "lobby") } else { @($Place) }
foreach ($t in $targets) {
	if (-not $ids[$t] -or $ids[$t] -eq "0") {
		Write-Host "No $t place id in src/shared/Places.luau." -ForegroundColor Red
		exit 1
	}
}

if (-not $SkipChecks) {
	Write-Host "Checking: tests, lint, format..."
	lune run tests
	if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed: nothing published." -ForegroundColor Red; exit 1 }
	selene src
	if ($LASTEXITCODE -ne 0) { Write-Host "Lint failed: nothing published." -ForegroundColor Red; exit 1 }
	stylua --check src tests
	if ($LASTEXITCODE -ne 0) { Write-Host "Format check failed (run: stylua src tests): nothing published." -ForegroundColor Red; exit 1 }
}

$commit = (git rev-parse --short HEAD).Trim()
$dirty = git status --porcelain -- src *.project.json
if ($dirty) { Write-Host "Note: publishing changes that aren't committed yet (on top of $commit)." -ForegroundColor Yellow }

$version = [regex]::Match((Get-Content "src\shared\Version.luau" -Raw), '"([^"]+)"').Groups[1].Value
foreach ($t in $targets) {
	Write-Host "Publishing $t (place $($ids[$t])), version $version, commit $commit..."
	rojo upload "$t.project.json" --asset_id $ids[$t] --universe_id $universe --api_key $key
	if ($LASTEXITCODE -ne 0) { Write-Host "Publishing $t failed." -ForegroundColor Red; exit 1 }
}
Write-Host "Published: $($targets -join ', '). New servers run it; rejoin to play the new version." -ForegroundColor Green
