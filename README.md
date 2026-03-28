# SafeTrack

Incident Investigation & Corrective Action System (SRD-10). Cross-platform Flutter app with Go backend, built using a multi-agent Claude Code team.

## Contents

| Section | |
|---|---|
| [Quick Start](#quick-start) | Get the app running locally |
| [Stopping Everything](#stopping-everything) | Shut down services |
| [Demo Roles](#demo-roles) | 7 roles to explore |
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

> AI chat is enabled automatically — the Qwen 2.5 7B model pulls on first startup (~30s delay).

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

## Demo Roles

| Role | What you can do |
|---|---|
| **Field Reporter** | Create incidents |
| **Safety Coordinator** | Manage investigations/CAPAs, link incidents |
| **Safety Manager** | Approve investigations, assign investigators, configure system |
| **PM** | View project-scoped data |
| **Division Manager** | View division-scoped data |
| **Executive** | View all data (read-only) |
| **Admin** | Configure system settings, view audit log |

> **Suggested walkthrough:** Start as Field Reporter to create an incident, then switch to Safety Manager to investigate it.

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `Alt+D` | Dashboard |
| `Alt+I` | Incidents |
| `Alt+V` | Investigations |
| `Alt+C` | CAPAs |
| `Ctrl+K` | Toggle AI chat |
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
| AI assistant returns empty responses | Wait ~30s for model pull, or run `docker logs highlander-ollama-pull-1` to check progress |
