# ADG Auto-Commiter

🚀 **Automatic git commit & sync tool** for seamless multi-computer collaboration.

## Features

- ⏱️ Auto-commit with configurable timeout
- 🔄 Auto-sync (pull/push) with conflict resolution
- 🛡️ Downgrade protection (never overwrites newer local version)
- 🌐 Network retry with exponential backoff
- 📦 Large file auto-ignore (>99MB)
- 🔥 Hot-reload configuration without restart
- 💕 Cloud experience - no branch splits!

## Quick Start

### Option 1: Use the Launcher (Recommended)

Add `adg-launcher.sh` to your repo and run it from any subdirectory:

```bash
./adg-launcher.sh
```

The launcher will:
1. Download the latest `autocommiter_live.sh` from this repo
2. Cache it in `.git/adg-autocommiter/`
3. Compare versions (never downgrades!)
4. Run the autocommiter

### Option 2: Direct Download

```bash
curl -fsSL https://raw.githubusercontent.com/adamerso/adg-autocommiter/main/autocommiter_live.sh -o autocommiter.sh
chmod +x autocommiter.sh
./autocommiter.sh
```

## Configuration

Edit these variables in `autocommiter_live.sh` (or they'll be reloaded automatically!):

```bash
VERSION="6.1.0"              # Script version

# Timing
COMMIT_TIMEOUT=180           # seconds before auto-commit (3 min)
CHECK_EVERY=15               # check for local changes every N seconds
PULL_EVERY=30                # pull from remote every N seconds

# Limits
MAX_FILE_SIZE_MB=99          # files larger than this are auto-ignored

# Network
NETWORK_RETRY_MAX=0          # 0 = infinite retries
GIT_TIMEOUT=120              # timeout for git operations (seconds)
```

## Keyboard Shortcuts

While running:
- `y` - Commit NOW
- `m` - Commit with custom message
- `r` - Reload configuration

## Version Protection

The script protects against accidental downgrades:
- If remote version < local version → **keeps local**
- If remote version > local version → **updates**
- Creates backups in `.git/autocommiter-backup/`

## License

MIT - Do whatever you want with it! 💕
