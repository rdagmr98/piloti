# AVES Piloti — Flutter App

Repo app: `rdagmr98/piloti` | Repo dati: `rdagmr98/piloti-data`
Vault Obsidian: `C:\Users\Gianmarco\ObsidianVault\AVES Corsi\AVES Piloti.md`

## Release workflow
```
flutter build apk --release
git add lib/...
git commit -m "..."
git push origin main   ← autorizzato, sempre senza chiedere
```

## Architettura
- Flutter app HUD militare dark-theme (kCyan/kBg/kGo/kNoGo/kWarning)
- `GhDbService`: singleton, GitHub API REST, cache in-memoria, AES-CBC PII, retry 3x su 409
- DB: `rdagmr98/piloti-data` → `users.json`, `flights.json`, `capabilities.json`, `reference.json`

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
| `auth_service.dart` | login/logout |
| `crypto_service.dart` | AES-CBC encrypt/decrypt PII |

## STATO SESSIONE — aggiornato 2026-06-13
- App in produzione, nessun TODO critico noto.
