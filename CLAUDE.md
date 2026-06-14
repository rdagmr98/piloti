# AVES Piloti — Flutter App

Repo app: `rdagmr98/piloti` | Repo dati: `rdagmr98/piloti-data`
Vault Obsidian: `C:\Users\Gianmarco\ObsidianVault\AVES Corsi\AVES Piloti.md`

## Release workflow
App **web** deployata su GitHub Pages (`/piloti/`) via GitHub Actions (`.github/workflows/deploy.yml`).
NON è un'app APK (non esiste cartella `android/`).
```
flutter build web --release --base-href /piloti/
git add -A
git commit -m "..."
git push origin main   ← autorizzato, sempre senza chiedere
```
GitHub Actions builda con `--dart-define=READ_PAT=${{ secrets.AVES_READ_PAT }}` e deploya.

## Architettura
- Flutter app HUD militare dark-theme (kCyan/kBg/kGo/kNoGo/kWarning)
- `GhDbService`: singleton, GitHub API REST, cache in-memoria, AES-CBC PII, retry 3x su 409
- DB: `rdagmr98/piloti-data` → `users.json`, `flights.json`, `capabilities.json`, `reference.json`

## Sicurezza
- **Token**: `GhConfig` supporta proxy. Se `--dart-define=PROXY_URL=...` è valorizzato le
  chiamate passano da un Cloudflare Worker (`proxy/worker.js`, repo `piloti-data`) che tiene
  il token lato server; altrimenti modalità diretta con Bearer `READ_PAT` (comportamento attuale).
  Per attivare il proxy: deploy worker → `wrangler secret put GH_TOKEN` → aggiungere PROXY_URL
  (e opzionale APP_KEY) ai dart-define del workflow → rimuovere READ_PAT → revocare il vecchio PAT.
- **Password**: PBKDF2-HMAC-SHA256, 10000 iter, salt per-utente. Formato `pbkdf2$<iter>$<salt>$<hash>`.
  `verifyPassword` accetta anche i vecchi hash SHA-256; migrazione trasparente al primo login.
- **PII** (`crypto_service.dart`): AES-CBC con IV casuale per record, formato `ENC1:<iv>:<ct>`.
  Decifra ancora il legacy `ENC:` (IV zero) per retrocompatibilità con i dati esistenti.
- **Robustezza**: `GhDbService.saveError` (ValueNotifier) + listener globale in `app.dart` →
  SnackBar d'errore (`utils/snackbar.dart`) se un salvataggio fallisce.

## Schermate
| Screen | File |
|--------|------|
| Admin dashboard | `lib/screens/admin/admin_dashboard.dart` |
| User dashboard | `lib/screens/user/user_dashboard.dart` |

## Logica Go/No-Go — `_pilotOverallStatus()`
- Medical fitness scaduta → **NO-GO** (rosso)
- Ore semestre precedente < 6h → **NO-GO**
- Scadenza ≤ 60gg **oppure** ore < 6h → **WARNING** (giallo)
- Altrimenti → **GO** (verde)

## Servizi
| Servizio | Ruolo |
|----------|-------|
| `user_service.dart` | CRUD piloti |
| `flight_service.dart` | registrazione/lettura voli |
| `gh_db_service.dart` | GitHub API, cache, SHA versioning |
| `auth_service.dart` | login + verifyPassword + migrazione hash |
| `crypto_service.dart` | AES-CBC encrypt/decrypt PII (IV casuale ENC1 + legacy ENC) |

## STATO SESSIONE — aggiornato 2026-06-14
- Allineata sicurezza/robustezza a corsi: proxy token opzionale (`PROXY_URL`),
  hashing PBKDF2 con migrazione trasparente, PII con IV casuale (ENC1), `saveError` + SnackBar globale.
  Tutto retrocompatibile (dati e login esistenti continuano a funzionare).
- Corretto workflow: è un'app **web**, non APK.
- File morti rimasti in repo: `lib/crypto_service.dart`, `lib/gh_config.dart` (duplicati non importati).
- App in produzione, nessun TODO critico noto.
