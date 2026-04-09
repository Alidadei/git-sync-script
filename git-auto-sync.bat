@echo off
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
set "REPO_LIST=%SCRIPT_DIR%repos.txt"
set "LOG_FILE=%SCRIPT_DIR%git-auto-sync.log"
set "TMP_LOG=%SCRIPT_DIR%git-auto-sync.tmp"

:: Truncate temp file
echo. > "%TMP_LOG%" 2>nul

call :log "=== Sync started ==="

if not exist "%REPO_LIST%" (
    call :log "ERROR repos.txt not found"
    goto :finish
)

for /f "usebackq tokens=* delims=" %%R in ("%REPO_LIST%") do (
    call :sync_repo "%%R"
)

:finish
call :log "=== Sync finished ==="

:: Prepend new log to main log (newest first), with UTF-8 BOM
powershell -NoProfile -Command ^
    "$new=[IO.File]::ReadAllText('%TMP_LOG%',[Text.Encoding]::UTF8);" ^
    "$old=''; if(Test-Path '%LOG_FILE%'){$old=[IO.File]::ReadAllText('%LOG_FILE%',[Text.Encoding]::UTF8)};" ^
    "[IO.File]::WriteAllText('%LOG_FILE%',([char]239+[char]187+[char]191)+$new+$old,(New-Object Text.UTF8Encoding $false));" ^
    "Remove-Item '%TMP_LOG%' -Force" >nul 2>&1
exit /b 0

:: === Subroutines ===

:log
echo [%date% %time:~0,8%] %~1 >> "%TMP_LOG%"
goto :eof

:sync_repo
set "REPO=%~1"

if "%REPO%"=="" goto :eof
echo %REPO% | findstr /b "#" >nul
if not errorlevel 1 goto :eof

if not exist "%REPO%\.git" (
    call :log "SKIP %REPO% not a git repo"
    goto :eof
)

call :log "Syncing %REPO%"

pushd "%REPO%"

git add -A 2>> "%TMP_LOG%"

git diff --cached --quiet 2>nul
if errorlevel 1 (
    git commit -m "auto sync %date:/=-% %time:~0,5%" >> "%TMP_LOG%" 2>&1
    call :log "  Committed"
) else (
    call :log "  Nothing to commit"
)

git pull --rebase --autostash >> "%TMP_LOG%" 2>&1

git push >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
    call :log "  ERROR Push failed"
) else (
    call :log "  Pushed"
)

popd
goto :eof
