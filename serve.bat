@echo off
REM Live-sync Survival Hour into Roblox Studio (see docs/LIVE_SYNC.md).
REM Needs rojo.exe (version 7.7.0) in this folder.
cd /d "%~dp0"
if not exist rojo.exe (
  echo rojo.exe not found. Download rojo-7.7.0-windows-x86_64.zip from
  echo https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0 and put rojo.exe in this folder.
  pause
  exit /b 1
)
echo Rojo is running. In Studio: Plugins ^> Rojo ^> Connect. Leave this window open.
rojo.exe serve default.project.json
pause
