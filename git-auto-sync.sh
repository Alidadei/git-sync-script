#!/bin/bash

# Git Auto Sync Script (Linux / macOS)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_LIST="$SCRIPT_DIR/repos.txt"
LOG_FILE="$SCRIPT_DIR/logs/git-auto-sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

is_rebase_in_progress() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
    [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]
}

is_merge_in_progress() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
    [ -f "$git_dir/MERGE_HEAD" ] || [ -f "$git_dir/CHERRY_PICK_HEAD" ]
}

drop_leftover_stash() {
    if git stash drop >> "$LOG_FILE" 2>&1; then
        log "  Dropped leftover stash"
    fi
}

sync_repo() {
    local repo="$1"
    local branch="HEAD"

    if [ ! -e "$repo/.git" ]; then
        log "SKIP: $repo is not a git repo"
        return
    fi

    log "Syncing: $repo"

    if ! pushd "$repo" > /dev/null; then
        log "  ERROR: Failed to enter repo $repo"
        return
    fi

    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo HEAD)"

    # Add all changes
    git add -A

    # Commit if there are staged changes
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "auto sync $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE" 2>&1
        log "  Committed"
    else
        log "  Nothing to commit"
    fi

    # Pull with rebase; abort and skip push if pull/rebase fails
    if git pull --rebase --autostash >> "$LOG_FILE" 2>&1; then
        if git push >> "$LOG_FILE" 2>&1; then
            log "  Pushed"
        else
            log "  ERROR: Push failed"
        fi
    else
        log "  ERROR: Pull/rebase failed for $repo on branch $branch"

        if is_rebase_in_progress; then
            if git rebase --abort >> "$LOG_FILE" 2>&1; then
                log "  Rebase aborted for $repo on branch $branch"
            else
                log "  ERROR: Rebase abort failed for $repo on branch $branch"
            fi
            drop_leftover_stash
        elif is_merge_in_progress; then
            if git merge --abort >> "$LOG_FILE" 2>&1; then
                log "  Merge aborted for $repo on branch $branch"
            else
                log "  ERROR: Merge abort failed for $repo on branch $branch"
            fi
            drop_leftover_stash
        else
            log "  No conflict state detected for $repo on branch $branch"
        fi

        log "  SKIP: Push skipped for $repo on branch $branch"
    fi

    popd > /dev/null || exit 1
}

log "=== Sync started ==="

if [ ! -f "$REPO_LIST" ]; then
    log "ERROR: repos.txt not found"
    exit 1
fi

cd "$SCRIPT_DIR" || exit 1

while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    line=$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue

    sync_repo "$line"
done < "$REPO_LIST"

log "=== Sync finished ==="
