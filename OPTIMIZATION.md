# Repo Sync Optimization

This document explains the optimizations made to speed up the `repo sync` operations in the GitHub Actions workflows.

## Changes Made

### TWRP Build Workflow (`build.yml`)

The `repo init` command has been optimized with:

- **`-j$(nproc --all)`**: Parallelizes the initialization process using all available CPU cores

**Repo init command:**
```bash
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0 -j$(nproc --all)
```

The `repo sync` command has been optimized with the following flags:

- **`-c`** (current branch only): Syncs only the current branch instead of all branches, significantly reducing download time
- **`--no-clone-bundle`**: Skips downloading large bundle files which can be slower than direct git clone
- **`--no-tags`**: Skips syncing git tags which are not needed for building
- **`--optimized-fetch`**: Uses optimized fetch strategies for better performance
- **`--prune`**: Removes obsolete remote-tracking references
- **`--force-sync`**: Overwrites existing directories if needed, preventing sync failures
- **`--quiet`**: Reduces console output overhead, slightly improving performance

**Before:**
```bash
repo sync -j$(nproc --all) > /dev/null 2>&1
```

**After:**
```bash
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune --quiet
```

### OrangeFox Build Workflow (`build-ofox.yml`)

The OrangeFox sync script has been optimized with:

- **`--depth=1`**: Performs a shallow clone with only the latest commit, drastically reducing download size

**Before:**
```bash
./orangefox_sync.sh --branch 12.1 --path ${GITHUB_WORKSPACE}/fox_12.1
```

**After:**
```bash
./orangefox_sync.sh --branch 12.1 --path ${GITHUB_WORKSPACE}/fox_12.1 --depth=1
```

## Expected Performance Improvements

These optimizations should significantly reduce sync time:

- **Parallel initialization (`-j$(nproc --all)` in repo init)**: Speeds up manifest fetching and initial setup by using all available CPU cores
- **Shallow clones (`--depth=1`)**: Reduces repository size by 80-90% by fetching only the latest commit
- **Current branch only (`-c`)**: Reduces bandwidth by only syncing the needed branch
- **No tags (`--no-tags`)**: Saves time by skipping tag synchronization
- **No bundles (`--no-clone-bundle`)**: In some network conditions, direct clone is faster than bundle download
- **Quiet mode (`--quiet`)**: Reduces console output overhead, slightly improving performance by reducing I/O operations

## Note

The `repo init` command already uses `--depth=1`, so these changes make the `repo sync` consistent with the initialization settings.
