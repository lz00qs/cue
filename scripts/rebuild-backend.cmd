@echo off
setlocal

set "PROJECT_DIR=%~dp0.."

where dart >nul 2>nul
if errorlevel 1 (
  echo Error: Dart is not available in PATH. Install Flutter/Dart and try again. 1>&2
  exit /b 1
)

pushd "%PROJECT_DIR%"
dart run tool\rebuild_backend.dart %*
set "SCRIPT_EXIT_CODE=%ERRORLEVEL%"
popd

exit /b %SCRIPT_EXIT_CODE%
