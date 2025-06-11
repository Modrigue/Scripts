@echo off
REM Create the Registry key to disable web search in taskbar
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f

REM Create the Registry key to re-enable web search in taskbar
REM reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /f

REM Restart Windows Explorer to apply changes immediately
echo Restarting Explorer...
taskkill /f /im explorer.exe
start explorer.exe

echo.
echo Bing/web search in taskbar has been disabled.
pause