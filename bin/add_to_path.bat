@echo off
setlocal
set "HUST_HOME=%~dp0"
for /f "tokens=2,*" %%A in ('reg query HKCU\Environment /v Path 2^>nul') do set "OLDPATH=%%B"
echo %OLDPATH% | find /I "%HUST_HOME%" >nul
if not errorlevel 1 (
  echo Hust is already in your user PATH.
  exit /b 0
)
if defined OLDPATH (setx PATH "%OLDPATH%;%HUST_HOME%" >nul) else (setx PATH "%HUST_HOME%" >nul)
echo Added %HUST_HOME% to your user PATH.
echo Open a new terminal before using Hust programs by name.
