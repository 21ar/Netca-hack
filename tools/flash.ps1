# Upload the firmware to the ESP32 and show its serial output (the IP address).
#   powershell -ExecutionPolicy Bypass -File tools\flash.ps1
# Run tools\setup.ps1 once first. Re-run this after any code change.
$ErrorActionPreference = "Stop"

$Repo   = Split-Path -Parent $PSScriptRoot
$Sketch = Join-Path $Repo "firmware\Reach"
$Cli    = Join-Path $env:LOCALAPPDATA "arduino-cli\arduino-cli.exe"
$Fqbn   = "esp32:esp32:esp32"

if (-not (Test-Path $Cli)) { throw "arduino-cli not found - run tools\setup.ps1 first" }
if (-not (Test-Path (Join-Path $Sketch "secrets.h"))) { throw "secrets.h missing - run tools\setup.ps1 first" }

$ports = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object -Unique)
if ($ports.Count -eq 0) {
  throw "No COM port found. Try another USB cable (some are charge-only), or install the USB driver for the chip next to the ESP32's USB socket: CP2102 -> 'CP210x driver', CH340 -> 'CH340 driver'."
}
if ($ports.Count -eq 1) { $port = $ports[0] }
else {
  Write-Host "COM ports found: $($ports -join ', ')"
  $port = Read-Host "Which one is the ESP32? (unplug it and run again to see which one disappears)"
}

Write-Host "`n==> Compiling and uploading to $port" -ForegroundColor Cyan
Write-Host "    If it gets stuck on 'Connecting....', hold the BOOT button on the ESP32." -ForegroundColor Yellow
& $Cli compile --fqbn $Fqbn --upload -p $port $Sketch
if ($LASTEXITCODE -ne 0) { throw "Upload failed - see the error above" }

Write-Host "`n==> Serial monitor (look for 'Open on phone: http://...'). Press the EN/RST button to see it again. Ctrl+C to quit." -ForegroundColor Green
& $Cli monitor -p $port --config baudrate=115200
