@echo off
echo ==========================================
echo   FamHub Flutter App Launcher
echo ==========================================
echo.

echo Installing dependencies...
C:\Users\user\Documents\flutter\bin\flutter.bat pub get
echo.

echo Launching app in Chrome...
C:\Users\user\Documents\flutter\bin\flutter.bat run -d chrome

echo.
echo App should now be running in Chrome!
pause