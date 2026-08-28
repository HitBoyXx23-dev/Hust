@echo off
setlocal
if "%~1"=="" (
  echo Drop a .rs file or a folder onto this script, or run:
  echo   convert_rust.bat input.rs output.hs
  echo   convert_rust.bat input_folder output_folder
  pause
  exit /b 1
)
if exist "%~1\*" (
  if "%~2"=="" ( "%~dp0HustInterpreter.exe" --convert-rust-dir "%~1" "%~1_hust" ) else ( "%~dp0HustInterpreter.exe" --convert-rust-dir "%~1" "%~2" )
) else (
  if "%~2"=="" ( "%~dp0HustInterpreter.exe" --convert-rust "%~1" "%~dpn1.hs" ) else ( "%~dp0HustInterpreter.exe" --convert-rust "%~1" "%~2" )
)
pause
