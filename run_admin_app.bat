@echo off
echo Starting GameLogs Admin Dashboard...
echo.
echo This will run the dedicated admin dashboard app.
echo Only users with admin privileges can access admin features.
echo.
if not exist dart_defines.json (
    echo dart_defines.json not found. Copy dart_defines.example.json to dart_defines.json and add your API keys.
    pause
    exit /b 1
)
flutter run --flavor admin --target lib/main_admin.dart --dart-define-from-file=dart_defines.json
