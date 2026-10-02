@echo off
setlocal
for %%I in ("%~dp0.") do set "FT_PROJECT=%%~fI"
set "FT_GODOT=F:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
set "APPDATA=%FT_PROJECT%\.cache\windows\roaming"
set "LOCALAPPDATA=%FT_PROJECT%\.cache\windows\local"
set "TEMP=%FT_PROJECT%\.cache\windows\temp"
set "TMP=%TEMP%"
set "FT_LOGS=%FT_PROJECT%\.cache\windows\logs"
for %%D in ("%APPDATA%" "%LOCALAPPDATA%" "%TEMP%" "%FT_LOGS%") do if not exist "%%~D" mkdir "%%~D"
if not exist "%FT_GODOT%" (
    echo Godot 4.7.2 was not found at "%FT_GODOT%".
    pause
    exit /b 1
)
if /I "%~1"=="--editor" goto editor
"%FT_GODOT%" --headless --editor --path "%FT_PROJECT%" --import --log-file "%FT_LOGS%\import.log"
if errorlevel 1 goto failed
if /I "%~1"=="--import-only" exit /b 0
"%FT_GODOT%" --path "%FT_PROJECT%" --log-file "%FT_LOGS%\playtest.log"
if errorlevel 1 goto failed
exit /b 0
:editor
"%FT_GODOT%" --editor --path "%FT_PROJECT%" --log-file "%FT_LOGS%\editor.log"
if errorlevel 1 goto failed
exit /b 0
:failed
echo Godot reported an error. Logs are in "%FT_LOGS%".
pause
exit /b 1
