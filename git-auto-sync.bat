@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "REPO_LIST=%SCRIPT_DIR%repos.txt"
set "LOG_FILE=%SCRIPT_DIR%logs\git-auto-sync.log"

echo [%date% %time:~0,8%] Sync started >> "%LOG_FILE%"

if not exist "%REPO_LIST%" (
    echo [%date% %time:~0,8%] ERROR repos.txt not found >> "%LOG_FILE%"
    exit /b 1
)

for /f "usebackq eol= tokens=* delims=" %%R in ("%REPO_LIST%") do (
    call :sync_repo "%%R"
)

echo [%date% %time:~0,8%] Sync finished >> "%LOG_FILE%"
exit /b 0

:sync_repo
setlocal DisableDelayedExpansion
set "REPO=%~1"

if "%REPO%"=="" goto :sync_repo_end
if "%REPO:~0,1%"=="#" goto :sync_repo_end

if not exist "%REPO%\.git" (
    echo [%date% %time:~0,8%] SKIP %REPO% not a git repo >> "%LOG_FILE%"
    goto :sync_repo_end
)

echo [%date% %time:~0,8%] Syncing %REPO% >> "%LOG_FILE%"

pushd "%REPO%" >nul 2>&1
if errorlevel 1 (
    echo [%date% %time:~0,8%] ERROR Failed to enter %REPO% >> "%LOG_FILE%"
    goto :sync_repo_end
)

git add -A 2>> "%LOG_FILE%"

git diff --cached --quiet 2>nul
if errorlevel 1 (
    git commit -m "auto sync %date:/=-% %time:~0,5%" >> "%LOG_FILE%" 2>&1
    echo [%date% %time:~0,8%]   Committed >> "%LOG_FILE%"
) else (
    echo [%date% %time:~0,8%]   Nothing to commit >> "%LOG_FILE%"
)

git pull --rebase --autostash >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo [%date% %time:~0,8%]   ERROR Pull failed >> "%LOG_FILE%"
    call :abort_rebase_if_needed
    echo [%date% %time:~0,8%]   Skipped push >> "%LOG_FILE%"
    popd
    goto :sync_repo_end
)

git push >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo [%date% %time:~0,8%]   ERROR Push failed >> "%LOG_FILE%"
) else (
    echo [%date% %time:~0,8%]   Pushed >> "%LOG_FILE%"
)

popd

:sync_repo_end
endlocal
goto :eof

:abort_rebase_if_needed
set "REBASE_MERGE="
for /f "delims=" %%G in ('git rev-parse --git-path rebase-merge 2^>nul') do set "REBASE_MERGE=%%G"
if defined REBASE_MERGE if exist "%REBASE_MERGE%\NUL" goto :do_abort_rebase

set "REBASE_APPLY="
for /f "delims=" %%G in ('git rev-parse --git-path rebase-apply 2^>nul') do set "REBASE_APPLY=%%G"
if defined REBASE_APPLY if exist "%REBASE_APPLY%\NUL" goto :do_abort_rebase

:: Also check for merge/cherry-pick conflicts
set "MERGE_HEAD="
for /f "delims=" %%G in ('git rev-parse --git-path MERGE_HEAD 2^>nul') do set "MERGE_HEAD=%%G"
if defined MERGE_HEAD if exist "%MERGE_HEAD%" goto :do_abort_merge

set "CHERRY_HEAD="
for /f "delims=" %%G in ('git rev-parse --git-path CHERRY_PICK_HEAD 2^>nul') do set "CHERRY_HEAD=%%G"
if defined CHERRY_HEAD if exist "%CHERRY_HEAD%" goto :do_abort_merge

goto :eof

:do_abort_rebase
git rebase --abort >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo [%date% %time:~0,8%]   ERROR Rebase abort failed >> "%LOG_FILE%"
) else (
    echo [%date% %time:~0,8%]   Rebase aborted >> "%LOG_FILE%"
)
call :drop_leftover_stash
goto :eof

:do_abort_merge
git merge --abort >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo [%date% %time:~0,8%]   ERROR Merge abort failed >> "%LOG_FILE%"
) else (
    echo [%date% %time:~0,8%]   Merge aborted >> "%LOG_FILE%"
)
call :drop_leftover_stash
goto :eof

:drop_leftover_stash
:: If autostash pop failed, a stash entry may remain
git stash drop >> "%LOG_FILE%" 2>&1
if not errorlevel 1 (
    echo [%date% %time:~0,8%]   Dropped leftover stash >> "%LOG_FILE%"
)
goto :eof
