#!/bin/bash
set -u

# =======================
# AUTO-COMMITER 4.2.21  ♥ I<3U ♥
# =======================
# Self-reload via source: zmienne aktualizowane bez restartu
# Full exec reload: tylko gdy SHA skryptu się zmieni
# =======================

# HARDCODED SCRIPT PATH (for source detection)
SCRIPT_FILE="${SCRIPT_FILE:-$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")}"

#### ========================================================
#### IF SCRIPT IS SOURCED - RELOAD VARIABLES ONLY
#### ========================================================
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then

  # --- GUARD: Tylko jeśli skrypt już działa (IS_RUNNING=true) ---
  # Zapobiega przypadkowemu zatruwaniu środowiska przez `source`
  if [[ "${IS_RUNNING:-false}" != "true" ]]; then
    echo "[source] ⛔ Skrypt nie jest uruchomiony (IS_RUNNING!=true). Ignoruję source."
    echo "[source] Aby uruchomić: ./auto-commiter4.sh"
    return 0 2>/dev/null || exit 0
  fi

  # --- CONFIGURABLE VARIABLES (edit these to hot-reload) ---
  VERSION="4.2.21"
  COMMIT_TIMEOUT=180       # 3 minuty
  CHECK_EVERY=15           # sprawdzanie lokalnych zmian
  PULL_EVERY=300           # pull co 5 minut
  SELF_CHECK_EVERY=50      # source self co N cykli
  MAX_FILE_SIZE_MB=99
  MAX_FILE_SIZE_BYTES=$((MAX_FILE_SIZE_MB * 1024 * 1024))
  
  # --- SHA CHECK: czy plik się zmienił strukturalnie? ---
  SHA_SCRIPT_CURRENT="$(/usr/bin/sha1sum "$SCRIPT_FILE" 2>/dev/null | /usr/bin/awk '{print $1}')"
  
  # Jeśli SHA_SCRIPT_ORIGINAL nie istnieje = coś poszło nie tak
  if [[ -z "${SHA_SCRIPT_ORIGINAL:-}" ]]; then
    echo "[source] ⚠️ SHA_SCRIPT_ORIGINAL nie ustawione - pomijam"
    return 0
  fi
  
  # Porównaj SHA - jeśli się zmienił, pełny reload
  if [[ "$SHA_SCRIPT_CURRENT" != "$SHA_SCRIPT_ORIGINAL" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🔄 SCRIPT SHA CHANGED - FULL RELOAD!                        ║"
    echo "║  Old: ${SHA_SCRIPT_ORIGINAL:0:20}...                         ║"
    echo "║  New: ${SHA_SCRIPT_CURRENT:0:20}...                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Release lock before exec
    /usr/bin/flock -u 200 2>/dev/null || true
    
    # Full restart
    IS_RUNNING=false
    exec "$SCRIPT_FILE" "$@"
    exit 1  # fallback if exec fails
  fi
  
  # SHA unchanged - just variables reloaded
  echo "[source] ✅ Variables reloaded (v$VERSION) | PULL:${PULL_EVERY}s CHECK:${CHECK_EVERY}s TIMEOUT:${COMMIT_TIMEOUT}s"
  return 0

#### ========================================================  
#### ELSE - NORMAL SCRIPT EXECUTION (first run)
#### ========================================================
else

# --- MARK AS RUNNING (guard for source) ---
IS_RUNNING=true
export IS_RUNNING

# --- INITIAL SOURCE: załaduj zmienne z sekcji source ---
# To ustawi VERSION, COMMIT_TIMEOUT, etc. z jednego miejsca
source "$SCRIPT_FILE" 2>/dev/null || true

# --- SHA na start (przed source będzie puste, więc oblicz) ---
SHA_SCRIPT_ORIGINAL="${SHA_SCRIPT_ORIGINAL:-$(/usr/bin/sha1sum "$SCRIPT_FILE" 2>/dev/null | /usr/bin/awk '{print $1}')}"

# =======================
# AUTO-COMMITER 4.2.21  ♥ I<3U ♥
# =======================
# Funkcje:
# - Blokada plików >99MB (auto-dodaje do .gitignore)
# - Sprawdzanie rozmiaru staged files PRZED commit
# - Wykrywanie i podsumowanie zmian
# - 3-minutowy timeout przed auto-commit
# - Pull w trakcie timeoutu (bez blokowania)
# - Merge wszystkiego (jeden branch - CLOUD EXPERIENCE!)
# - FORCE main branch - brak splitów, brak divergence
# - Self-reload przez source (hot-reload zmiennych)
# - [y] = commit NOW z auto-message
# - [m] = wpisz własny message
# - Statystyki sesji (commits, merges, files, lines)
# =======================

# --- SCRIPT INFO ---
SCRIPT_NAME="auto-commiter4"

# =======================
# config (defaults - source may override)
# =======================
GIT="/usr/bin/git"
LOCKFILE="/tmp/autogit4.lock"

# These should be set by source, but provide defaults
PULL_EVERY="${PULL_EVERY:-300}"           # 5 min default
CHECK_EVERY="${CHECK_EVERY:-15}"          # 15s default
COMMIT_TIMEOUT="${COMMIT_TIMEOUT:-180}"   # 3 min default
MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB:-99}"
MAX_FILE_SIZE_BYTES=$((MAX_FILE_SIZE_MB * 1024 * 1024))
SELF_CHECK_EVERY="${SELF_CHECK_EVERY:-50}" # source self co N cykli

USER_NAME="${USER:-unknown}"
HOST_NAME="$(/bin/hostname)"
DATE_FMT_COMMIT="%y%m%d %H%M"

# =======================
# state variables (persist across source)
# =======================
CHANGES_DETECTED_AT="${CHANGES_DETECTED_AT:-0}"
PENDING_COMMIT="${PENDING_COMMIT:-false}"
CYCLE_COUNT="${CYCLE_COUNT:-0}"

# =======================
# SESSION STATISTICS (persist across source)
# =======================
SESSION_START="${SESSION_START:-$(/usr/bin/date +%s)}"
STAT_COMMITS="${STAT_COMMITS:-0}"
STAT_MERGES="${STAT_MERGES:-0}"
STAT_FILES="${STAT_FILES:-0}"
STAT_LINES_ADDED="${STAT_LINES_ADDED:-0}"
STAT_LINES_REMOVED="${STAT_LINES_REMOVED:-0}"

# =======================
# no-interactive git
# =======================
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
export SSH_ASKPASS=/bin/false
export GIT_EDITOR=/bin/true

# =======================
# colors + logging (pink -> orange -> red theme)
# =======================
c_reset="\033[0m"
c_dim="\033[2m"
c_red="\033[91m"        # bright red
c_green="\033[32m"
c_yellow="\033[33m"
c_blue="\033[34m"
c_magenta="\033[95m"    # bright magenta/pink
c_cyan="\033[36m"
c_bold="\033[1m"
c_pink="\033[38;5;213m"   # pink
c_orange="\033[38;5;208m" # orange
c_hotpink="\033[38;5;199m" # hot pink
c_heart="\033[38;5;197m"  # heart red/pink

ts() { /usr/bin/date +%H:%M:%S; }

# =======================
# session stats display
# =======================
show_session_stats() {
  local now=$(/usr/bin/date +%s)
  local elapsed=$((now - SESSION_START))
  local mins=$((elapsed / 60))
  local secs=$((elapsed % 60))
  /usr/bin/printf "%b[%s %s v%s]%b 📊 Session: %dm%ds | Commits:%d Merges:%d Files:%d Lines:+%d/-%d\n" \
    "$c_pink" "$SCRIPT_NAME" "$VERSION" "$(ts)" "$c_reset" \
    "$mins" "$secs" "$STAT_COMMITS" "$STAT_MERGES" "$STAT_FILES" "$STAT_LINES_ADDED" "$STAT_LINES_REMOVED"
}

log()     { /usr/bin/printf "%b[%s]%b %s\n" "$c_dim" "$(ts)" "$c_reset" "$*"; }
info()    { /usr/bin/printf "%b[%s]%b %bINFO%b  %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_cyan" "$c_reset" "$*"; }
ok()      { /usr/bin/printf "%b[%s]%b %bOK%b    %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_green" "$c_reset" "$*"; }
warn()    { /usr/bin/printf "%b[%s]%b %bWARN%b  %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_yellow" "$c_reset" "$*"; }
err()     { /usr/bin/printf "%b[%s]%b %bERR%b   %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_red" "$c_reset" "$*"; }
pending() { /usr/bin/printf "%b[%s]%b %bPEND%b  %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_magenta" "$c_reset" "$*"; }

die() { err "$*"; exit 1; }

# =======================
# flock lock (kill-safe) + heartbeat timestamp
# =======================
exec 200>"$LOCKFILE" || die "Nie mogę otworzyć lockfile: $LOCKFILE"

/usr/bin/flock -n 200 || {
  err "Już działa inna instancja (lock: $LOCKFILE). Oto zawartość lockfile:"
  /usr/bin/cat "$LOCKFILE" 2>/dev/null || true
  exit 0
}

heartbeat() {
  /usr/bin/printf "pid=%s host=%s user=%s last_seen_epoch=%s last_seen_iso=%s\n" \
    "$$" "$HOST_NAME" "$USER_NAME" "$(/usr/bin/date +%s)" "$(/usr/bin/date -Is)" \
    > "$LOCKFILE"
}

heartbeat

# =======================
# SELF-RELOAD VIA SOURCE
# =======================
# Hot-reload: source skrypt aby zaktualizować zmienne
# Full reload: exec jeśli SHA się zmieniło (obsługiwane w sekcji source)
# =======================
check_self_reload() {
  info "♻️  Source self for variable reload..."
  
  # Source the script - this will:
  # 1. Check IS_RUNNING guard (must be true)
  # 2. Update variables (VERSION, COMMIT_TIMEOUT, etc.)
  # 3. Check SHA - if changed, exec full restart
  # 4. Return if SHA unchanged
  if source "$SCRIPT_FILE"; then
    ok "Hot-reload OK: v$VERSION | PULL:${PULL_EVERY}s CHECK:${CHECK_EVERY}s COMMIT:${COMMIT_TIMEOUT}s"
  else
    warn "Source failed - continuing with current config"
  fi
}

# =======================
# sanity
# =======================
$GIT rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Odpal skrypt w katalogu repo Git."

# =======================
# setup GitHub authentication (SSH)
# =======================
setup_git_auth() {
  local current_url
  current_url=$($GIT remote get-url origin 2>/dev/null || echo "")
  
  # Check if already using SSH
  if [[ "$current_url" == git@github.com:* ]]; then
    ok "Git remote już używa SSH: $current_url"
    return 0
  fi
  
  # Check if using HTTPS
  if [[ "$current_url" == https://github.com/* ]]; then
    warn "Git remote używa HTTPS - może wymagać autoryzacji"
    
    # Extract user/repo from HTTPS URL
    local repo_path
    repo_path=$(echo "$current_url" | /usr/bin/sed 's|https://github.com/||' | /usr/bin/sed 's|\.git$||')
    
    /usr/bin/printf "\n%b╔══════════════════════════════════════════════════════════════╗%b\n" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  🔐 KONFIGURACJA AUTORYZACJI GIT                             %b║%b\n" "$c_yellow" "$c_reset" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  Aktualny remote: %-40s %b║%b\n" "$c_yellow" "$c_reset" "$current_url" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  Wykryto repo:    %-40s %b║%b\n" "$c_yellow" "$c_reset" "$repo_path" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  Czy zmienić na SSH? (wymaga klucza SSH w GitHub)            %b║%b\n" "$c_yellow" "$c_reset" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b                                                              %b║%b\n" "$c_yellow" "$c_reset" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  %b[y]%b = Tak, zmień na SSH (git@github.com:...)               %b║%b\n" "$c_yellow" "$c_reset" "$c_green" "$c_reset" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  %b[n]%b = Nie, zostaw HTTPS (może pytać o hasło)               %b║%b\n" "$c_yellow" "$c_reset" "$c_red" "$c_reset" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b║%b  %b[c]%b = Podaj własny URL                                     %b║%b\n" "$c_yellow" "$c_reset" "$c_cyan" "$c_reset" "$c_yellow" "$c_reset"
    /usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n" "$c_yellow" "$c_reset"
    
    /usr/bin/printf "\nTwój wybór [y/n/c]: "
    read -r choice
    
    case "$choice" in
      y|Y)
        local ssh_url="git@github.com:${repo_path}.git"
        info "Zmieniam remote na SSH: $ssh_url"
        if $GIT remote set-url origin "$ssh_url"; then
          ok "Remote zmieniony na SSH!"
          
          # Test SSH connection
          info "Testuję połączenie SSH z GitHub..."
          if ssh -T git@github.com 2>&1 | /usr/bin/grep -q "successfully authenticated"; then
            ok "SSH działa poprawnie!"
          else
            warn "SSH może nie być skonfigurowany. Sprawdź klucz SSH w GitHub."
            /usr/bin/printf "\n%bAby dodać klucz SSH:%b\n" "$c_cyan" "$c_reset"
            /usr/bin/printf "  1. ssh-keygen -t ed25519 -C \"your_email@example.com\"\n"
            /usr/bin/printf "  2. cat ~/.ssh/id_ed25519.pub\n"
            /usr/bin/printf "  3. Dodaj klucz na: https://github.com/settings/keys\n\n"
          fi
        else
          err "Nie udało się zmienić remote!"
        fi
        ;;
      c|C)
        /usr/bin/printf "Podaj pełny URL remote (np. git@github.com:user/repo.git): "
        read -r custom_url
        if [[ -n "$custom_url" ]]; then
          if $GIT remote set-url origin "$custom_url"; then
            ok "Remote zmieniony na: $custom_url"
          else
            err "Nie udało się zmienić remote!"
          fi
        fi
        ;;
      *)
        info "Zostawiam HTTPS. Pull/push może wymagać autoryzacji."
        ;;
    esac
    
    return 0
  fi
  
  # No remote or unknown format
  if [[ -z "$current_url" ]]; then
    warn "Brak skonfigurowanego remote 'origin'!"
    
    /usr/bin/printf "\n%bPodaj URL repozytorium GitHub:%b\n" "$c_yellow" "$c_reset"
    /usr/bin/printf "  Format SSH:   git@github.com:user/repo.git\n"
    /usr/bin/printf "  Format HTTPS: https://github.com/user/repo.git\n"
    /usr/bin/printf "\nURL: "
    read -r new_url
    
    if [[ -n "$new_url" ]]; then
      if $GIT remote add origin "$new_url"; then
        ok "Dodano remote origin: $new_url"
      else
        err "Nie udało się dodać remote!"
      fi
    else
      warn "Brak URL - pull/push nie będzie działać!"
    fi
  fi
  
  return 0
}

# Run auth setup
setup_git_auth

# =======================
# check for large files (>99MB) - auto-add to .gitignore
# =======================
check_large_files() {
  local large_files
  large_files=$(/usr/bin/find . -type f -size +${MAX_FILE_SIZE_MB}M 2>/dev/null | /usr/bin/grep -v "^./.git/" || true)
  
  if [[ -z "$large_files" ]]; then
    return 0
  fi
  
  local new_files_found=false
  local files_to_add=""
  
  # First pass: check which files need to be added
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local clean_path="${f#./}"
    
    # Check if already in .gitignore
    if ! /usr/bin/grep -qxF "$clean_path" .gitignore 2>/dev/null; then
      new_files_found=true
      files_to_add+="$f"$'\n'
    fi
  done <<< "$large_files"
  
  # Only show warning if there are NEW large files to add
  if [[ "$new_files_found" == true ]]; then
    warn "═══════════════════════════════════════════════════════════════"
    warn "Wykryto NOWE pliki większe niż ${MAX_FILE_SIZE_MB}MB:"
    warn "═══════════════════════════════════════════════════════════════"
    
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      local size
      size=$(/usr/bin/du -h "$f" 2>/dev/null | /usr/bin/cut -f1)
      local clean_path="${f#./}"
      
      warn "  $size  $f  → dodaję do .gitignore"
      echo "$clean_path" >> .gitignore
    done <<< "$files_to_add"
    
    warn "═══════════════════════════════════════════════════════════════"
    warn "Duże pliki dodane do .gitignore (nie będą commitowane)"
    warn "═══════════════════════════════════════════════════════════════"
  fi
  
  return 0
}

# =======================
# check STAGED files for size (after git add, before commit)
# This is the critical check - catches files that made it past .gitignore
# =======================
check_staged_large_files() {
  local found_large=false
  local staged_to_remove=()
  
  # Get all staged files with their blob hashes
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    
    local hash=$(echo "$line" | /usr/bin/awk '{print $2}')
    local file=$(echo "$line" | /usr/bin/awk '{print $4}')
    
    # Skip deleted files (hash is all zeros)
    [[ "$hash" == "0000000000000000000000000000000000000000" ]] && continue
    [[ -z "$hash" ]] && continue
    
    # Get blob size
    local size=$($GIT cat-file -s "$hash" 2>/dev/null || echo 0)
    
    if [[ "$size" -gt "$MAX_FILE_SIZE_BYTES" ]]; then
      local size_mb=$((size / 1024 / 1024))
      found_large=true
      staged_to_remove+=("$file")
      
      warn "⚠️  STAGED FILE TOO LARGE: $file (${size_mb}MB > ${MAX_FILE_SIZE_MB}MB)"
    fi
  done < <($GIT ls-files --stage 2>/dev/null)
  
  if [[ "$found_large" == true ]]; then
    warn "═══════════════════════════════════════════════════════════════"
    warn "BLOKADA: Wykryto duże pliki w staging area!"
    warn "Te pliki przekraczają limit GitHub (100MB)"
    warn "═══════════════════════════════════════════════════════════════"
    
    # Auto-fix: remove from staging and add to .gitignore
    for file in "${staged_to_remove[@]}"; do
      local clean_path="${file#./}"
      
      # Add to .gitignore if not already there
      if ! /usr/bin/grep -qxF "$clean_path" .gitignore 2>/dev/null; then
        echo "$clean_path" >> .gitignore
        ok "Dodano do .gitignore: $clean_path"
      fi
      
      # Remove from staging
      if $GIT reset HEAD -- "$file" 2>/dev/null; then
        ok "Usunięto ze staging: $file"
      else
        # Alternative: git rm --cached
        $GIT rm --cached "$file" 2>/dev/null && ok "Usunięto (rm --cached): $file"
      fi
    done
    
    warn "═══════════════════════════════════════════════════════════════"
    warn "Duże pliki usunięte ze staging i dodane do .gitignore"
    warn "═══════════════════════════════════════════════════════════════"
    
    # Re-add .gitignore
    $GIT add .gitignore 2>/dev/null || true
    
    return 1  # Signal that we had to fix something
  fi
  
  return 0
}

# =======================
# helpers: count local changes
# =======================
count_changes() {
  local st
  st="$($GIT status --porcelain)"

  if [[ -z "$st" ]]; then
    echo "0 0 0 0 0"
    return
  fi

  local added modified renamed removed total
  added=$(printf "%s\n" "$st" | /usr/bin/awk '
    $1=="??" {a++}
    $1 ~ /^A/ || $1 ~ /^.A/ {a++}
    END{print a+0}')
  modified=$(printf "%s\n" "$st" | /usr/bin/awk '$1 ~ /^M/ || $1 ~ /^.M/ {m++} END{print m+0}')
  renamed=$(printf "%s\n" "$st" | /usr/bin/awk '$1 ~ /^R/ || $1 ~ /^.R/ {r++} END{print r+0}')
  removed=$(printf "%s\n" "$st" | /usr/bin/awk '$1 ~ /^D/ || $1 ~ /^.D/ {d++} END{print d+0}')
  total=$(printf "%s\n" "$st" | /usr/bin/wc -l | /usr/bin/tr -d ' ')

  echo "$total $added $modified $renamed $removed"
}

# =======================
# display changes summary
# =======================
show_changes_summary() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  
  if [[ "$total" -eq 0 ]]; then
    return 0
  fi
  
  /usr/bin/printf "\n%b╔══════════════════════════════════════════════════════════════╗%b\n" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b║%b           %b📊 PODSUMOWANIE ZMIAN%b                               %b║%b\n" "$c_cyan" "$c_reset" "$c_bold" "$c_reset" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b║%b  %b+%b Dodane:     %-5s                                        %b║%b\n" "$c_cyan" "$c_reset" "$c_green" "$c_reset" "$added" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b║%b  %b~%b Zmienione:  %-5s                                        %b║%b\n" "$c_cyan" "$c_reset" "$c_yellow" "$c_reset" "$modified" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b║%b  %b→%b Renamed:    %-5s                                        %b║%b\n" "$c_cyan" "$c_reset" "$c_blue" "$c_reset" "$renamed" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b║%b  %b-%b Usunięte:   %-5s                                        %b║%b\n" "$c_cyan" "$c_reset" "$c_red" "$c_reset" "$removed" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b║%b  %b=%b RAZEM:      %-5s                                        %b║%b\n" "$c_cyan" "$c_reset" "$c_bold" "$c_reset" "$total" "$c_cyan" "$c_reset"
  /usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$c_cyan" "$c_reset"
  
  # Show file list (top 10)
  local st
  st="$($GIT status --porcelain)"
  local file_count
  file_count=$(echo "$st" | /usr/bin/wc -l)
  
  info "Szczegóły zmian (max 10):"
  echo "$st" | /usr/bin/head -10 | while read -r line; do
    local status="${line:0:2}"
    local file="${line:3}"
    case "$status" in
      "??"|"A "|" A") /usr/bin/printf "  %b+%b %s\n" "$c_green" "$c_reset" "$file" ;;
      "M "|" M"|"MM") /usr/bin/printf "  %b~%b %s\n" "$c_yellow" "$c_reset" "$file" ;;
      "R "|" R")      /usr/bin/printf "  %b→%b %s\n" "$c_blue" "$c_reset" "$file" ;;
      "D "|" D")      /usr/bin/printf "  %b-%b %s\n" "$c_red" "$c_reset" "$file" ;;
      *)              /usr/bin/printf "  %b?%b %s\n" "$c_dim" "$c_reset" "$file" ;;
    esac
  done
  
  if [[ "$file_count" -gt 10 ]]; then
    log "  ... i $(( file_count - 10 )) więcej plików"
  fi
  echo
}

# =======================
# generate auto commit message
# =======================
generate_commit_message() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  echo "autocommit ${USER_NAME}@${HOST_NAME} - $(/usr/bin/date +"$DATE_FMT_COMMIT") - ${added} added, ${modified} modified, ${renamed} renamed, ${removed} removed."
}

# =======================
# count diff lines (added/removed)
# =======================
count_diff_lines() {
  local diff_stat
  diff_stat=$($GIT diff --cached --numstat 2>/dev/null || echo "")
  
  if [[ -z "$diff_stat" ]]; then
    echo "0 0 0"
    return
  fi
  
  local lines_added=0
  local lines_removed=0
  local files_count=0
  
  while IFS=$'\t' read -r added removed file; do
    [[ -z "$added" ]] && continue
    [[ "$added" == "-" ]] && added=0
    [[ "$removed" == "-" ]] && removed=0
    lines_added=$((lines_added + added))
    lines_removed=$((lines_removed + removed))
    files_count=$((files_count + 1))
  done <<< "$diff_stat"
  
  echo "$files_count $lines_added $lines_removed"
}

# =======================
# do actual commit and push
# =======================
do_commit_push() {
  local msg="$1"
  
  # Check for large files in working directory first (auto-adds to .gitignore, doesn't block)
  check_large_files
  
  info "git add -A ..."
  if ! $GIT add -A; then
    warn "git add -A nie poszło. Pomijam commit."
    heartbeat
    return 1
  fi
  heartbeat

  # CRITICAL: Check staged files AFTER git add, BEFORE commit
  # This catches any large files that slipped through
  info "Sprawdzam rozmiar staged files przed commitem..."
  if ! check_staged_large_files; then
    # Large files were found and removed from staging
    # Re-run git add to pick up .gitignore changes
    info "Ponawiam git add po usunięciu dużych plików..."
    $GIT add -A 2>/dev/null || true
    heartbeat
  fi

  # Count diff lines BEFORE commit (for stats)
  local files_count lines_added lines_removed
  read -r files_count lines_added lines_removed < <(count_diff_lines)

  info "git commit ..."
  if $GIT commit -m "$msg" >/dev/null 2>&1; then
    ok "commit OK: $msg"
    # Update session statistics
    STAT_COMMITS=$((STAT_COMMITS + 1))
    STAT_FILES=$((STAT_FILES + files_count))
    STAT_LINES_ADDED=$((STAT_LINES_ADDED + lines_added))
    STAT_LINES_REMOVED=$((STAT_LINES_REMOVED + lines_removed))
    show_session_stats
  else
    warn "commit pominięty (brak zmian do commitu)."
    heartbeat
    PENDING_COMMIT=false
    CHANGES_DETECTED_AT=0
    return 0
  fi
  heartbeat

  info "git push ..."
  if $GIT push; then
    ok "push OK"
  else
    warn "push nieudany (remote reject? konflikt?)."
    
    # Try force push to prevent divergence (CLOUD EXPERIENCE!)
    warn "Próbuję force-push z lease aby uniknąć rozgałęzień..."
    if $GIT push --force-with-lease; then
      ok "force-push OK - synchronizacja przywrócona!"
    else
      # Check if it's a large file error
      local push_output
      push_output=$($GIT push 2>&1 || true)
      if echo "$push_output" | /usr/bin/grep -qi "large\|100.*MB\|exceeded"; then
        err "═══════════════════════════════════════════════════════════════"
        err "PUSH FAILED: Wykryto duży plik w historii gita!"
        err "Uruchom: ./git-clean-large-files.sh"
        err "═══════════════════════════════════════════════════════════════"
      fi
    fi
    
    heartbeat
    return 1
  fi
  
  # Reset state after successful commit
  PENDING_COMMIT=false
  CHANGES_DETECTED_AT=0
  heartbeat
  return 0
}

# =======================
# check for user input (non-blocking)
# =======================
check_user_input() {
  local key
  if read -t 0.1 -n 1 key 2>/dev/null; then
    case "$key" in
      y|Y)
        /usr/bin/printf "\n%b[!] Commit NOW z auto-message...%b\n" "$c_green" "$c_reset"
        local msg
        msg=$(generate_commit_message)
        do_commit_push "$msg"
        return 0
        ;;
      m|M)
        /usr/bin/printf "\n%b[!] Wpisz message dla commitu:%b " "$c_yellow" "$c_reset"
        local custom_msg
        read -r custom_msg
        if [[ -n "$custom_msg" ]]; then
          do_commit_push "$custom_msg"
        else
          warn "Pusty message - commit anulowany."
        fi
        return 0
        ;;
    esac
  fi
  return 1
}

# =======================
# handle pending commit with timeout
# =======================
handle_pending_commit() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)
  
  if [[ "$total" -eq 0 ]]; then
    if [[ "$PENDING_COMMIT" == true ]]; then
      log "Zmiany zniknęły (reset/checkout?). Anuluję pending commit."
      PENDING_COMMIT=false
      CHANGES_DETECTED_AT=0
    fi
    return 0
  fi
  
  # Check for large files (auto-adds to .gitignore)
  check_large_files
  
  local now
  now=$(/usr/bin/date +%s)
  
  # First detection of changes
  if [[ "$PENDING_COMMIT" == false ]]; then
    PENDING_COMMIT=true
    CHANGES_DETECTED_AT=$now
    
    show_changes_summary
    
    local commit_at=$((CHANGES_DETECTED_AT + COMMIT_TIMEOUT))
    local commit_time
    commit_time=$(/usr/bin/date -d "@$commit_at" +%H:%M:%S 2>/dev/null || /usr/bin/date -r "$commit_at" +%H:%M:%S 2>/dev/null || echo "za 3 min")
    
    /usr/bin/printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$c_pink" "$c_reset"
    /usr/bin/printf "%b║%b  ⏱️  Auto-commit za 3 minuty (o %s)                    %b║%b\n" "$c_pink" "$c_reset" "$commit_time" "$c_pink" "$c_reset"
    /usr/bin/printf "%b║%b                                                              %b║%b\n" "$c_orange" "$c_reset" "$c_orange" "$c_reset"
    /usr/bin/printf "%b║%b  %b[y]%b = commit NOW z auto-message                            %b║%b\n" "$c_orange" "$c_reset" "$c_hotpink" "$c_reset" "$c_orange" "$c_reset"
    /usr/bin/printf "%b║%b  %b[m]%b = wpisz własny message                                 %b║%b\n" "$c_orange" "$c_reset" "$c_heart" "$c_reset" "$c_orange" "$c_reset"
    /usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$c_red" "$c_reset"
    
    pending "Wykryto zmiany. Timeout rozpoczęty. Naciśnij [y] lub [m]..."
    return 0
  fi
  
  # Check if timeout expired
  local elapsed=$((now - CHANGES_DETECTED_AT))
  local remaining=$((COMMIT_TIMEOUT - elapsed))
  
  if [[ "$remaining" -le 0 ]]; then
    info "⏰ Timeout wygasł! Wykonuję auto-commit..."
    local msg
    msg=$(generate_commit_message)
    do_commit_push "$msg"
    return 0
  fi
  
  # Show remaining time every 60 seconds
  if [[ $((elapsed % 60)) -eq 0 ]] && [[ "$elapsed" -gt 0 ]]; then
    local mins=$((remaining / 60))
    local secs=$((remaining % 60))
    pending "Do auto-commit: ${mins}m ${secs}s | Naciśnij [y] commit now, [m] własny message"
  fi
  
  return 0
}

# =======================
# do pull with ours strategy + anti-divergence (CLOUD EXPERIENCE!)
# =======================
do_pull_ours() {
  info "git pull (merge preferuje NASZE: -X ours)..."
  heartbeat

  # First, ensure we're on main branch
  local current_branch
  current_branch=$($GIT rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  
  if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
    warn "Nie jesteś na main/master! Przełączam na main..."
    $GIT checkout main 2>/dev/null || $GIT checkout master 2>/dev/null || {
      warn "Nie mogę przełączyć na main/master. Tworzę main..."
      $GIT checkout -b main 2>/dev/null || true
    }
  fi

  # Fetch first to check for divergence
  $GIT fetch origin 2>/dev/null || true
  
  # Check if we have diverged
  local local_head remote_head base
  local_head=$($GIT rev-parse HEAD 2>/dev/null || echo "")
  remote_head=$($GIT rev-parse origin/main 2>/dev/null || $GIT rev-parse origin/master 2>/dev/null || echo "")
  
  if [[ -n "$local_head" ]] && [[ -n "$remote_head" ]] && [[ "$local_head" != "$remote_head" ]]; then
    base=$($GIT merge-base "$local_head" "$remote_head" 2>/dev/null || echo "")
    
    # Check if branches have diverged (neither is ancestor of the other)
    if [[ -n "$base" ]] && [[ "$base" != "$local_head" ]] && [[ "$base" != "$remote_head" ]]; then
      warn "⚠️ Wykryto DIVERGENCE! Naprawiam - CLOUD EXPERIENCE!"
      
      # Save local changes
      $GIT stash push -m "auto-stash-before-reset" 2>/dev/null || true
      
      # Reset to remote - accept remote as truth, then apply our changes on top
      info "Reset do origin/main + merge naszych zmian..."
      
      if $GIT pull --no-rebase -X ours --no-edit 2>/dev/null; then
        ok "Pull merge OK"
        STAT_MERGES=$((STAT_MERGES + 1))
      else
        # More aggressive: reset hard and re-apply
        warn "Pull merge failed. Używam strategii reset + re-apply..."
        $GIT merge --abort 2>/dev/null || true
        
        # Keep a backup of our changes
        local backup_branch="backup-$(date +%s)"
        $GIT branch "$backup_branch" 2>/dev/null || true
        
        # Reset to remote
        $GIT reset --hard origin/main 2>/dev/null || $GIT reset --hard origin/master 2>/dev/null || true
        
        # Re-apply stash
        $GIT stash pop 2>/dev/null || true
        
        ok "Reset + re-apply wykonany. Backup: $backup_branch"
        STAT_MERGES=$((STAT_MERGES + 1))
      fi
      
      heartbeat
      show_session_stats
      return 0
    fi
  fi

  # Normal pull
  if $GIT pull --no-rebase -X ours --no-edit; then
    ok "pull OK"
    
    # Check if merge happened
    local pull_result=$?
    if [[ $pull_result -eq 0 ]]; then
      # Check if it was a merge (not just fast-forward)
      local merge_head
      merge_head=$($GIT rev-parse MERGE_HEAD 2>/dev/null || echo "")
      if [[ -n "$merge_head" ]] || $GIT log -1 --pretty=%B 2>/dev/null | /usr/bin/grep -q "Merge"; then
        STAT_MERGES=$((STAT_MERGES + 1))
        show_session_stats
      fi
    fi
    
    heartbeat
    return 0
  else
    warn "pull nieudany. Próbuję naprawić..."
    
    # Try to abort any ongoing merge
    $GIT merge --abort 2>/dev/null || true
    
    # More aggressive recovery
    warn "Próbuję fetch + merge z force..."
    $GIT fetch origin 2>/dev/null || true
    
    if $GIT merge -X ours --no-edit origin/main 2>/dev/null || $GIT merge -X ours --no-edit origin/master 2>/dev/null; then
      ok "merge recovery OK"
      STAT_MERGES=$((STAT_MERGES + 1))
      show_session_stats
    else
      # Nuclear option - keep local
      warn "Merge nadal failuje. Zachowuję lokalne zmiany, push nadpisze remote."
      $GIT merge --abort 2>/dev/null || true
    fi
    
    $GIT status -sb || true
    heartbeat
    return 1
  fi
}

# =======================
# main loop
# =======================
last_pull=0
last_check=0

/usr/bin/printf "\n"
/usr/bin/printf "%b╔══════════════════════════════════════════════════════════════╗%b\n" "$c_pink" "$c_reset"
/usr/bin/printf "%b║%b       %b💕 AUTO-COMMITER v%s STARTED%b       %b♥ I<3U ♥%b       %b║%b\n" "$c_pink" "$c_reset" "$c_bold$c_hotpink" "$VERSION" "$c_reset" "$c_heart" "$c_reset" "$c_pink" "$c_reset"
/usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$c_orange" "$c_reset"
/usr/bin/printf "%b║%b  Pull co:          %3ds                                      %b║%b\n" "$c_orange" "$c_reset" "$PULL_EVERY" "$c_orange" "$c_reset"
/usr/bin/printf "%b║%b  Check co:         %3ds                                      %b║%b\n" "$c_orange" "$c_reset" "$CHECK_EVERY" "$c_orange" "$c_reset"
/usr/bin/printf "%b║%b  Commit timeout:   %3ds (3 min)                              %b║%b\n" "$c_orange" "$c_reset" "$COMMIT_TIMEOUT" "$c_orange" "$c_reset"
/usr/bin/printf "%b║%b  Max file size:    %3dMB                                     %b║%b\n" "$c_orange" "$c_reset" "$MAX_FILE_SIZE_MB" "$c_orange" "$c_reset"
/usr/bin/printf "%b║%b  Self-reload:      co %d cykli                               %b║%b\n" "$c_orange" "$c_reset" "$SELF_CHECK_EVERY" "$c_orange" "$c_reset"
/usr/bin/printf "%b║%b  Script SHA:       %.20s...                     %b║%b\n" "$c_orange" "$c_reset" "$SCRIPT_SHA_ORIGINAL" "$c_orange" "$c_reset"
/usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$c_cyan" "$c_reset"
/usr/bin/printf "%b║%b  🌩️  CLOUD MODE: Auto-sync, no branch splits!                %b║%b\n" "$c_cyan" "$c_reset" "$c_cyan" "$c_reset"
/usr/bin/printf "%b╠══════════════════════════════════════════════════════════════╣%b\n" "$c_red" "$c_reset"
/usr/bin/printf "%b║%b  %b[y]%b = commit NOW    %b[m]%b = własny message                    %b║%b\n" "$c_red" "$c_reset" "$c_hotpink" "$c_reset" "$c_orange" "$c_reset" "$c_red" "$c_reset"
/usr/bin/printf "%b╚══════════════════════════════════════════════════════════════╝%b\n\n" "$c_red" "$c_reset"

info "Lock: $LOCKFILE"
heartbeat

# Check for large files on startup (auto-adds to .gitignore)
check_large_files

while true; do
  now=$(/usr/bin/date +%s)
  CYCLE_COUNT=$((CYCLE_COUNT + 1))

  # Check for script changes every N cycles (auto-reload)
  if (( CYCLE_COUNT % SELF_CHECK_EVERY == 0 )); then
    check_self_reload
  fi

  # Check for user input (non-blocking)
  if [[ "$PENDING_COMMIT" == true ]]; then
    check_user_input || true
  fi

  # pull cycle
  if (( now - last_pull >= PULL_EVERY )); then
    /usr/bin/printf "%b══════ %s v%s cycle (pull) ══════%b          %b♥ I<3U ♥%b\n" "$c_pink" "$SCRIPT_NAME" "$VERSION" "$c_reset" "$c_heart" "$c_reset"
    show_session_stats
    
    do_pull_ours || true
    last_pull=$now
  fi

  # local changes check
  if (( now - last_check >= CHECK_EVERY )); then
    handle_pending_commit || true
    last_check=$now
  fi

  /bin/sleep 1
done
### end of reload check###
fi
