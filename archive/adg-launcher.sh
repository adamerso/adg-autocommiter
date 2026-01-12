#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# ADG LAUNCHER v1.0.0
# ═══════════════════════════════════════════════════════════════════
# Lightweight launcher that:
# 1. Downloads latest autocommiter_live.sh from adamerso/adg-autocommiter
# 2. Compares versions (never downgrades!)
# 3. Runs the autocommiter
#
# Usage: Just run this script from any subdirectory of your repo!
# ═══════════════════════════════════════════════════════════════════

set -u

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
LAUNCHER_VERSION="1.0.0"
REMOTE_REPO="adamerso/adg-autocommiter"
REMOTE_BRANCH="main"
REMOTE_SCRIPT="autocommiter_live.sh"
REMOTE_VERSION_FILE="VERSION"

# Where to cache the downloaded script (in .git folder - ignored by git)
CACHE_DIR=""
CACHED_SCRIPT=""

# ═══════════════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════════════
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RED="\033[91m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"
C_MAGENTA="\033[95m"
C_PINK="\033[38;5;213m"

# ═══════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════
_ts() { date +%H:%M:%S; }
log()  { printf "%b[%s]%b %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$*"; }
info() { printf "%b[%s]%b %bINFO%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_CYAN" "$C_RESET" "$*"; }
ok()   { printf "%b[%s]%b %bOK%b    %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%b[%s]%b %bWARN%b  %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%b[%s]%b %bERR%b   %s\n" "$C_DIM" "$(_ts)" "$C_RESET" "$C_RED" "$C_RESET" "$*"; }
die()  { err "$*"; exit 1; }

# ═══════════════════════════════════════════════════════════════════
# VERSION COMPARE - returns: 0=equal, 1=v1>v2, 2=v1<v2
# ═══════════════════════════════════════════════════════════════════
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
    
    # Extract numeric part
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

# ═══════════════════════════════════════════════════════════════════
# EXTRACT VERSION FROM SCRIPT
# ═══════════════════════════════════════════════════════════════════
extract_version() {
  local file="$1"
  if [[ -f "$file" ]]; then
    grep -m1 '^[[:space:]]*VERSION=' "$file" 2>/dev/null | cut -d'"' -f2 | head -1
  else
    echo ""
  fi
}

# ═══════════════════════════════════════════════════════════════════
# FIND GIT ROOT
# ═══════════════════════════════════════════════════════════════════
find_git_root() {
  local dir="${1:-$(pwd)}"
  local max_depth=20
  local depth=0
  
  while [[ $depth -lt $max_depth ]]; do
    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    
    local parent=$(dirname "$dir")
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
    depth=$((depth + 1))
  done
  
  return 1
}

# ═══════════════════════════════════════════════════════════════════
# DOWNLOAD FILE FROM GITHUB RAW
# ═══════════════════════════════════════════════════════════════════
download_from_github() {
  local repo="$1"
  local branch="$2"
  local file="$3"
  local output="$4"
  
  local url="https://raw.githubusercontent.com/${repo}/${branch}/${file}"
  
  log "Downloading: $url"
  
  if command -v curl &>/dev/null; then
    curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output" 2>/dev/null
    return $?
  elif command -v wget &>/dev/null; then
    wget -q --timeout=60 "$url" -O "$output" 2>/dev/null
    return $?
  else
    err "Neither curl nor wget available!"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# CHECK AND UPDATE AUTOCOMMITER
# ═══════════════════════════════════════════════════════════════════
update_autocommiter() {
  info "🔍 Checking for updates from $REMOTE_REPO..."
  
  # Download VERSION file first (small, quick check)
  local tmp_version=$(mktemp)
  if download_from_github "$REMOTE_REPO" "$REMOTE_BRANCH" "$REMOTE_VERSION_FILE" "$tmp_version"; then
    local remote_version=$(cat "$tmp_version" 2>/dev/null | tr -d '[:space:]')
    rm -f "$tmp_version"
    
    if [[ -z "$remote_version" ]]; then
      warn "Could not read remote version, downloading full script..."
    else
      info "Remote version: $remote_version"
      
      # Check local version
      local local_version=""
      if [[ -f "$CACHED_SCRIPT" ]]; then
        local_version=$(extract_version "$CACHED_SCRIPT")
        info "Local version:  $local_version"
        
        # Compare versions
        version_compare "$local_version" "$remote_version"
        local cmp=$?
        
        if [[ $cmp -eq 1 ]]; then
          # Local > Remote = Local is NEWER (maybe dev version)
          warn "🛡️ Local version ($local_version) is NEWER than remote ($remote_version)"
          warn "   Keeping local version (downgrade protection)"
          return 0
        elif [[ $cmp -eq 0 ]]; then
          ok "✓ Already up to date (v$local_version)"
          return 0
        else
          info "📥 Update available: $local_version → $remote_version"
        fi
      else
        info "No local cache, downloading..."
      fi
    fi
  else
    rm -f "$tmp_version"
    warn "Could not check remote version, trying full download..."
  fi
  
  # Download full script
  local tmp_script=$(mktemp)
  if download_from_github "$REMOTE_REPO" "$REMOTE_BRANCH" "$REMOTE_SCRIPT" "$tmp_script"; then
    # Verify it's a valid script
    if ! head -1 "$tmp_script" | grep -q "^#!"; then
      err "Downloaded file doesn't look like a valid script!"
      rm -f "$tmp_script"
      return 1
    fi
    
    local new_version=$(extract_version "$tmp_script")
    
    # Final version check before replacing
    if [[ -f "$CACHED_SCRIPT" ]]; then
      local old_version=$(extract_version "$CACHED_SCRIPT")
      
      if [[ -n "$old_version" ]] && [[ -n "$new_version" ]]; then
        version_compare "$old_version" "$new_version"
        if [[ $? -eq 1 ]]; then
          warn "🛡️ Downgrade blocked: $old_version > $new_version"
          rm -f "$tmp_script"
          return 0
        fi
      fi
    fi
    
    # All checks passed - update!
    mv "$tmp_script" "$CACHED_SCRIPT"
    chmod +x "$CACHED_SCRIPT"
    ok "✅ Updated to v$new_version"
    return 0
  else
    rm -f "$tmp_script"
    warn "Download failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# SELF-UPDATE LAUNCHER
# ═══════════════════════════════════════════════════════════════════
update_launcher() {
  local launcher_file="$1"
  
  info "🔍 Checking launcher updates..."
  
  local tmp_launcher=$(mktemp)
  if download_from_github "$REMOTE_REPO" "$REMOTE_BRANCH" "launcher.sh" "$tmp_launcher"; then
    local remote_launcher_version=$(grep -m1 '^LAUNCHER_VERSION=' "$tmp_launcher" 2>/dev/null | cut -d'"' -f2)
    
    if [[ -n "$remote_launcher_version" ]]; then
      version_compare "$LAUNCHER_VERSION" "$remote_launcher_version"
      local cmp=$?
      
      if [[ $cmp -eq 2 ]]; then
        # Remote is newer
        info "📥 Launcher update: $LAUNCHER_VERSION → $remote_launcher_version"
        mv "$tmp_launcher" "$launcher_file"
        chmod +x "$launcher_file"
        ok "✅ Launcher updated! Please restart."
        exit 0
      elif [[ $cmp -eq 1 ]]; then
        log "Launcher: local ($LAUNCHER_VERSION) > remote ($remote_launcher_version), keeping local"
      else
        log "Launcher: up to date (v$LAUNCHER_VERSION)"
      fi
    fi
  fi
  rm -f "$tmp_launcher" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════
main() {
  printf "\n"
  printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$C_PINK" "$C_RESET"
  printf "%b║%b     %b🚀 ADG LAUNCHER v%s%b                                    %b║%b\n" "$C_PINK" "$C_RESET" "$C_BOLD" "$LAUNCHER_VERSION" "$C_RESET" "$C_PINK" "$C_RESET"
  printf "%b║%b     Remote: %s                            %b║%b\n" "$C_PINK" "$C_RESET" "$REMOTE_REPO" "$C_PINK" "$C_RESET"
  printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$C_PINK" "$C_RESET"
  printf "\n"
  
  # Find git root
  local git_root=$(find_git_root)
  if [[ -z "$git_root" ]]; then
    die "Not in a git repository!"
  fi
  
  info "Git root: $git_root"
  
  # Setup cache directory
  CACHE_DIR="$git_root/.git/adg-autocommiter"
  CACHED_SCRIPT="$CACHE_DIR/autocommiter_live.sh"
  
  mkdir -p "$CACHE_DIR"
  
  # Get this script's path for self-update
  local this_script="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
  
  # Self-update launcher (optional - can be disabled)
  # update_launcher "$this_script"
  
  # Update autocommiter
  if ! update_autocommiter; then
    if [[ ! -f "$CACHED_SCRIPT" ]]; then
      die "No cached script and download failed!"
    fi
    warn "Using cached version"
  fi
  
  # Verify script exists
  if [[ ! -f "$CACHED_SCRIPT" ]]; then
    die "Autocommiter script not found!"
  fi
  
  # Show what we're running
  local running_version=$(extract_version "$CACHED_SCRIPT")
  ok "🎯 Launching autocommiter v$running_version"
  printf "\n"
  
  # Change to git root before running
  cd "$git_root"
  
  # Run the autocommiter!
  exec bash "$CACHED_SCRIPT" "$@"
}

# Run!
main "$@"
