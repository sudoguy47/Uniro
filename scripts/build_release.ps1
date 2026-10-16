#Requires -Version 5.1
<#
  Uniro release build: clean -> get -> analyze -> test -> split + universal APKs.
  Run from the repo root:  powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
  Unsigned/local runs fall back to the debug key (see android/KEYSTORE.md);
  ship only builds signed with the release key.
#>
$ErrorActionPreference = 'Stop'

function Step($name) { Write-Host "`n=== $name ===" -ForegroundColor Cyan }

Step 'flutter clean'
flutter clean

Step 'flutter pub get'
flutter pub get

Step 'flutter analyze'
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'analyze failed — fix issues before release.' }

Step 'flutter test'
# --concurrency=1: widget pumps are heavy; parallel isolates flake on
# dev machines (see test/responsive_test.dart). CI with headroom may drop it.
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) { throw 'tests failed — fix before release.' }

Step 'split APKs (sideload / GitHub Releases)'
flutter build apk --release --split-per-abi

Step 'universal APK (fallback for odd devices)'
flutter build apk --release

Write-Host "`n=== APKs ===" -ForegroundColor Green
Get-ChildItem build/app/outputs/flutter-apk/*.apk | ForEach-Object {
  '{0,-34} {1,8:N2} MB' -f $_.Name, ($_.Length / 1MB)
}
