#!/bin/bash
# =============================================================================
# PATCH: Downgrade Protection for ADG Auto-Commiter
# =============================================================================
# Adds:
# 1. version_compare() - porównuje wersje semver
# 2. Backup przy starcie (nie z trampoliny)
# 3. Downgrade protection - jeśli nowa wersja < obecna, nadpisuje ją
# =============================================================================

SCRIPT_FILE="D:/instant_run/CODE/adasio_and_martusia/adasio_and_martusia/adasio/scripts/adg-autocommiter/adg-auto-commiter-UpNext.sh"

echo "=== PATCH: Downgrade Protection ==="
echo ""

# Backup original
cp "$SCRIPT_FILE" "${SCRIPT_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
echo "✓ Created backup"

# =============================================================================
# 1. Add version_compare function after color definitions
# =============================================================================
echo "1. Adding version_compare function..."

# Find line after "C_RESET=" and before first function
INSERT_AFTER=$(grep -n "^C_RESET=" "$SCRIPT_FILE" | tail -1 | cut -d: -f1)

# New code to insert
VERSION_COMPARE='
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
  
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$git_root" ]]; then
    return 1
  fi
  
  BACKUP_DIR="$git_root/.git/autocommiter-backup"
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
'

# Insert after C_RESET line
{
  head -n "$INSERT_AFTER" "$SCRIPT_FILE"
  echo "$VERSION_COMPARE"
  tail -n +$((INSERT_AFTER + 1)) "$SCRIPT_FILE"
} > /tmp/patched1.sh

if bash -n /tmp/patched1.sh; then
  cp /tmp/patched1.sh "$SCRIPT_FILE"
  echo "   ✓ version_compare and backup functions added"
else
  echo "   ✗ Syntax error after adding version_compare!"
  exit 1
fi

# =============================================================================
# 2. Modify SOURCE section to check version on SHA change
# =============================================================================
echo "2. Modifying SOURCE section SHA check..."

# Find the SHA check section and add version comparison
sed -i '/SHA changed! Need full restart/,/WILL_RELOAD=true/{
  /WILL_RELOAD=true/a\
\
      # ═══ DOWNGRADE PROTECTION ═══\
      # Extract version from new file\
      local new_version=$(grep -m1 "^  VERSION=" "$SCRIPT_FILE" 2>/dev/null | cut -d'"'"'"'"'"' -f2)\
      \
      if [[ -n "$new_version" ]] && [[ -n "$VERSION" ]]; then\
        version_compare "$VERSION" "$new_version"\
        local cmp_result=$?\
        \
        if [[ $cmp_result -eq 1 ]]; then\
          # Current version > new version = DOWNGRADE ATTEMPT!\
          echo "║  ⚠️  DOWNGRADE DETECTED! Current: v$VERSION > New: v$new_version  ║"\
          echo "║  🛡️  PROTECTING: Overwriting file with current version...  ║"\
          echo "╚════════════════════════════════════════════════════════════╝"\
          \
          # Overwrite the file with our backup\
          if [[ -n "${BACKUP_FILE:-}" ]] && [[ -f "$BACKUP_FILE" ]]; then\
            cp "$BACKUP_FILE" "$SCRIPT_FILE"\
            echo "[source] ✅ Restored from backup: ${BACKUP_FILE##*/}"\
          else\
            echo "[source] ⚠️ No backup available, keeping current state"\
          fi\
          \
          # Update SHA to prevent loop\
          AC5_SHA_ORIGINAL="$_SHA_CURRENT"\
          export AC5_SHA_ORIGINAL\
          WILL_RELOAD=false\
          return 0\
        elif [[ $cmp_result -eq 2 ]]; then\
          echo "║  ✅ UPGRADE: v$VERSION → v$new_version                        ║"\
          echo "╚════════════════════════════════════════════════════════════╝"\
        fi\
      fi
}' "$SCRIPT_FILE"

if bash -n "$SCRIPT_FILE"; then
  echo "   ✓ SOURCE section modified"
else
  echo "   ✗ Syntax error in SOURCE section!"
  # Try to restore
  cp "${SCRIPT_FILE}.backup-"* "$SCRIPT_FILE" 2>/dev/null || true
  exit 1
fi

# =============================================================================
# 3. Add backup creation call after lock acquisition
# =============================================================================
echo "3. Adding backup creation at startup..."

# Find "Lock acquired" line and add backup call after it
sed -i '/ok "Lock acquired (PID: \$\$)"/a\
\
# Create startup backup for downgrade protection\
create_startup_backup' "$SCRIPT_FILE"

if bash -n "$SCRIPT_FILE"; then
  echo "   ✓ Startup backup call added"
else
  echo "   ✗ Syntax error adding backup call!"
  exit 1
fi

# =============================================================================
# 4. Bump version
# =============================================================================
echo "4. Bumping version to 6.1.0..."

sed -i 's/VERSION="6\.0\.[0-9]*"/VERSION="6.1.0"/g' "$SCRIPT_FILE"

# Final check
if bash -n "$SCRIPT_FILE"; then
  echo ""
  echo "=== PATCH COMPLETE ==="
  grep "VERSION=" "$SCRIPT_FILE" | head -3
else
  echo "=== PATCH FAILED - RESTORING BACKUP ==="
  cp "${SCRIPT_FILE}.backup-"*".sh" "$SCRIPT_FILE" 2>/dev/null || true
  exit 1
fi
