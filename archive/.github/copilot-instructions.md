# 🚨 ADG Auto-Commiter - Instrukcje dla AI (Copilot/Claude/GPT)

## ⚠️ KRYTYCZNE: TO JEST KOD PRODUKCYJNY!

Ten skrypt (`adg-auto-commiter-UpNext.sh`) **działa na żywo u klientów** i posiada mechanizm **auto-upgrade**. Każda zmiana w kodzie jest automatycznie wdrażana na wszystkie działające instancje w ciągu kilku sekund!

---

## 🔒 ZASADY BEZPIECZEŃSTWA PRZY EDYCJI

### 1. PRZED rozpoczęciem pracy nad kodem:

```bash
# ZAWSZE najpierw wyłącz auto-reload!
RELOAD_ON_SHA_CHANGE=false   # ← zmień na false
```

**DLACZEGO?** Gdy `RELOAD_ON_SHA_CHANGE=true`, każda zapisana zmiana w pliku (nawet niekompletna!) zostanie natychmiast załadowana przez wszystkie działające instancje. Błąd składni = crash u wszystkich klientów.

### 2. PO zakończeniu edycji:

```bash
# 1. Sprawdź składnię bash PRZED włączeniem reload!
bash -n adg-auto-commiter-UpNext.sh

# 2. Jeśli OK, włącz reload
RELOAD_ON_SHA_CHANGE=true    # ← przywróć na true

# 3. Ponownie sprawdź składnię (paranoja = bezpieczeństwo)
bash -n adg-auto-commiter-UpNext.sh
```

### 3. NIGDY nie:
- ❌ Nie zostawiaj `RELOAD_ON_SHA_CHANGE=false` po zakończeniu pracy
- ❌ Nie commituj z `RELOAD_ON_SHA_CHANGE=false` (chyba że celowo blokujesz update)
- ❌ Nie edytuj kodu bez wcześniejszego wyłączenia reload
- ❌ Nie włączaj reload bez weryfikacji składni

---

## 📊 WERSJONOWANIE

### Format wersji: `MAJOR.MINOR.PATCH`

```
6.0.2
│ │ └── PATCH: każda zmiana/poprawka (inkrementuj przy KAŻDEJ edycji)
│ └──── MINOR: nowe funkcje, większe zmiany
└────── MAJOR: breaking changes, przepisanie architektury
```

### Zasady:
1. **Każda edycja = bump wersji** (minimum PATCH +1)
2. Wersja jest w **dwóch miejscach** - obie muszą być zaktualizowane:
   - Sekcja SOURCE: `VERSION="X.Y.Z"`
   - Fallback w MAIN: `VERSION="${VERSION:-X.Y.Z}"`
3. **Nigdy nie zmniejszaj wersji** - tylko zwiększaj

### Przykład workflow:

```bash
# Obecna wersja: 6.0.2

# Krok 1: Wyłącz reload
RELOAD_ON_SHA_CHANGE=false

# Krok 2: Zmień wersję na 6.0.3 (lub 6.1.0 dla większych zmian)
VERSION="6.0.3"

# Krok 3: Wprowadź zmiany w kodzie...

# Krok 4: Sprawdź składnię
bash -n adg-auto-commiter-UpNext.sh

# Krok 5: Włącz reload
RELOAD_ON_SHA_CHANGE=true

# Krok 6: Ostateczna weryfikacja
bash -n adg-auto-commiter-UpNext.sh
```

---

## 🏗️ ARCHITEKTURA SKRYPTU

### Struktura pliku:
```
┌─────────────────────────────────────────┐
│ SCRIPT_FILE detection (linie 1-20)      │
├─────────────────────────────────────────┤
│ SOURCE SECTION (if AC5_RUNNING=true)    │
│ ├── VERSION, COMMIT_TIMEOUT, etc.       │
│ ├── RELOAD_ON_SHA_CHANGE                │
│ └── SHA check logic                     │
├─────────────────────────────────────────┤
│ MAIN SECTION (else)                     │
│ ├── Trampoline system                   │
│ ├── Functions (network_retry, etc.)     │
│ ├── Startup sequence                    │
│ └── Main loop                           │
└─────────────────────────────────────────┘
```

### Kluczowe mechanizmy:
- **Hot-reload**: Zmienne z SOURCE section są przeładowywane co `SELF_CHECK_EVERY` cykli
- **Trampoline (GOWNO)**: Pełny restart przez plik tymczasowy gdy SHA się zmieni
- **Network retry**: Nieskończone próby z cyklicznym backoff
- **Flock**: Blokada zapobiegająca wielokrotnym instancjom

---

## 🔧 ZMIENNE KONFIGURACYJNE

| Zmienna | Domyślna | Opis |
|---------|----------|------|
| `VERSION` | - | Wersja skryptu (WYMAGANE przy każdej zmianie) |
| `RELOAD_ON_SHA_CHANGE` | `true` | **KRYTYCZNE** - wyłącz na czas edycji! |
| `COMMIT_TIMEOUT` | 180 | Sekundy do auto-commit |
| `CHECK_EVERY` | 15 | Interwał sprawdzania zmian |
| `PULL_EVERY` | 30 | Interwał git pull |
| `NETWORK_RETRY_MAX` | 0 | 0 = nieskończone próby |
| `GIT_TIMEOUT` | 120 | Timeout operacji git |

---

## 📋 CHECKLIST PRZED KAŻDĄ ZMIANĄ

```
[ ] Ustawiłem RELOAD_ON_SHA_CHANGE=false
[ ] Zwiększyłem VERSION (minimum +0.0.1)
[ ] Zaktualizowałem VERSION w fallback defaults
[ ] Wykonałem: bash -n adg-auto-commiter-UpNext.sh
[ ] Przywróciłem RELOAD_ON_SHA_CHANGE=true
[ ] Ponownie wykonałem: bash -n adg-auto-commiter-UpNext.sh
[ ] Wszystko OK - mogę commitować
```

---

## 🚑 W RAZIE AWARII

Jeśli klienci zgłaszają problemy po aktualizacji:

1. **Natychmiast** ustaw `RELOAD_ON_SHA_CHANGE=false` w repo
2. Znajdź i napraw błąd
3. Sprawdź składnię
4. Przywróć `RELOAD_ON_SHA_CHANGE=true`
5. Klienci automatycznie dostaną poprawkę przy następnym SELF_CHECK_EVERY

---

## 💡 TIPS DLA AI

1. **Zawsze pytaj** czy `RELOAD_ON_SHA_CHANGE` jest wyłączone przed edycją
2. **Proponuj małe, atomowe zmiany** - łatwiej debugować
3. **Testuj składnię** po każdej zmianie
4. **Pamiętaj o obu miejscach** gdzie jest VERSION
5. **Nie usuwaj komentarzy** z emoji - pomagają w nawigacji
6. **Zachowaj strukturę** SOURCE/MAIN - mechanizm reload od niej zależy
