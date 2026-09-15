@echo off
setlocal

set "SUPABASE_URL=https://PROJECT_ID.supabase.co"
set "SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY"

if "%SUPABASE_URL%"=="" (
    echo ERROR: SUPABASE_URL kosong.
    exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
    echo ERROR: SUPABASE_ANON_KEY kosong.
    exit /b 1
)

flutter clean
if errorlevel 1 (
    echo ERROR: flutter clean gagal.
    exit /b 1
)

flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get gagal.
    exit /b 1
)

flutter build windows --release ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if errorlevel 1 (
    echo ERROR: build windows release gagal.
    exit /b 1
)

echo.
echo ========================================
echo BUILD WINDOWS BERHASIL
echo ========================================
echo Hasil:
echo build\windows\x64\runner\Release\
echo.
pause
