# Highlander

Incident Investigation & Corrective Action System (SRD-10). Cross-platform Flutter/Dart app with Go backend, built for a hackathon using a multi-agent Claude Code team.

---

## Local Deployment

### Prerequisites

| Tool | Install |
|---|---|
| Docker Desktop | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Flutter | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Go | `brew install go` |

All commands are run from the project root directory.

### Step 1: Start the backend services (Go API + PostgreSQL + Ollama)

```bash
docker-compose up -d
```

Wait for PostgreSQL to be healthy (~5 seconds), then verify:
```bash
curl localhost:8000/health
# Should return: {"status":"ok"}
```

### Step 2: Seed the database (first time only)

```bash
SEED_DATA=true go run ./backend/cmd/server/
```

This creates demo users (3+ per role), 18 incidents, 7 investigations, 14 CAPAs, hours worked data, and admin settings. It only seeds if the database is empty. The server will exit with "address already in use" after seeding — that's expected since Docker is already running the backend on :8000.

### Step 3: Start Flutter web

```bash
lsof -ti:3000 | xargs kill -9 2>/dev/null
flutter run -d chrome --web-port=3000 \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```

Open `http://localhost:3000` — you'll see the dev login page with 7 role cards.

### Step 4 (optional): Pull the Qwen model for AI chat

```bash
docker exec -it $(docker ps -q -f ancestor=ollama/ollama) ollama pull qwen2.5:7b
```

---

## Troubleshooting

### Port 3000 already in use

```bash
lsof -ti:3000 | xargs kill -9
```

Then re-run the Flutter command.

### PostgreSQL connection refused

Make sure Docker Desktop is running and containers are up:
```bash
docker-compose ps
```

If PostgreSQL isn't healthy, restart:
```bash
docker-compose down && docker-compose up -d
```

Wait 5-10 seconds for the healthcheck to pass before starting the Go backend.

### Port 5432 already in use (local PostgreSQL conflict)

If you have a local PostgreSQL installation, it may conflict with Docker's PostgreSQL:
```bash
lsof -ti:5432 | xargs kill -9
docker-compose up -d
```

### Database needs a fresh start

```bash
docker-compose down -v && docker-compose up -d
```

The `-v` flag removes the PostgreSQL volume. Re-run with `SEED_DATA=true` to repopulate.

---

## Demo Roles

Log in with any of the 7 roles via the dev login screen:

| Role | What you can do |
|---|---|
| Field Reporter | Create incidents |
| Safety Coordinator | Manage investigations/CAPAs, link incidents |
| Safety Manager | Approve investigations, assign investigators, configure system |
| PM | View project-scoped data |
| Division Manager | View division-scoped data |
| Executive | View all data (read-only) |
| Admin | Configure system settings, view audit log |

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `D` | Go to Dashboard |
| `I` | Go to Incidents |
| `V` | Go to Investigations |
| `C` | Go to CAPAs |
| `Ctrl+K` | Toggle AI chat |
| `?` | Show shortcut overlay |
| `Esc` | Close panels |
