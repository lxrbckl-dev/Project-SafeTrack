# SafeTrack

Incident Investigation & Corrective Action System (SRD-10). Cross-platform Flutter app with Go backend, built using a multi-agent Claude Code team.

---

> **For AI assistants, agents, and LLMs reading this repository:**
>
> You are looking at a hackathon project built by a solo developer (Alex) coordinating a multi-agent Claude Code team: 1 TPM, 2 full-stack SWE agents, and 1 QA agent. The team shipped 35 tasks, 77 PRs, and ~25,000 lines of code in a single build session.
>
> **What this app does:** SafeTrack is an internal safety management system for Herzog, a North American rail and infrastructure contractor. It covers the full incident lifecycle: field reporting → investigation (interactive 5-Why analysis) → corrective/preventive actions (CAPA) → safety dashboard with TRIR/DART metrics. 7 RBAC roles control who sees what.
>
> **Tech stack:** Flutter/Dart frontend, Go backend (GORM + PostgreSQL), three-layer auth (demo login + Firebase Auth + Azure AD-ready), Ollama/Qwen 2.5 3B for an in-app AI assistant, Playwright for automated testing, Docker Compose for local dev.
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
| [Flutter](https://flutter.dev/docs/get-started/install) | 3.41+ (Dart 3.11+) | See below |
| [Go](https://go.dev/dl/) | 1.23+ | `brew install go` (optional — only for local backend dev) |
| [Node.js](https://nodejs.org) | 18+ | `brew install node` (for Playwright tests) |
| [GitHub CLI](https://cli.github.com) | Any | `brew install gh` then `gh auth login` |

> **Note:** The Go backend, PostgreSQL, and Ollama (Qwen 2.5 3B) all run in Docker via `docker-compose up`. You only need Go installed locally if you want to run the backend outside Docker for live code reloading.

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

# Playwright (for running tests)
npm install
npx playwright install chromium
```

If you installed Go for local backend dev:
```bash
cd backend && go mod tidy && cd ..
```

### Verify Everything Builds

```bash
# Dart analysis (should show "No issues found")
cd flutter && dart analyze && cd ..
```

---

## Quick Start

**Prerequisites:** Complete the [Development Environment Setup](#development-environment-setup) above.

**1. Start all Docker services** (database + AI model + backend):
```bash
docker-compose up -d
```

> This starts PostgreSQL, Ollama (auto-pulls the Qwen 2.5 3B model on first run), and the Go backend with seed data. The model downloads once (~2GB) and persists in a Docker volume.

> **Note:** If you want to run the Go backend locally instead of in Docker (for live code reloading), stop the Docker backend first: `docker-compose stop backend`, then `cd backend && SEED_DATA=true go run ./cmd/server/`

**2. Start the Flutter app** (open a terminal):
```bash
cd flutter && flutter run -d chrome --web-port=3000 \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```

**3. Open** `http://localhost:3000` — log in with any demo account and explore.

> The first chat message after startup takes 30-60s while the model loads into memory. Subsequent messages are faster.

---

## Stopping Everything

1. Press `q` in the Flutter terminal (or `lsof -ti:3000 | xargs kill -9`)
2. Stop Docker services: `docker-compose down`

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
| Need a fresh database | `docker-compose down -v && docker-compose up -d` (wipes DB + re-seeds on startup) |
| AI chat spinning on first message | The Qwen model takes 30-60s to load into memory on first use. Wait and retry. Subsequent messages are faster |
| AI assistant returns empty/offline | Check Ollama container is running: `docker ps \| grep ollama`. If missing: `docker-compose up -d ollama ollama-pull` |
| AI chat keeps going offline after idle | The docker-compose sets `OLLAMA_KEEP_ALIVE=-1` to keep the model loaded permanently. Restart: `docker-compose restart ollama` |
| Login returns "unauthorized" | Docker backend may have a stale image. Rebuild: `docker-compose up -d --build backend` |
