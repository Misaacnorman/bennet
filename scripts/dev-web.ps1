# Local Flutter web dev server — port 8080 (same as .vscode/launch.json).
# Usage from repo root: .\scripts\dev-web.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$portInUse = netstat -ano 2>$null | Select-String ":8080\s+.*LISTENING"
if ($portInUse) {
  Write-Host "Port 8080 is already in use. Stop the other dev server first:" -ForegroundColor Yellow
  Write-Host "  In its terminal, press q (quit), or close that terminal." -ForegroundColor Yellow
  Write-Host "  To see which process: netstat -ano | findstr `:8080`" -ForegroundColor DarkGray
  exit 1
}

flutter run -d web-server --web-port 8080 --web-hostname localhost
