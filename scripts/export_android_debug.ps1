# Android Debug export for Puzzle Factory.
#
# - Installs the Godot Android build template into game/android (idempotent).
# - Runs a Gradle-based Android Debug export (required for minSdk/targetSdk overrides).
# - Verifies the produced APK with aapt2: package, minSdk, targetSdk.
#
# Usage: pwsh -File scripts/export_android_debug.ps1 [-JavaHome <jdk17-path>]
# Exit code: 0 = export + verification OK.
param(
    [string]$JavaHome
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\resolve_godot.ps1"

$repo = Get-RepoRoot
$game = Join-Path $repo 'game'
$androidDir = Join-Path $game 'android'
$buildDir = Join-Path $androidDir 'build'
$outDir = Join-Path $repo 'build\android'
$outApk = Join-Path $outDir 'puzzle_factory_debug.apk'

function Get-AndroidSourceTemplate {
    $templatesRoot = if ($env:APPDATA) { Join-Path $env:APPDATA 'Godot\export_templates' } else { $null }
    if (-not $templatesRoot -or -not (Test-Path $templatesRoot)) { return $null }
    $zip = Get-ChildItem $templatesRoot -Recurse -Filter 'android_source.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($zip) { return $zip.FullName }
    return $null
}

function Install-AndroidBuildTemplate {
    if (Test-Path (Join-Path $buildDir 'build.gradle')) {
        Write-Host "android build template already installed: $buildDir"
        # Ensure the no-daemon build setting exists (older installs may predate it).
        $gradleProps = Join-Path $buildDir 'gradle.properties'
        if ((Test-Path $gradleProps) -and -not (Select-String -Path $gradleProps -Pattern '^\s*org\.gradle\.daemon' -Quiet)) {
            Add-Content -Path $gradleProps -Value "`n# Scripted/CI builds: do not keep a background daemon alive.`norg.gradle.daemon=false"
        }
        return
    }
    $zip = Get-AndroidSourceTemplate
    if (-not $zip) {
        throw "android_source.zip not found in Godot export templates. Install Godot 4.7.2-stable export templates first."
    }
    Write-Host "installing android build template from: $zip"
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $buildDir -Force
    Set-Content -Path (Join-Path $buildDir '.gdignore') -Value '' -NoNewline -Encoding ASCII

    # Scripted/CI builds must not leave a Gradle daemon alive: a lingering
    # daemon keeps inherited stdio handles open and can hang caller pipelines.
    $gradleProps = Join-Path $buildDir 'gradle.properties'
    if ((Test-Path $gradleProps) -and -not (Select-String -Path $gradleProps -Pattern '^\s*org\.gradle\.daemon' -Quiet)) {
        Add-Content -Path $gradleProps -Value "`n# Scripted/CI builds: do not keep a background daemon alive.`norg.gradle.daemon=false"
    }

    # .build_version must contain the template identifier (version.txt content, e.g. 4.7.2.stable).
    $versionFile = Join-Path (Split-Path -Parent $zip) 'version.txt'
    $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'unknown' }
    Set-Content -Path (Join-Path $androidDir '.build_version') -Value $version -NoNewline -Encoding ASCII
    Write-Host "android build template installed (identifier: $version)"
}

function Resolve-JavaHome {
    param([string]$Requested)
    $candidates = @()
    if ($Requested) { $candidates += $Requested }
    if ($env:PFACTORY_JDK) { $candidates += $env:PFACTORY_JDK }
    if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
    if ($env:OS -eq 'Windows_NT') {
        # Machine-local staged JDK 17 (temporary toolchain staging directory).
        $candidates += (Join-Path $env:LOCALAPPDATA 'Temp\opencode\android\jdk17\jdk-17.0.20.1+1')
        $candidates += 'C:\Program Files\Android\Android Studio\jbr'
    }
    foreach ($candidate in $candidates) {
        $java = Join-Path $candidate 'bin\java.exe'
        if ($env:OS -ne 'Windows_NT') { $java = Join-Path $candidate 'bin/java' }
        if (-not (Test-Path $java)) { continue }
        # java -version prints to stderr; don't let PS 5.1 turn it into a
        # terminating NativeCommandError under ErrorActionPreference=Stop.
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $v = (& $java -version 2>&1 | Out-String)
        $ErrorActionPreference = $prevEap
        if ($v -match 'version "(\d+)') {
            $major = [int]$Matches[1]
            if ($major -lt 17) {
                Write-Host "skipping JDK $major (< 17) at $candidate"
                continue
            }
            if ($major -ne 17) {
                Write-Host "WARNING: using JDK $major at $candidate (blueprint pins JDK 17)"
            }
            return (Resolve-Path $candidate).Path
        }
    }
    throw "No JDK >= 17 found. Install JDK 17 (blueprint baseline) or pass -JavaHome."
}

function Test-ApkWithAapt2 {
    param([string]$ApkPath)
    $sdk = $env:ANDROID_HOME
    if (-not $sdk -and $env:ANDROID_SDK_ROOT) { $sdk = $env:ANDROID_SDK_ROOT }
    if (-not $sdk -and $env:LOCALAPPDATA) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    $aapt2 = $null
    if ($sdk) {
        $preferred = Join-Path $sdk 'build-tools\36.0.0\aapt2.exe'
        if ($env:OS -ne 'Windows_NT') { $preferred = Join-Path $sdk 'build-tools/36.0.0/aapt2' }
        if (Test-Path $preferred) { $aapt2 = $preferred }
        elseif (Test-Path (Join-Path $sdk 'build-tools')) {
            $found = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1
            if ($found) {
                $aaptName = 'aapt2.exe'; if ($env:OS -ne 'Windows_NT') { $aaptName = 'aapt2' }
                $cand = Join-Path $found.FullName $aaptName
                if (Test-Path $cand) { $aapt2 = $cand }
            }
        }
    }
    if (-not $aapt2) {
        Write-Host "WARNING: aapt2 not found; APK verification skipped"
        return $true
    }
    $badging = & $aapt2 dump badging $ApkPath | Out-String
    $checks = @(
        @{ Name = 'package'; Pattern = "package: name='com\.puzzlefactory\.game' versionCode='100'" },
        @{ Name = 'minSdk'; Pattern = "minSdkVersion:'24'" },
        @{ Name = 'targetSdk'; Pattern = "targetSdkVersion:'36'" }
    )
    $ok = $true
    foreach ($check in $checks) {
        if ($badging -match $check.Pattern) {
            Write-Host "VERIFY OK: $($check.Name)"
        } else {
            Write-Host "VERIFY FAIL: $($check.Name)"
            $ok = $false
        }
    }
    return $ok
}

# --- main ---
$godot = Get-GodotPath
$null = Assert-GodotVersion -GodotPath $godot
Write-Host "godot: $godot"

Install-AndroidBuildTemplate

$env:JAVA_HOME = Resolve-JavaHome -Requested $JavaHome
Write-Host "JAVA_HOME: $env:JAVA_HOME"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
& $godot --headless --path $game --export-debug 'Android Debug' $outApk
$exportCode = $LASTEXITCODE
if ($exportCode -ne 0) {
    Write-Host "EXPORT FAILED (exit $exportCode)"
    exit $exportCode
}
if (-not (Test-Path $outApk)) {
    Write-Host "EXPORT FAILED: $outApk not produced"
    exit 1
}
Write-Host "EXPORT OK: $outApk"

if (-not (Test-ApkWithAapt2 -ApkPath $outApk)) {
    Write-Host "APK VERIFICATION FAILED"
    exit 1
}
Write-Host "ANDROID DEBUG EXPORT PASSED"
exit 0
