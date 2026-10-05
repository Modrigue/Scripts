@echo off
rem Double-click launcher for Get-RamInfo.ps1: bypasses the execution policy
rem for this run only, forwards any arguments, and keeps the window open.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-RamInfo.ps1" %*
pause
