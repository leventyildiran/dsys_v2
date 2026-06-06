@echo off
echo Flutter web derlemesi basliyor...
call flutter build web --release
if %errorlevel% neq 0 (
    echo Flutter derleme hatasi!
    exit /b %errorlevel%
)

echo.
echo Firebase'e gonderiliyor...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo Firebase deploy hatasi!
    exit /b %errorlevel%
)

echo.
echo Islem tamamlandi!
