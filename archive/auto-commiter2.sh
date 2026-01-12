#!/bin/bash
set -u

# =======================
# config
# =======================
GIT="/usr/bin/git"
LOCKFILE="/tmp/autogit.lock"

PULL_EVERY=12          # seconds
CHECK_EVERY=12          # seconds (check local changes)

USER_NAME="${USER:-unknown}"
HOST_NAME="$(/bin/hostname)"
DATE_FMT_COMMIT="%y%m%d %H%M"

# =======================
# no-interactive git
# =======================
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
export SSH_ASKPASS=/bin/false
export GIT_EDITOR=/bin/true

# =======================
# colors + logging
# =======================
c_reset="\033[0m"
c_dim="\033[2m"
c_red="\033[31m"
c_green="\033[32m"
c_yellow="\033[33m"
c_blue="\033[34m"
c_magenta="\033[35m"
c_cyan="\033[36m"

ts() { /usr/bin/date +%H:%M:%S; }

log()  { /usr/bin/printf "%b[%s]%b %s\n" "$c_dim" "$(ts)" "$c_reset" "$*"; }
info() { /usr/bin/printf "%b[%s]%b %bINFO%b  %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_cyan" "$c_reset" "$*"; }
ok()   { /usr/bin/printf "%b[%s]%b %bOK%b    %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_green" "$c_reset" "$*"; }
warn() { /usr/bin/printf "%b[%s]%b %bWARN%b  %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_yellow" "$c_reset" "$*"; }
err()  { /usr/bin/printf "%b[%s]%b %bERR%b   %s\n" "$c_dim" "$(ts)" "$c_reset" "$c_red" "$c_reset" "$*"; }

die() { err "$*"; exit 1; }

# =======================
# flock lock (kill-safe) + heartbeat timestamp
# =======================
exec 200>"$LOCKFILE" || die "Nie mogę otworzyć lockfile: $LOCKFILE"

# -n: nie czekaj, tylko wyjdź jeśli już działa
/usr/bin/flock -n 200 || {
  err "Już działa inna instancja (lock: $LOCKFILE). Oto zawartość lockfile:"
  /usr/bin/cat "$LOCKFILE" 2>/dev/null || true
  exit 0
}

heartbeat() {
  # zapis diagnostyczny (nie mechanizm locka!)
  # (piszemy przez > "$LOCKFILE", ale lock jest trzymany przez FD=200, więc dalej bezpiecznie)
  /usr/bin/printf "pid=%s host=%s user=%s last_seen_epoch=%s last_seen_iso=%s\n" \
    "$$" "$HOST_NAME" "$USER_NAME" "$(/usr/bin/date +%s)" "$(/usr/bin/date -Is)" \
    > "$LOCKFILE"
}

heartbeat

# =======================
# sanity
# =======================
$GIT rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Odpal skrypt w katalogu repo Git."

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

do_commit_push_if_needed() {
  local total added modified renamed removed
  read -r total added modified renamed removed < <(count_changes)

  if [[ "$total" -eq 0 ]]; then
    log "Brak lokalnych zmian (nic do add/commit)."
    return 0
  fi

  info "Lokalne zmiany: total=$total | A=$added M=$modified R=$renamed D=$removed"
  heartbeat

  info "git add -A ..."
  if ! $GIT add -A; then
    warn "git add -A nie poszło. Pomijam commit w tym przebiegu."
    heartbeat
    return 1
  fi
  heartbeat

  local msg
  msg="autocommit ${USER_NAME}@${HOST_NAME} - $(/usr/bin/date +"$DATE_FMT_COMMIT") - ${added} added, ${modified} modified, ${renamed} renamed, ${removed} removed."

  info "git commit ..."
  if $GIT commit -m "$msg" >/dev/null 2>&1; then
    ok "commit OK: $msg"
  else
    warn "commit pominięty (po add finalnie brak zmian / nic do commitu)."
    heartbeat
    return 0
  fi
  heartbeat

  info "git push ..."
  if $GIT push; then
    ok "push OK"
  else
    warn "push nieudany (remote reject? brak uprawnień? konflikt?)."
    heartbeat
    return 1
  fi
  heartbeat
  return 0
}

do_pull_ours() {
  # Dla dokumentów: wygrywa lokalne ("nasze") przy konfliktach.
  # --no-edit: nie otwieraj edytora
  # -X ours: polityka rozwiązywania konfliktów (gdy merge dojdzie do konfliktu)
  info "git pull (merge preferuje NASZE: -X ours)..."
  heartbeat

  if $GIT pull --no-rebase -X ours --no-edit; then
    ok "pull OK"
    heartbeat
    return 0
  else
    warn "pull nieudany (konflikt/stan repo/brak sieci?). Sprawdzę status i spróbuję w następnym cyklu."
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

info "Start: pull co ${PULL_EVERY}s, check local changes co ${CHECK_EVERY}s."
info "Lock: $LOCKFILE (flock) + heartbeat timestamp w środku."
heartbeat

while true; do
  now=$(/usr/bin/date +%s)

  # pull co 13s
  if (( now - last_pull >= PULL_EVERY )); then
    /usr/bin/printf "%b====== new cycle (pull) ======%b\n" "$c_magenta" "$c_reset"

    # Najpierw spróbuj skompletować lokalne zmiany, żeby pull miał czystsze pole gry.
    do_commit_push_if_needed || true

    do_pull_ours || true
    last_pull=$now
  fi

  # częstsze local check
  if (( now - last_check >= CHECK_EVERY )); then
    do_commit_push_if_needed || true
    last_check=$now
  fi

  /bin/sleep 1
done

