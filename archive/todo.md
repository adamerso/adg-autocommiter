# ADG Auto-Commiter - Obsługa Problemów Git/GitHub

## 📦 1. Rozmiary i binaria

| Problem | Strategia rozwiązania | Status |
|---------|----------------------|--------|
| Plik > 99 MB (GitHub hard-limit) | `check_large_files()` - skanuje repo, auto-dodaje do .gitignore | ✅ Działa |
| Plik > 99 MB już w historii | `network_retry()` - WIELKI BANNER przy każdym push, instrukcje BFG | ✅ v6.0.4 |
| Commit > 100 MB sumarycznie | `check_staged_large()` - sprawdza staged przed commit | ⚠️ Częściowo (per-file) |
| Binaria bez LFS (*.zip, *.exe) | Brak - można dodać pattern do .gitignore | ❌ TODO |
| Binaria w src/, docs/ | Brak - można dodać wykrywanie | ❌ TODO |
| Nagłe 10+ binariów naraz | Brak - można dodać limit | ❌ TODO |
| Plik tekstowy → binarny | Brak - można wykryć przez `file` | ❌ TODO |
| CRLF/LF → binarny blob | Brak - git sam obsługuje przez .gitattributes | ➖ N/A |

## 🔄 2. Konflikty zdalne / stan repo

| Problem | Strategia rozwiązania | Status |
|---------|----------------------|--------|
| origin ma nowe commity | `do_pull()` z `-X ours` strategy | ✅ Działa |
| git status ≠ clean | `handle_pending()` - czeka na commit timeout | ✅ Działa |
| Repo w stanie rebase/merge | `do_pull()` - `merge --abort` + reset | ✅ Działa |
| Nierozwiązane konflikty `<<<<<<<` | `-X ours` auto-rozwiązuje na korzyść local | ✅ Działa |
| Detached HEAD | `do_pull()` - auto-checkout main/master | ✅ Działa |
| Branch nie istnieje na remote | `do_pull()` - `checkout -b main` fallback | ✅ Działa |
| Branch chroniony (main, release) | Brak - GitHub odrzuci, retry będzie krzyczeć | ⚠️ Częściowo |
| Force-push wymagany | `do_commit_push()` - `--force-with-lease` fallback | ✅ Działa |
| Zmieniony origin URL | `setup_git_auth()` - wykrywa i pyta o rekonfigurację | ✅ Działa |
| Brak dostępu 401/403 | `network_retry()` - nieskończone próby z backoff | ✅ Działa |

## 🌐 3. Sieć i połączenie

| Problem | Strategia rozwiązania | Status |
|---------|----------------------|--------|
| Timeout operacji git | `GIT_TIMEOUT=120` + `timeout` wrapper | ✅ Działa |
| Brak sieci | `network_retry()` - backoff 1→3→5→10→30→60→120s | ✅ Działa |
| Niestabilne połączenie | `NETWORK_RETRY_MAX=0` - nieskończone próby | ✅ Działa |
| SSH key nie załadowany | `setup_git_auth()` - ssh-agent setup | ✅ Działa |

## 🧱 4. Struktura repo i polityki

| Problem | Strategia rozwiązania | Status |
|---------|----------------------|--------|
| Usunięcie .github/, Knowledge Hub/ | Brak - można dodać protected paths | ❌ TODO |
| Rename + modify w jednym commit | Git radzi sobie sam | ➖ N/A |

## 📋 Legenda

| Symbol | Znaczenie |
|--------|-----------|
| ✅ | Wdrożone i działa |
| ⚠️ | Częściowo zaimplementowane |
| ❌ | TODO - do zrobienia |
| ➖ | N/A - nie wymaga obsługi |