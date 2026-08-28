@echo off
setlocal EnableDelayedExpansion
set "HUST_HOME=%~dp0"
for /f "tokens=2,*" %%A in ('reg query HKCU\Environment /v Path 2^>nul') do set "OLDPATH=%%B"
set "NEWPATH=!OLDPATH:%HUST_HOME%;=!"
set "NEWPATH=!NEWPATH:;%HUST_HOME%=!"
set "NEWPATH=!NEWPATH:%HUST_HOME%=!"
setx PATH "!NEWPATH!" >nul
echo Removed Hust package folder from your user PATH where present.
