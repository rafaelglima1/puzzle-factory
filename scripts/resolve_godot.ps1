# Shared helpers for Puzzle Factory build/test scripts.
# Dot-source: . "$PSScriptRoot\resolve_godot.ps1"

function Get-RepoRoot {
    Split-Path -Parent $PSScriptRoot
}

function Get-GodotPath {
    if ($env:GODOT_PATH) {
        if (-not (Test-Path $env:GODOT_PATH)) {
            throw "GODOT_PATH is set but does not exist: $env:GODOT_PATH"
        }
        return (Resolve-Path $env:GODOT_PATH).Path
    }

    $cmd = Get-Command 'godot' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    if ($env:OS -eq 'Windows_NT') {
        $candidates = @(
            (Join-Path $env:LOCALAPPDATA 'Temp\opencode\godot\Godot_v4.7.2-stable_win64_console.exe'),
            'C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe',
            (Join-Path $env:LOCALAPPDATA 'Programs\Godot\Godot_v4.7.2-stable_win64_console.exe')
        )
        foreach ($candidate in $candidates) {
            if ($candidate -and (Test-Path $candidate)) { return $candidate }
        }
    }

    throw "Godot 4.7.2-stable not found. Set GODOT_PATH or add 'godot' to PATH."
}

function Assert-GodotVersion {
    param([string]$GodotPath)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $versionOutput = (& $GodotPath --version 2>&1 | Out-String)
    $ErrorActionPreference = $prevEap
    if ($versionOutput -notmatch '4\.7\.2') {
        throw "Godot 4.7.2-stable required, but got: $($versionOutput.Trim())"
    }
    return $versionOutput.Trim()
}
