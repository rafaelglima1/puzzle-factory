# Runs the Puzzle Factory headless test suite.
# Usage: pwsh -File scripts/run_tests.ps1
# Exit code: 0 = all tests passed, non-zero = failures.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\resolve_godot.ps1"

$godot = Get-GodotPath
$null = Assert-GodotVersion -GodotPath $godot

$game = Join-Path (Get-RepoRoot) 'game'
& $godot --headless --path $game --script res://tests/run_tests.gd
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host "TESTS FAILED (exit $code)"
} else {
    Write-Host "TESTS PASSED"
}
exit $code
