@echo off
echo ==========================================
echo   FRESH FLUTTER START - Clean Environment
echo ==========================================
echo.

echo Killing any existing Flutter processes...
taskkill /f /im flutter.bat 2>nul
taskkill /f /im dart.exe 2>nul
taskkill /f /im chrome.exe 2>nul
timeout 2 >nul
echo.

echo Checking Flutter installation...
C:\Users\user\Documents\flutter\bin\flutter.bat --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter not found
    goto :error
)
echo.

echo Clearing Flutter cache...
C:\Users\user\Documents\flutter\bin\flutter.bat clean
echo.

echo Getting dependencies...
C:\Users\user\Documents\flutter\bin\flutter.bat pub get
echo.

echo Starting Flutter in Chrome...
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --new-window --disable-web-security --disable-features=VizDisplayCompositor
timeout 3 >nul

C:\Users\user\Documents\flutter\bin\flutter.bat run -d chrome --web-hostname localhost --web-port 8080

echo.
echo If app doesn't load, try:
echo 1. Close all Chrome windows
echo 2. Run this script again
echo.
goto :end

:error
echo.
echo ERROR: Flutter environment issue
echo Run: fix_flutter_environment.bat

:end
pause