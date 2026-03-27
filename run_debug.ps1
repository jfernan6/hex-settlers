# run_debug.ps1
# Runs the game in debug-screenshot mode, captures all output, and saves a log.
# Usage: Right-click -> Run with PowerShell  (or: powershell -File run_debug.ps1)

$project = Split-Path -Parent $MyInvocation.MyCommand.Path
$godot   = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }
$logDir  = Join-Path $project "debug\screenshots\latest_run"
$logFile = Join-Path $logDir "latest_run.log"
$latest  = Join-Path $project "debug\screenshots\latest.png"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host "=== Hex Settlers Debug Run ===" -ForegroundColor Cyan
Write-Host "Running game and capturing output..." -ForegroundColor Yellow

# Run Godot with debug-screenshot flag; capture output to log and display it
& $godot --path "$project" -- --debug-screenshot 2>&1 | Tee-Object -FilePath $logFile

Write-Host "`n=== Done ===" -ForegroundColor Cyan
if (Test-Path $latest) {
    Write-Host "Screenshot: $latest" -ForegroundColor Green
} else {
    Write-Host "No screenshot found — check for errors above." -ForegroundColor Red
}
Write-Host "Log:        $logFile" -ForegroundColor Green
