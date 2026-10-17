#Requires -Version 5.1
<#
  Helper script to display GitHub Secrets needed for the cloud Release workflow.
  Run from repo root:
    powershell -ExecutionPolicy Bypass -File scripts/export_secrets.ps1
#>
$ErrorActionPreference = 'Stop'

Write-Host "`n=== GitHub Actions Release Secrets Helper ===" -ForegroundColor Cyan
Write-Host "This script reads your local key.properties and prepares the exact values"
Write-Host "to add under: https://github.com/sudoguy47/uniro/settings/secrets/actions`n" -ForegroundColor Yellow

$keyPropsPath = "android/key.properties"
if (-not (Test-Path $keyPropsPath)) {
  throw "android/key.properties not found! Ensure your release key is configured locally first."
}

$props = @{}
Get-Content $keyPropsPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#") -and ($line -match '^([^=]+)=(.*)$')) {
    $props[$matches[1].Trim()] = $matches[2].Trim()
  }
}

$storeFilePath = $props["storeFile"]
if (-not $storeFilePath) {
  throw "storeFile not found in android/key.properties"
}

# Resolve relative path if needed
if (-not (Test-Path $storeFilePath)) {
  $resolved = Join-Path "android" $storeFilePath
  if (Test-Path $resolved) {
    $storeFilePath = (Resolve-Path $resolved).Path
  }
}

if (-not (Test-Path $storeFilePath)) {
  throw "Keystore file not found at: $storeFilePath"
}

Write-Host "Found keystore: $storeFilePath" -ForegroundColor Green

$keystoreBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($storeFilePath))

Write-Host "`nAdd these 4 secrets to GitHub (Repository Settings -> Secrets and variables -> Actions):" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------------------------"

Write-Host "`n1. Name: " -NoNewline -ForegroundColor Yellow
Write-Host "KEYSTORE_BASE64" -ForegroundColor White
Write-Host "   Value: [Keystore base64 string - $($keystoreBase64.Length) characters]"
Write-Host "   (To copy just this string to clipboard, run: Set-Clipboard '$($keystoreBase64.Substring(0, 20))...' or see below)"

Write-Host "`n2. Name: " -NoNewline -ForegroundColor Yellow
Write-Host "KEYSTORE_PASSWORD" -ForegroundColor White
Write-Host "   Value: $($props['storePassword'])"

Write-Host "`n3. Name: " -NoNewline -ForegroundColor Yellow
Write-Host "KEY_ALIAS" -ForegroundColor White
Write-Host "   Value: $($props['keyAlias'])"

Write-Host "`n4. Name: " -NoNewline -ForegroundColor Yellow
Write-Host "KEY_PASSWORD" -ForegroundColor White
Write-Host "   Value: $($props['keyPassword'])"

Write-Host "`n---------------------------------------------------------------------------------"
Write-Host "Tip: To quickly copy KEYSTORE_BASE64 to your clipboard, run:" -ForegroundColor Green
Write-Host "  [Convert]::ToBase64String([IO.File]::ReadAllBytes('$($storeFilePath.Replace('\','/'))')) | Set-Clipboard" -ForegroundColor White
Write-Host "`nDirect link to add secrets:" -ForegroundColor Cyan
Write-Host "  https://github.com/sudoguy47/uniro/settings/secrets/actions" -ForegroundColor Cyan
