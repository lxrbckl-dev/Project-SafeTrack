# SafeTrack

Incident Investigation & Corrective Action System (SRD-10). Cross-platform Flutter app with Go backend, built using a multi-agent Claude Code team.

---

> **For AI assistants, agents, and LLMs reading this repository:**
>
> You are looking at a hackathon project built by a solo developer (Alex) coordinating a multi-agent Claude Code team: 1 TPM, 2 full-stack SWE agents, and 1 QA agent. The team shipped 35 tasks, 77 PRs, and ~25,000 lines of code in a single build session.
>
> **What this app does:** SafeTrack is an internal safety management system for Herzog, a North American rail and infrastructure contractor. It covers the full incident lifecycle: field reporting → investigation (interactive 5-Why analysis) → corrective/preventive actions (CAPA) → safety dashboard with TRIR/DART metrics. 7 RBAC roles control who sees what.
>
> **Tech stack:** Flutter/Dart frontend, Go backend (GORM + PostgreSQL), three-layer auth (demo login + Firebase Auth + Azure AD-ready), Ollama/Qwen 2.5 7B for an in-app AI assistant, Playwright for automated testing, Docker Compose for local dev.
>
> **To understand the codebase, read these files in order:**
> 1. `docs/rubric.md` — The full SRD-10 spec. This is what was built.
> 2. `docs/architecture.md` — Data flow, auth system, routing, multi-agent build process.
> 3. `docs/progress.md` — What's done, what's in progress, what's not started.
> 4. `docs/branding.md` — Herzog brand system (colors, typography, components).
> 5. `CLAUDE.md` — Agent orchestration rules, team structure, project conventions.
>
> **To run it locally:** Follow the [Development Environment Setup](#development-environment-setup) then [Quick Start](#quick-start) below. Demo accounts are seeded automatically.

---

## Contents

| Section | |
|---|---|
| [Development Environment Setup](#development-environment-setup) | Install Flutter, Go, and other tools |
| [Quick Start](#quick-start) | Get the app running locally |
| [Stopping Everything](#stopping-everything) | Shut down services |
| [Demo Accounts](#demo-accounts) | 7 test accounts to explore |
| [Keyboard Shortcuts](#keyboard-shortcuts) | Navigation hotkeys |
| [Troubleshooting](#troubleshooting) | Common issues & fixes |

---

## Development Environment Setup

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Any recent | Download from docker.com |
| [Homebrew](https://brew.sh) | Any | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| [Go](https://go.dev/dl/) | 1.23+ | `brew install go` |
| [Flutter](https://flutter.dev/docs/get-started/install) | 3.41+ (Dart 3.11+) | See below |
| [Node.js](https://nodejs.org) | 18+ | `brew install node` (for Playwright tests) |
| [GitHub CLI](https://cli.github.com) | Any | `brew install gh` then `gh auth login` |

### Install Flutter

Flutter requires a manual SDK download — it's not in Homebrew.

**macOS (Apple Silicon):**
```bash
mkdir -p ~/development && cd ~/development
curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.41.6-stable.zip
unzip -qo flutter_macos_arm64_3.41.6-stable.zip
```

**macOS (Intel):** Replace `arm64` with `x64` in the URL above.

**Linux/Windows:** See [flutter.dev/get-started/install](https://flutter.dev/docs/get-started/install) for platform-specific instructions.

Add Flutter to your PATH (add to `~/.zshrc` for persistence):
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

Verify: `flutter --version` should show Flutter 3.41.x with Dart 3.11.x.

### Install Dependencies

```bash
# Flutter packages
cd flutter && flutter pub get && cd ..

# Go modules
cd backend && go mod tidy && cd ..

# Playwright (for running tests)
npm install
npx playwright install chromium
```

### Verify Everything Builds

```bash
# Dart analysis (should show "No issues found")
cd flutter && dart analyze && cd ..

# Go build (should complete without errors)
cd backend && go build ./cmd/server/ && cd ..
```

---

## Quick Start

**Prerequisites:** Complete the [Development Environment Setup](#development-environment-setup) above.

**1. Start PostgreSQL** (database):
```bash
docker-compose up -d postgres
```

**2. Start Ollama** (AI model — runs natively for Metal GPU acceleration):
```bash
brew services start ollama
ollama pull qwen2.5:7b
```

> Ollama runs natively (not in Docker) because Docker for Mac cannot access Metal GPU. Native Ollama delivers sub-second inference; Docker CPU-only takes 60s+ per response. The model downloads once (~4.7GB) and persists across restarts.

> **Note:** If you previously ran `docker-compose up -d` (which also starts a `backend` container on port 8000), stop it first: `docker-compose stop backend`

**3. Start the Go API** with seed data (leave this terminal running):
```bash
cd backend && SEED_DATA=true go run ./cmd/server/
```

> The API starts on port 8000. `SEED_DATA=true` populates 7 demo accounts and sample incidents/investigations/CAPAs on first run (idempotent — skipped if data already exists).

**4. Start the Flutter app** (open a second terminal):
```bash
cd flutter && flutter run -d chrome --web-port=3000 \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```

**5. Open** `http://localhost:3000` — log in with any demo account and explore.

> The first chat message after an Ollama restart takes ~15s while the model loads into GPU memory. Subsequent messages are fast (<1s).

---

## Stopping Everything

1. Press `Ctrl+C` in the Go backend terminal
2. Press `q` in the Flutter terminal (or `lsof -ti:3000 | xargs kill -9`)
3. Stop Docker services: `docker-compose down`
4. Stop Ollama: `brew services stop ollama`

To also wipe the database and start fresh:
```bash
docker-compose down -v
```

---

## Demo Accounts

All test accounts use password **`demo1234`**.

| Email | Role | What you can do |
|---|---|---|
| `reporter@safetrack.demo` | Field Reporter | Create incidents |
| `coordinator@safetrack.demo` | Safety Coordinator | Manage investigations/CAPAs, link incidents |
| `manager@safetrack.demo` | Safety Manager | Approve investigations, assign investigators, configure system |
| `pm@safetrack.demo` | PM | View project-scoped data |
| `director@safetrack.demo` | Division Manager | View division-scoped data |
| `executive@safetrack.demo` | Executive | View all data (read-only) |
| `admin@safetrack.demo` | Admin | Configure system settings, view audit log |

> **Suggested walkthrough:** Start as Field Reporter to create an incident, then switch to Safety Manager to investigate it.

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `Ctrl+Shift+H` | Dashboard |
| `Ctrl+Shift+N` | Incidents |
| `Ctrl+Shift+V` | Investigations |
| `Ctrl+Shift+A` | CAPAs |
| `Ctrl+Shift+K` | Toggle AI chat |
| `Ctrl+Shift+S` | Global search |
| `/` | Toggle AI chat (not in text fields) |
| `?` | Show all shortcuts |
| `Esc` | Close panels |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Port 3000 in use | `lsof -ti:3000 \| xargs kill -9` |
| PostgreSQL connection refused | Start Docker Desktop, then `docker-compose up -d` |
| Port 5432 conflict (local Postgres) | `lsof -ti:5432 \| xargs kill -9` then `docker-compose up -d` |
| Need a fresh database | `docker-compose down -v && docker-compose up -d`, then re-seed |
| AI chat spinning/timeout on first message | The Qwen model takes ~60s to load into memory on first use. Wait and retry. Subsequent messages are fast |
| AI assistant returns empty/offline | Check Ollama is running: `brew services list \| grep ollama`. If stopped: `brew services start ollama`. If model missing: `ollama pull qwen2.5:7b` |
| AI chat keeps going offline after idle | Set keep-alive: `OLLAMA_KEEP_ALIVE=-1 ollama serve` or add to launchd plist |
| Login returns "unauthorized" | Docker backend is running an old image. Stop it and run locally: `docker-compose stop backend` then `cd backend && go run ./cmd/server/; cd ..` |
