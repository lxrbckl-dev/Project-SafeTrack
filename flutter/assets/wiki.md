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

### Data Flow
1. User action → Go API → PostgreSQL (primary data path)
2. Drift is available for local caching
3. Full offline-first sync is a future phase feature

## Key Features

- **API-first architecture**: Data flows through the Go backend to PostgreSQL. Local caching via Drift is available; full offline sync is a future phase.
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
