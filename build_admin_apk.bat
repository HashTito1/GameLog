@echo off
echo Building GameLog APKs...
echo.

if not exist dart_defines.json (
    echo dart_defines.json not found. Copy dart_defines.example.json to dart_defines.json and add your API keys.
    pause
    exit /b 1
)
if not exist android\key.properties (
    echo WARNING: android\key.properties not found - release APKs will be signed with the debug key.
    echo See README.md "Release signing" before publishing.
    echo.
)

echo Step 1: Building User APK...
flutter build apk --flavor user --target lib/main.dart --release --dart-define-from-file=dart_defines.json
if %errorlevel% neq 0 (
    echo Failed to build user APK
    pause
    exit /b 1
)

echo.
echo Step 2: Building Admin APK...
flutter build apk --flavor admin --target lib/main_admin.dart --release --dart-define-from-file=dart_defines.json
if %errorlevel% neq 0 (
    echo Failed to build admin APK
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
echo.
echo APK Files:
echo - User APK: build\app\outputs\flutter-apk\app-user-release.apk
echo - Admin APK: build\app\outputs\flutter-apk\app-admin-release.apk
echo.
echo Install "GameLog" on regular user devices and "GameLogs Admin" only on admin devices.
echo Admin access is controlled by the admins/list document in Firestore (see docs/ADMIN_SETUP.md).
echo.
pause
