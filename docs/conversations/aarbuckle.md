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
