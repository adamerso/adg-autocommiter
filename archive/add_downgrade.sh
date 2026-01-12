#!/bin/bash
# Add downgrade protection after SHA CHANGED banner

FILE="D:/instant_run/CODE/adasio_and_martusia/adasio_and_martusia/adasio/scripts/adg-autocommiter/adg-auto-commiter-UpNext.sh"

# Find line with WILL_RELOAD=true after SHA changed
LINE=$(grep -n "WILL_RELOAD=true" "$FILE" | head -1 | cut -d: -f1)

if [[ -z "$LINE" ]]; then
  echo "ERROR: WILL_RELOAD=true not found"
  exit 1
fi

echo "Found WILL_RELOAD=true at line $LINE"

# Create protection code
PROTECTION='      
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
'

# Build new file by inserting before WILL_RELOAD=true
{
  head -n $((LINE - 1)) "$FILE"
  echo "$PROTECTION"
  echo "      WILL_RELOAD=true"
  tail -n +$((LINE + 1)) "$FILE"
} > /tmp/patched_downgrade.sh

if bash -n /tmp/patched_downgrade.sh; then
  cp /tmp/patched_downgrade.sh "$FILE"
  echo "SUCCESS! Downgrade protection added before line $LINE"
else
  echo "ERROR: Syntax check failed!"
  bash -n /tmp/patched_downgrade.sh
  exit 1
fi
