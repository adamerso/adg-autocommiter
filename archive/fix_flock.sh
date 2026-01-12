#!/bin/bash
# Patch to fix flock and /usr/bin/ paths

FILE="D:/instant_run/CODE/adasio_and_martusia/adasio_and_martusia/adasio/scripts/adg-autocommiter/adg-auto-commiter-UpNext.sh"

echo "1. Removing /usr/bin/ and /bin/ prefixes..."
sed -i 's|/usr/bin/||g; s|/bin/||g' "$FILE"

echo "2. Replacing flock with PID-based lock..."

# Find line numbers
FLOCK_START=$(grep -n "# FLOCK LOCK" "$FILE" | head -1 | cut -d: -f1)
FLOCK_END=$(awk "NR>$FLOCK_START && /^_heartbeat$/ {print NR; exit}" "$FILE")

if [[ -z "$FLOCK_START" ]] || [[ -z "$FLOCK_END" ]]; then
  echo "ERROR: Could not find FLOCK LOCK section"
  grep -n "FLOCK\|flock" "$FILE" | head -10
  exit 1
fi

echo "   Found FLOCK section: lines $FLOCK_START to $FLOCK_END"

# Create new lock section
NEW_LOCK='# ═══════════════════════════════════════════════════════════
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
ok "Lock acquired (PID: $$)"'

# Build new file
{
  head -n $((FLOCK_START - 1)) "$FILE"
  echo "$NEW_LOCK"
  tail -n +$((FLOCK_END + 1)) "$FILE"
} > /tmp/fixed_script.sh

# Verify and replace
if bash -n /tmp/fixed_script.sh; then
  cp /tmp/fixed_script.sh "$FILE"
  echo "SUCCESS! Lock mechanism fixed"
else
  echo "ERROR: Syntax check failed!"
  bash -n /tmp/fixed_script.sh
  exit 1
fi
