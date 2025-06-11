@echo off

REM Must be run as Administrator

REM Enable classic context menus in Explorer
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\FlightedFeatures" /v ImmersiveContextMenu /t REG_DWORD /d 0 /f

REM Revert back to immersive context menus
REM reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\FlightedFeatures" /v ImmersiveContextMenu /f

REM Restart Explorer to apply changes immediately
echo Restarting Explorer to apply changes...
taskkill /f /im explorer.exe
start explorer.exe

echo.
echo Immersive context menu status updated in Explorer.
pause
