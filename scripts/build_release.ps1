# Matcast Release Packaging Script
# Builds optimized release binary and packages into a portable ZIP archive

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Matcast Portable Release Packager     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$projectRoot\pubspec.yaml")) {
    $projectRoot = (Get-Location).Path
}

Set-Location $projectRoot
Write-Host "Project root: $projectRoot" -ForegroundColor Gray

# 1. Terminate any running instance of matcast or zombie dns-sd
Write-Host "`n[1/5] Checking for running instances..." -ForegroundColor Yellow
Stop-Process -Name "matcast","dns-sd" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# 2. Build Release Windows App
Write-Host "`n[2/5] Building Flutter Windows (Release mode)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter release build failed with exit code $LASTEXITCODE"
}

$releaseDir = "$projectRoot\build\windows\x64\runner\Release"
if (-not (Test-Path "$releaseDir\matcast.exe")) {
    Write-Error "Could not find matcast.exe in $releaseDir"
}

# 3. Verify and Copy Receiver Libs
Write-Host "`n[3/5] Verifying native receiver libraries..." -ForegroundColor Yellow
$receiverLibsDir = "$projectRoot\windows\receiver_libs"
if (Test-Path $receiverLibsDir) {
    Get-ChildItem -Path "$receiverLibsDir\*.dll" -Exclude "*.bak" | ForEach-Object {
        $dest = Join-Path $releaseDir $_.Name
        Copy-Item $_.FullName $dest -Force
    }
}

# 4. Prepare Staging Directory for Clean Portable Distribution
Write-Host "`n[4/5] Preparing portable distribution package..." -ForegroundColor Yellow
$distDir = "$projectRoot\dist\Matcast-Portable"
if (!(Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# Copy application files (excluding .pdb symbols and dev artifacts)
Copy-Item "$releaseDir\matcast.exe" "$distDir\" -Force
Copy-Item "$releaseDir\data" "$distDir\data" -Recurse -Force
Get-ChildItem -Path "$releaseDir\*.dll" | Copy-Item -Destination "$distDir\" -Force

# Create clean default settings file if not present
$defaultSettings = @"
{
  "receiverName": "Matcast",
  "autoStart": true,
  "castPort": 8009,
  "miracastPort": 7236,
  "rtpPort": 19999,
  "enableGoogleCast": true,
  "enableMiracast": true,
  "hardwareDecoding": true,
  "autoFullScreenOnConnect": false,
  "themeMode": 0,
  "targetWidth": 1920,
  "targetHeight": 1080,
  "targetFps": 60
}
"@
Set-Content -Path "$distDir\matcast_settings.json" -Value $defaultSettings -Encoding UTF8

# Add README.txt
$readme = @"
Matcast - Windows Screen Cast Receiver (Portable)
==================================================
Бесплатный приёмник трансляций Google Cast и Miracast с Android на Windows.

Инструкция по запуску:
1. Запустите matcast.exe (установка и права администратора не требуются).
2. На телефоне Android опустите шторку быстрых настроек и нажмите «Трансляция» (Google Cast).
3. В списке выберите «Matcast». Экран вашего телефона появится на компьютере.

Требования:
- Компьютер и телефон должны быть подключены к одной локальной сети (Wi-Fi или Ethernet).
- Windows 10 или Windows 11 (x64).
"@
Set-Content -Path "$distDir\README.txt" -Value $readme -Encoding UTF8

# 5. Create ZIP Archive
Write-Host "`n[5/5] Creating ZIP archive..." -ForegroundColor Yellow
$zipOutput = "$projectRoot\dist\Matcast-Windows-Portable.zip"
if (Test-Path $zipOutput) {
    Remove-Item $zipOutput -Force
}

Compress-Archive -Path "$distDir\*" -DestinationPath $zipOutput -CompressionLevel Optimal

$zipInfo = Get-Item $zipOutput
$zipSizeMb = [Math]::Round($zipInfo.Length / 1MB, 2)

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "   Release Archive Created Successfully!   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Archive Path: $($zipInfo.FullName)" -ForegroundColor White
Write-Host "Archive Size: $zipSizeMb MB" -ForegroundColor White
Write-Host "Ready for distribution or copying to USB/flash drive." -ForegroundColor Green
