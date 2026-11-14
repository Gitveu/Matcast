@echo off
setlocal
cd /d "%~dp0"
echo ==========================================
echo Starting Matcast Release Packager...
echo ==========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_release.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed! Check the output above.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo [DONE] Build completed successfully!
pause
