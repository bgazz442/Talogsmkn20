@echo off
setlocal

set APP_DIR=%APPDATA%\Talog20
set SOURCE_FILE=%~dp0supabase.env.example
set DEST_FILE=%APP_DIR%\supabase.env

if not exist "%APP_DIR%" mkdir "%APP_DIR%"

if exist "%SOURCE_FILE%" (
    copy /Y "%SOURCE_FILE%" "%DEST_FILE%"
    echo Supabase env berhasil dibuat di %DEST_FILE%
    echo.
    echo Edit file berikut sebelum menjalankan aplikasi Windows:
    echo %DEST_FILE%
    echo.
    echo Contoh isi file:
    echo SUPABASE_URL=https://bnajhpskaspkpqobipzc.supabase.co
    echo SUPABASE_ANON_KEY=sb_publishable_w4Yw1I-ozDmGTtD50Ft9Hg_tXvqzVj2
) else (
    echo File sumber tidak ditemukan: %SOURCE_FILE%
    echo Pastikan supabase.env.example ada di folder project ini.
    exit /b 1
)

endlocal
