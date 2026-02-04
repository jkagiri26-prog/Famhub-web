@echo off
echo Testing Flutter Environment...
echo.

echo 1. Checking Flutter version...
C:\Users\user\Documents\flutter\bin\flutter.bat --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter version check failed
    goto :error
)
echo.

echo 2. Checking Flutter doctor...
timeout 10 C:\Users\user\Documents\flutter\bin\flutter.bat doctor --verbose
echo.

echo 3. Checking project structure...
if exist "lib\main.dart" (
    echo ✓ main.dart found
) else (
    echo ✗ main.dart not found
)

if exist "pubspec.yaml" (
    echo ✓ pubspec.yaml found
) else (
    echo ✗ pubspec.yaml not found
)
echo.

echo 4. Checking dependencies...
C:\Users\user\Documents\flutter\bin\flutter.bat pub get
echo.

echo 5. Testing build...
C:\Users\user\Documents\flutter\bin\flutter.bat build web --debug
if %errorlevel% neq 0 (
    echo ERROR: Build failed
    goto :error
)
echo.

echo SUCCESS: Flutter environment is working!
echo You can now run: flutter run -d chrome
goto :end

:error
echo.
echo FAILED: Flutter environment has issues
echo Please run fix_flutter_environment.bat

:end
pause