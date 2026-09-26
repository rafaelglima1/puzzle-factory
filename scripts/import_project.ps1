# Headless import/validation of the Godot project (no import errors expected).
# Usage: pwsh -File scripts/import_project.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\resolve_godot.ps1"

$godot = Get-GodotPath
$version = Assert-GodotVersion -GodotPath $godot
Write-Host "godot: $godot"
Write-Host "version: $version"

$game = Join-Path (Get-RepoRoot) 'game'
& $godot --headless --path $game --import
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot import failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
Write-Host "IMPORT OK"
exit 0
