@echo off
setlocal enabledelayedexpansion

echo Searching for Visual Studio installations...
echo =========================================

REM Check for vswhere.exe in Program Files
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist %VSWHERE% (
    echo Found vswhere.exe at: %VSWHERE%
    echo.
    echo Detected Visual Studio installations:
    echo ----------------------------------
    %VSWHERE% -all -products * -format json
) else (
    echo vswhere.exe not found in default location.
)

echo.
echo =========================================
echo Checking common installation paths...
echo.

REM Check common VS 2022 paths
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe" (
    echo Found VS 2022 Community at: C:\Program Files\Microsoft Visual Studio\2022\Community
    set "VS2022_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community"
)

if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe" (
    echo Found VS 2022 Professional at: C:\Program Files\Microsoft Visual Studio\2022\Professional
    set "VS2022_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional"
)

if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe" (
    echo Found VS 2022 Enterprise at: C:\Program Files\Microsoft Visual Studio\2022\Enterprise
    set "VS2022_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
)

REM Check common VS 2019 paths
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\IDE\devenv.exe" (
    echo Found VS 2019 Community at: C:\Program Files (x86)\Microsoft Visual Studio\2019\Community
    set "VS2019_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community"
)

if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\devenv.exe" (
    echo Found VS 2019 Professional at: C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
    set "VS2019_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional"
)

if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\devenv.exe" (
    echo Found VS 2019 Enterprise at: C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise
    set "VS2019_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise"
)

REM Check common VS 2017 paths
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\devenv.exe" (
    echo Found VS 2017 Community at: C:\Program Files (x86)\Microsoft Visual Studio\2017\Community
    set "VS2017_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2017\Community"
)

if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" (
    echo Found VS 2017 Professional at: C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional
    set "VS2017_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional"
)

if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\devenv.exe" (
    echo Found VS 2017 Enterprise at: C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise
    set "VS2017_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise"
)

echo.
echo =========================================
if defined VS2022_PATH (
    echo Most recent VS installation found: %VS2022_PATH%
) else if defined VS2019_PATH (
    echo Most recent VS installation found: %VS2019_PATH%
) else if defined VS2017_PATH (
    echo Most recent VS installation found: %VS2017_PATH%
) else (
    echo No Visual Studio installations found in common locations.
)

echo.
pause
