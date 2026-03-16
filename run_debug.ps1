# run_debug.ps1
# Runs the game in debug-screenshot mode, captures all output, and saves a log.
# Usage: Right-click -> Run with PowerShell  (or: powershell -File run_debug.ps1)

$godot   = "C:\Users\jefernandez\Desktop\game_dev\godot\Godot_v4.6.1-stable_win64_console.exe"
$project = "C:\Users\jefernandez\Desktop\game_dev\hex-settlers"
$logFile = "$project\debug-screenshots\latest_run.log"

Write-Host "=== Hex Settlers Debug Run ===" -ForegroundColor Cyan
Write-Host "Running game and capturing output..." -ForegroundColor Yellow

# Run Godot with debug-screenshot flag; capture output to log and display it
& $godot --path "$project" -- --debug-screenshot 2>&1 | Tee-Object -FilePath $logFile

# Find the latest screenshot saved by the game
$latest = Get-ChildItem -Path "$project\debug-screenshots" -Filter "run_*.png" `
          | Sort-Object LastWriteTime -Descending `
          | Select-Object -First 1

Write-Host "`n=== Done ===" -ForegroundColor Cyan
if ($latest) {
    Write-Host "Screenshot: $($latest.FullName)" -ForegroundColor Green
} else {
    Write-Host "No screenshot found — check for errors above." -ForegroundColor Red
}
Write-Host "Log:        $logFile" -ForegroundColor Green
