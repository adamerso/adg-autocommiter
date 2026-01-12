#!/bin/bash
# =======================
# AUTO-COMMITER 5.0.21.37  ♥ I<3U ♥
# =======================
# Clean refactored version with proper variable management
# - All config in SOURCE section (hot-reload)
# - SHA-based full reload (only when RELOAD_ON_SHA_CHANGE=true)
# - Variables always reload on source
# - TRAMPOLINE restart via temp file (Cygwin-safe)
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
  VERSION="5.0.21.69"
  
  # Timing
  COMMIT_TIMEOUT=180       # seconds before auto-commit (3 min)
  CHECK_EVERY=15           # check for local changes every N seconds
  PULL_EVERY=30           # pull from remote every N seconds (5 min)
  SELF_CHECK_EVERY=10      # source self every N cycles for variable reload
  AA=aaa
  # Limits
  MAX_FILE_SIZE_MB=99      # files larger than this are auto-ignored
  # Behavior
  RELOAD_ON_SHA_CHANGE=true   # true = full exec restart on SHA change
                              # false = only reload variables, no restart
  
  # ═══════════════════════════════════════════════════════════
  # SHA CHECK: Set WILL_RELOAD flag (actual exec happens in main script)
  # SKIP if we just returned from trampoline (RUNLEVEL=returning)
  # ═══════════════════════════════════════════════════════════
  WILL_RELOAD=false
  echo "[source] 📖 Reloading variables... (RUNLEVEL=${RUNLEVEL:-default})"
  
  if [[ "$RELOAD_ON_SHA_CHANGE" == "true" ]] && [[ "${RUNLEVEL:-default}" != "returning" ]]; then
    _SHA_CURRENT="$(/usr/bin/sha1sum "$SCRIPT_FILE" 2>/dev/null | /usr/bin/awk '{print $1}')"
    
    if [[ -n "${AC5_SHA_ORIGINAL:-}" ]] && [[ "$_SHA_CURRENT" != "$AC5_SHA_ORIGINAL" ]]; then
      echo ""
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  🔄 SCRIPT SHA CHANGED - WILL RELOAD!                        ║"
      echo "║  Old: ${AC5_SHA_ORIGINAL:0:20}...                            ║"
      echo "║  New: ${_SHA_CURRENT:0:20}...                                ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo ""
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
  exec /bin/bash "$SCRIPT_FILE"
  echo "│ ⛔ exec failed!"
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# CLEANUP: If we're back at SCRIPT_FILE after trampoline, clean up GOWNO
# and UPDATE SHA to prevent infinite restart loop!
# ─────────────────────────────────────────────────────────────
if [[ -n "$GOWNO" ]] && [[ -f "$GOWNO" ]] && [[ "$CALLED_AS" != "$GOWNO" ]]; then
  echo "│ 🧹 Cleaning up GOWNO file..."
  /bin/rm -f "$GOWNO" 2>/dev/null || true
  export GOWNO=""
  
  # UPDATE SHA after successful trampoline - prevents infinite loop!
  AC5_SHA_ORIGINAL="$(/usr/bin/sha1sum "$SCRIPT_FILE" 2>/dev/null | /usr/bin/awk '{print $1}')"
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
  if /bin/bash -n "$SCRIPT_FILE" 2>/dev/null; then
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
  VERSION="${VERSION:-5.0.21.37}"
  COMMIT_TIMEOUT="${COMMIT_TIMEOUT:-180}"
  CHECK_EVERY="${CHECK_EVERY:-15}"
  PULL_EVERY="${PULL_EVERY:-300}"
  SELF_CHECK_EVERY="${SELF_CHECK_EVERY:-50}"
  MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB:-99}"
  RELOAD_ON_SHA_CHANGE="${RELOAD_ON_SHA_CHANGE:-true}"
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
SCRIPT_NAME="auto-commiter5"
AC5_SHA_ORIGINAL="$(/usr/bin/sha1sum "$SCRIPT_FILE" 2>/dev/null | /usr/bin/awk '{print $1}')"
export AC5_SHA_ORIGINAL

# ═══════════════════════════════════════════════════════════
# FIXED VARIABLES (not configurable via source)
# ═══════════════════════════════════════════════════════════
GIT="/usr/bin/git"
LOCKFILE="/tmp/autocommiter5.lock"
USER_NAME="${USER:-$(/usr/bin/whoami 2>/dev/null || echo unknown)}"
HOST_NAME="$(/bin/hostname 2>/dev/null || echo unknown)"
DATE_FMT_COMMIT="%y%m%d %H%M"

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
SESSION_START=$(/usr/bin/date +%s)
STAT_COMMITS=0
STAT_MERGES=0
STAT_FILES=0
STAT_LINES_ADDED=0
STAT_LINES_REMOVED=0

# ═══════════════════════════════════════════════════════════
# GIT: No-interactive mode
# ═══════════════════════════════════════════════════════════
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
export SSH_ASKPASS=/bin/false
export GIT_EDITOR=/bin/true

# ═══════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════
C_RESET="\033[0m"
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
_ts() { /usr/bin/date +%H:%M:%S; }

log()     { /usr/bin/printf "%b[%s]%b %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$*"; }
info()    { /usr/bin/printf "%b[%s]%b %bINFO%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_CYAN" "$C_RESET" "$*"; }
ok()      { /usr/bin/printf "%b[%s]%b %bOK%b    %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_GREEN" "$C_RESET" "$*"; }
warn()    { /usr/bin/printf "%b[%s]%b %bWARN%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_YELLOW" "$C_RESET" "$*"; }
err()     { /usr/bin/printf "%b[%s]%b %bERR%b   %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_RED" "$C_RESET" "$*"; }
pend()    { /usr/bin/printf "%b[%s]%b %bPEND%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_MAGENTA" "$C_RESET" "$*"; }

die() { err "$*"; exit 1; }

# ═══════════════════════════════════════════════════════════
# SESSION STATS DISPLAY
# ═══════════════════════════════════════════════════════════
show_stats() {
  local now=$(/usr/bin/date +%s)
  local elapsed=$((now - SESSION_START))
  local mins=$((elapsed / 60))
  local secs=$((elapsed % 60))
  local ver_info="loaded v$LOADED_VERSION"
  [[ "$LOADED_VERSION" != "$VERSION" ]] && ver_info="$ver_info, current v$VERSION"
  [[ "$RELOAD_ON_SHA_CHANGE" == "false" ]] && ver_info="$ver_info ⚠️"
  /usr/bin/printf "%b[%s %s @ %s]%b 📊 %dm%ds | C:%d M:%d F:%d L:+%d/-%d\n" \
    "$C_PINK" "$SCRIPT_NAME" "$ver_info" "$(_ts)" "$C_RESET" \
    "$mins" "$secs" "$STAT_COMMITS" "$STAT_MERGES" "$STAT_FILES" "$STAT_LINES_ADDED" "$STAT_LINES_REMOVED"
}

# ═══════════════════════════════════════════════════════════
# FLOCK LOCK (kill-safe)
# ═══════════════════════════════════════════════════════════
exec 200>"$LOCKFILE" || die "Cannot open lockfile: $LOCKFILE"

/usr/bin/flock -n 200 || {
  err "Another instance is running (lock: $LOCKFILE)"
  /usr/bin/cat "$LOCKFILE" 2>/dev/null || true
  exit 0
}

_heartbeat() {
  /usr/bin/printf "pid=%s host=%s user=%s ts=%s\n" \
    "$$" "$HOST_NAME" "$USER_NAME" "$(/usr/bin/date -Is)" > "$LOCKFILE"
}
_heartbeat

# ═══════════════════════════════════════════════════════════
# FULL RESTART via TRAMPOLINE (GOWNO jump!)
# ═══════════════════════════════════════════════════════════
do_full_restart() {
  /usr/bin/printf "\n"
  /usr/bin/printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_HOTPINK" "$C_RESET"
  /usr/bin/printf "%b║%b  🔄 FULL RESTART via TRAMPOLINE!                             %b║%b\n" "$C_HOTPINK" "$C_RESET" "$C_HOTPINK" "$C_RESET"
  /usr/bin/printf "%b║%b  Loaded: v%-12s → Current: v%-12s          %b║%b\n" "$C_HOTPINK" "$C_RESET" "$LOADED_VERSION" "$VERSION" "$C_HOTPINK" "$C_RESET"
  /usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$C_HOTPINK" "$C_RESET"
  /usr/bin/printf "\n"
  
  # Generate GOWNO filename (random temp file)
  local script_dir
  script_dir="$(/usr/bin/dirname "$SCRIPT_FILE")"
  export GOWNO="${script_dir}/.gowno_${RANDOM}${RANDOM}${RANDOM}.sh"
  
  info "🦘 Creating trampoline: $GOWNO"
  
  # Copy script to GOWNO (cp -a preserves permissions)
  if ! /bin/cp -a "$SCRIPT_FILE" "$GOWNO" 2>/dev/null; then
    # Fallback without -a
    /bin/cp "$SCRIPT_FILE" "$GOWNO" 2>/dev/null || {
      err "Cannot create trampoline file!"
      return 1
    }
    /bin/chmod +x "$GOWNO" 2>/dev/null || true
  fi
  
  info "Jumping to GOWNO in 1s..."
  /bin/sleep 1
  
  # Release flock
  /usr/bin/flock -u 200 2>/dev/null || true
  exec 200>&- 2>/dev/null || true
  /bin/rm -f "$LOCKFILE" 2>/dev/null || true
  
  # Reset guard
  AC5_RUNNING=false
  export AC5_RUNNING=false
  
  # Set RUNLEVEL to gowno (trampoline mode)
  export RUNLEVEL="gowno"
  
  # JUMP TO GOWNO!
  info "🚀 exec $GOWNO"
  exec /bin/bash "$GOWNO"
  
  # Fallback (should never reach)
  err "exec failed!"
  exit 1
}

# ═══════════════════════════════════════════════════════════
# SAFE SELF-RELOAD (via tmp file)
# ═══════════════════════════════════════════════════════════
do_reload() {
  local old_version="$VERSION"
  info "♻️  Reloading variables (loaded: v$LOADED_VERSION, current: v$old_version)..."
  
  # First check syntax
  log "Testing script syntax..."
  if ! /bin/bash -n "$SCRIPT_FILE" 2>/dev/null; then
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
    ok "auto-commiter5 loaded v$LOADED_VERSION, most current v$VERSION$policy_msg"
    
    # Check if full restart is needed (flag set by source section)
    if [[ "$WILL_RELOAD" == "true" ]]; then
      do_full_restart
    fi
  else
    warn "Reload failed - keeping current config (v$old_version)"
  fi
}

# ═══════════════════════════════════════════════════════════
# GIT SANITY CHECK
# ═══════════════════════════════════════════════════════════
$GIT rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not in a Git repository!"

# ═══════════════════════════════════════════════════════════
# CHECK FOR LARGE FILES (>99MB) - auto-add to .gitignore
# ═══════════════════════════════════════════════════════════
check_large_files() {
  local large_files
  large_files=$(/usr/bin/find . -type f -size +${MAX_FILE_SIZE_MB}M 2>/dev/null | /usr/bin/grep -v "^./.git/" || true)
  
  [[ -z "$large_files" ]] && return 0
  
  local new_found=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local clean="${f#./}"
    
    if ! /usr/bin/grep -qxF "$clean" .gitignore 2>/dev/null; then
      new_found=true
      local size=$(/usr/bin/du -h "$f" 2>/dev/null | /usr/bin/cut -f1)
      warn "Large file: $size $f → adding to .gitignore"
      echo "$clean" >> .gitignore
    fi
  done <<< "$large_files"
  
  [[ "$new_found" == true ]] && warn "Large files added to .gitignore"
  return 0
}

# ═══════════════════════════════════════════════════════════
# CHECK STAGED FILES FOR SIZE (fast - only checks diff)
# ═══════════════════════════════════════════════════════════
check_staged_large() {
  # Only check files that are actually staged (not all tracked files!)
  log "Scanning staged files..."
  local staged_files=$($GIT diff --cached --name-only 2>/dev/null)
  
  if [[ -z "$staged_files" ]]; then
    log "No staged files to check"
    return 0
  fi
  
  local file_count=$(echo "$staged_files" | /usr/bin/wc -l | /usr/bin/tr -d ' ')
  log "Checking $file_count staged file(s) for size..."
  
  local found_large=false
  local to_remove=()
  local checked=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    checked=$((checked + 1))
    
    if [[ ! -f "$file" ]]; then
      continue  # skip deleted files
    fi
    
    local size=$(/usr/bin/stat -c%s "$file" 2>/dev/null || echo 0)
    
    if [[ "$size" -gt "$MAX_FILE_SIZE_BYTES" ]]; then
      found_large=true
      to_remove+=("$file")
      warn "⚠️ STAGED TOO LARGE: $file ($((size/1024/1024))MB)"
    fi
  done <<< "$staged_files"
  
  log "Checked $checked file(s) - all OK"
  
  if [[ "$found_large" == true ]]; then
    for file in "${to_remove[@]}"; do
      local clean="${file#./}"
      /usr/bin/grep -qxF "$clean" .gitignore 2>/dev/null || echo "$clean" >> .gitignore
      $GIT reset HEAD -- "$file" 2>/dev/null || $GIT rm --cached "$file" 2>/dev/null || true
      ok "Removed from staging: $file"
    done
    $GIT add .gitignore 2>/dev/null || true
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
  
  local added=$(/usr/bin/printf "%s\n" "$st" | /usr/bin/awk '$1=="??" || $1~/^A/ || $1~/^.A/ {a++} END{print a+0}')
  local modified=$(/usr/bin/printf "%s\n" "$st" | /usr/bin/awk '$1~/^M/ || $1~/^.M/ {m++} END{print m+0}')
  local renamed=$(/usr/bin/printf "%s\n" "$st" | /usr/bin/awk '$1~/^R/ || $1~/^.R/ {r++} END{print r+0}')
  local removed=$(/usr/bin/printf "%s\n" "$st" | /usr/bin/awk '$1~/^D/ || $1~/^.D/ {d++} END{print d+0}')
  local total=$(/usr/bin/printf "%s\n" "$st" | /usr/bin/wc -l | /usr/bin/tr -d ' ')
  
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
  
  /usr/bin/printf "\n%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_CYAN" "$C_RESET"
  /usr/bin/printf "%b║%b           %b📊 CHANGES SUMMARY%b                                  %b║%b\n" "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_CYAN" "$C_RESET"
  /usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_CYAN" "$C_RESET"
  /usr/bin/printf "%b║%b  %b+%b Added:    %-5s    %b~%b Modified: %-5s                    %b║%b\n" "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET" "$added" "$C_YELLOW" "$C_RESET" "$modified" "$C_CYAN" "$C_RESET"
  /usr/bin/printf "%b║%b  %b→%b Renamed:  %-5s    %b-%b Removed:  %-5s                    %b║%b\n" "$C_CYAN" "$C_RESET" "$C_BLUE" "$C_RESET" "$renamed" "$C_RED" "$C_RESET" "$removed" "$C_CYAN" "$C_RESET"
  /usr/bin/printf "%b║%b  %b=%b TOTAL:    %-5s                                          %b║%b\n" "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET" "$total" "$C_CYAN" "$C_RESET"
  /usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$C_CYAN" "$C_RESET"
}

# ═══════════════════════════════════════════════════════════
# GENERATE COMMIT MESSAGE
# ═══════════════════════════════════════════════════════════
gen_commit_msg() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  echo "auto ${USER_NAME}@${HOST_NAME} $(/usr/bin/date +"$DATE_FMT_COMMIT") +$added ~$modified →$renamed -$removed"
}

# ═══════════════════════════════════════════════════════════
# DO COMMIT AND PUSH
# ═══════════════════════════════════════════════════════════
do_commit_push() {
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
  
  log "Step 5/5: git push..."
  if $GIT push; then
    ok "Push OK"
  else
    warn "Push failed, trying force-with-lease..."
    if $GIT push --force-with-lease; then
      ok "Force-push OK"
    else
      err "Push failed!"
    fi
    _heartbeat
    return 1
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
        /usr/bin/printf "\n%b[!] Commit NOW...%b\n" "$C_GREEN" "$C_RESET"
        do_commit_push "$(gen_commit_msg)"
        return 0
        ;;
      m|M)
        /usr/bin/printf "\n%b[!] Enter commit message:%b " "$C_YELLOW" "$C_RESET"
        local custom_msg
        read -r custom_msg
        [[ -n "$custom_msg" ]] && do_commit_push "$custom_msg" || warn "Empty message - cancelled"
        return 0
        ;;
      r|R)
        /usr/bin/printf "\n%b[!] Manual reload...%b\n" "$C_CYAN" "$C_RESET"
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
  
  local now=$(/usr/bin/date +%s)
  
  # First detection
  if [[ "$PENDING_COMMIT" == false ]]; then
    PENDING_COMMIT=true
    CHANGES_DETECTED_AT=$now
    
    show_changes
    
    local commit_at=$((CHANGES_DETECTED_AT + COMMIT_TIMEOUT))
    local commit_time=$(/usr/bin/date -d "@$commit_at" +%H:%M:%S 2>/dev/null || echo "in ${COMMIT_TIMEOUT}s")
    
    /usr/bin/printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_PINK" "$C_RESET"
    /usr/bin/printf "%b║%b  ⏱️  Auto-commit in %ds (at %s)                         %b║%b\n" "$C_PINK" "$C_RESET" "$COMMIT_TIMEOUT" "$commit_time" "$C_PINK" "$C_RESET"
    /usr/bin/printf "%b║%b  %b[y]%b=commit now  %b[m]%b=custom msg  %b[r]%b=reload config        %b║%b\n" "$C_ORANGE" "$C_RESET" "$C_GREEN" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_ORANGE" "$C_RESET"
    /usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$C_RED" "$C_RESET"
    
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
# DO PULL WITH OURS STRATEGY (CLOUD EXPERIENCE)
# ═══════════════════════════════════════════════════════════
do_pull() {
  info "git pull (-X ours)..."
  _heartbeat
  
  # Ensure on main/master
  local branch=$($GIT rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  if [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
    warn "Not on main/master ($branch) - switching..."
    $GIT checkout main 2>/dev/null || $GIT checkout master 2>/dev/null || $GIT checkout -b main 2>/dev/null || true
  fi
  
  # Fetch first
  $GIT fetch origin 2>/dev/null || true
  
  # Check for divergence
  local local_head=$($GIT rev-parse HEAD 2>/dev/null || echo "")
  local remote_head=$($GIT rev-parse origin/main 2>/dev/null || $GIT rev-parse origin/master 2>/dev/null || echo "")
  
  if [[ -n "$local_head" ]] && [[ -n "$remote_head" ]] && [[ "$local_head" != "$remote_head" ]]; then
    local base=$($GIT merge-base "$local_head" "$remote_head" 2>/dev/null || echo "")
    
    if [[ -n "$base" ]] && [[ "$base" != "$local_head" ]] && [[ "$base" != "$remote_head" ]]; then
      warn "⚠️ DIVERGENCE detected! Fixing..."
      $GIT stash push -m "auto-stash-$(date +%s)" 2>/dev/null || true
      
      if $GIT pull --no-rebase -X ours --no-edit 2>/dev/null; then
        ok "Pull merge OK"
        STAT_MERGES=$((STAT_MERGES + 1))
      else
        warn "Pull merge failed - using reset strategy"
        $GIT merge --abort 2>/dev/null || true
        $GIT reset --hard origin/main 2>/dev/null || $GIT reset --hard origin/master 2>/dev/null || true
        $GIT stash pop 2>/dev/null || true
        STAT_MERGES=$((STAT_MERGES + 1))
      fi
      
      _heartbeat
      show_stats
      return 0
    fi
  fi
  
  # Normal pull
  if $GIT pull --no-rebase -X ours --no-edit; then
    ok "Pull OK"
    _heartbeat
    return 0
  else
    warn "Pull failed - trying to fix..."
    $GIT merge --abort 2>/dev/null || true
    $GIT fetch origin 2>/dev/null || true
    $GIT merge -X ours --no-edit origin/main 2>/dev/null || $GIT merge -X ours --no-edit origin/master 2>/dev/null || true
    _heartbeat
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# STARTUP BANNER
# ═══════════════════════════════════════════════════════════
/usr/bin/printf "\n"
/usr/bin/printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_PINK" "$C_RESET"
/usr/bin/printf "%b║%b     %b💕 AUTO-COMMITER v%s STARTED%b    %b♥ I<3U ♥%b    %b║%b\n" "$C_PINK" "$C_RESET" "$C_BOLD$C_HOTPINK" "$LOADED_VERSION" "$C_RESET" "$C_HEART" "$C_RESET" "$C_PINK" "$C_RESET"
/usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_ORANGE" "$C_RESET"
/usr/bin/printf "%b║%b  Pull:     %4ds    Check:   %4ds    Timeout: %4ds         %b║%b\n" "$C_ORANGE" "$C_RESET" "$PULL_EVERY" "$CHECK_EVERY" "$COMMIT_TIMEOUT" "$C_ORANGE" "$C_RESET"
/usr/bin/printf "%b║%b  Max file: %4dMB   Reload:  co %d cykli                     %b║%b\n" "$C_ORANGE" "$C_RESET" "$MAX_FILE_SIZE_MB" "$SELF_CHECK_EVERY" "$C_ORANGE" "$C_RESET"
/usr/bin/printf "%b║%b  SHA:      %.20s...   RELOAD_SHA: %-5s         %b║%b\n" "$C_ORANGE" "$C_RESET" "$AC5_SHA_ORIGINAL" "$RELOAD_ON_SHA_CHANGE" "$C_ORANGE" "$C_RESET"
if [[ "$RELOAD_ON_SHA_CHANGE" == "false" ]]; then
  /usr/bin/printf "%b║%b  %b⚠️  SELF-UPDATE DISABLED DUE TO POLICY%b                       %b║%b\n" "$C_ORANGE" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_ORANGE" "$C_RESET"
fi
/usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_CYAN" "$C_RESET"
/usr/bin/printf "%b║%b  🌩️  CLOUD MODE: Auto-sync, no branch splits!                %b║%b\n" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
/usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$C_RED" "$C_RESET"
/usr/bin/printf "%b║%b  %b[y]%b=commit now  %b[m]%b=custom msg  %b[r]%b=reload config          %b║%b\n" "$C_RED" "$C_RESET" "$C_GREEN" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_RED" "$C_RESET"
/usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$C_RED" "$C_RESET"

info "Lock: $LOCKFILE | Script: $SCRIPT_FILE"
_heartbeat

# Initial check for large files
check_large_files

# ═══════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════
last_pull=0
last_check=0

while true; do
  now=$(/usr/bin/date +%s)
  CYCLE_COUNT=$((CYCLE_COUNT + 1))
  
  # Heartbeat every 30 cycles (~30s)
  if (( CYCLE_COUNT % 30 == 0 )); then
    /usr/bin/printf "%b.%b" "$C_DIM" "$C_RESET"
  fi
  
  # Self-reload every N cycles
  if (( CYCLE_COUNT % SELF_CHECK_EVERY == 0 )); then
    /usr/bin/printf "\n"
    do_reload
  fi
  
  # Check user input
  [[ "$PENDING_COMMIT" == true ]] && check_input || true
  
  # Pull cycle
  if (( now - last_pull >= PULL_EVERY )); then
    /usr/bin/printf "\n"
    /usr/bin/printf "%b══════ %s v%s [cycle #%d] ══════%b %b♥ I<3U ♥%b\n" "$C_PINK" "$SCRIPT_NAME" "$VERSION" "$CYCLE_COUNT" "$C_RESET" "$C_HEART" "$C_RESET"
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
      /usr/bin/printf "%b[%s]%b 💤 Watching... (cycle #%d)\r" "$C_DIM" "$(_ts)" "$C_RESET" "$CYCLE_COUNT"
    fi
  fi
  
  /bin/sleep 1
done

fi
