#!/bin/bash
# Patch to fix flock -> PID-based lock

SCRIPT_FILE="D:/instant_run/CODE/adasio_and_martusia/adasio_and_martusia/adasio/scripts/adg-autocommiter/adg-auto-commiter-UpNext.sh"

# Replace flock lock with PID-based lock
sed -i '
/# FLOCK LOCK/,/_heartbeat$/ {
  /# FLOCK LOCK/c\
# ═══════════════════════════════════════════════════════════\
# PID-BASED LOCK (flock doesnt work in Git Bash)\
# ═══════════════════════════════════════════════════════════\
if [[ -f "$LOCKFILE" ]]; then\
  _old_pid=$(grep -oP '\''pid=\\K\\d+'\'' "$LOCKFILE" 2>/dev/null || echo "")\
  if [[ -n "$_old_pid" ]] \&\& kill -0 "$_old_pid" 2>/dev/null; then\
    err "Another instance is running (PID: $_old_pid)"\
    cat "$LOCKFILE" 2>/dev/null || true\
    exit 0\
  else\
    warn "Stale lockfile found, removing..."\
    rm -f "$LOCKFILE"\
  fi\
fi\
\
_heartbeat() {\
  printf "pid=%s host=%s user=%s ts=%s\\n" \\\
    "$$" "$HOST_NAME" "$USER_NAME" "$(date '\''+%Y-%m-%dT%H:%M:%S'\'')" > "$LOCKFILE"\
}\
_heartbeat\
ok "Lock acquired (PID: $$)"
  /^exec 200/d
  /flock -n 200/,/^}/d
  /_heartbeat()/,/^_heartbeat$/d
}
' "$SCRIPT_FILE"

# Also remove flock release in cleanup
sed -i 's|/usr/bin/flock -u 200.*||g' "$SCRIPT_FILE"
sed -i 's|exec 200>&-.*||g' "$SCRIPT_FILE"
sed -i 's|# Release flock||g' "$SCRIPT_FILE"

# Update VERSION
sed -i 's/VERSION="[0-9.]*"/VERSION="6.0.11"/g' "$SCRIPT_FILE"

# Test syntax
if bash -n "$SCRIPT_FILE"; then
  echo "SUCCESS! Lock patched to PID-based, VERSION=6.0.11"
else
  echo "ERROR: Syntax check failed!"
fi
