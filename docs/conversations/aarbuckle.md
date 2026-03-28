# Conversation Log — Alex Arbuckle (2026-03-27)

---

## Decisions Made

### Resolved

| Decision | Resolution |
|---|---|
| Parent DB | **PostgreSQL via Go API** — relational match with Drift/SQLite, GORM ORM for auto-migration. Firebase retained for auth only. |
| Primary build environment | **Claude Code CLI** — all development, agent teams, and Alex's contributions happen here |
| 7B model selection | **Qwen 2.5 7B** — strong coding/reasoning, good fit for in-app assistant |
| Playwright role | **Primary QA tool** — QA agent writes Playwright tests for every PR. Claude browser agent is secondary for exploratory validation |
| AutoResearch depth | **Deferred** — ship with base Qwen 2.5 7B + wiki-as-RAG during hackathon. AutoResearch optimization is post-build |
| App Store review | **Not needed** — distributing via TestFlight (beta), skips review entirely |
| Chrome extension for QA | **Not building one** — using Anthropic's existing Claude browser agent |
| Number of SWE agents | **2 full-stack agents** — identical capabilities, TPM assigns whole features not frontend/backend slices |
| DevOps agent | **Removed** — Alex owns CI/CD, pipelines, TestFlight, GitHub Actions personally |

---

## Architecture Decisions

### Agent Team Structure (Final)
```
Alex ← CI/CD, pipelines, TestFlight, GitHub Actions, infrastructure
 └── TPM (sole point of contact)
       ├── SWE 1 (Full-Stack)
       ├── SWE 2 (Full-Stack)
       └── QA (Playwright + exploratory)
```

- 4-agent team: TPM + 2 SWEs + QA
- Both SWE agents are identically capable full-stack developers
- Thought logging is required but kept brief (2-4 lines, developer notes not reports)
- Alex can talk directly to individual agents if needed, but default flow is TPM-only

### AutoResearch Two-Phase Play
- **Phase 1:** Optimize agent definition prompts against eval test cases (better developers)
- **Phase 2:** Optimize Qwen 2.5 7B with app-specific wiki/docs (better in-app assistant)
- Same pattern, two applications — strong judge narrative

### Agent Personas Post-Build Feature
- After hackathon, upload each agent's persona + conversation logs into a Claude project
- When someone asks about a feature, the agent who built it surfaces and responds with firsthand knowledge
- Full parent system prompt was written and documented in docs/requirements.md

### Wiki Pipeline
- Claude regenerates `docs/wiki.md` before every commit → copies to `flutter/assets/wiki.md` → Flutter bundles it → Ollama reads as RAG context

### Offline-First Data Flow
```
User Action → Drift (local) → Sync Queue → Go API → PostgreSQL (when online)
```
- connectivity_plus detects network state
- SyncService auto-triggers on offline → online transition
- Records tracked with `synced` boolean column

---

## Files Created

### Documentation (docs/)
| File | Purpose |
|---|---|
| `docs/overview.md` | Project overview, tech stack, engineering principles |
| `docs/architecture.md` | Data architecture, multi-agent system, QA strategy, wiki pipeline |
| `docs/requirements.md` | Feature requirements, distribution, agent personas post-build prompt |
| `docs/branding.md` | Full Herzog brand system (typography, colors, components, dark mode, layouts) |
| `docs/accessibility.md` | ADA/WCAG specs, contrast ratios, focus indicators, motion |
| `docs/presentation.md` | Judge-facing narratives and talking points |
| `docs/checklist.md` | Validation items, open decisions, resolved contingencies |
| `docs/caveats.md` | Gotchas, constraints, raw ideas, scratch notes |

### Agent Definitions (.claude/agents/)
| File | Purpose |
|---|---|
| `tpm.md` | TPM/orchestrator — breaks features into tasks, assigns to SWEs, manages GitHub Issues |
| `swe-1.md` | Full-stack developer — owns features end-to-end |
| `swe-2.md` | Full-stack developer — identical to SWE 1 |
| `qa.md` | QA engineer — Playwright scripts primary, Claude browser agent secondary |

### App Code (lib/)
| File | Purpose |
|---|---|
| `lib/main.dart` | App entry point with go_router and Herzog theming |
| `lib/router/app_router.dart` | 4 routes: home, drift test, connectivity test, ollama test |
| `lib/database/app_database.dart` | Drift schema with Notes table (id, content, createdAt, synced) |
| `lib/database/connection.dart` | Platform-aware database constructor (SQLite native + WASM web) |
| `lib/pages/home_page.dart` | Infrastructure status — test cards with Herzog styling |
| `lib/pages/drift_test_page.dart` | Drift read/write test + sync trigger |
| `lib/pages/connectivity_test_page.dart` | Real-time online/offline detection display |
| `lib/pages/ollama_test_page.dart` | HTTP calls to Qwen 2.5 7B with latency tracking |
| `lib/services/sync_service.dart` | Offline-first sync: Drift → Go API → PostgreSQL |

### Config
| File | Purpose |
|---|---|
| `CLAUDE.md` | Central orchestration file — auto-loaded by Claude Code every session |
| `.gitignore` | macOS, IDE, Flutter, Firebase, Ollama, logs, secrets |
| `pubspec.yaml` | Flutter dependencies (go_router, drift, connectivity_plus, firebase, http) |

---

## Tools Installed

| Tool | Version | Purpose |
|---|---|---|
| Ollama | 0.18.2 | Local LLM serving |
| Qwen 2.5 7B | 4.7 GB | In-app assistant model (downloaded and tested) |
| tmux | 3.6a | Agent Teams split-pane view |

Already installed: Flutter 3.41.4, Xcode 26.3, Playwright 1.58.2

---

## Flutter Project Setup

- Scaffolded with `flutter create --org com.herzog --project-name the_march_project`
- Platforms: **iOS, Android, Web, macOS, Windows** (5 platforms, one codebase)
- Dependencies added: go_router, drift, drift_flutter, connectivity_plus, firebase_core, firebase_auth, http, fl_chart, image_picker, geolocator, intl, uuid, encrypt, path_provider
- Dev dependencies: drift_dev, build_runner
- Web build verified: `flutter build web` passes
- macOS build verified: `flutter run -d macos` compiles and launches
- Drift code generation verified: `dart run build_runner build` succeeds

---

## Key Insights

1. **Alex is new to Flutter.** Frame explanations clearly, don't assume familiarity with Dart syntax, widget trees, or Flutter conventions.

2. **Alex owns infrastructure, agents own features.** Clean separation — no DevOps agent needed.

3. **"orchestrator" is not a required keyword** for Agent Teams. Renamed to `tpm.md`.

4. **Agent Teams creates teams dynamically** from natural language prompts, not strictly from pre-defined files. Agent definition files serve as reference instructions.

5. **TestFlight skips App Store review entirely.** No expedited review needed.

---

## Conversation Highlights

- "what are the pros vs cons of using one versus the other?" (Supabase vs Firebase)
- "I'll go Firebase"
- "i will own the pipeline and ci/cd so you dont have to worry about that. remove the devops agent. however each subagent will still have to do logging"
- "an swe agent is going to be responsible for the frontend and backend right? i sort of want full stack developers"
- "i'll keep it at 2 full stacks"
- "i definitely want to write playwright tests, this is very important to me"
- "we'll go with Qwen"
- "i like the idea of using autoresearch to optimize qwen with our program instructions"
- "I'm solo. The fallback is just me doing it myself and you helping me."
- "so can you give a one-sentence explanation as to where we're at right now? i've never used flutter"
- "bingo. it worked!" (connectivity pass)
- "I just realized are we running a 9b model on our system right now? lol"
- "okay so we really have an authentic more-permanent database other than what saves locally?"
- "kind of like how python has PEP/standardization I need Flutter and Go to follow standardization"
- "can you add a new skill to our agents for SOLID Principles?"
- "can you do some self-reflection and imagine us stress-testing this application with features, see if we missed anything?"
- "what is the possibility that we label each ticket with a difficulty level and the swe agents automatically adjust which LLM they use?"
- "OH okay so a TPM agent is capable of spawning sub agents"
- "okay then lets go this route, but I want the Trivial difficulty to use Sonnet"
- Approved plan: difficulty-based model routing (Trivial/Routine → Sonnet, Complex/Critical → Opus)
- "I think it would be nice to iterate through every one of these rubric categories during our presentation"
- "I want you to help me build a prompt that emulates the respective agents talking to judges"
- "if someone presents a problem in my code I don't want to awkwardly admit guilt. I'd like to present a solution"
- "I am not an agent, if a judge asks a question I don't want someone emulating me"
- "how are we setup with Go? do you see any scalability problems?" (stateless, horizontally scalable, Ollama is the bottleneck)
- New architecture: Go backend, PostgreSQL, monorepo — decided Firebase auth + Go data layer
- GORM wired up, database/migrations removed
- Caddy reverse proxy config: themarchproject.lxrbckl.com → :2780
- Set up GitHub OAuth App for themarchproject.lxrbckl.com
- Multiple stress test rounds (9 rounds) — found and fixed worktree branch issues, pubspec.lock, ApiConfig prod URL, Ollama chat proxy, auth flow, CORS headers, iOS Podfile
- Created docs/judge-session-prompt.md — post-build Claude project prompt for judge Q&A
- Added criticism handling, origin credit, and "never emulate Alex" rules to agent personas

---

## 2026-03-27 — Morning

### Repo Setup & Rename
- Copied flutter/ and backend/ into highlander repo
- Updated all Go import paths to `github.com/lxRbckl/highlander/backend`
- Updated database credentials across docker-compose, main.go, setup.md
- Updated worktree paths in all agent definitions to ../highlander-*
- Updated CLAUDE.md: title to "SafeTrack", description to SRD-10, worktree paths, key files
- Updated web/index.html and manifest.json titles to "SafeTrack"
- Verified Go compiles and Flutter resolves after all changes

### Documentation Cleanup
- Renamed docs/poc-checklist.md → docs/checklist.md
- Updated docs/overview.md to describe current project state with rubric reference
- Updated docs/wiki.md and flutter/assets/wiki.md titles and descriptions
- Cleaned up docs/conversations/aarbuckle.md — merged session logs
- Updated Playwright test file and package.json references

### Rubric Clarifications
- Received and documented 13 implementation clarifications in docs/rubric.md
- GPS auto-fill: developer's call
- Photos: no limit
- Completion %: equal weight all fields
- 5-Why chain: interactive (ADA-friendly)
- Contributing factor types: configurable via admin UI
- Verify button: hidden from assignee
- TRIR benchmark: configurable via admin settings
- Medical encryption: application-level (AES-256-GCM)
- Draft visibility: reporter only
- Total hours: literal man-hours entered by Safety Manager
- Escalation notifications: developer's call
- Cluster view: developer's call
- Audit log: UI viewer required (judges want to see it)

---

## 2026-03-27 — Afternoon

### Backend Infrastructure
- Created backend/internal/crypto/encrypt.go — AES-256-GCM encryption module for medical data
- Created backend/internal/models/audit_log.go — immutable audit log model
- Created backend/internal/handlers/audit_logs.go — LogAction() helper + paginated GET /api/audit-logs
- Registered AuditLog in AllModels()
- Split routes in main.go: public (/health, /api/chat) vs authenticated (everything else behind FirebaseAuth middleware)
- Added GET /api/audit-logs route

### New Documentation
- Created docs/backend-patterns.md — GORM models, handlers, routes, encryption, audit logging, RBAC, error handling
- Created docs/admin-settings-pattern.md — Settings model, seed data, Flutter page pattern
- Created docs/judge-session-prompt.md — post-build Claude project prompt for judge Q&A

### Flutter Dependencies
- Added fl_chart, image_picker, geolocator, intl, uuid, encrypt, path_provider to pubspec.yaml

### Agent Definition Updates
- Updated SWE-1 and SWE-2 feature checklists to 11 steps (encryption, audit logging, admin settings)
- Added "Before Starting a Task" instructions: read rubric Implementation Clarifications + backend-patterns.md
- Updated QA agent with specific RBAC test rules (hidden verify button, draft visibility, audit log access)
- Switched to GitHub Issues as sole source of truth for task tracking

### Settings & Config
- Generated clean .claude/settings.json with permissions, hooks (dart format + gofmt), and bypassPermissions
- Added launch command to CLAUDE.md for spinning up agent team
- Added judge-session-prompt.md reference to CLAUDE.md with Claude project URL
- Set up gh auth login and created difficulty labels (trivial, routine, complex, critical, bug)

### Playwright
- Installed Playwright dependencies and Chromium
- Created playwright.config.ts
- Updated home.spec.ts tests — 3/3 passing (page loads, no JS errors, bootstrap script present)

### Stress Testing
- Ran multiple comprehensive stress tests across all docs, agents, and code
- All categories pass: broken references, stale content, cross-doc consistency, agent workflow readiness, build verification, missing files
- Go compiles, Flutter resolves, gh CLI authenticated, Playwright operational

### Build Planning
- Spawned two planning agents to independently analyze the rubric and cross-reference against each other
- Agent A produced a 16-task breakdown covering all rubric features
- Agent B validated line-by-line against rubric.md, requirements.md, progress.md, presentation.md, and checklist.md
- Both agents converged: all rubric features are covered within the 16 tasks' detailed specs
- Identified 3 genuinely missing features from requirements.md (not rubric): in-app AI chat widget, keyboard shortcuts, in-app AI agent
- Added TASK-017/018/019 for those differentiators (Phase 5, if time permits)
- Created docs/build-plan.md — comprehensive 19-task plan across 5 phases with parallelism map, difficulty ratings, shared file coordination, and full QA specs per task
- Final task statistics: 10 Routine, 8 Complex, 1 Critical. 10 assigned to SWE-1, 9 to SWE-2
- Added judge-session-prompt.md to docs for post-build Claude project Q&A
- Added launch command to CLAUDE.md so any session can retrieve the agent team spawn prompt
- Updated conversation logging format in CLAUDE.md: Morning/Afternoon/Evening with categorized sub-headings

### Build Plan Validation & Refinement
- Ran two additional agent validation passes against the 19-task plan
- First pass found 6 issues: missing CAPA In Progress status transition, 3 shared file conflicts in parallelism map, PM project-scoping gap, audit log missing filters, Draft not in status flow, InjuredPerson model ambiguity
- Applied all 6 fixes to build-plan.md
- Ran second validation pass (2 agents) to verify fixes — all applied correctly
- Final pass found 2 remaining items: TASK-012 difficulty upgraded Routine → Complex, admin settings access expanded to Safety Manager + Admin (per rubric RBAC table)
- Final result: 46/46 rubric requirements covered, 13/13 implementation clarifications reflected, 7/7 RBAC roles enforced, all formulas implemented, full status flow verified, all deferred items excluded
- Verified all requirements.md features mapped: LLM + wiki pipeline already built, keyboard shortcuts + AI agent in Phase 5, ADA cross-cutting, agent personas post-hackathon, distribution is Alex's domain
- Updated task statistics: 9 Routine, 9 Complex, 1 Critical

### Pre-Launch Stress Testing (Multiple Rounds)
- Spawned two stress-test agents to anticipate problems across frontend, backend, GitHub workflow, and agent coordination
- **Round 1** found 6 blockers + 7 high-priority issues:
  - go.mod missing JWT library — added `golang-jwt/jwt/v5`
  - No state management — added Provider to pubspec.yaml + rule in CLAUDE.md
  - Flutter canvas blocks Playwright testing — enabled semantics mode in main.dart
  - Offline-first contradiction — updated CLAUDE.md rule to API-first (offline sync deferred per rubric)
  - GORM relationships not documented — added HasMany/Preload patterns to backend-patterns.md
  - Auth middleware using headers instead of request context — created helpers.go with GetUserRole/GetUserID, updated auth.go to use context.WithValue
  - Route registration helpers, handler splitting guidance, completion % pattern, business day calculator all added to backend-patterns.md
  - Herzog theme extended with NavigationRail, TabBar, DataTable, Chip, SnackBar, chart color palette
  - SWE agent feature directory standardized (pages/, widgets/, data/)
  - TPM instructed to create GitHub Issues upfront per phase
  - Playwright config updated with PLAYWRIGHT_BASE_URL env var for QA port override
- **Round 2** found auth.go still didn't match documented pattern, build-plan TASK-001 still said "headers", CreateIncident example used client-supplied data, /api/chat was public, audit log had no RBAC check, SWE agents still referenced offline-first + headers:
  - Created middleware/helpers.go with real GetUserRole/GetUserID functions
  - Rewrote auth.go to set context values (stub for TASK-001 JWT decoding)
  - Moved /api/chat behind auth middleware
  - Fixed CreateIncident example to use context-derived identity
  - Updated build-plan TASK-001 to say context.WithValue
  - Removed all "offline-first" and "header" references from SWE agents
  - Fixed SWE agent directory tree (presentation/ → pages/)
  - Updated error handling ("must always work offline" → "degrade gracefully with retry")
- **Round 3** found offline-first language remaining in wiki.md, presentation.md, progress.md, architecture.md, overview.md:
  - Updated all 7 files to API-first language
  - Confirmed both wiki copies (docs/ + flutter/assets/) are consistent
- **Round 4 (final)** — all 8 checks pass, zero issues remaining
- Go compiles, Flutter resolves after every round of changes

### Build Plan Final Alignment Check
- Verified build-plan.md matches actual codebase state after all stress test fixes
- Found 3 minor discrepancies: TASK-001 missing Provider pattern, TASK-012 filter/RBAC clarity, auth service path
- Fixed all 3 — plan and codebase fully in sync
- Confirmed every stress test fix is reflected in the build plan
- Backend structure is clean, canonical Go layout, ready for agent expansion

---

## 2026-03-27 — Evening

### Agent Team Launch
- Launched multi-agent team via Claude CLI with build-plan launch prompt
- TPM created GitHub Issues for Phase 0 and spawned SWE-1 + SWE-2 in parallel
- Agents immediately began building TASK-001 (Dev Login) and TASK-002 (App Shell)

### Full Build Execution — 19/19 Tasks Complete
- **Phase 0 (Foundation):** TASK-001 ✅ TASK-002 ✅ TASK-003 ✅
- **Phase 1 (Incident Reporting):** TASK-004 ✅ TASK-005 ✅
- **Phase 2 (Investigation + CAPA):** TASK-006 ✅ TASK-007 ✅ TASK-008 ✅ TASK-009 ✅ TASK-010 ✅
- **Phase 3 (Dashboard + More):** TASK-011 ✅ TASK-012 ✅ TASK-013 ✅
- **Phase 4 (Hardening):** TASK-014 ✅ TASK-015 ✅ TASK-016 ✅
- **Phase 5 (Differentiators):** TASK-017 ✅ TASK-018 ✅ TASK-019 ✅

### What Was Built
- Incident reporting (7 types, OSHA 29 CFR 1904 decision tree, railroad deadlines, GPS, photos, completion %, medical encryption)
- Investigation management (interactive 5-Why chain, configurable contributing factors, witness statements, Safety Manager approve/return)
- CAPA lifecycle (verify button hidden from assignee, ineffective → new CAPA/reopen, KPI dashboard)
- Safety dashboard (TRIR/DART/Near Miss with fl_chart, configurable benchmark, leading indicators)
- Manual recurrence linking with union-find cluster view
- Audit log viewer with expandable JSON diffs
- Escalation notifications (bell badge, +3/+7/+14 day thresholds)
- Full RBAC across 7 roles (PM project-scoped, Division Manager division-scoped, Executive read-only)
- Application-level medical data encryption (AES-256-GCM)
- Comprehensive seed data for demo (18 incidents, 7 investigations, 14 CAPAs)
- AI chat widget with Qwen 2.5 7B (graceful Ollama degradation)
- Keyboard shortcuts (D/I/V/C navigation, Ctrl+K chat, ? overlay)
- AI agent with JSON action dispatch (page nav + form filling)
- Herzog branding across 51 files — Oswald headings, Roboto body, gold/navy palette
- 12+ Playwright test suites (7,157 lines of test code)

### Build Stats
- 19 tasks, 40 PRs, every PR peer-reviewed + QA tested before merge
- Difficulty-based model routing: Routine → Sonnet, Complex/Critical → Opus
- TPM managed merge ordering, rebase conflicts, and shared file coordination throughout

### Bugs Caught by Peer Review & QA
| Bug | Caught By | How Found |
|---|---|---|
| Admin route gate excluded Safety Manager | QA | Tested all 7 roles, filed Issue #10 |
| Escalation thresholds wrong (8+ → 14+ days) | Peer Review | SWE caught incorrect constants |
| Unused Go variable (compiler reject) | Peer Review | Code review |
| TRIR/DART YTD scoping mismatch | Peer Review | Dashboard query not scoped to current year |
| Missing role guard on GET /api/hours-worked | Peer Review | Endpoint accessible to all roles |
| LostWorkDaysYTD naming (counted incidents not days) | Peer Review | Metric logic error |
| N+1 query in recurrence linking | Peer Review | Batch query missing |
| Missing Playwright spec | Peer Review | Feature PR had no test file |
| ChatRepository injection missing | Peer Review | Provider not wired |
| Missing ADA liveRegion on chat | Peer Review | Accessibility gap |
| Keyboard shortcut / not guarded in text fields | Peer Review | Would trigger while typing |
| Unreliable text field check for shortcuts | Peer Review | Edge case in focus detection |
| CAPAs tab was placeholder | Integration Testing | TASK-016 found during E2E |
| Close/Reopen buttons missing from incident detail | Integration Testing | TASK-016 found |
| PM/Division Manager saw unauthorized action buttons | Integration Testing | isAtLeast too permissive for orthogonal roles |

### Key Observations
- Zero manual intervention required during the entire build
- Agents followed backend-patterns.md (handler splitting, GORM relationships, context auth, audit logging)
- QA caught real bugs and filed GitHub Issues — TPM triaged them into subsequent tasks
- The entire SRD-10 rubric spec implemented in one evening session

### Project Rename: Highlander → SafeTrack
- Renamed project from "Highlander" to "SafeTrack" across all user-facing files
- Updated: CLAUDE.md, README.md, main.dart, index.html, manifest.json, wiki.md (both copies), role.dart, auth_service.dart, chat_widget.dart
- Did NOT change: GitHub repo name, Flutter package name (pubspec.yaml), Firebase bundle IDs, domain name

---

## 2026-03-28 — Late Night

### Local Dev Setup & README Cleanup
- Diagnosed PostgreSQL connection refused error — Docker Desktop wasn't running
- Fixed port 3000 already in use (stale Flutter process)
- Fixed Go module error — `go run ./backend/cmd/server/` must be run from `backend/`, not project root
- Fixed README.md seed command: `SEED_DATA=true go run ./backend/cmd/server/` → `cd backend && SEED_DATA=true go run ./cmd/server/`
- Simplified README for judges: condensed from 122 to ~70 lines, collapsed troubleshooting into a table
- Added "Stopping Everything" section with `docker-compose down` instructions
- Added table of contents with anchor links
- Added suggested walkthrough hint for judges (Field Reporter → Safety Manager)
- Added `cd ..` to all README commands so judges stay in project root
- Restored troubleshooting table format (preferred over code blocks)
- Added troubleshooting entry for empty AI assistant responses

### AI Assistant Fix & Docker Compose Improvement
- Diagnosed empty AI chat responses — Ollama model was wiped by `docker-compose down -v`
- Added `ollama-pull` init service to `docker-compose.yml` — Qwen 2.5 7B now auto-pulls on startup
- No more manual `ollama pull` step required; survives volume wipes
- Verified full teardown/startup cycle: `down -v` → `up -d` → seed → all services healthy
- Updated README to reflect AI chat is now automatic (~30s delay on first start)

### Keyboard Shortcut Updates
- Changed navigation shortcuts from single-letter (D/I/V/C) to Alt+D/I/V/C — prevents accidental triggers while typing
- Changed chat toggle from Ctrl+K to Alt+K for consistency with Alt+ convention
- Updated overlay, sidebar badges, README, wiki, and build-plan references
- Sub-agents handled both changes: PR #44 (Alt nav) and PR #46 (Alt+K chat), both QA verified

### Documentation Sweep
- Searched entire codebase for stale keyboard shortcut references
- Updated build-plan.md with Alt+ shortcuts
- Regenerated wiki.md — was severely outdated (still had POC routes), now covers all 17 routes, features, roles, shortcuts
- Confirmed conversation logs are historical records — left old references as-is

### Phase 6 Roadmap
- Added Phase 6 to build-plan.md with 7 future tasks from rubric's deferred items
- TASK-020: User authentication (login page + seeded accounts)
- TASK-023: Offline incident reporting (Drift + connectivity_plus POC already exists)
- TASK-024: Fishbone/Ishikawa diagram
- TASK-025: Automated recurrence detection
- TASK-026: Advanced analytics (body heat map, time heatmap, radar chart)
- TASK-027: OSHA 300/300A/301 log generation
- TASK-028: Email/push notifications
- Discussed Training system CAPA integration — skipped because it requires external system that doesn't exist

### User Authentication Implementation
- Sub-agents built TASK-020 (login system): PR #48, peer reviewed + QA (22 checks) + merged
- Go: User model with bcrypt, POST /api/login, 12 seeded test users (shared password `demo1234`)
- Flutter: LoginPage with email/password form, tap-to-autofill test accounts card
- All seed data updated to reference real user IDs
- Dev login page and endpoint removed
- QA flagged: some Playwright specs still reference POST /api/dev-login (follow-up needed)
