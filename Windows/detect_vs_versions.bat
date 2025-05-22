@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo Searching for Visual Studio installations...
echo ========================================
echo.

echo Checking common installation paths...
echo.

set "PATHS_TO_CHECK="

:: VS 2022 (64-bit)
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files\Microsoft Visual Studio\2022\Community""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files\Microsoft Visual Studio\2022\Professional""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files\Microsoft Visual Studio\2022\Enterprise""

:: VS 2019 (64-bit)
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files\Microsoft Visual Studio\2019\Community""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files\Microsoft Visual Studio\2019\Professional""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files\Microsoft Visual Studio\2019\Enterprise""

:: VS 2019 (32-bit)
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise""

:: VS 2017 (32-bit)
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional""
set "PATHS_TO_CHECK=!PATHS_TO_CHECK! "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise""

:: Check all paths
set FOUND=0
for %%P in (!PATHS_TO_CHECK!) do (
    if exist "%%~P\Common7\IDE\devenv.exe" (
        echo Found Visual Studio at: %%~P
        set /a FOUND+=1
    )
)

echo.
echo ========================================
if !FOUND! EQU 0 (
    echo No Visual Studio installations found in common locations.
    echo.
    echo Checking registry...
    reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\SxS\VS7" /s 2>nul | findstr /i "17.0 16.0 15.0"
) else (
    echo Found !FOUND! Visual Studio installation(s).
)

echo.
echo ========================================
echo Checking for vswhere.exe...
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist %VSWHERE% (
    echo vswhere.exe found at: %VSWHERE%
    echo.
    echo Running vswhere to find installations:
    %VSWHERE% -all -products * -format json
) else (
    echo vswhere.exe not found at: %VSWHERE%
)

echo.
pause
