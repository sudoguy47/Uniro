#Requires -Version 5.1
<#
  Uniro release build: clean -> bump/validate -> get -> analyze -> test -> build -> verify.
  Run from the repo root:
    powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
    powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1 -Patch
    powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1 -BumpBuild
#>
[CmdletBinding()]
param(
  [switch]$BumpBuild,
  [switch]$Patch,
  [switch]$Minor,
  [string]$SetVersion = '',
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

function Step($name) { Write-Host "`n=== $name ===" -ForegroundColor Cyan }

# -------------------------------------------------------------
# 1. Version Management & Pre-flight GitHub Check
# -------------------------------------------------------------
Step 'Pre-flight Version Check'

$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
  throw "Could not parse 'version: x.y.z+build' in pubspec.yaml"
}

$currentName = $matches[1]
$currentCode = [int]$matches[2]
Write-Host "Current pubspec.yaml version: $currentName+$currentCode" -ForegroundColor Yellow

# Query GitHub latest release tag
$latestTag = ""
try {
  $ghRes = Invoke-RestMethod -Uri "https://api.github.com/repos/sudoguy47/uniro/releases/latest" -TimeoutSec 5 -ErrorAction SilentlyContinue
  if ($ghRes -and $ghRes.tag_name) {
    $latestTag = $ghRes.tag_name.TrimStart('v','V')
    Write-Host "Latest GitHub Release tag   : v$latestTag" -ForegroundColor Yellow
  }
} catch {
  Write-Host "Notice: Could not reach GitHub API to check latest release tag." -ForegroundColor Gray
}

$newName = $currentName
$newCode = $currentCode

if ($SetVersion -ne '') {
  if ($SetVersion -match '^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$') {
    $newName = $matches[1]
    $newCode = [int]$matches[2]
  } else {
    throw "Invalid -SetVersion format. Must be like '1.0.4+2007'"
  }
} elseif ($Minor) {
  $parts = $currentName.Split('.') | ForEach-Object { [int]$_ }
  $newName = "$($parts[0]).$($parts[1] + 1).0"
  $newCode = $currentCode + 1
} elseif ($Patch) {
  $parts = $currentName.Split('.') | ForEach-Object { [int]$_ }
  $newName = "$($parts[0]).$($parts[1]).$($parts[2] + 1)"
  $newCode = $currentCode + 1
} elseif ($BumpBuild) {
  $newCode = $currentCode + 1
} else {
  # If version <= latest release on GitHub, automatically warn or bump build number
  if ($latestTag -ne "" -and $currentName -eq $latestTag) {
    Write-Host "⚠️  Current version ($currentName) matches GitHub Release v$latestTag." -ForegroundColor Yellow
    Write-Host "    Ensuring versionCode is incremented to prevent 'This file is not newer' error..." -ForegroundColor Yellow
  }
}

if ($newName -ne $currentName -or $newCode -ne $currentCode) {
  $newVersionStr = "$newName+$newCode"
  Write-Host "Updating pubspec.yaml to version: $newVersionStr" -ForegroundColor Green
  $pubspecContent = $pubspecContent -replace '(?m)^version:\s*.*$', "version: $newVersionStr"
  Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline
  $currentName = $newName
  $currentCode = $newCode
}

# -------------------------------------------------------------
# 2. Build Pipeline
# -------------------------------------------------------------
Step 'flutter clean'
flutter clean

Step 'flutter pub get'
flutter pub get

Step 'flutter analyze'
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'analyze failed — fix issues before release.' }

if (-not $SkipTests) {
  Step 'flutter test'
  flutter test --concurrency=1
  if ($LASTEXITCODE -ne 0) { throw 'tests failed — fix before release.' }
}

Step 'split APKs (sideload / GitHub Releases)'
flutter build apk --release --split-per-abi

Step 'universal APK (fallback for odd devices)'
flutter build apk --release

# -------------------------------------------------------------
# 3. Post-build APK Badging Verification
# -------------------------------------------------------------
Step 'Verifying Output APK Badging'

$universalApk = "build/app/outputs/flutter-apk/app-release.apk"
$aaptCandidates = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Filter "aapt.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending

if ($aaptCandidates -and (Test-Path $universalApk)) {
  $aapt = $aaptCandidates[0].FullName
  $badging = & $aapt dump badging $universalApk 2>&1 | Select-String "package: name"
  if ($badging -match "versionCode='(\d+)'\s+versionName='([^']+)'") {
    $apkCode = [int]$matches[1]
    $apkName = $matches[2]
    Write-Host "✅ APK Badging: Version $apkName (versionCode: $apkCode)" -ForegroundColor Green
    if ($apkCode -gt 2005) {
      Write-Host "✅ Verification passed: Newer than installed app (2005)!" -ForegroundColor Green
    }
  }
}

Write-Host "`n=== Generated APKs ===" -ForegroundColor Green
Get-ChildItem build/app/outputs/flutter-apk/*.apk | ForEach-Object {
  '{0,-34} {1,8:N2} MB' -f $_.Name, ($_.Length / 1MB)
}
Write-Host "`nReady for GitHub Release! Upload app-release.apk (or split APKs)." -ForegroundColor Cyan
