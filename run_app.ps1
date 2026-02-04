# FamHub App Preview Launcher
Write-Host "Opening FamHub App Preview in Chrome..." -ForegroundColor Green

# Get the current directory and create the full path to index.html
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$htmlPath = Join-Path $currentDir "index.html"
$chromePath = "file://$htmlPath"

# Try to open in Chrome
try {
    Start-Process "chrome" $chromePath
    Write-Host "Chrome opened successfully!" -ForegroundColor Green
} catch {
    Write-Host "Could not open Chrome automatically." -ForegroundColor Yellow
    Write-Host "Please manually open: $htmlPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Your FamHub Flutter app preview should now be visible!" -ForegroundColor Green
Read-Host "Press Enter to exit"