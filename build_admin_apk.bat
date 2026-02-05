@echo off
echo Building GameLogs Admin APK...
echo.

echo Step 1: Building User APK...
flutter build apk --flavor user --target lib/main.dart --release
if %errorlevel% neq 0 (
    echo Failed to build user APK
    pause
    exit /b 1
)

echo.
echo Step 2: Building Admin APK...
flutter build apk --flavor admin --target lib/main_admin.dart --release
if %errorlevel% neq 0 (
    echo Failed to build admin APK
    pause
    exit /b 1
)

echo.
echo ✅ Build completed successfully!
echo.
echo APK Files:
echo - User APK: build\app\outputs\flutter-apk\app-user-release.apk
echo - Admin APK: build\app\outputs\flutter-apk\app-admin-release.apk
echo.
echo 📱 Install Instructions:
echo 1. Install "GameLog" APK on regular user devices
echo 2. Install "GameLogs Admin" APK only on admin devices
echo 3. Super admin @petrch0rV will be automatically initialized
echo.
echo 🔐 Admin App Features:
echo - Dedicated admin dashboard
echo - Forum moderation tools
echo - Content moderation interface
echo - User management (super admin only)
echo.
pause