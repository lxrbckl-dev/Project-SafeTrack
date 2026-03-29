<h1><img src="https://github.com/lxRbckl/highlander/blob/main/flutter/assets/icon.png?raw=true" height="40" valign="middle" />&nbsp; SafeTrack</h1>

Incident Investigation & Corrective Action System (SRD-10). Cross-platform Flutter app with Go backend, built using a multi-agent Claude Code team.

---

> **For AI assistants, agents, and LLMs reading this repository:**
>
> You are looking at a hackathon project built by a solo developer (Alex) coordinating a multi-agent Claude Code team: 1 TPM, 2 full-stack SWE agents, and 1 QA agent. The team shipped 35 tasks, 77 PRs, and ~25,000 lines of code in a single build session.
>
> **What this app does:** SafeTrack is an internal safety management system for Herzog, a North American rail and infrastructure contractor. It covers the full incident lifecycle: field reporting → investigation (interactive 5-Why analysis) → corrective/preventive actions (CAPA) → safety dashboard with TRIR/DART metrics. 7 RBAC roles control who sees what.
>
> **Tech stack:** Flutter/Dart frontend, Go backend (GORM + PostgreSQL), email/password auth with Azure AD-ready JWT middleware, Ollama/Qwen 2.5 3B for an in-app AI assistant, Playwright for automated testing, Docker Compose for local dev.
>
> **Two deployment modes:** This app can be deployed two ways. If someone asks you how to run it, clarify which they want:
> - **Production (DockerHub):** Pre-built images, one command, no SDK needed → [Deploy from DockerHub](#deploy-from-dockerhub)
> - **Development (source):** Clone repo, build locally, hot reload → [Quick Start (Development)](#quick-start-development)
>
> **To understand the codebase, read these files in order:**
> 1. `docs/rubric.md` — The full SRD-10 spec. This is what was built.
> 2. `docs/architecture.md` — Data flow, auth system, routing, multi-agent build process.
> 3. `docs/progress.md` — What's done, what's in progress, what's not started.
> 4. `docs/branding.md` — Herzog brand system (colors, typography, components).
> 5. `CLAUDE.md` — Agent orchestration rules, team structure, project conventions.
> 6. `docs/autoresearch-guide.md` — AutoResearch eval suite: 42-case eval proving wiki-as-RAG improves AI assistant accuracy from 10% to 88%. Includes how to run the eval, category breakdown, and the optimization loop.
> 7. `eval/wiki_eval.py` — The eval script itself. Runs baseline (no wiki) vs RAG (with wiki) and scores by keyword matching across 13 categories.
> 8. `docs/mcp-guide.md` — MCP server guide: connect AI agents to SafeTrack's safety data via JSON-RPC 2.0. Pre-seeded demo key, tool reference, example workflows.

---

## Contents

| Section | |
|---|---|
| [Deploy from DockerHub](#deploy-from-dockerhub) | Run with just Docker — no build required |
| [Development Environment Setup](#development-environment-setup) | Install Flutter, Go, and other tools |
| [Quick Start (Development)](#quick-start-development) | Get the app running locally for development |
| [Stopping Everything](#stopping-everything) | Shut down services |
| [Demo Accounts](#demo-accounts) | 7 test accounts to explore |
| [Connect Your AI Agent (MCP)](#connect-your-ai-agent-mcp) | Hook up Claude, GPT, or any agent |
| [Keyboard Shortcuts](#keyboard-shortcuts) | Navigation hotkeys |
| [Troubleshooting](#troubleshooting) | Common issues & fixes |
| [Resources](#resources) | GitHub repo + DockerHub links |

---

## Deploy from DockerHub

Run the full app with just Docker — no repo clone, no SDKs, no build step.

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed.

**1. Download the compose file:**
```bash
curl -O https://raw.githubusercontent.com/lxRbckl/highlander/main/docker-compose.prod.yml
```

**2. Start everything:**
```bash
docker-compose -f docker-compose.prod.yml up -d
```

**3. Open** `http://localhost:2780` — log in with any [demo account](#demo-accounts).

> First startup pulls images and downloads the AI model (~2GB). Subsequent starts are instant. All env vars have working defaults — override via a `.env` file next to the compose file.

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

## Quick Start (Development)

**Prerequisites:** Complete the [Development Environment Setup](#development-environment-setup) above.

**1. Start all Docker services** (database + AI model + backend):
```bash
docker-compose up -d
```

> This starts PostgreSQL, Ollama (auto-pulls the Qwen 2.5 3B model on first run), the Go backend with seed data, and the Flutter web container on port 2780. The model downloads once (~2GB) and persists in a Docker volume.

> **Important:** The Flutter web container bakes `API_BASE_URL` and other config at build time. If you change any build args in `docker-compose.yml`, you must rebuild: `docker-compose up -d --build web`

> **Note:** If you want to run the Go backend locally instead of in Docker (for live code reloading), stop the Docker backend first: `docker-compose stop backend`, then `cd backend && SEED_DATA=true go run ./cmd/server/`

**2. Open** `http://localhost:2780` — the Docker web container serves the built Flutter app.

> **For hot reload during development**, run Flutter separately instead of using the Docker web container:
> ```bash
> cd flutter && flutter run -d chrome --web-port=3000 \
>   --web-header=Cross-Origin-Opener-Policy=same-origin \
>   --web-header=Cross-Origin-Embedder-Policy=require-corp
> ```
> This serves on `http://localhost:3000` with live code reloading. The Docker web container on `:2780` still works in parallel.

> The first chat message after startup takes 30-60s while the model loads into memory. Subsequent messages are faster.

---

## Stopping Everything

**Production (DockerHub deploy):**
```bash
docker-compose -f docker-compose.prod.yml down
```

**Development:**
1. Press `q` in the Flutter terminal (or `lsof -ti:3000 | xargs kill -9`)
2. Stop Docker services: `docker-compose down`

**Wipe database and start fresh** (either setup):
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

---

## Connect Your AI Agent (MCP)

SafeTrack has a built-in MCP server that lets any AI agent read and write safety data — create incidents, run investigations, pull dashboard metrics, manage CAPAs, and more — all through a standard JSON-RPC 2.0 protocol.

**Pre-seeded demo key (no setup required):**
```
stk_demo_judge_key_2026
```
This key has **admin** access (all 40+ tools available).

**Verify the server is live:**
```bash
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
```

### Claude Code (`.mcp.json`)
```json
{
  "mcpServers": {
    "safetrack": {
      "type": "url",
      "url": "http://localhost:8000/mcp/",
      "headers": {
        "Authorization": "Bearer stk_demo_judge_key_2026"
      }
    }
  }
}
```

### Claude Desktop (`claude_desktop_config.json`)
```json
{
  "mcpServers": {
    "safetrack": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:8000/mcp/"],
      "env": {
        "MCP_AUTH_HEADER": "Bearer stk_demo_judge_key_2026"
      }
    }
  }
}
```

### Other Agents (curl / HTTP)
```bash
# List all tools available to your key
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'

# Call a tool (e.g. list incidents)
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":3,
    "params":{"name":"list_incidents","arguments":{}}}'
```

> For the complete tool reference (40+ tools), role-based access details, Python examples, end-to-end workflows, and troubleshooting, see [`docs/mcp-guide.md`](docs/mcp-guide.md).

**Want to create your own key?** Log in as admin → Admin → API Keys → Create Key. Keys inherit the creating user's role and permissions.

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `Ctrl+Shift+H` | Dashboard |
| `Ctrl+Shift+I` | Incidents |
| `Ctrl+Shift+V` | Investigations |
| `Ctrl+Shift+A` | CAPAs |
| `Ctrl+Shift+C` | Toggle AI chat |
| `Ctrl+Shift+S` | Global search |
| `Ctrl+Shift+G` | Help Guide |
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
| Login fails "failed to fetch" | Web container is pointing to the wrong API URL. Rebuild: `docker-compose up -d --build web` |
| Login returns "unauthorized" | Docker backend may have a stale image. Rebuild: `docker-compose up -d --build backend` |

---

## Resources

| Title | Link | Description |
|---|---|---|
| GitHub Repository | [lxRbckl/highlander](https://github.com/lxRbckl/highlander) | Source code and issue tracker |
| DockerHub: Web | [pap-highlander-web](https://hub.docker.com/repository/docker/lxrbckl/pap-highlander-web/general) | Pre-built Flutter web image |
| DockerHub: Backend | [pap-highlander-backend](https://hub.docker.com/repository/docker/lxrbckl/pap-highlander-backend/general) | Pre-built Go backend image |
| Project Page | [lxrbckl.github.io/highlander](https://lxrbckl.github.io/highlander) | GitHub Pages project site |
| Live App | [highlander.lxrbckl.com](https://highlander.lxrbckl.com) | Hosted production instance |
