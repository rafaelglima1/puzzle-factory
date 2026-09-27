# M5 solver CLI wrapper.
# Usage:
#   pwsh -File scripts/solve_level.ps1 traffic_m3_l10_rush_hour
#   pwsh -File scripts/solve_level.ps1 --all
#   pwsh -File scripts/solve_level.ps1 --all --json
#   pwsh -File scripts/solve_level.ps1 path/to/level.json
#
# Exit codes (from the underlying Godot script):
#   0 = every requested level proven SOLVABLE
#   1 = invalid input / level failed to load or validate
#   2 = UNSOLVABLE
#   3 = UNKNOWN (bounds) / tooling error
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\resolve_godot.ps1"

$godot = Get-GodotPath
$null = Assert-GodotVersion -GodotPath $godot

$game = Join-Path (Get-RepoRoot) 'game'
$forwarded = @()
foreach ($arg in $args) { $forwarded += $arg }

& $godot --headless --path $game --script res://tools/solve_level.gd -- @forwarded
exit $LASTEXITCODE
