@echo off
echo ==========================================
echo   FamHub - Local Dev with --dart-define
echo ==========================================
echo.

REM Read .env file and extract SUPABASE_URL and SUPABASE_ANON_KEY
for /f "tokens=*" %%a in ('findstr /b "SUPABASE_URL=" .env 2^>nul') do set %%a
for /f "tokens=*" %%b in ('findstr /b "SUPABASE_ANON_KEY=" .env 2^>nul') do set %%b

if "%SUPABASE_URL%"=="" (
    echo ERROR: SUPABASE_URL not found in .env file
    echo Make sure .env exists and has SUPABASE_URL=your-url
    pause
    exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
    echo ERROR: SUPABASE_ANON_KEY not found in .env file
    echo Make sure .env exists and has SUPABASE_ANON_KEY=your-key
    pause
    exit /b 1
)

echo Using SUPABASE_URL=%SUPABASE_URL%
echo Using SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
echo.

echo Installing dependencies...
C:\Users\user\Documents\flutter\bin\flutter.bat pub get
echo.

echo Launching app in Chrome...
C:\Users\user\Documents\flutter\bin\flutter.bat run -d chrome --dart-define=SUPABASE_URL="%SUPABASE_URL%" --dart-define=SUPABASE_ANON_KEY="%SUPABASE_ANON_KEY%"

echo.
echo App should now be running in Chrome!
pause
