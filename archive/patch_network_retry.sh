#!/bin/bash
# Patch script to update network_retry function

SCRIPT_FILE="D:/instant_run/CODE/adasio_and_martusia/adasio_and_martusia/adasio/scripts/adg-autocommiter/adg-auto-commiter-UpNext.sh"

# Create new network_retry function
NEW_FUNC='network_retry() {
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

      # Get git root directory
      local git_root=$($GIT rev-parse --show-toplevel 2>/dev/null)

      # Extract blocking file paths from git output
      local blocking_files=$(echo "$git_output" | awk '"'"'/untracked working tree files would be overwritten/,/Please move or remove/ {
        if (/^\t/) { gsub(/^\t/, ""); print }
      }'"'"')

      if [[ -n "$blocking_files" ]]; then
        echo "$blocking_files" | while read -r file; do
          if [[ -n "$file" ]]; then
            local full_path="$git_root/$file"
            if [[ -f "$full_path" ]]; then
              # Move to backup instead of deleting
              local backup_dir="$git_root/.git/backup-untracked"
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
}'

# Find line numbers
START_LINE=$(grep -n "^network_retry() {" "$SCRIPT_FILE" | cut -d: -f1)
END_LINE=$(awk "NR>$START_LINE && /^# ═+$/ && getline && /GIT REMOTE DETECTION/ {print NR-1; exit}" "$SCRIPT_FILE")

if [[ -z "$START_LINE" ]]; then
  echo "ERROR: Could not find network_retry function start"
  exit 1
fi

# Find the closing brace of network_retry
END_LINE=$(awk -v start="$START_LINE" '
  NR >= start {
    if (/^}$/) { print NR; exit }
  }
' "$SCRIPT_FILE")

echo "Replacing lines $START_LINE to $END_LINE"

# Create new file with replacement
head -n $((START_LINE - 1)) "$SCRIPT_FILE" > /tmp/patched_script.sh
echo "$NEW_FUNC" >> /tmp/patched_script.sh
tail -n +$((END_LINE + 1)) "$SCRIPT_FILE" >> /tmp/patched_script.sh

# Verify and replace
if bash -n /tmp/patched_script.sh; then
  cp /tmp/patched_script.sh "$SCRIPT_FILE"
  echo "SUCCESS! network_retry patched"
else
  echo "ERROR: Syntax check failed!"
  exit 1
fi
