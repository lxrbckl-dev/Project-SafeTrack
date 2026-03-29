# Development Environment Setup

## Prerequisites

| Tool | Install | Purpose |
|---|---|---|
| Flutter | [flutter.dev/get-started](https://flutter.dev/docs/get-started/install) | Frontend framework |
| Go | `brew install go` | Backend API |
| Docker | [docker.com](https://www.docker.com/products/docker-desktop/) | PostgreSQL + containerized services |
| Xcode | Mac App Store | iOS + macOS builds |
| Node.js | [nodejs.org](https://nodejs.org) | Firebase CLI + Playwright |
| Homebrew | [brew.sh](https://brew.sh) | Package manager for macOS |

## Tool Installation

```bash
# Go (backend API)
brew install go

# Ollama (local LLM serving) — must run natively for Metal GPU acceleration
# Docker for Mac cannot access Metal, so Ollama runs as a native macOS service
brew install ollama
brew services start ollama
ollama pull qwen2.5:7b

# tmux (agent teams split-pane view)
brew install tmux

# Firebase CLI (auth only)
npm install -g firebase-tools
firebase login

# Playwright (QA testing)
npm install
npx playwright install chromium

# FlutterFire CLI (connects Flutter to Firebase Auth)
dart pub global activate flutterfire_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"

# xcodeproj (required by FlutterFire for iOS/macOS config)
sudo gem install xcodeproj
```

## Monorepo Structure

```
highlander/
├── flutter/              # Flutter frontend
├── backend/              # Go API server
├── backend/internal/models/  # GORM models (auto-migrated)
├── deploy/                # Docker, K8s, Terraform
├── playwright/                  # Playwright tests
├── eval/                 # AutoResearch evals
├── docs/                 # Project documentation
├── docker-compose.yml    # Local dev stack
└── CLAUDE.md             # Agent orchestration
```

## URLs & Services Reference

| Service | URL | Purpose |
|---|---|---|
| Firebase Console | `https://console.firebase.google.com/project/project-175f3` | Auth management, user accounts |
| Firebase Auth Handler | `https://project-175f3.firebaseapp.com/__/auth/handler` | OAuth callback URL |
| GitHub OAuth App | `https://github.com/settings/developers` | Manage OAuth client ID/secret |
| Production Web App | `https://highlander.lxrbckl.com` | Live web deployment |
| Local Flutter (dev) | `http://localhost:3000` | SWE dev server |
| Local Flutter (QA) | `http://localhost:3001` | QA test server |
| Local Go API | `http://localhost:8000` | Backend API |
| Local PostgreSQL | `localhost:5432` | Database (highlander/marchpass) |
| Local Ollama | `http://localhost:11434` | LLM (direct, dev only) |
| Go Chat Proxy | `http://localhost:8000/api/chat` | LLM via Go (production path) |

**Test accounts (seeded in database):** All use password `demo1234`
- `reporter@safetrack.demo` (Field Reporter)
- `coordinator@safetrack.demo` (Safety Coordinator)
- `manager@safetrack.demo` (Safety Manager)
- `pm@safetrack.demo` (Project Manager)
- `director@safetrack.demo` (Division Manager)
- `executive@safetrack.demo` (Executive)
- `admin@safetrack.demo` (Admin)

## Firebase Setup (Auth Only)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** → Email/Password
3. Enable **Multi-factor authentication** in Authentication → Settings
4. Connect to Flutter:
   ```bash
   cd flutter
   flutterfire configure --project=YOUR-PROJECT-ID --platforms=ios,android,web,macos
   ```

## Flutter Setup

```bash
cd flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Go Backend Setup

```bash
cd backend
go mod tidy
go build ./cmd/server/
```

## Local Dev Stack (Docker Compose + Native Ollama)

Start PostgreSQL (Docker) and Ollama (native):
```bash
docker-compose up -d postgres
brew services start ollama
```

This starts:
- **PostgreSQL** on `:5432` (Docker)
- **Ollama** on `:11434` (native, Metal GPU)

> **Why native Ollama?** Docker for Mac runs containers in a Linux VM that cannot access Metal GPU. Native Ollama gets Metal acceleration — sub-second inference vs 60s+ in Docker. The Docker backend container reaches native Ollama via `host.docker.internal:11434`.

## Drift Web (WASM) Requirements

Two files must exist in `flutter/web/`:
- `flutter/web/sqlite3.wasm` — from [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases)
- `flutter/web/drift_worker.js` — from [drift releases](https://github.com/simolus3/drift/releases)

When running the web build, CORS headers are required:
```bash
cd flutter
flutter run -d chrome \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```

## macOS Network Entitlements

macOS sandbox blocks network by default. Both entitlement files need `network.client`:
- `flutter/macos/Runner/DebugProfile.entitlements`
- `flutter/macos/Runner/Release.entitlements`

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Already configured in this repo.

## Wiki Generation

The wiki (`docs/wiki.md` and `flutter/assets/wiki.md`) is auto-regenerated by Claude before every commit. Commits should be done through Claude Code to ensure the wiki stays current.

---

## Deployment (Production)

**Host:** Mac Mini M4 Pro (192.168.68.200)
**Subdomain:** `highlander.lxrbckl.com`

**Caddy reverse proxy config (on host):**
```
highlander.lxrbckl.com {
    handle /api/* {
        reverse_proxy http://192.168.68.200:8000
    }
    handle {
        reverse_proxy http://192.168.68.200:2780
    }
}
```

**Architecture:**
```
Internet → Caddy (HTTPS/TLS) → :2780 → Flutter web (nginx container)
                                              ↕
                                    Go API (:8000) → PostgreSQL (:5432)
                                              ↕
                                    Ollama (:11434, native, Metal GPU)
```

**Ollama runs natively** (not in Docker) for Metal GPU acceleration:
```bash
brew services start ollama
ollama pull qwen2.5:7b
```

**Production docker-compose** — web, backend, and PostgreSQL in Docker; Ollama native:
```yaml
services:
  web:
    build:
      context: ./flutter
      dockerfile: ../deploy/docker/Dockerfile.web
    ports:
      - "2780:80"
    restart: unless-stopped

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - PORT=8000
      - DATABASE_URL=postgres://highlander:marchpass@postgres:5432/highlander?sslmode=disable
      - OLLAMA_URL=http://host.docker.internal:11434
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=highlander
      - POSTGRES_USER=highlander
      - POSTGRES_PASSWORD=marchpass
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U highlander -d highlander"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
```

**Nginx Dockerfile** (`deploy/docker/Dockerfile.web`):
```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        try_files $uri $uri/ /index.html; \
        add_header Cross-Origin-Opener-Policy same-origin; \
        add_header Cross-Origin-Embedder-Policy require-corp; \
    } \
}' > /etc/nginx/conf.d/default.conf
EXPOSE 80
```

## TestFlight Upload (iOS + macOS)

**Prerequisite:** Apple Developer account approved + code signing configured in Xcode.

```bash
# Build iOS
cd flutter
flutter build ipa

# The IPA is at: build/ios/ipa/the_march_project.ipa
# Upload via Xcode: Open Xcode → Window → Organizer → Distribute App
# Or via command line:
xcrun altool --upload-app -f build/ios/ipa/the_march_project.ipa -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD

# Build macOS
flutter build macos
# Open Xcode → Product → Archive → Distribute App → App Store Connect
```

**First build takes up to 24 hours for Apple review.** Subsequent builds are available in minutes.

**Reminder:** TestFlight uses one link for both iOS and macOS. Apple routes automatically.

---

**Deploy steps (web + backend):**
```bash
# Start Ollama natively (first time: install + pull model)
brew install ollama
brew services start ollama
ollama pull qwen2.5:7b

# Build Flutter web
cd flutter && flutter build web && cd ..

# Start Docker services (PostgreSQL + backend + web)
docker-compose up -d
```

---

## Run Commands

| What | Command |
|---|---|
| PostgreSQL (Docker) | `docker-compose up -d postgres` |
| Ollama (native) | `brew services start ollama` |
| Flutter web (Chrome) | `cd flutter && flutter run -d chrome --web-header=Cross-Origin-Opener-Policy=same-origin --web-header=Cross-Origin-Embedder-Policy=require-corp` |
| Flutter macOS | `cd flutter && flutter run -d macos` |
| Flutter iOS | `cd flutter && flutter run -d iphone` |
| Go backend (standalone) | `cd backend && go run ./cmd/server/` |
| Playwright tests | `npx playwright test` |
| Build Flutter web | `cd flutter && flutter build web` |
| Build Go binary | `cd backend && go build ./cmd/server/` |
