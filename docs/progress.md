# Feature Progress

> Updated before every commit. Tracks what's built vs what's planned.

---

## Done

| Feature | Details |
|---|---|
| Flutter multi-platform scaffold | iOS, Android, Web, macOS, Windows — all build and run |
| go_router navigation | 4 routes configured, works on web with URL handling |
| Drift local database | Notes table with CRUD, works on mobile (SQLite) and web (WASM) |
| Auth system (3-layer) | Dev login (role picker for demo) + Firebase Auth (real SSO) + provider-agnostic Go middleware (Azure AD-ready) |
| RBAC (7 roles) | Field Reporter, Safety Coordinator, Safety Manager, PM, Division Manager, Executive, Admin |
| Go backend | Go API server with GORM ORM, health/sync/data/chat endpoints, JWT auth middleware |
| PostgreSQL (via GORM) | Auto-migrating ORM — agents define tables as Go structs, no SQL migrations needed |
| Sync service | API-first: Flutter → Go API → PostgreSQL. Drift available for local caching (offline sync deferred). |
| connectivity_plus | Real-time online/offline detection, tested on web |
| Ollama + Qwen 2.5 7B | Installed, serving, responds to prompts via REST API |
| Wiki-as-RAG | Wiki injected into Qwen system prompt, answers questions accurately from context |
| Wiki auto-generation | Claude regenerates wiki before every commit (CLAUDE.md instruction) |
| Herzog branding | Full theme system: Oswald headings, Roboto body, gold accents, navy actions, KPI cards, status badges |
| AutoResearch eval loop | 5/5 evals passing — wiki RAG context validated, pattern proven for post-build optimization |
| Playwright setup | Installed, browser downloaded, test scripts run against Flutter web |
| Multi-agent development system | 4-agent team (TPM + 2 SWEs + QA) with embedded skills (see below) |
| CLAUDE.md orchestration | Central config with rules, key files, automated instructions |
| Monorepo structure | flutter/, backend/, deploy/, playwright/, eval/ |
| Docker-compose | Go + PostgreSQL + Ollama — full local dev stack |
| Auto-format hook | `dart format` + `gofmt` run automatically after every file write |
| Code style enforcement | Effective Dart + Effective Go referenced in agent definitions, linters active |
| Task tracking | GitHub Issues via `gh` CLI — sole source of truth |
| Agent worktree isolation | All agents work in separate git worktrees. SWEs open PRs, peer review each other, author merges |
| Agent conversation logging | Each agent logs exchanges to docs/conversations/[agent-name].md |
| Agent Teams launch prompt | Production + validation test prompts documented in architecture.md |
| AutoResearch guide | Full post-build optimization process documented |
| macOS network entitlements | network.client added for API/Ollama access |
| Drift WASM web setup | sqlite3.wasm + drift_worker.js configured, CORS headers documented |
| Feature-first architecture | flutter/lib/ restructured: app/, core/, features/, shared/ |
| API config (centralized) | `ApiConfig.baseUrl` and `ApiConfig.ollamaUrl` — single source of truth for all endpoints |
| Sync service | Drift → Go API → PostgreSQL. Uses `ApiConfig.baseUrl` (overridable via `--dart-define=API_PORT`), JWT auth placeholder ready |
| Project documentation | Architecture, requirements, branding, accessibility, presentation, setup, conversations |

### Multi-Agent Skills & Training

Each agent is trained with embedded skills in their definition files (`.claude/agents/`):

| Skill | Agents | Description |
|---|---|---|
| SOLID Principles | SWE-1, SWE-2 | All five principles enforced on every design decision |
| Effective Dart | SWE-1, SWE-2 | Official Dart style guide, auto-formatted via `dart format` |
| Effective Go | SWE-1, SWE-2 | Official Go style guide, auto-formatted via `gofmt` |
| API-first pattern | SWE-1, SWE-2 | Flutter → Go API → PostgreSQL (Drift for local caching) |
| ADA/WCAG compliance | SWE-1, SWE-2, QA | Semantic widgets, contrast ratios, focus indicators, keyboard nav |
| Herzog brand system | SWE-1, SWE-2 | Oswald headings, Roboto body, full color palette |
| Feature-first architecture | SWE-1, SWE-2 | Monorepo structure with self-contained feature directories |
| GORM database patterns | SWE-1, SWE-2 | Define tables as Go structs, register in AllModels() |
| New feature checklist | SWE-1, SWE-2 | Step-by-step guide: Flutter UI → Go API → GORM model → route registration |
| Dev environment setup | SWE-1, SWE-2 | docker-compose up + flutter run commands embedded in prompt |
| API config pattern | SWE-1, SWE-2 | Use ApiConfig.baseUrl for all API calls, never hardcode URLs |
| Shared file conflict prevention | TPM, SWE-1, SWE-2 | Coordinate access to app_router.dart, main.go, models.go |
| Error handling pattern | SWE-1, SWE-2 | API failure → SnackBar + fall back to local Drift data, never crash |
| Health check verification | SWE-1, SWE-2, QA | Verify `curl localhost:8000/health` before starting work |
| API surface awareness | TPM | Check existing routes and models before assigning work to prevent duplication |
| Test data seeding | QA | Test user credentials and API-based seed data for authenticated flows |
| Playwright testing | QA | Write and run automated browser tests against Flutter web |
| ADA audit | QA | Validate contrast, focus, keyboard nav, zoom, semantic structure |
| Worktree isolation | All | Each agent works in a separate git worktree |
| Thought logging | All | Brief 2-4 line developer notes after every task |
| Conversation logging | All | Log exchanges to docs/conversations/[agent-name].md |
| Task difficulty rating | TPM | Trivial / Routine / Complex / Critical classification |
| Task management | TPM | Creates and manages GitHub Issues via `gh` CLI |
| QA coordination | TPM | Manages SWE pause/resume around QA worktree cycles |
| Difficulty-based model routing | TPM | Trivial/Routine → Sonnet, Complex/Critical → Opus. TPM sets model at spawn time |

### Skills-per-Agent Matrix

| Skill | TPM | SWE-1 | SWE-2 | QA |
|---|---|---|---|---|
| SOLID Principles | | x | x | |
| Effective Dart | | x | x | |
| Effective Go | | x | x | |
| API-first pattern | | x | x | |
| ADA/WCAG compliance | | x | x | x |
| Herzog brand system | | x | x | |
| Feature-first architecture | | x | x | |
| GORM database patterns | | x | x | |
| New feature checklist | | x | x | |
| Dev environment setup | | x | x | |
| API config pattern | | x | x | |
| Shared file conflict prevention | x | x | x | |
| Error handling pattern | | x | x | |
| Health check verification | | x | x | x |
| API surface awareness | x | | | |
| Test data seeding | | | | x |
| Playwright testing | | | | x |
| ADA audit | | | | x |
| Worktree isolation | x | x | x | x |
| Thought logging | x | x | x | x |
| Conversation logging | x | x | x | x |
| Task difficulty rating | x | | | |
| Task board management | x | | | |
| QA coordination | x | | | |
| Difficulty-based model routing | x | | | |
| **Total** | **11** | **18** | **18** | **9** |

## In Progress

| Feature | Status | What's Left |
|---|---|---|
| TestFlight distribution | Waiting on Apple Developer approval | Upload first build once approved |
| Agent Teams validation | Alex testing in CLI | Confirm team spawns and coordinates |

## Not Started — Rubric Features (SRD-10)

| Feature | Notes |
|---|---|
| Incident reporting | Full form with 7 types, GPS auto-fill, photos, draft save, completion %, OSHA decision tree, railroad notification tracking, injured person details |
| Investigation management | Assign investigator, auto-deadlines by severity, 5-Why interactive chain, contributing factor classification (configurable via admin UI), witness statements, review/approval workflow |
| CAPA management | Create from investigations, priority-based due dates, lifecycle with effectiveness verification, verifier != assignee (verify button hidden from assignee), dashboard with KPIs |
| Safety dashboard | TRIR/DART/Near Miss KPIs, trend charts, incidents by division, severity donut, leading indicators, recent incidents table, TRIR benchmark configurable via admin settings |
| Manual recurrence linking | Link incidents by similarity type, cluster view |
| Admin settings page | Configurable factor types, TRIR industry benchmark, system settings |
| Audit log viewer | UI for browsing immutable audit trail — Admin and Safety Manager access |
| Medical data encryption | Application-level encryption for injured person fields in Go backend |
| RBAC route protection | 7 roles with scoped UI and API permissions per rubric |
| Draft incident visibility | Drafts visible only to reporter |

## Not Started — Supporting Features

| Feature | Notes |
|---|---|
| In-app AI agent (page nav + form filling) | JSON action dispatch to go_router/TextEditingController. Not started. |
| Keyboard shortcuts | Flutter Shortcuts/Actions system. Not started. |
| Playwright test suite | QA agent writes tests during hackathon. Infrastructure ready. |
| Claude browser agent QA | Secondary QA — exploratory validation. |
| ADA/WCAG compliance | Built into every feature during hackathon — requirement per accessibility.md |

## Post-Hackathon

| Feature | Notes |
|---|---|
| AutoResearch Phase 1 | Optimize agent prompts against eval test cases. |
| AutoResearch Phase 2 | Optimize Qwen with app-specific training. |
| Agent personas post-build | Upload personas + logs to Claude project for interactive Q&A. |
| Horizontal scaling (Go backend) | Stateless API design enables multi-container scaling. No code changes needed. |
| Ollama load balancing | Multiple Ollama instances behind a load balancer or request queuing. |
