#!bash
# =======================
# ADG AUTO-COMMITER 7.2.0  ♥ I<3U ♥
# =======================
# v7.2.0 - GITHUB AUTO-UPDATE:
# - Auto-check for newer version on GitHub
# - Download and apply updates automatically
# - Configurable update interval (default: 5 min)
# v7.1.x features:
# - Dedicated 'autocommit' branch for multi-PC sync
# - Smart merge: newer work commits win (author date)
# - Skip merge commits when comparing timestamps
# - GIT_ROOT detection (works in nested subdirectories)
# =======================

# ═══════════════════════════════════════════════════════════
# SCRIPT_FILE - set ONCE, never overwritten on trampoline jumps
# Only set if GOWNO is unset (first run) or empty
# ═══════════════════════════════════════════════════════════
if [[ -z "${GOWNO:-}" ]] && [[ -z "${SCRIPT_FILE:-}" ]]; then
  SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
  export SCRIPT_FILE
fi

#### ════════════════════════════════════════════════════════════
#### SOURCE SECTION - All configurable variables here
#### Triggered when AC5_RUNNING=true (script sources itself)
#### ════════════════════════════════════════════════════════════
if [[ "${AC5_RUNNING:-false}" == "true" ]]; then

  # ═══════════════════════════════════════════════════════════
  # CONFIGURABLE VARIABLES (edit these for hot-reload)
  # ═══════════════════════════════════════════════════════════
  VERSION="7.3.1"
  
  # Hardening & safety
  AUTO_RESOLVE_SELF_CONFLICT=true   # Try to auto-resolve conflicts in this script
  PREFER_REMOTE_ON_CONFLICT=true    # Prefer remote version of this script when resolving
  APPLY_REPO_HARDENING=true         # Enforce .gitattributes and merge driver for this script
  REMOTE_PROTOCOL_FALLBACK=true     # On SSH auth error, fall back to HTTPS
  SAFE_MODE_ON_CONFLICT=true        # When merge/rebase in progress, skip pull/push/commit
  
  # Multi-PC Cloud Mode
  NEWER_WINS_MODE=true              # On conflict: newer commit wins (by timestamp)
  CONFLICT_STRATEGY="newer-wins"    # Options: "newer-wins", "ours", "theirs"
  AUTOCOMMIT_BRANCH="autocommit"    # Dedicated branch for auto-commits (all PCs sync here)
  SYNC_FROM_MAIN=true               # On startup, merge latest main/master into autocommit
  
  # GitHub Auto-Update
  GITHUB_UPDATE_CHECK=true          # Check for newer version on GitHub
  GITHUB_REPO="adamerso/adg-autocommiter"   # GitHub repo to check
  GITHUB_BRANCH="autocommit"        # Branch to check for updates
  GITHUB_UPDATE_INTERVAL=300        # Check every N seconds (default: 5 min)
  
  # Timing
  COMMIT_TIMEOUT=180       # seconds before auto-commit (3 min)
  CHECK_EVERY=15           # check for local changes every N seconds
  PULL_EVERY=30            # pull from remote every N seconds
  SELF_CHECK_EVERY=10      # source self every N cycles for variable reload
  
  # Limits
  MAX_FILE_SIZE_MB=99      # files larger than this are auto-ignored
  
  # Network retry settings
  NETWORK_RETRY_MAX=0              # 0 = infinite retries, >0 = max attempts
  NETWORK_RETRY_BACKOFF="1 3 5 10 30 60 120 240"  # seconds between retries (cycles back to start)
  GIT_TIMEOUT=120                  # timeout for git network operations (seconds)
  
  # Behavior
  RELOAD_ON_SHA_CHANGE=true    # Auto-reload when script changes
                               # Set to false only for development
                               # Set to true when code is stable
  
  # ═══════════════════════════════════════════════════════════
  # SHA CHECK: Set WILL_RELOAD flag (actual exec happens in main script)
  # SKIP if we just returned from trampoline (RUNLEVEL=returning)
  # ═══════════════════════════════════════════════════════════
  WILL_RELOAD=false
  echo "[source] 📖 Reloading variables... (RUNLEVEL=${RUNLEVEL:-default})"
  
  if [[ "$RELOAD_ON_SHA_CHANGE" == "true" ]] && [[ "${RUNLEVEL:-default}" != "returning" ]]; then
    _SHA_CURRENT="$(sha1sum "$SCRIPT_FILE" 2>/dev/null | awk '{print $1}')"
    
    if [[ -n "${AC5_SHA_ORIGINAL:-}" ]] && [[ "$_SHA_CURRENT" != "$AC5_SHA_ORIGINAL" ]]; then
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  🔄 SCRIPT SHA CHANGED - WILL RELOAD!                        ║"
      echo "║  Old: ${AC5_SHA_ORIGINAL:0:20}...                            ║"
      echo "║  New: ${_SHA_CURRENT:0:20}...                                ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
      
      # ═══ DOWNGRADE PROTECTION ═══
      # Extract version from new file
      local new_version=$(grep -m1 "^  VERSION=\"" "$SCRIPT_FILE" 2>/dev/null | cut -d"\"" -f2)
      
      if [[ -n "$new_version" ]] && [[ -n "$VERSION" ]]; then
        version_compare "$VERSION" "$new_version"
        local cmp_result=$?
        
        if [[ $cmp_result -eq 1 ]]; then
          # Current version > new version = DOWNGRADE ATTEMPT!
          echo ""
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "║  ⚠️  DOWNGRADE DETECTED!                                      ║"
          echo "║  Current: v$VERSION  >  New: v$new_version                    ║"
          echo "║  🛡️  PROTECTING: Overwriting file with current version...     ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          
          # Overwrite the file with our backup
          if [[ -n "${BACKUP_FILE:-}" ]] && [[ -f "$BACKUP_FILE" ]]; then
            cp "$BACKUP_FILE" "$SCRIPT_FILE"
            echo "[source] ✅ Restored from backup: ${BACKUP_FILE##*/}"
          else
            echo "[source] ⚠️ No backup available - cannot restore"
          fi
          
          # Update SHA to prevent loop
          AC5_SHA_ORIGINAL="$_SHA_CURRENT"
          export AC5_SHA_ORIGINAL
          echo "[source] ✅ SHA updated, downgrade blocked"
          return 0
          
        elif [[ $cmp_result -eq 2 ]]; then
          echo "║  ✅ UPGRADE: v$VERSION → v$new_version                        ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
        fi
      fi

      WILL_RELOAD=true
    else
      echo "[source] ✓ SHA unchanged"
    fi
  else
    echo "[source] ⏭️ Skipping SHA check (RUNLEVEL=${RUNLEVEL:-default})"
  fi
  
  # Variables reloaded successfully - unified message format
  _src_loaded="${LOADED_VERSION:-$VERSION}"
  _src_msg="[source] ✅ Variables reloaded | loaded v$_src_loaded"
  
  # Show "most current" only if different
  [[ "$_src_loaded" != "$VERSION" ]] && _src_msg="$_src_msg → current v$VERSION"
  
  # Add policy warning if self-update disabled
  [[ "$RELOAD_ON_SHA_CHANGE" == "false" ]] && _src_msg="$_src_msg | ⚠️ SELF-UPDATE OFF"
  
  # Add WILL_RELOAD status
  [[ "$WILL_RELOAD" == "true" ]] && _src_msg="$_src_msg | 🔄 RESTART PENDING"
  
  echo "$_src_msg"
  return 0

#### ════════════════════════════════════════════════════════════
#### MAIN EXECUTION SECTION - Fresh start or exec restart
#### ════════════════════════════════════════════════════════════
else

set -u

# ═══════════════════════════════════════════════════════════
# ITERATION COUNTER - increments on every exec/restart
# (Only in MAIN section, not when sourced!)
# ═══════════════════════════════════════════════════════════
export ITER="${ITER:-0}"
ITER=$((ITER + 1))
export ITER

# ═══════════════════════════════════════════════════════════
# TRAMPOLINE SYSTEM - jump via temp file for clean restart
# ═══════════════════════════════════════════════════════════
# GOWNO = temporary trampoline file (random name)
# RUNLEVEL = "default" (normal) or "gowno" (trampoline jump)

# Initialize RUNLEVEL if not set
export RUNLEVEL="${RUNLEVEL:-default}"
export GOWNO="${GOWNO:-}"

# Get what we were actually called as
CALLED_AS="$(readlink -f "$0" 2>/dev/null || echo "$0")"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ [TRAMPOLINE] ITER=$ITER  RUNLEVEL=$RUNLEVEL"
echo "│ CALLED_AS: ${CALLED_AS##*/}"
echo "│ SCRIPT:    ${SCRIPT_FILE##*/}"
[[ -n "$GOWNO" ]] && echo "│ GOWNO:     ${GOWNO##*/}" || echo "│ GOWNO:     <none>"
echo "└─────────────────────────────────────────────────────────────┘"

# ─────────────────────────────────────────────────────────────
# SAFETY CHECK: Don't delete ourselves!
# ─────────────────────────────────────────────────────────────
if [[ -n "$GOWNO" ]] && [[ -f "$GOWNO" ]]; then
  if [[ "$SCRIPT_FILE" == "$GOWNO" ]]; then
    echo "[trampoline] ⛔ ALE GOWNO! SCRIPT_FILE == GOWNO, this should never happen!"
    exit 1
  fi
fi

# ─────────────────────────────────────────────────────────────
# TRAMPOLINE DETECTION: Are we running as GOWNO (temp file)?
# If yes, jump back to real SCRIPT_FILE
# ─────────────────────────────────────────────────────────────
if [[ "$RUNLEVEL" == "gowno" ]] && [[ -n "$GOWNO" ]] && [[ "$CALLED_AS" == "$GOWNO" ]]; then
  echo "│ 🦘 ON TRAMPOLINE! Jumping back to SCRIPT_FILE..."
  export RUNLEVEL="returning"
  exec bash "$SCRIPT_FILE"
  echo "│ ⛔ exec failed!"
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# CLEANUP: If we're back at SCRIPT_FILE after trampoline, clean up GOWNO
# and UPDATE SHA to prevent infinite restart loop!
# ─────────────────────────────────────────────────────────────
if [[ -n "$GOWNO" ]] && [[ -f "$GOWNO" ]] && [[ "$CALLED_AS" != "$GOWNO" ]]; then
  echo "│ 🧹 Cleaning up GOWNO file..."
  rm -f "$GOWNO" 2>/dev/null || true
  export GOWNO=""
  
  # UPDATE SHA after successful trampoline - prevents infinite loop!
  AC5_SHA_ORIGINAL="$(sha1sum "$SCRIPT_FILE" 2>/dev/null | awk '{print $1}')"
  export AC5_SHA_ORIGINAL
  echo "│ 🔄 SHA updated to: ${AC5_SHA_ORIGINAL:0:20}..."
  echo "│ ✅ TRAMPOLINE COMPLETE - script reloaded!"
fi

# Set default runlevel now that we're in the real script
export RUNLEVEL="default"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# ═══════════════════════════════════════════════════════════
# RUNTIME FLAG (guard for source)
# ═══════════════════════════════════════════════════════════
AC5_RUNNING=true
export AC5_RUNNING

# ═══════════════════════════════════════════════════════════
# INITIAL SOURCE: Load variables from source section
# Uses tmp file to protect against syntax errors during edit
# ═══════════════════════════════════════════════════════════
_safe_source() {
  # Test syntax directly on script file first
  if bash -n "$SCRIPT_FILE" 2>/dev/null; then
    # Syntax OK - source it
    source "$SCRIPT_FILE" 2>/dev/null
    return $?
  else
    echo "[safe_source] ⚠️ Syntax error in script - using current values"
    return 1
  fi
}

# Initial variable load
_safe_source || {
  # Fallback defaults if source fails
  VERSION="${VERSION:-7.2.1}"
  COMMIT_TIMEOUT="${COMMIT_TIMEOUT:-180}"
  CHECK_EVERY="${CHECK_EVERY:-15}"
  PULL_EVERY="${PULL_EVERY:-30}"
  SELF_CHECK_EVERY="${SELF_CHECK_EVERY:-10}"
  MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB:-99}"
  RELOAD_ON_SHA_CHANGE="${RELOAD_ON_SHA_CHANGE:-true}"
  NETWORK_RETRY_MAX="${NETWORK_RETRY_MAX:-5}"
  NETWORK_RETRY_BACKOFF="${NETWORK_RETRY_BACKOFF:-1 3 5 10 20}"
  GIT_TIMEOUT="${GIT_TIMEOUT:-120}"
}

# ═══════════════════════════════════════════════════════════
# LOADED_VERSION - set ONCE at startup, never changes on reload
# ═══════════════════════════════════════════════════════════
LOADED_VERSION="$VERSION"
export LOADED_VERSION

# ═══════════════════════════════════════════════════════════
# COMPUTED VARIABLES (derived from config)
# ═══════════════════════════════════════════════════════════
MAX_FILE_SIZE_BYTES=$((MAX_FILE_SIZE_MB * 1024 * 1024))
SCRIPT_NAME="adg-auto-commiter"
AC5_SHA_ORIGINAL="$(sha1sum "$SCRIPT_FILE" 2>/dev/null | awk '{print $1}')"
export AC5_SHA_ORIGINAL

# ═══════════════════════════════════════════════════════════
# FIXED VARIABLES (not configurable via source)
# ═══════════════════════════════════════════════════════════
GIT="git"
USER_NAME="${USER:-$(whoami 2>/dev/null || echo unknown)}"
HOST_NAME="$(hostname 2>/dev/null || echo unknown)"
DATE_FMT_COMMIT="%y%m%d %H%M"

# ═══════════════════════════════════════════════════════════
# GIT_ROOT DETECTION - find repo root ONCE at startup
# This ensures script works correctly in nested subdirectories
# ═══════════════════════════════════════════════════════════
GIT_ROOT="$($GIT rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$GIT_ROOT" ]]; then
  echo "❌ ERROR: Not inside a Git repository!"
  echo "   Please run this script from within a git repo."
  exit 1
fi
export GIT_ROOT

# Generate unique lockfile per-repo (hash of GIT_ROOT path)
_REPO_HASH=$(echo "$GIT_ROOT" | md5sum 2>/dev/null | cut -c1-8 || echo "default")
LOCKFILE="/tmp/adg-autocommiter-${_REPO_HASH}.lock"

# ═══════════════════════════════════════════════════════════
# STATE VARIABLES (persist across source reloads)
# ═══════════════════════════════════════════════════════════
CHANGES_DETECTED_AT=0
PENDING_COMMIT=false
CYCLE_COUNT=0
WILL_RELOAD=false  # Flag set by source when SHA changes

# ═══════════════════════════════════════════════════════════
# SESSION STATISTICS
# ═══════════════════════════════════════════════════════════
SESSION_START=$(date +%s)
STAT_COMMITS=0
STAT_MERGES=0
STAT_FILES=0
STAT_LINES_ADDED=0
STAT_LINES_REMOVED=0
STAT_NETWORK_RETRIES=0

# ═══════════════════════════════════════════════════════════
# GIT: No-interactive mode
# ═══════════════════════════════════════════════════════════
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=false
export SSH_ASKPASS=false
export GIT_EDITOR=true

# ═══════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════
C_RESET="\033[0m"

# ═══════════════════════════════════════════════════════════
# VERSION COMPARE - returns: 0=equal, 1=v1>v2, 2=v1<v2
# Usage: version_compare "1.2.3" "1.2.4" => returns 2
# ═══════════════════════════════════════════════════════════
version_compare() {
  local v1="$1" v2="$2"
  
  # Remove v prefix if present
  v1="${v1#v}"
  v2="${v2#v}"
  
  # Split into arrays
  IFS="." read -ra V1_PARTS <<< "$v1"
  IFS="." read -ra V2_PARTS <<< "$v2"
  
  # Compare each part
  local max_len=${#V1_PARTS[@]}
  [[ ${#V2_PARTS[@]} -gt $max_len ]] && max_len=${#V2_PARTS[@]}
  
  for ((i=0; i<max_len; i++)); do
    local p1=${V1_PARTS[$i]:-0}
    local p2=${V2_PARTS[$i]:-0}
    
    # Extract numeric part (ignore -rc1, -beta etc)
    p1=$(echo "$p1" | grep -oE "^[0-9]+" || echo "0")
    p2=$(echo "$p2" | grep -oE "^[0-9]+" || echo "0")
    
    if [[ $p1 -gt $p2 ]]; then
      return 1  # v1 > v2
    elif [[ $p1 -lt $p2 ]]; then
      return 2  # v1 < v2
    fi
  done
  
  return 0  # equal
}

# ═══════════════════════════════════════════════════════════
# STARTUP BACKUP - save current version before any reload
# Location: .git/autocommiter-backup/
# ═══════════════════════════════════════════════════════════
BACKUP_DIR=""
BACKUP_FILE=""

create_startup_backup() {
  # Only on first run (not from trampoline)
  if [[ -n "${GOWNO:-}" ]] || [[ -n "${BACKUP_CREATED:-}" ]]; then
    return 0
  fi
  
  # Use global GIT_ROOT (already detected at startup)
  if [[ -z "$GIT_ROOT" ]]; then
    return 1
  fi
  
  BACKUP_DIR="$GIT_ROOT/.git/autocommiter-backup"
  mkdir -p "$BACKUP_DIR"
  
  BACKUP_FILE="$BACKUP_DIR/$(basename "$SCRIPT_FILE").v${VERSION}.$(date +%Y%m%d-%H%M%S)"
  
  if cp "$SCRIPT_FILE" "$BACKUP_FILE" 2>/dev/null; then
    export BACKUP_CREATED="true"
    export BACKUP_FILE
    export BACKUP_DIR
    echo "[startup] 💾 Backup created: ${BACKUP_FILE##*/}"
    
    # Cleanup old backups (keep last 5)
    ls -t "$BACKUP_DIR"/*.sh 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    return 0
  fi
  return 1
}

C_DIM="\033[2m"
C_BOLD="\033[1m"
C_RED="\033[91m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_MAGENTA="\033[95m"
C_CYAN="\033[36m"
C_PINK="\033[38;5;213m"
C_ORANGE="\033[38;5;208m"
C_HOTPINK="\033[38;5;199m"
C_HEART="\033[38;5;197m"

# ═══════════════════════════════════════════════════════════
# LOGGING FUNCTIONS
# ═══════════════════════════════════════════════════════════
_ts() { date +%H:%M:%S; }

log()     { printf "%b[%s]%b %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$*"; }
info()    { printf "%b[%s]%b %bINFO%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_CYAN" "$C_RESET" "$*"; }
ok()      { printf "%b[%s]%b %bOK%b    %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf "%b[%s]%b %bWARN%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_YELLOW" "$C_RESET" "$*"; }
err()     { printf "%b[%s]%b %bERR%b   %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_RED" "$C_RESET" "$*"; }
pend()    { printf "%b[%s]%b %bPEND%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_MAGENTA" "$C_RESET" "$*"; }

die() { err "$*"; exit 1; }

# ═══════════════════════════════════════════════════════════
# HARDENING HELPERS (merge-safety, remote fallback, CRLF policy)
# ═══════════════════════════════════════════════════════════

# Return repo-relative path of this script
_script_relpath() {
  local rel
  rel=$($GIT ls-files --full-name -- "$SCRIPT_FILE" 2>/dev/null)
  [[ -z "$rel" ]] && rel=$(realpath --relative-to="$($GIT rev-parse --show-toplevel 2>/dev/null)" "$SCRIPT_FILE" 2>/dev/null || echo "")
  echo "$rel"
}

# Ensure .gitattributes and merge driver rules for this script
repo_hardening_setup() {
  [[ "$APPLY_REPO_HARDENING" != "true" ]] && return 0
  local rel=$(_script_relpath)
  [[ -z "$rel" ]] && return 0

  local changed=false
  local gitattributes_path="$GIT_ROOT/.gitattributes"
  
  # Enforce LF for shell scripts
  if [[ -f "$gitattributes_path" ]]; then
    if ! grep -qE '^\*\.sh\s+text\s+eol=lf' "$gitattributes_path" 2>/dev/null; then
      echo "*.sh text eol=lf" >> "$gitattributes_path"
      changed=true
    fi
  else
    printf "*.sh text eol=lf\n" > "$gitattributes_path"
    changed=true
  fi

  # Always keep OUR version of this script on merges
  if ! grep -qF "${rel} merge=ours" "$gitattributes_path" 2>/dev/null; then
    echo "${rel} merge=ours" >> "$gitattributes_path"
    changed=true
  fi

  # Define the 'ours' merge driver locally (no-op keeps current)
  $GIT config --local merge.ours.driver true 2>/dev/null || true

  if [[ "$changed" == true ]]; then
    info "Repo hardening: updating .gitattributes at $GIT_ROOT"
    $GIT add "$gitattributes_path" 2>/dev/null || true
    # do not force an immediate commit; it will be included in next auto-commit
  fi
}

# Detect merge/rebase operations in progress and optionally enter SAFE MODE
detect_repo_in_progress() {
  local gitdir=$($GIT rev-parse --git-dir 2>/dev/null || echo "")
  [[ -z "$gitdir" ]] && return 0
  if [[ -f "$gitdir/MERGE_HEAD" || -d "$gitdir/rebase-apply" || -d "$gitdir/rebase-merge" ]]; then
    if [[ "$SAFE_MODE_ON_CONFLICT" == "true" ]]; then
      export SAFE_MODE=true
      warn "SAFE MODE: merge/rebase in progress; skipping pull/push/commit until resolved"
    fi
  else
    export SAFE_MODE=false
  fi
}

# Ensure we can talk to origin; switch SSH→HTTPS on auth errors
ensure_remote_access() {
  [[ "$REMOTE_PROTOCOL_FALLBACK" != "true" ]] && return 0
  local out
  out=$($GIT ls-remote --heads origin 2>&1) && return 0
  
  # Check for HTTPS credential issues
  if echo "$out" | grep -qiE 'could not read Username|terminal prompts disabled|askpass'; then
    printf "\n"
    printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_RED" "$C_RESET"
    printf "%b║%b  ⚠️  GIT AUTHENTICATION REQUIRED                              %b║%b\n" "$C_RED" "$C_YELLOW" "$C_RED" "$C_RESET"
    printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_RED" "$C_RESET"
    printf "%b║%b  Git cannot connect to GitHub - credentials not configured   %b║%b\n" "$C_RED" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b                                                              %b║%b\n" "$C_RED" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b  %bFix options (run in terminal):%b                              %b║%b\n" "$C_RED" "$C_RESET" "$C_GREEN" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b                                                              %b║%b\n" "$C_RED" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b  1. %bgh auth login%b        (GitHub CLI - easiest)             %b║%b\n" "$C_RED" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b                                                              %b║%b\n" "$C_RED" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b  2. %bgit config --global credential.helper manager%b           %b║%b\n" "$C_RED" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b     then: %bgit fetch origin%b (enter credentials once)        %b║%b\n" "$C_RED" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b                                                              %b║%b\n" "$C_RED" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b  3. Create Personal Access Token at:                        %b║%b\n" "$C_RED" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b║%b     %bhttps://github.com/settings/tokens%b                      %b║%b\n" "$C_RED" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RED" "$C_RESET"
    printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$C_RED" "$C_RESET"
    printf "\n"
    warn "Continuing in offline mode (local commits only)..."
    return 1
  fi
  
  if echo "$out" | grep -qiE 'permission denied|publickey|repository access|authentication failed'; then
    local url=$($GIT remote get-url origin 2>/dev/null || echo "")
    if [[ "$url" =~ ^git@github\.com:([^/]+)/([^/]+)\.git$ ]]; then
      local user="${BASH_REMATCH[1]}" repo="${BASH_REMATCH[2]}"
      local https="https://github.com/${user}/${repo}.git"
      warn "Remote auth via SSH failed → switching to HTTPS"
      $GIT remote set-url origin "$https" 2>/dev/null || true
    fi
  fi
}

# Auto-resolve conflicts in THIS script by choosing the newer or preferred side
self_conflict_guard() {
  [[ "$AUTO_RESOLVE_SELF_CONFLICT" != "true" ]] && return 0
  local rel=$(_script_relpath)
  [[ -z "$rel" ]] && return 0

  # Is this file unmerged?
  if $GIT ls-files -u -- "$rel" >/dev/null 2>&1; then
    local unmerged_count=$($GIT ls-files -u -- "$rel" | wc -l | tr -d ' ')
    if [[ "$unmerged_count" -gt 0 ]]; then
      warn "Self-conflict detected in ${rel} — attempting auto-resolve"
      # Read versions from ours/theirs, if available
      local ours_ver theirs_ver
      ours_ver=$($GIT show :2:"$rel" 2>/dev/null | grep -m1 '^  VERSION="' | cut -d'"' -f2)
      theirs_ver=$($GIT show :3:"$rel" 2>/dev/null | grep -m1 '^  VERSION="' | cut -d'"' -f2)

      local prefer_side="theirs"
      if [[ -n "$ours_ver" && -n "$theirs_ver" ]]; then
        version_compare "$ours_ver" "$theirs_ver"
        case $? in
          1) prefer_side="ours";;   # ours newer
          2) prefer_side="theirs";; # theirs newer
          0) prefer_side=$([[ "$PREFER_REMOTE_ON_CONFLICT" == "true" ]] && echo "theirs" || echo "ours") ;;
        esac
      else
        prefer_side=$([[ "$PREFER_REMOTE_ON_CONFLICT" == "true" ]] && echo "theirs" || echo "ours")
      fi

      if [[ "$prefer_side" == "theirs" ]]; then
        $GIT checkout --theirs -- "$rel" 2>/dev/null || true
      else
        $GIT checkout --ours -- "$rel" 2>/dev/null || true
      fi
      $GIT add -- "$rel" 2>/dev/null || true
      $GIT commit -m "fix(auto-committer): auto-resolve self-conflict in ${rel} (prefer ${prefer_side})" >/dev/null 2>&1 || true
      ok "Self-conflict resolved (prefer ${prefer_side})"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# SESSION STATS DISPLAY
# ═══════════════════════════════════════════════════════════
show_stats() {
  local now=$(date +%s)
  local elapsed=$((now - SESSION_START))
  local hours=$((elapsed / 3600))
  local mins=$(( (elapsed % 3600) / 60 ))
  local secs=$((elapsed % 60))
  local ver_info="loaded v$LOADED_VERSION"
  [[ "$LOADED_VERSION" != "$VERSION" ]] && ver_info="$ver_info, current v$VERSION"
  [[ "$RELOAD_ON_SHA_CHANGE" == "false" ]] && ver_info="$ver_info ⚠️"
  
  # Line 1: Header with version and uptime
  printf "%b[%s %s @ %s]%b\n" \
    "$C_PINK" "$SCRIPT_NAME" "$ver_info" "$(_ts)" "$C_RESET"
  
  # Line 2: Uptime
  if [[ $hours -gt 0 ]]; then
    printf "  %b📊 Uptime:%b %dh %dm %ds\n" "$C_CYAN" "$C_RESET" "$hours" "$mins" "$secs"
  else
    printf "  %b📊 Uptime:%b %dm %ds\n" "$C_CYAN" "$C_RESET" "$mins" "$secs"
  fi
  
  # Line 3: Stats with full names
  printf "  %b📈 Stats:%b Commits: %d | Merges: %d | Files: %d | Lines: +%d/-%d | Retries: %d\n" \
    "$C_CYAN" "$C_RESET" \
    "$STAT_COMMITS" "$STAT_MERGES" "$STAT_FILES" "$STAT_LINES_ADDED" "$STAT_LINES_REMOVED" "$STAT_NETWORK_RETRIES"
}

# ═══════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════
# PID-BASED LOCK (Git Bash compatible - flock doesnt work)
# ═══════════════════════════════════════════════════════════
if [[ -f "$LOCKFILE" ]]; then
  old_pid=$(grep -oP "pid=\K[0-9]+" "$LOCKFILE" 2>/dev/null || echo "")
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    err "Another instance is running (PID: $old_pid, lock: $LOCKFILE)"
    cat "$LOCKFILE" 2>/dev/null || true
    exit 0
  else
    warn "Removing stale lock (PID $old_pid not running)"
    rm -f "$LOCKFILE"
  fi
fi

_heartbeat() {
  printf "pid=%s host=%s user=%s ts=%s\n" \
    "$$" "$HOST_NAME" "$USER_NAME" "$(date -Is)" > "$LOCKFILE"
}
_heartbeat
ok "Lock acquired (PID: $$)"

# Create startup backup for downgrade protection
create_startup_backup

# ═══════════════════════════════════════════════════════════
# NETWORK RETRY WRAPPER - with exponential backoff
# Usage: network_retry "description" command [args...]
# NETWORK_RETRY_MAX: 0 = infinite retries, >0 = max attempts
# Backoff cycles back to start after reaching end of array
# ═══════════════════════════════════════════════════════════
network_retry() {
  local desc="$1"
  shift
  local cmd=("$@")

  local attempt=0
  local backoff_arr=($NETWORK_RETRY_BACKOFF)
  local max_attempts=$NETWORK_RETRY_MAX
  local backoff_len=${#backoff_arr[@]}
  local git_output=""

  # Infinite loop when max_attempts=0, otherwise limited
  while [[ $max_attempts -eq 0 ]] || [[ $attempt -lt $max_attempts ]]; do
    attempt=$((attempt + 1))

    # Show attempt info
    local attempt_info=""
    if [[ $max_attempts -eq 0 ]]; then
      attempt_info="#$attempt/∞"
    else
      attempt_info="$attempt/$max_attempts"
    fi

    # Run command with timeout, capture output
    git_output=$(timeout "$GIT_TIMEOUT" "${cmd[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      [[ $attempt -gt 1 ]] && ok "$desc succeeded after $attempt attempts"
      return 0
    fi

    # ═══════════════════════════════════════════════════════════
    # HANDLE SPECIAL GIT ERRORS
    # ═══════════════════════════════════════════════════════════

    # Check for untracked files blocking merge/pull
    if echo "$git_output" | grep -q "untracked working tree files would be overwritten"; then
      warn "🗑️ Untracked files blocking $desc - auto-fixing..."

      # Extract blocking file paths from git output
      local blocking_files=$(echo "$git_output" | awk '/untracked working tree files would be overwritten/,/Please move or remove/ {
        if (/^\t/) { gsub(/^\t/, ""); print }
      }')

      if [[ -n "$blocking_files" ]]; then
        echo "$blocking_files" | while read -r file; do
          if [[ -n "$file" ]]; then
            local full_path="$GIT_ROOT/$file"
            if [[ -f "$full_path" ]]; then
              # Move to backup instead of deleting
              local backup_dir="$GIT_ROOT/.git/backup-untracked"
              mkdir -p "$backup_dir"
              local backup_name="$(basename "$file").$(date +%s)"
              mv "$full_path" "$backup_dir/$backup_name" 2>/dev/null && \
                info "  Moved: $file -> .git/backup-untracked/$backup_name" || \
                warn "  Failed to move: $file"
            fi
          fi
        done
        ok "Blocking files handled, retrying $desc..."
        continue  # Retry immediately without backoff
      fi
    fi

    # Check for non-fast-forward (cant push without pull)
    if echo "$git_output" | grep -q "non-fast-forward"; then
      warn "$desc rejected (non-fast-forward) - need to pull first"
      echo "┌─── git output ───────────────────────────────────────────────┐"
      echo "$git_output" | head -20
      echo "└───────────────────────────────────────────────────────────────┘"
      return 2  # Special code: non-fast-forward
    fi

    # ═══════════════════════════════════════════════════════════
    # STANDARD RETRY LOGIC
    # ═══════════════════════════════════════════════════════════

    # Check if it was a timeout (exit code 124)
    if [[ $exit_code -eq 124 ]]; then
      warn "$desc timed out after ${GIT_TIMEOUT}s ($attempt_info)"
    else
      warn "$desc FAILED ($attempt_info, exit: $exit_code)"
      echo "┌─── git output ───────────────────────────────────────────────┐"
      echo "$git_output" | head -20
      echo "└───────────────────────────────────────────────────────────────┘"
    fi

    # Get backoff delay - stay at max when we reach it
    local delay_idx=$((attempt - 1))
    if [[ $delay_idx -ge $backoff_len ]]; then
      delay_idx=$((backoff_len - 1))
    fi
    local delay=${backoff_arr[$delay_idx]}

    # Check if we should continue (for limited retries)
    if [[ $max_attempts -gt 0 ]] && [[ $attempt -ge $max_attempts ]]; then
      err "$desc failed after $max_attempts attempts!"
      return 1
    fi

    # Log retry info
    info "🔄 Retry $attempt_info in ${delay}s..."
    STAT_NETWORK_RETRIES=$((STAT_NETWORK_RETRIES + 1))
    _heartbeat
    sleep "$delay"

    # Auto-reload during wait (if enabled)
    if [[ "$RELOAD_ON_SHA_CHANGE" == "true" ]] && [[ $delay -ge 10 ]]; then
      do_reload 2>/dev/null || true
    fi
  done

  # Should never reach here with infinite retries
  err "$desc failed!"
  return 1
}

# ═══════════════════════════════════════════════════════════
# GIT REMOTE DETECTION - find username/repo from .git/config
# ═══════════════════════════════════════════════════════════
detect_git_remote() {
  local remote_url=""
  
  # Try to get remote URL
  remote_url=$($GIT config --get remote.origin.url 2>/dev/null || echo "")
  
  if [[ -z "$remote_url" ]]; then
    echo ""
    return 1
  fi
  
  # Parse username/repo from various URL formats:
  # git@github.com:user/repo.git
  # https://github.com/user/repo.git
  # https://github.com/user/repo
  # ssh://git@github.com/user/repo.git
  
  local user_repo=""
  
  # SSH format: git@github.com:user/repo.git
  if [[ "$remote_url" =~ git@[^:]+:([^/]+)/([^/]+)(\.git)?$ ]]; then
    user_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  # HTTPS format: https://github.com/user/repo.git
  elif [[ "$remote_url" =~ https?://[^/]+/([^/]+)/([^/]+)(\.git)?$ ]]; then
    user_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  # SSH URL format: ssh://git@github.com/user/repo.git
  elif [[ "$remote_url" =~ ssh://[^/]+/([^/]+)/([^/]+)(\.git)?$ ]]; then
    user_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  
  # Remove .git suffix if present
  user_repo="${user_repo%.git}"
  
  echo "$user_repo"
}

# ═══════════════════════════════════════════════════════════
# FIND GIT ROOT - search upward for .git directory
# ═══════════════════════════════════════════════════════════
find_git_root() {
  local dir="$1"
  local max_depth=20
  local depth=0
  
  while [[ $depth -lt $max_depth ]]; do
    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    
    local parent=$(dirname "$dir")
    [[ "$parent" == "$dir" ]] && break  # reached root
    dir="$parent"
    depth=$((depth + 1))
  done
  
  return 1
}

# ═══════════════════════════════════════════════════════════
# SSH/HTTPS SETUP - configure git authentication
# ═══════════════════════════════════════════════════════════
setup_git_auth() {
  local detected_repo=""
  local user_repo=""
  
  printf "\n"
  printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_CYAN" "$C_RESET"
  printf "%b║%b     🔐 GIT AUTHENTICATION SETUP                              %b║%b\n" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
  printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$C_CYAN" "$C_RESET"
  printf "\n"
  
  # Try to detect from .git/config
  detected_repo=$(detect_git_remote)
  
  if [[ -n "$detected_repo" ]]; then
    info "Detected repository: $detected_repo"
    printf "%b[?]%b Use detected repo? [Y/n]: " "$C_GREEN" "$C_RESET"
    
    # Check for pipe input first
    if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
      read -r answer || answer=""
    else
      read -t 10 -r answer || answer=""
    fi
    
    if [[ -z "$answer" ]] || [[ "$answer" =~ ^[Yy] ]]; then
      user_repo="$detected_repo"
      ok "Using: $user_repo"
    fi
  fi
  
  # If not detected or user declined, ask manually
  if [[ -z "$user_repo" ]]; then
    printf "%b[?]%b Enter GitHub username: " "$C_YELLOW" "$C_RESET"
    local gh_user=""
    if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
      read -r gh_user || gh_user=""
    else
      read -r gh_user
    fi
    
    printf "%b[?]%b Enter repository name: " "$C_YELLOW" "$C_RESET"
    local gh_repo=""
    if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
      read -r gh_repo || gh_repo=""
    else
      read -r gh_repo
    fi
    
    if [[ -n "$gh_user" ]] && [[ -n "$gh_repo" ]]; then
      user_repo="$gh_user/$gh_repo"
    fi
  fi
  
  if [[ -z "$user_repo" ]]; then
    warn "No repository configured - using existing remote"
    return 1
  fi
  
  # Configure remote
  info "Configuring remote for: $user_repo"
  
  # Check SSH availability
  local use_ssh=false
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    use_ssh=true
    ok "SSH authentication available"
  elif [[ -f ~/.ssh/id_rsa ]] || [[ -f ~/.ssh/id_ed25519 ]]; then
    info "SSH keys found, attempting SSH..."
    use_ssh=true
  fi
  
  local remote_url=""
  if [[ "$use_ssh" == "true" ]]; then
    remote_url="git@github.com:${user_repo}.git"
  else
    remote_url="https://github.com/${user_repo}.git"
    warn "Using HTTPS - you may need to configure credentials"
  fi
  
  # Set remote
  if $GIT remote get-url origin >/dev/null 2>&1; then
    $GIT remote set-url origin "$remote_url" 2>/dev/null
    ok "Updated remote origin: $remote_url"
  else
    $GIT remote add origin "$remote_url" 2>/dev/null
    ok "Added remote origin: $remote_url"
  fi
  
  # Export for later use
  export GIT_REPO_USER_REPO="$user_repo"
  export GIT_REMOTE_URL="$remote_url"
  
  return 0
}

# ═══════════════════════════════════════════════════════════
# STARTUP PUSH - push any pending commits from before
# ═══════════════════════════════════════════════════════════
do_startup_push() {
  info "🚀 Checking for pending commits to push..."
  
  # Check if there are unpushed commits
  local unpushed=$($GIT log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  
  if [[ "$unpushed" -eq 0 ]]; then
    ok "No pending commits to push"
    return 0
  fi
  
  info "Found $unpushed unpushed commit(s), pushing..."
  
  if network_retry "Startup push" $GIT push; then
    ok "Startup push: $unpushed commit(s) pushed!"
    return 0
  else
    warn "Startup push failed - will retry later"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# FULL RESTART via TRAMPOLINE (GOWNO jump!)
# ═══════════════════════════════════════════════════════════
do_full_restart() {
  printf "\n"
  printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_HOTPINK" "$C_RESET"
  printf "%b║%b  🔄 FULL RESTART via TRAMPOLINE!                             %b║%b\n" "$C_HOTPINK" "$C_RESET" "$C_HOTPINK" "$C_RESET"
  printf "%b║%b  Loaded: v%-12s → Current: v%-12s          %b║%b\n" "$C_HOTPINK" "$C_RESET" "$LOADED_VERSION" "$VERSION" "$C_HOTPINK" "$C_RESET"
  printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$C_HOTPINK" "$C_RESET"
  printf "\n"
  
  # Generate GOWNO filename (random temp file)
  local script_dir
  script_dir="$(dirname "$SCRIPT_FILE")"
  export GOWNO="${script_dir}/.gowno_${RANDOM}${RANDOM}${RANDOM}.sh"
  
  info "🦘 Creating trampoline: $GOWNO"
  
  # Copy script to GOWNO (cp -a preserves permissions)
  if ! cp -a "$SCRIPT_FILE" "$GOWNO" 2>/dev/null; then
    # Fallback without -a
    cp "$SCRIPT_FILE" "$GOWNO" 2>/dev/null || {
      err "Cannot create trampoline file!"
      return 1
    }
    chmod +x "$GOWNO" 2>/dev/null || true
  fi
  
  info "Jumping to GOWNO in 1s..."
  sleep 1
  
  # Release lock (remove lockfile)
  rm -f "$LOCKFILE" 2>/dev/null || true
  exec 200>&- 2>/dev/null || true
  rm -f "$LOCKFILE" 2>/dev/null || true
  
  # Reset guard
  AC5_RUNNING=false
  export AC5_RUNNING=false
  
  # Set RUNLEVEL to gowno (trampoline mode)
  export RUNLEVEL="gowno"
  
  # JUMP TO GOWNO!
  info "🚀 exec $GOWNO"
  exec bash "$GOWNO"
  
  # Fallback (should never reach)
  err "exec failed!"
  exit 1
}

# ═══════════════════════════════════════════════════════════
# SELF-GITIGNORE - add script to .gitignore (live update!)
# Since we have GitHub auto-update, script shouldn't be
# committed to user's repo - it updates itself!
# ═══════════════════════════════════════════════════════════
ensure_self_gitignore() {
  local script_name
  script_name="$(basename "$SCRIPT_FILE")"
  local gitignore_path="${GIT_ROOT}/.gitignore"
  
  # Also ignore trampoline files
  local patterns=("$script_name" ".gowno_*.sh")
  
  local added=0
  
  for pattern in "${patterns[@]}"; do
    # Check if already in .gitignore
    if [[ -f "$gitignore_path" ]]; then
      # Use grep with fixed string for exact match (line by line)
      if grep -qxF "$pattern" "$gitignore_path" 2>/dev/null; then
        continue  # Already there
      fi
    fi
    
    # Add to .gitignore
    echo "$pattern" >> "$gitignore_path"
    added=$((added + 1))
  done
  
  if [[ $added -gt 0 ]]; then
    ok "🛡️ Added $added pattern(s) to .gitignore (live update protection)"
    log "   Patterns: ${patterns[*]}"
  fi
  
  return 0
}

# ═══════════════════════════════════════════════════════════
# GITHUB AUTO-UPDATE - check for newer version on GitHub
# Downloads new version if available, then existing reload
# mechanism detects SHA change and restarts
# ═══════════════════════════════════════════════════════════
LAST_GITHUB_CHECK=0

check_github_update() {
  # Skip if disabled
  [[ "${GITHUB_UPDATE_CHECK:-true}" != "true" ]] && return 0
  
  # Rate limit - don't check too often
  local now=$(date +%s)
  local interval=${GITHUB_UPDATE_INTERVAL:-300}
  if (( now - LAST_GITHUB_CHECK < interval )); then
    return 0
  fi
  LAST_GITHUB_CHECK=$now
  
  local repo="${GITHUB_REPO:-adamerso/adg-autocommiter}"
  local branch="${GITHUB_BRANCH:-autocommit}"
  local version_url="https://raw.githubusercontent.com/${repo}/${branch}/VERSION"
  local script_url="https://raw.githubusercontent.com/${repo}/${branch}/adg-autocommiter-continous.sh"
  
  log "🌐 Checking GitHub for updates..."
  
  # Fetch remote VERSION with timeout
  local remote_version
  remote_version=$(curl -sL --connect-timeout 5 --max-time 10 "$version_url" 2>/dev/null | tr -d '\r\n ')
  
  if [[ -z "$remote_version" ]]; then
    log "Could not fetch remote version (network issue?)"
    return 1
  fi
  
  # Compare versions
  version_compare "$VERSION" "$remote_version"
  local cmp_result=$?
  
  if [[ $cmp_result -eq 2 ]]; then
    # Remote is newer!
    printf "\n"
    printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_GREEN" "$C_RESET"
    printf "%b║%b  🚀 NEW VERSION AVAILABLE ON GITHUB!                          %b║%b\n" "$C_GREEN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf "%b║%b  Current: v%-10s  →  Available: v%-10s          %b║%b\n" "$C_GREEN" "$C_RESET" "$VERSION" "$remote_version" "$C_GREEN" "$C_RESET"
    printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$C_GREEN" "$C_RESET"
    printf "\n"
    
    info "Downloading new version from GitHub..."
    
    # Download to temp file first
    local tmp_script="${SCRIPT_FILE}.github-update.tmp"
    if curl -sL --connect-timeout 10 --max-time 60 "$script_url" -o "$tmp_script" 2>/dev/null; then
      # Verify download - check if it has VERSION string
      if grep -q "^  VERSION=" "$tmp_script" 2>/dev/null; then
        # Check syntax
        if bash -n "$tmp_script" 2>/dev/null; then
          # All good - replace current script
          cp "$tmp_script" "$SCRIPT_FILE" 2>/dev/null
          rm -f "$tmp_script" 2>/dev/null
          ok "Downloaded v$remote_version from GitHub - reload will happen automatically!"
          return 0
        else
          warn "Downloaded script has syntax errors - keeping current version"
          rm -f "$tmp_script" 2>/dev/null
          return 1
        fi
      else
        warn "Downloaded file doesn't look like valid script - keeping current version"
        rm -f "$tmp_script" 2>/dev/null
        return 1
      fi
    else
      warn "Failed to download new version from GitHub"
      rm -f "$tmp_script" 2>/dev/null
      return 1
    fi
    
  elif [[ $cmp_result -eq 1 ]]; then
    # Local is newer (development version?)
    log "Local version (v$VERSION) is newer than GitHub (v$remote_version)"
    return 0
  else
    # Same version
    log "Up to date (v$VERSION)"
    return 0
  fi
}

# ═══════════════════════════════════════════════════════════
# SAFE SELF-RELOAD (via tmp file)
# ═══════════════════════════════════════════════════════════
do_reload() {
  # First, check GitHub for updates (will overwrite file if newer)
  check_github_update || true
  
  local old_version="$VERSION"
  info "♻️  Reloading variables (loaded: v$LOADED_VERSION, current: v$old_version)..."
  
  # First check syntax
  log "Testing script syntax..."
  if ! bash -n "$SCRIPT_FILE" 2>/dev/null; then
    warn "⚠️ Syntax error in script - keeping current config (v$old_version)"
    return 1
  fi
  log "Syntax OK, sourcing..."
  
  # Reset flag before source
  WILL_RELOAD=false
  
  if source "$SCRIPT_FILE" 2>/dev/null; then
    # Update computed variables after reload
    MAX_FILE_SIZE_BYTES=$((MAX_FILE_SIZE_MB * 1024 * 1024))
    local policy_msg=""
    [[ "$RELOAD_ON_SHA_CHANGE" == "false" ]] && policy_msg=" | ⚠️ SELF-UPDATE DISABLED"
    
    if [[ "$old_version" != "$VERSION" ]]; then
      ok "🆕 VERSION CHANGED: v$old_version → v$VERSION"
    fi
    ok "adg-auto-commiter loaded v$LOADED_VERSION, most current v$VERSION$policy_msg"
    
    # Ensure we're still on autocommit branch after reload
    ensure_autocommit_branch || true
    
    # Check if full restart is needed (flag set by source section)
    if [[ "$WILL_RELOAD" == "true" ]]; then
      do_full_restart
    fi
  else
    warn "Reload failed - keeping current config (v$old_version)"
  fi
}

# ═══════════════════════════════════════════════════════════
# GIT ROOT INFO (already verified during GIT_ROOT detection)
# ═══════════════════════════════════════════════════════════
info "📁 Git root: $GIT_ROOT"
info "📁 Lock file: $LOCKFILE"

# Initial hardening pass as soon as Git is available
repo_hardening_setup
detect_repo_in_progress

# ═══════════════════════════════════════════════════════════
# ENSURE AUTOCOMMIT BRANCH - create & switch to dedicated branch
# This is the heart of multi-PC cloud sync!
# ═══════════════════════════════════════════════════════════
ensure_autocommit_branch() {
  local target_branch="${AUTOCOMMIT_BRANCH:-autocommit}"
  local current_branch=$($GIT rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  
  # Already on autocommit branch?
  if [[ "$current_branch" == "$target_branch" ]]; then
    ok "🌿 Already on branch: $target_branch"
    return 0
  fi
  
  info "🌿 Ensuring autocommit branch: $target_branch"
  
  # Stash any uncommitted changes first
  local had_changes=false
  if [[ -n "$($GIT status --porcelain 2>/dev/null)" ]]; then
    info "Stashing uncommitted changes..."
    $GIT stash push -m "auto-stash-before-branch-switch-$(date +%s)" 2>/dev/null && had_changes=true
  fi
  
  # Check if autocommit branch exists locally
  if $GIT show-ref --verify --quiet "refs/heads/$target_branch" 2>/dev/null; then
    # Branch exists locally - just switch to it
    info "Switching to existing local branch: $target_branch"
    if $GIT checkout "$target_branch" 2>/dev/null; then
      ok "Switched to $target_branch"
    else
      warn "Failed to switch to $target_branch"
      [[ "$had_changes" == true ]] && $GIT stash pop 2>/dev/null || true
      return 1
    fi
  else
    # Branch doesn't exist locally - check remote
    network_retry "Fetch" $GIT fetch origin 2>/dev/null || true
    
    if $GIT show-ref --verify --quiet "refs/remotes/origin/$target_branch" 2>/dev/null; then
      # Branch exists on remote - checkout and track
      info "Branch exists on remote - checking out: $target_branch"
      if $GIT checkout -b "$target_branch" --track "origin/$target_branch" 2>/dev/null; then
        ok "Checked out and tracking origin/$target_branch"
      else
        warn "Failed to checkout remote branch"
        [[ "$had_changes" == true ]] && $GIT stash pop 2>/dev/null || true
        return 1
      fi
    else
      # Branch doesn't exist anywhere - create it!
      info "Creating new branch: $target_branch"
      
      # Find base branch (main or master)
      local base_branch=""
      if $GIT show-ref --verify --quiet refs/heads/main 2>/dev/null; then
        base_branch="main"
      elif $GIT show-ref --verify --quiet refs/heads/master 2>/dev/null; then
        base_branch="master"
      elif $GIT show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
        base_branch="origin/main"
      elif $GIT show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
        base_branch="origin/master"
      fi
      
      if [[ -n "$base_branch" ]]; then
        # Create from base branch
        info "Creating $target_branch from $base_branch"
        if $GIT checkout -b "$target_branch" "$base_branch" 2>/dev/null; then
          ok "Created branch $target_branch from $base_branch"
        else
          warn "Failed to create branch from $base_branch, creating orphan"
          $GIT checkout -b "$target_branch" 2>/dev/null || true
        fi
      else
        # No base branch - create from current HEAD
        info "No main/master found - creating $target_branch from current HEAD"
        $GIT checkout -b "$target_branch" 2>/dev/null || true
      fi
      
      # Push new branch to remote
      info "Pushing new branch to origin..."
      if network_retry "Push new branch" $GIT push -u origin "$target_branch" 2>/dev/null; then
        ok "Branch $target_branch pushed to origin"
      else
        warn "Could not push branch to origin (will retry later)"
      fi
    fi
  fi
  
  # Restore stashed changes
  if [[ "$had_changes" == true ]]; then
    info "Restoring stashed changes..."
    $GIT stash pop 2>/dev/null || warn "Could not restore stash"
  fi
  
  # Merge latest from main/master if configured
  if [[ "${SYNC_FROM_MAIN:-true}" == "true" ]]; then
    local main_branch=""
    if $GIT show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
      main_branch="origin/main"
    elif $GIT show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
      main_branch="origin/master"
    fi
    
    if [[ -n "$main_branch" ]]; then
      info "Syncing latest from $main_branch..."
      if $GIT merge --no-edit -X ours "$main_branch" 2>/dev/null; then
        ok "Merged latest from $main_branch"
      else
        # Merge conflict - abort and continue
        $GIT merge --abort 2>/dev/null || true
        warn "Could not auto-merge from $main_branch (continuing anyway)"
      fi
    fi
  fi
  
  # Verify we're on the right branch
  current_branch=$($GIT rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$current_branch" == "$target_branch" ]]; then
    ok "✅ Now on branch: $target_branch"
    return 0
  else
    err "Failed to switch to $target_branch (still on $current_branch)"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# CHECK FOR LARGE FILES (>99MB) - auto-add to .gitignore
# Uses GIT_ROOT for proper path resolution
# ═══════════════════════════════════════════════════════════
check_large_files() {
  local large_files
  local gitignore_path="$GIT_ROOT/.gitignore"
  
  # Search from GIT_ROOT to find all large files
  large_files=$(find "$GIT_ROOT" -type f -size +${MAX_FILE_SIZE_MB}M 2>/dev/null | grep -v "/.git/" || true)
  
  [[ -z "$large_files" ]] && return 0
  
  local new_found=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # Make path relative to GIT_ROOT
    local clean="${f#$GIT_ROOT/}"
    
    if ! grep -qxF "$clean" "$gitignore_path" 2>/dev/null; then
      new_found=true
      local size=$(du -h "$f" 2>/dev/null | cut -f1)
      warn "Large file: $size $clean → adding to .gitignore"
      echo "$clean" >> "$gitignore_path"
    fi
  done <<< "$large_files"
  
  [[ "$new_found" == true ]] && warn "Large files added to $gitignore_path"
  return 0
}

# ═══════════════════════════════════════════════════════════
# CHECK STAGED FILES FOR SIZE (fast - only checks diff)
# Uses GIT_ROOT for proper .gitignore location
# ═══════════════════════════════════════════════════════════
check_staged_large() {
  # Only check files that are actually staged (not all tracked files!)
  log "Scanning staged files..."
  local staged_files=$($GIT diff --cached --name-only 2>/dev/null)
  local gitignore_path="$GIT_ROOT/.gitignore"
  
  if [[ -z "$staged_files" ]]; then
    log "No staged files to check"
    return 0
  fi
  
  local file_count=$(echo "$staged_files" | wc -l | tr -d ' ')
  log "Checking $file_count staged file(s) for size..."
  
  local found_large=false
  local to_remove=()
  local checked=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    checked=$((checked + 1))
    
    local full_path="$GIT_ROOT/$file"
    if [[ ! -f "$full_path" ]]; then
      continue  # skip deleted files
    fi
    
    local size=$(stat -c%s "$full_path" 2>/dev/null || echo 0)
    
    if [[ "$size" -gt "$MAX_FILE_SIZE_BYTES" ]]; then
      found_large=true
      to_remove+=("$file")
      warn "⚠️ STAGED TOO LARGE: $file ($((size/1024/1024))MB)"
    fi
  done <<< "$staged_files"
  
  log "Checked $checked file(s) - all OK"
  
  if [[ "$found_large" == true ]]; then
    for file in "${to_remove[@]}"; do
      grep -qxF "$file" "$gitignore_path" 2>/dev/null || echo "$file" >> "$gitignore_path"
      $GIT reset HEAD -- "$file" 2>/dev/null || $GIT rm --cached "$file" 2>/dev/null || true
      ok "Removed from staging: $file"
    done
    $GIT add "$gitignore_path" 2>/dev/null || true
    return 1
  fi
  return 0
}

# ═══════════════════════════════════════════════════════════
# COUNT LOCAL CHANGES
# ═══════════════════════════════════════════════════════════
count_changes() {
  local st="$($GIT status --porcelain)"
  [[ -z "$st" ]] && echo "0 0 0 0 0" && return
  
  local added=$(printf "%s\n" "$st" | awk '$1=="??" || $1~/^A/ || $1~/^.A/ {a++} END{print a+0}')
  local modified=$(printf "%s\n" "$st" | awk '$1~/^M/ || $1~/^.M/ {m++} END{print m+0}')
  local renamed=$(printf "%s\n" "$st" | awk '$1~/^R/ || $1~/^.R/ {r++} END{print r+0}')
  local removed=$(printf "%s\n" "$st" | awk '$1~/^D/ || $1~/^.D/ {d++} END{print d+0}')
  local total=$(printf "%s\n" "$st" | wc -l | tr -d ' ')
  
  echo "$total $added $modified $renamed $removed"
}

# ═══════════════════════════════════════════════════════════
# COUNT DIFF LINES
# ═══════════════════════════════════════════════════════════
count_diff_lines() {
  local diff_stat=$($GIT diff --cached --numstat 2>/dev/null || echo "")
  [[ -z "$diff_stat" ]] && echo "0 0 0" && return
  
  local lines_add=0 lines_rem=0 files=0
  while IFS=$'\t' read -r add rem file; do
    [[ -z "$add" ]] && continue
    [[ "$add" == "-" ]] && add=0
    [[ "$rem" == "-" ]] && rem=0
    lines_add=$((lines_add + add))
    lines_rem=$((lines_rem + rem))
    files=$((files + 1))
  done <<< "$diff_stat"
  
  echo "$files $lines_add $lines_rem"
}

# ═══════════════════════════════════════════════════════════
# SHOW CHANGES SUMMARY
# ═══════════════════════════════════════════════════════════
show_changes() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  
  [[ "$total" -eq 0 ]] && return 0
  
  printf "\n%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_CYAN" "$C_RESET"
  printf "%b║%b           %b📊 CHANGES SUMMARY%b                                  %b║%b\n" "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_CYAN" "$C_RESET"
  printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_CYAN" "$C_RESET"
  printf "%b║%b  %b+%b Added:    %-5s    %b~%b Modified: %-5s                    %b║%b\n" "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET" "$added" "$C_YELLOW" "$C_RESET" "$modified" "$C_CYAN" "$C_RESET"
  printf "%b║%b  %b→%b Renamed:  %-5s    %b-%b Removed:  %-5s                    %b║%b\n" "$C_CYAN" "$C_RESET" "$C_BLUE" "$C_RESET" "$renamed" "$C_RED" "$C_RESET" "$removed" "$C_CYAN" "$C_RESET"
  printf "%b║%b  %b=%b TOTAL:    %-5s                                          %b║%b\n" "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET" "$total" "$C_CYAN" "$C_RESET"
  printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$C_CYAN" "$C_RESET"
}

# ═══════════════════════════════════════════════════════════
# GENERATE COMMIT MESSAGE
# ═══════════════════════════════════════════════════════════
gen_commit_msg() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  echo "auto ${USER_NAME}@${HOST_NAME} $(date +"$DATE_FMT_COMMIT") [+${added} new, ~${modified} mod, ${renamed} ren, -${removed} del]"
}

# ═══════════════════════════════════════════════════════════
# DO COMMIT AND PUSH (with network retry)
# ═══════════════════════════════════════════════════════════
do_commit_push() {
  # Respect SAFE MODE
  if [[ "${SAFE_MODE:-false}" == "true" ]]; then
    warn "SAFE MODE: skipping commit/push"
    return 0
  fi

  ensure_remote_access
  local msg="$1"
  
  info "🚀 Starting commit sequence..."
  
  log "Step 1/5: Check for large files in repo..."
  check_large_files
  
  log "Step 2/5: git add -A..."
  $GIT add -A || { warn "git add failed"; _heartbeat; return 1; }
  _heartbeat
  
  log "Step 3/5: Verify staged files size..."
  check_staged_large || {
    log "Re-running git add after removing large files..."
    $GIT add -A 2>/dev/null || true
    _heartbeat
  }
  
  local files_count lines_add lines_rem
  read -r files_count lines_add lines_rem < <(count_diff_lines)
  log "Staged: $files_count files, +$lines_add/-$lines_rem lines"
  
  log "Step 4/5: git commit..."
  if $GIT commit -m "$msg" >/dev/null 2>&1; then
    ok "Commit: $msg"
    STAT_COMMITS=$((STAT_COMMITS + 1))
    STAT_FILES=$((STAT_FILES + files_count))
    STAT_LINES_ADDED=$((STAT_LINES_ADDED + lines_add))
    STAT_LINES_REMOVED=$((STAT_LINES_REMOVED + lines_rem))
    show_stats
  else
    warn "Nothing to commit"
    _heartbeat
    PENDING_COMMIT=false
    CHANGES_DETECTED_AT=0
    return 0
  fi
  _heartbeat
  
  log "Step 5/5: git push (with retry)..."
  if network_retry "Push" $GIT push; then
    ok "Push OK"
  else
    warn "Push failed, trying force-with-lease..."
    if network_retry "Force push" $GIT push --force-with-lease; then
      ok "Force-push OK"
    else
      err "Push failed after retries!"
      _heartbeat
      return 1
    fi
  fi
  
  PENDING_COMMIT=false
  CHANGES_DETECTED_AT=0
  _heartbeat
  return 0
}

# ═══════════════════════════════════════════════════════════
# CHECK USER INPUT (non-blocking)
# ═══════════════════════════════════════════════════════════
check_input() {
  local key
  if read -t 0.1 -n 1 key 2>/dev/null; then
    case "$key" in
      y|Y)
        printf "\n%b[!] Commit NOW...%b\n" "$C_GREEN" "$C_RESET"
        do_commit_push "$(gen_commit_msg)"
        return 0
        ;;
      m|M)
        printf "\n%b[!] Enter commit message:%b " "$C_YELLOW" "$C_RESET"
        local custom_msg
        read -r custom_msg
        [[ -n "$custom_msg" ]] && do_commit_push "$custom_msg" || warn "Empty message - cancelled"
        return 0
        ;;
      r|R)
        printf "\n%b[!] Manual reload...%b\n" "$C_CYAN" "$C_RESET"
        do_reload
        return 0
        ;;
    esac
  fi
  return 1
}

# ═══════════════════════════════════════════════════════════
# HANDLE PENDING COMMIT WITH TIMEOUT
# ═══════════════════════════════════════════════════════════
handle_pending() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  
  if [[ "$total" -eq 0 ]]; then
    [[ "$PENDING_COMMIT" == true ]] && log "Changes gone - cancelling pending commit"
    PENDING_COMMIT=false
    CHANGES_DETECTED_AT=0
    return 0
  fi
  
  check_large_files
  
  local now=$(date +%s)
  
  # First detection
  if [[ "$PENDING_COMMIT" == false ]]; then
    PENDING_COMMIT=true
    CHANGES_DETECTED_AT=$now
    
    show_changes
    
    local commit_at=$((CHANGES_DETECTED_AT + COMMIT_TIMEOUT))
    local commit_time=$(date -d "@$commit_at" +%H:%M:%S 2>/dev/null || echo "in ${COMMIT_TIMEOUT}s")
    
    printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_PINK" "$C_RESET"
    printf "%b║%b  ⏱️  Auto-commit in %ds (at %s)                         %b║%b\n" "$C_PINK" "$C_RESET" "$COMMIT_TIMEOUT" "$commit_time" "$C_PINK" "$C_RESET"
    printf "%b║%b  %b[y]%b=commit now  %b[m]%b=custom msg  %b[r]%b=reload config        %b║%b\n" "$C_ORANGE" "$C_RESET" "$C_GREEN" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_ORANGE" "$C_RESET"
    printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$C_RED" "$C_RESET"
    
    pend "Changes detected. Timeout started..."
    return 0
  fi
  
  # Check timeout
  local elapsed=$((now - CHANGES_DETECTED_AT))
  local remaining=$((COMMIT_TIMEOUT - elapsed))
  
  if [[ "$remaining" -le 0 ]]; then
    info "⏰ Timeout! Auto-committing..."
    do_commit_push "$(gen_commit_msg)"
    return 0
  fi
  
  # Show remaining time every 60s
  if [[ $((elapsed % 60)) -eq 0 ]] && [[ "$elapsed" -gt 0 ]]; then
    pend "Auto-commit in ${remaining}s | [y]=now [m]=custom [r]=reload"
  fi
  
  return 0
}

# ═══════════════════════════════════════════════════════════
# DO PULL WITH SMART "NEWER WINS" STRATEGY (CLOUD EXPERIENCE)
# Multi-PC sync on AUTOCOMMIT branch - newer commits win!
# No user intervention required!
# ═══════════════════════════════════════════════════════════
do_pull() {
  # Respect SAFE MODE
  if [[ "${SAFE_MODE:-false}" == "true" ]]; then
    warn "SAFE MODE: skipping pull"
    return 0
  fi

  ensure_remote_access
  
  # Ensure we're on autocommit branch
  local target_branch="${AUTOCOMMIT_BRANCH:-autocommit}"
  local branch=$($GIT rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  
  if [[ "$branch" != "$target_branch" ]]; then
    warn "Not on $target_branch ($branch) - switching..."
    ensure_autocommit_branch || return 1
    branch="$target_branch"
  fi
  
  info "🌩️ Cloud sync on '$branch' (strategy: ${CONFLICT_STRATEGY:-newer-wins})..."
  _heartbeat
  
  # Fetch first (with retry)
  network_retry "Fetch" $GIT fetch origin 2>/dev/null || true
  
  # Get local and remote heads
  local local_head=$($GIT rev-parse HEAD 2>/dev/null || echo "")
  local remote_branch="origin/$branch"
  local remote_head=$($GIT rev-parse "$remote_branch" 2>/dev/null || echo "")
  
  # No remote? Nothing to pull
  if [[ -z "$remote_head" ]]; then
    ok "No remote branch yet - nothing to pull"
    return 0
  fi
  
  # Same commit? Already up to date
  if [[ "$local_head" == "$remote_head" ]]; then
    ok "Already up to date"
    return 0
  fi
  
  # Check relationship between local and remote
  local base=$($GIT merge-base "$local_head" "$remote_head" 2>/dev/null || echo "")
  
  # Case 1: Local is ahead (base == remote) - nothing to pull
  if [[ "$base" == "$remote_head" ]]; then
    ok "Local is ahead of remote - nothing to pull"
    return 0
  fi
  
  # Case 2: Remote is ahead (base == local) - fast-forward
  if [[ "$base" == "$local_head" ]]; then
    info "Remote is ahead - fast-forward merge..."
    if $GIT merge --ff-only "$remote_branch" 2>/dev/null; then
      ok "Fast-forward merge OK"
      _heartbeat
      return 0
    fi
  fi
  
  # Case 3: DIVERGENCE - need smart merge
  warn "⚠️ DIVERGENCE detected between local and remote!"
  
  # ═══════════════════════════════════════════════════════════
  # SMART TIMESTAMP COMPARISON
  # - Use AUTHOR date (not committer date) - stable across cherry-pick/rebase
  # - Skip merge commits (they have fresh dates but no real changes)
  # - Compare actual work commits, not merge artifacts
  # ═══════════════════════════════════════════════════════════
  
  # Get last NON-MERGE commit timestamps (author date = %at)
  # --no-merges skips merge commits, --first-parent follows main line
  local local_ts=$($GIT log --no-merges -1 --format="%at" HEAD 2>/dev/null || echo "0")
  local remote_ts=$($GIT log --no-merges -1 --format="%at" "$remote_branch" 2>/dev/null || echo "0")
  
  local local_date=$($GIT log --no-merges -1 --format="%ai" HEAD 2>/dev/null || echo "unknown")
  local remote_date=$($GIT log --no-merges -1 --format="%ai" "$remote_branch" 2>/dev/null || echo "unknown")
  
  # Also get the commit messages for context
  local local_msg=$($GIT log --no-merges -1 --format="%s" HEAD 2>/dev/null | head -c 40)
  local remote_msg=$($GIT log --no-merges -1 --format="%s" "$remote_branch" 2>/dev/null | head -c 40)
  
  info "📅 Local  (non-merge): $local_date | $local_msg..."
  info "📅 Remote (non-merge): $remote_date | $remote_msg..."
  
  # Determine merge strategy based on AUTHOR timestamps of real work commits
  local merge_strategy="ours"
  
  if [[ "${NEWER_WINS_MODE:-true}" == "true" ]] || [[ "${CONFLICT_STRATEGY:-newer-wins}" == "newer-wins" ]]; then
    if [[ "$local_ts" -ge "$remote_ts" ]]; then
      merge_strategy="ours"
      info "🏆 LOCAL WORK IS NEWER (ts:$local_ts >= $remote_ts) → local wins"
    else
      merge_strategy="theirs"
      info "🏆 REMOTE WORK IS NEWER (ts:$remote_ts > $local_ts) → remote wins"
    fi
  elif [[ "${CONFLICT_STRATEGY:-}" == "theirs" ]]; then
    merge_strategy="theirs"
  fi
  
  # Stash any uncommitted changes
  local had_stash=false
  if [[ -n "$($GIT status --porcelain 2>/dev/null)" ]]; then
    $GIT stash push -m "auto-stash-$(date +%s)" 2>/dev/null && had_stash=true
  fi
  
  # Attempt merge with chosen strategy
  if network_retry "Pull merge" $GIT pull --no-rebase -X "$merge_strategy" --no-edit; then
    ok "Pull merge OK (strategy: $merge_strategy)"
    STAT_MERGES=$((STAT_MERGES + 1))
  else
    warn "Pull merge failed - attempting recovery..."
    $GIT merge --abort 2>/dev/null || true
    
    # If local is newer, force push later; if remote is newer, reset to remote
    if [[ "$merge_strategy" == "theirs" ]]; then
      warn "Resetting to remote (remote was newer)..."
      $GIT reset --hard "$remote_branch" 2>/dev/null || true
    else
      info "Keeping local (local was newer) - will push later"
    fi
    STAT_MERGES=$((STAT_MERGES + 1))
  fi
  
  # Restore stash if we had one
  if [[ "$had_stash" == true ]]; then
    $GIT stash pop 2>/dev/null || warn "Could not restore stash"
  fi
  
  _heartbeat
  show_stats
  return 0
}

# ═══════════════════════════════════════════════════════════
# PIPE INPUT HANDLER - for automated setup
# ═══════════════════════════════════════════════════════════
handle_pipe_input() {
  if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
    info "📥 Pipe input detected, reading..."
    local line=""
    if read -t 2 -r line; then
      if [[ "$line" =~ ^([^/]+)/(.+)$ ]]; then
        export PIPE_GH_USER="${BASH_REMATCH[1]}"
        export PIPE_GH_REPO="${BASH_REMATCH[2]}"
        info "Pipe: user=$PIPE_GH_USER repo=$PIPE_GH_REPO"
        return 0
      fi
    fi
  fi
  return 1
}

# ═══════════════════════════════════════════════════════════
# STARTUP BANNER
# ═══════════════════════════════════════════════════════════
printf "\n"
printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_PINK" "$C_RESET"
printf "%b║%b     %b💕 ADG AUTO-COMMITER v%s STARTED%b   %b♥ I<3U ♥%b   %b║%b\n" "$C_PINK" "$C_RESET" "$C_BOLD$C_HOTPINK" "$LOADED_VERSION" "$C_RESET" "$C_HEART" "$C_RESET" "$C_PINK" "$C_RESET"
printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_ORANGE" "$C_RESET"
printf "%b║%b  Pull:     %4ds    Check:   %4ds    Timeout: %4ds         %b║%b\n" "$C_ORANGE" "$C_RESET" "$PULL_EVERY" "$CHECK_EVERY" "$COMMIT_TIMEOUT" "$C_ORANGE" "$C_RESET"
printf "%b║%b  Max file: %4dMB   Reload:  co %d cykli                     %b║%b\n" "$C_ORANGE" "$C_RESET" "$MAX_FILE_SIZE_MB" "$SELF_CHECK_EVERY" "$C_ORANGE" "$C_RESET"
printf "%b║%b  Git timeout: %3ds  Retry max: %d  Backoff: %s       %b║%b\n" "$C_ORANGE" "$C_RESET" "$GIT_TIMEOUT" "$NETWORK_RETRY_MAX" "$NETWORK_RETRY_BACKOFF" "$C_ORANGE" "$C_RESET"
printf "%b║%b  SHA:      %.20s...   RELOAD_SHA: %-5s         %b║%b\n" "$C_ORANGE" "$C_RESET" "$AC5_SHA_ORIGINAL" "$RELOAD_ON_SHA_CHANGE" "$C_ORANGE" "$C_RESET"
if [[ "$RELOAD_ON_SHA_CHANGE" == "false" ]]; then
  printf "%b║%b  %b⚠️  SELF-UPDATE DISABLED DUE TO POLICY%b                       %b║%b\n" "$C_ORANGE" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_ORANGE" "$C_RESET"
fi
printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_CYAN" "$C_RESET"
printf "%b║%b  �  BRANCH: %-20s (auto-sync enabled)          %b║%b\n" "$C_CYAN" "$C_RESET" "${AUTOCOMMIT_BRANCH:-autocommit}" "$C_CYAN" "$C_RESET"
printf "%b║%b  �🌩️  CLOUD MODE: Multi-PC sync, newer commits win!            %b║%b\n" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
printf "%b║%b  🔄  Strategy: %-12s  Retry: %dx with backoff        %b║%b\n" "$C_CYAN" "$C_RESET" "${CONFLICT_STRATEGY:-newer-wins}" "$NETWORK_RETRY_MAX" "$C_CYAN" "$C_RESET"
printf "%b║%b  📁  Root: %-50s %b║%b\n" "$C_CYAN" "$C_RESET" "${GIT_ROOT:0:50}" "$C_CYAN" "$C_RESET"
printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_RED" "$C_RESET"
printf "%b║%b  %b[y]%b=commit now  %b[m]%b=custom msg  %b[r]%b=reload config          %b║%b\n" "$C_RED" "$C_RESET" "$C_GREEN" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RED" "$C_RESET"
printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$C_RED" "$C_RESET"

info "Lock: $LOCKFILE | Script: $SCRIPT_FILE"
_heartbeat

# ═══════════════════════════════════════════════════════════
# STARTUP SEQUENCE
# ═══════════════════════════════════════════════════════════

# 0. Check remote access FIRST (shows helpful error if credentials missing)
ensure_remote_access || warn "Remote access issue - will work in offline mode"

# 1. Handle pipe input if present
handle_pipe_input || true

# 2. Setup git auth if needed (first run or no remote)
if ! $GIT remote get-url origin >/dev/null 2>&1; then
  setup_git_auth || true
fi

# 3. CRITICAL: Ensure we're on autocommit branch!
info "🚀 Setting up autocommit branch..."
ensure_autocommit_branch || warn "Could not setup autocommit branch"

# 3.5 Add self to .gitignore (live update protection!)
ensure_self_gitignore || true

# 4. Initial check for large files
check_large_files

# 3.1 Repo hardening and self-conflict guard
self_conflict_guard || true
detect_repo_in_progress || true

# 4. Startup push - push any pending commits!
do_startup_push || true

# ═══════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════
last_pull=0
last_check=0

while true; do
  now=$(date +%s)
  CYCLE_COUNT=$((CYCLE_COUNT + 1))
  
  # Heartbeat every 30 cycles (~30s)
  if (( CYCLE_COUNT % 30 == 0 )); then
    printf "%b.%b" "$C_DIM" "$C_RESET"
  fi
  
  # Self-reload every N cycles
  if (( CYCLE_COUNT % SELF_CHECK_EVERY == 0 )); then
    printf "\n"
    do_reload
  fi
  
  # Check user input
  [[ "$PENDING_COMMIT" == true ]] && check_input || true
  
  # Pull cycle
  if (( now - last_pull >= PULL_EVERY )); then
    detect_repo_in_progress || true
    self_conflict_guard || true
    printf "\n"
    printf "%b══════ %s v%s [cycle #%d] ══════%b %b♥ I<3U ♥%b\n" "$C_PINK" "$SCRIPT_NAME" "$VERSION" "$CYCLE_COUNT" "$C_RESET" "$C_HEART" "$C_RESET"
    show_stats
    do_pull || true
    last_pull=$now
  fi
  
  # Local changes check
  if (( now - last_check >= CHECK_EVERY )); then
    handle_pending || true
    last_check=$now
    # Show alive indicator if no pending commit
    if [[ "$PENDING_COMMIT" == false ]]; then
      printf "%b[%s]%b 💤 Watching... (cycle #%d)\r" "$C_DIM" "$(_ts)" "$C_RESET" "$CYCLE_COUNT"
    fi
  fi
  
  sleep 1
done

fi
