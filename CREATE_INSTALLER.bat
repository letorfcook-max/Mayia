@echo off
setlocal
cd /d "%~dp0"
where node.exe >nul 2>&1
if errorlevel 1 (
  echo Install Node.js 22 LTS from https://nodejs.org/ then open this file again.
  pause
  exit /b 1
)
node "%~dp0scripts\launchers.cjs" windows
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" echo MAYIA operation failed. Review the error above.
pause
exit /b %RESULT%
