# One-time laptop setup (Windows PowerShell). Run from the repo folder:
#   powershell -ExecutionPolicy Bypass -File tools\setup.ps1
# Installs arduino-cli + ESP32 board support + OLED library, writes secrets.h, test-compiles.
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # makes downloads much faster in Windows PowerShell

$Repo   = Split-Path -Parent $PSScriptRoot
$Sketch = Join-Path $Repo "firmware\Reach"
$CliDir = Join-Path $env:LOCALAPPDATA "arduino-cli"
$Cli    = Join-Path $CliDir "arduino-cli.exe"
$Fqbn   = "esp32:esp32:esp32"
$Esp32Index = "https://espressif.github.io/arduino-esp32/package_esp32_index.json"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Run([string[]]$cliArgs) {
  & $Cli @cliArgs
  if ($LASTEXITCODE -ne 0) { throw "FAILED: arduino-cli $($cliArgs -join ' ')" }
}

if (-not (Test-Path $Cli)) {
  Step "Downloading arduino-cli"
  New-Item -ItemType Directory -Force $CliDir | Out-Null
  $zip = Join-Path $env:TEMP "arduino-cli.zip"
  Invoke-WebRequest "https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip" -OutFile $zip
  Expand-Archive $zip -DestinationPath $CliDir -Force
}

Step "Installing ESP32 board support (large download - a few minutes)"
Run @("core", "update-index", "--additional-urls", $Esp32Index)
Run @("core", "install", "esp32:esp32", "--additional-urls", $Esp32Index)

Step "Installing OLED library"
Run @("lib", "install", "Adafruit SSD1306", "Adafruit GFX Library")

$Secrets = Join-Path $Sketch "secrets.h"
if (-not (Test-Path $Secrets)) {
  Step "Phone hotspot details (the hotspot must be 2.4 GHz)"
  $ssid = Read-Host "Hotspot name"
  $pass = Read-Host "Hotspot password"
  "#pragma once`r`n#define WIFI_SSID `"$ssid`"`r`n#define WIFI_PASS `"$pass`"`r`n" | Set-Content -Encoding ASCII -NoNewline $Secrets
  Write-Host "Saved $Secrets (git-ignored)."
}

Step "Test-compiling the firmware"
Run @("compile", "--fqbn", $Fqbn, $Sketch)

Write-Host "`nSETUP DONE. Plug the ESP32 into USB, then run:" -ForegroundColor Green
Write-Host "  powershell -ExecutionPolicy Bypass -File tools\flash.ps1" -ForegroundColor Green
