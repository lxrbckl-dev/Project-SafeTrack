# Highlander — App Wiki

## What This App Does

Highlander is a cross-platform Incident Investigation & Corrective Action System (SRD-10) built with Flutter. This wiki will be updated as features are built.

## Pages & Routes

| Route | Page | Purpose |
|---|---|---|
| `/` | Home | KPI cards showing pass/remaining/platform counts, test cards for each infrastructure component |
| `/drift` | Drift + Sync Test | Save notes to local database, sync to Go API with one tap, see sync status per record |
| `/connectivity` | Connectivity Test | Shows real-time online/offline status with live updates when network changes |
| `/ollama` | Ollama / Qwen Test | Send prompts to the local Qwen 2.5 7B model, see responses and latency in milliseconds |

## Data Storage

### Local Database (Drift)
- All data saves locally first using Drift, a SQLite wrapper
- On mobile (iOS/Android): native SQLite
- On web: compiles to WebAssembly (WASM)
- Schema is identical across all platforms

### Current Schema
- **Notes table**: `id` (auto-increment), `content` (text), `createdAt` (datetime), `synced` (boolean)

### Remote Database (PostgreSQL via Go API)
- Go backend serves as the API layer between Flutter and PostgreSQL
- GORM ORM auto-migrates tables from Go struct definitions on startup
- Firebase is used for authentication only, not data storage

### Sync Flow
1. User saves a note → writes to local Drift database immediately (works offline)
2. Record is marked `synced: false`
3. When online, SyncService pushes unsynced records to Go API → PostgreSQL
4. Successfully synced records are marked `synced: true`
5. SyncService auto-triggers when device transitions from offline → online
6. Manual sync available via "Sync Now" button
7. If the API is unreachable, data stays safe in local Drift — never lost

## Key Features

- **Offline-first**: The app works without internet. All writes go to the local database first.
- **Real-time connectivity detection**: Detects online/offline state and updates the UI live.
- **Local AI assistant**: Qwen 2.5 7B runs locally via Ollama and answers questions about the app using this wiki as context.
- **Cross-platform**: One codebase runs on iOS, Android, Web, macOS, and Windows.
- **Go backend**: RESTful API with health, sync, and data endpoints. PostgreSQL for persistent cloud storage.
- **Firebase Auth**: Email/password authentication with multi-factor authentication (2FA) support.
- **AutoResearch eval loop**: Automated testing validates the AI assistant's accuracy against known questions.

## Navigation

The app uses `go_router` for all navigation. Routes support deep linking and web URL handling.

## Styling

The app uses the Herzog brand system via a centralized theme (`flutter/lib/app/herzog_theme.dart`):
- **Headings**: Oswald font, uppercase, letter-spaced
- **Body text**: Roboto font
- **Primary brand color**: Herzog Gold (#FFD100)
- **Action color**: Navy Blue (#1E3A5F)
- **App bar**: Black background (#000000) with gold text and 3px gold bottom border
- **Status badges**: Green (pass/success), amber (in progress/test), teal (pending/info), gray (waiting)
- **Cards**: White background, gray border, 8px radius
- **KPI cards**: Gold accent bar, large Oswald value, uppercase label
