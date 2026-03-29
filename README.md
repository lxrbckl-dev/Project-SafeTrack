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
> **To run it locally:** Follow the Quick Start section below. Docker + Flutter + Go are the only prerequisites. Demo accounts are seeded automatically.

---

## Contents

| Section | |
|---|---|
| [Quick Start](#quick-start) | Get the app running locally |
| [Stopping Everything](#stopping-everything) | Shut down services |
| [Demo Accounts](#demo-accounts) | 7 test accounts to explore |
| [Keyboard Shortcuts](#keyboard-shortcuts) | Navigation hotkeys |
| [Troubleshooting](#troubleshooting) | Common issues & fixes |

---

## Quick Start

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/), [Flutter](https://flutter.dev/docs/get-started/install), [Go](https://go.dev/dl/)

**1. Start backend** (Go API + PostgreSQL + Ollama):
```bash
docker-compose up -d
```

**2. Seed demo data** (first time only):
```bash
cd backend && SEED_DATA=true go run ./cmd/server/; cd ..
```
> The server will exit with "address already in use" — that's expected since Docker is already running it.

**3. Start the app:**
```bash
cd flutter && flutter run -d chrome --web-port=3000 \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp; cd ..
```

**4. Open** `http://localhost:3000` — pick a role and explore.

> AI chat is enabled automatically — the Qwen 2.5 7B model pulls on first startup (~4 min download). The first chat message after startup takes ~60s while the model loads into memory. Subsequent messages are fast (1-3s).

---

## Stopping Everything

```bash
docker-compose down
```

To also wipe the database and start fresh:
```bash
docker-compose down -v
```

If the Flutter dev server is still running, press `q` in its terminal or:
```bash
lsof -ti:3000 | xargs kill -9
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
| AI assistant returns empty/offline | Check `docker ps` — Ollama container must be running. If model missing: `docker exec -it highlander-ollama-1 ollama pull qwen2.5:7b` |
| AI chat keeps going offline after idle | Ollama is using old config without keep-alive. Run `docker-compose restart ollama` to apply the permanent keep-alive setting |
| Login returns "unauthorized" | Docker backend is running an old image. Stop it and run locally: `docker-compose stop backend` then `cd backend && go run ./cmd/server/; cd ..` |
