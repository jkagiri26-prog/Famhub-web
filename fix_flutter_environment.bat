@echo off
echo ==========================================
echo   Flutter Environment Fix Script
echo ==========================================
echo.

echo Setting ANDROID_HOME environment variable...
setx ANDROID_HOME "C:\Users\user\AppData\Local\Android\Sdk"
echo.

echo Setting up PATH for Android tools...
setx PATH "%PATH%;C:\Users\user\AppData\Local\Android\Sdk\platform-tools;C:\Users\user\AppData\Local\Android\Sdk\tools;C:\Users\user\AppData\Local\Android\Sdk\tools\bin" /M 2>nul
if %errorlevel% neq 0 (
    echo Note: PATH update requires administrator privileges.
    echo You may need to run this script as Administrator.
)
echo.

echo Checking Flutter installation...
C:\Users\user\Documents\flutter\bin\flutter.bat --version
if %errorlevel% neq 0 (
    echo Flutter installation issue detected.
    goto :error
)
echo.

echo Installing Flutter dependencies...
C:\Users\user\Documents\flutter\bin\flutter.bat pub get
echo.

echo Checking available devices...
C:\Users\user\Documents\flutter\bin\flutter.bat devices
echo.

echo ==========================================
echo   Environment Setup Complete!
echo ==========================================
echo.
echo You can now run your Flutter app with:
echo   run_flutter_app.bat          (recommended)
echo   flutter run -d chrome        (web)
echo   flutter run -d windows       (desktop)
echo.
echo To fix Android development:
echo   1. Open Android Studio
echo   2. Go to SDK Manager
echo   3. Install cmdline-tools
echo   4. Run: flutter doctor --android-licenses
echo.
pause
goto :end

:error
echo.
echo ERROR: Flutter setup failed.
echo Please check your Flutter installation.
pause

:end