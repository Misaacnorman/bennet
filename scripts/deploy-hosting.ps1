# Deploy Flutter web to Firebase Hosting (classic Hosting, same as CI).
# Requires: Node/npm (for npx firebase-tools), Flutter, Firebase project in .firebaserc.
#
# Usage:
#   $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\path\to\service-account.json"
#   .\scripts\deploy-hosting.ps1
#
# Or pass the key path:
#   .\scripts\deploy-hosting.ps1 -ServiceAccountJson "D:\path\to\service-account.json"

param(
  [string] $ServiceAccountJson = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
  Write-Error "Run this script from the Bennet repo (pubspec.yaml not found)."
}

Set-Location $root

# Prefer service account auth over any cached `firebase login` (CLI picks user login first otherwise).
$env:CI = "true"

if ($ServiceAccountJson) {
  $env:GOOGLE_APPLICATION_CREDENTIALS = (Resolve-Path $ServiceAccountJson).Path
}

if (-not $env:GOOGLE_APPLICATION_CREDENTIALS -or -not (Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {
  Write-Error "Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path, or use -ServiceAccountJson."
}

flutter pub get
flutter build web --release
# Uses default project from `.firebaserc` (no `--project` flag).
npx --yes firebase-tools@latest deploy --only hosting
