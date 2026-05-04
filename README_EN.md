# Git Auto Sync

**English** | **[中文](README.md)**

Struggling to keep your repos in sync across multiple computers? Give this tool a try!

An ultra-lightweight Git repository auto-sync tool — system script + txt is all you need! No additional installation or dependencies required.

Runs silently, automatically commits, pushes, and pulls on schedule. Once started, zero manual effort required — your repos are always up to date across all your machines!

## Recommended Use Cases

- Auto-backup for **personal** notes and document repos
- **Multi-device** sync for single-branch or multi-branch repos
- **Periodic auto-save** of work progress

## Not Suitable For

- **Simultaneous multi-user editing** workflows (prone to conflicts)
- Projects requiring fine-grained commit message control

## Features

- **One-click start, ready to use** — Double-click the setup script and you're done.

- **Ultra-lightweight** — Core scripts are only ~4KB, zero dependencies, pure native system scripts, near-zero CPU/memory usage.

- **Multi-branch support** — Auto-generates `branches.txt` on first sync, listing all local branches per repo. Defaults to the current branch; uncomment to switch or sync multiple branches simultaneously. Supports short repo names.

- **Cross-platform** — Provides Windows / macOS / Linux scripts (currently only tested on Windows).

- **Log management** — Provides a lightweight log (keeps the last few cycles, configurable) and a full log (keeps all history, may become large and slow to open over time). The recent log defaults to 5 cycles, adjustable via `config/sync-settings.txt`.

- **Easy to maintain**

  This project provides rich user interfaces, yet the operation is very simple:

  In the config folder:

  — Edit `INTERVAL` in `sync-settings.txt` to adjust sync interval (minutes), takes effect on the next cycle.

  — Edit `KEEP_RECENT` in `sync-settings.txt` to adjust how many cycles the recent log retains, takes effect on the next cycle.

  — Edit repo paths in `repos.txt` to manage which repos to sync. Add `#` before a path to pause syncing while keeping the address for easy reactivation!
  — Edit `branches.txt`: uncomment the desired branch to sync it; supports syncing multiple branches simultaneously.

  In the platform-specific folder:

  — Double-click the `stop` script to immediately stop syncing. Run `setup` again to resume.

  — Running `setup` again automatically stops the old instance and starts a new one — no need to manually `stop` first. Especially handy for restarting after updating the scripts.

## Directory Structure

```
git-sync-script/
├── windows/
│   ├── git-auto-sync-silent.ps1   # Silent sync launcher
│   ├── git-auto-sync.bat          # Core sync script (no need to click directly)
│   ├── setup.bat                  # Click to register auto-start + begin syncing
│   └── stop.bat                   # Click to stop sync immediately
├── macos/
│   ├── git-auto-sync-silent.sh    # macOS silent launcher
│   ├── git-auto-sync.sh           # macOS core sync script
│   ├── setup.sh                   # Register auto-start + begin syncing
│   └── stop.sh                    # Stop sync process
├── linux/
│   ├── git-auto-sync-silent.sh    # Linux silent launcher
│   ├── git-auto-sync.sh           # Linux core sync script
│   ├── setup.sh                   # Register auto-start + begin syncing
│   └── stop.sh                    # Stop sync process
|
├── config/                        # Configuration directory
│   ├── sync-settings.txt          # Sync settings (auto-generated on first run)
│   ├── repos.txt                  # Repo path list (auto-generated on first run)
│   └── branches.txt               # Branch config (auto-generated on first run)
├── logs/                          # Log directory
│   ├── git-auto-sync.log          # Full log (all history)
│   └── git-auto-sync-recent.log   # Recent log (last few cycles, for quick debugging)
```

## Quick Start

### GUI

**1. Clone the repo**

```bash
git clone https://github.com/Alidadei/awesome-git-autosync.git
```

**2. One-click start**

Double-click `windows/setup.bat`. It will automatically register auto-start on login and begin syncing in the background.

**3. Configure repos**

On first sync, `config/repos.txt` will be auto-created and opened in your editor. Add one repo absolute path per line:

```
C:\Users\username\my-project
C:\Users\username\another-repo
```

**4. Change sync interval**

Edit `config/sync-settings.txt`. Changes take effect on the next cycle:

```
INTERVAL=10
```

**5. Change recent log retention**

Edit `config/sync-settings.txt`. Changes take effect on the next cycle:

```
KEEP_RECENT=5
```



### Command Line

**Windows:**

```
git clone https://github.com/Alidadei/awesome-git-autosync.git && cd git-sync-script && windows\setup.bat
```

**macOS / Linux:**

```
git clone https://github.com/Alidadei/awesome-git-autosync.git && cd git-sync-script && chmod +x macos/*.sh && macos/setup.sh
```

**View logs:**

```
cat logs/git-auto-sync-recent.log
```

> Two-level log management for easy debugging:
> - `logs/git-auto-sync-recent.log` — Lightweight log, keeps only the last 5 sync cycles. Recommended for daily use.
> - `logs/git-auto-sync.log` — Full log, keeps all history. For deep troubleshooting.
>
> Adjust the retained cycles via `KEEP_RECENT=5` in `config/sync-settings.txt`.

## Sync Logic

For each repo in `config/repos.txt`, the script runs the following for each branch configured in `config/branches.txt`:

1. `git checkout <branch>` (switch to target branch)
2. `git add -A`
3. `git commit` (when there are changes)
4. `git pull --rebase --autostash`
5. `git push`

> `config/branches.txt` is auto-generated on first run. Example:
> ```
> # YHL.github.io ：master；astro-v2
> YHL.github.io master
> #YHL.github.io astro-v2
> ```
> Uncomment `#YHL.github.io astro-v2` to sync that branch too.

### Multi-branch Sync

On first sync, `config/branches.txt` is auto-generated with all local branches detected. The current branch is active by default; others are listed as comments:

```
# my-project ：main；dev；feature-x
my-project main
#my-project dev
#my-project feature-x
```

**Sync a single branch (switch):** Comment out the current line, uncomment the target

```
# my-project ：main；dev；feature-x
#my-project main
my-project dev
#my-project feature-x
```

**Sync multiple branches:** Uncomment multiple branch lines

```
# my-project ：main；dev；feature-x
my-project main
my-project dev
#my-project feature-x
```

The above config runs the full add → commit → pull → push cycle for both `main` and `dev` sequentially.

## Sync Performance Analysis

### How the Sync Interval Works

The sync interval is a fixed sleep **after** each sync cycle completes, not a precise periodic timer:

```
Actual cycle = sync execution time + INTERVAL × 60 seconds
```

For example, with `INTERVAL=2` (2 minutes), if a sync cycle takes 30 seconds, the actual gap between cycles is 2 min 30 sec.

### Per-Cycle Stage Breakdown

Let N = number of repos, B = lines in branches.txt.

| Stage | Process Launches | Time Complexity | Typical Cost |
|---|---|---|---|
| Duplicate instance check | 1× PowerShell | O(1) | ~300ms |
| Read config | 2× findstr | O(1) | ~100ms |
| New repo check | 1× PowerShell | O(N × B) ≈ O(N) | ~400ms |
| **Per-repo sync** | **N × (findstr + PowerShell)** | **O(N)** | **Primary cost** |
| Log processing | 2× PowerShell | O(1) | ~600ms |

Total process launches: `4 + 2N` (4 fixed PowerShell + N findstr + N PowerShell).

### Per-Repo Sync Breakdown

| Step | Operation | Typical Cost |
|---|---|---|
| Comment check | findstr | ~50ms |
| Branch lookup | PowerShell + read branches.txt | ~350ms |
| `git add -A` | Scan working directory | Depends on repo size |
| `git diff --cached --quiet` | Check staging area | ~50ms |
| `git commit` | Only when changes exist | ~100ms |
| `git pull --rebase --autostash` | Network request | **Primary bottleneck** |
| `git push` | Network request | **Primary bottleneck** |

### Bottleneck Analysis

- **The real bottleneck is network I/O** (`git pull` / `git push`), independent of algorithm design
- **Process launch overhead**: Each repo's branch lookup spawns one PowerShell (~350ms); for 6 repos that's ~2.1s — acceptable compared to network I/O
- **Algorithmic complexity** is already O(N) and cannot be lower (each repo needs at least one git operation cycle)

## Status

> **Currently only tested on Windows.** macOS / Linux scripts are written but not yet tested.

## Roadmap

- Error handling: file too large, upload timeout, failure alerts with max retry time and error notifications
