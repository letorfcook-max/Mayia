@echo off
setlocal
cd /d "%~dp0"
where node.exe >nul 2>&1
if errorlevel 1 (
  echo Install Node.js 22 LTS first.
  pause
  exit /b 1
)
node "%~dp0scripts\native-launch.cjs" test
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" echo Model operation failed. Review the output above.
pause
exit /b %RESULT%
