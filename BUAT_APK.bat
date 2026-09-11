@echo off
setlocal
echo ==========================================
echo    MEMULAI PROSES BUILD APK (Talog20)
echo ==========================================

cd /d %~dp0

:: Hapus APK lama agar tidak tertukar
if exist "Talogsmkn20.apk" del "Talogsmkn20.apk"
if exist "build\app\outputs\flutter-apk\app-release.apk" del "build\app\outputs\flutter-apk\app-release.apk"

echo Membersihkan cache...
call flutter clean

echo Mengunduh dependensi...
call flutter pub get

echo Memulai Build (Ini butuh waktu 2-5 menit)...
:: Jalankan build (Single APK)
call flutter build apk --release --dart-define=SUPABASE_URL=https://bnajhpskaspkpqobipzc.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_w4Yw1I-ozDmGTtD50Ft9Hg_tXvqzVj2

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUKSES] Build selesai!

    set "OUT_DIR=%cd%\build\app\outputs\flutter-apk"
    set "OLD_NAME=app-release.apk"
    set "NEW_NAME=Talogsmkn20.apk"

    echo Mengganti nama file menjadi %NEW_NAME%...
    ren "%OUT_DIR%\%OLD_NAME%" "%NEW_NAME%"

    :: Salin ke folder utama agar Bagas gampang cari
    copy "%OUT_DIR%\%NEW_NAME%" "%cd%\%NEW_NAME%"

    echo.
    echo ==========================================
    echo    APK SIAP DI FOLDER UTAMA: %NEW_NAME%
    echo ==========================================
    start explorer "%cd%\"
) else (
    echo.
    echo [ERROR] Build gagal. Cek pesan error di atas.
    pause
)
endlocal
