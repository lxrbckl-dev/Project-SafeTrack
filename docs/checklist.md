# Checklist & Open Decisions

---

## Infrastructure Validation

These validate that the core infrastructure works correctly.

- [x] Flutter project scaffolds and runs on iOS, Android, and Web from single codebase
- [x] `go_router` navigation works across all platforms including web URL handling
- [x] Drift database works on mobile (native SQLite) and web (WASM) with identical schema code
- [x] `connectivity_plus` correctly detects online/offline state on all platforms
- [x] Offline write → sync queue → Go API → PostgreSQL works end-to-end
- [x] Go backend + GORM integrates with Drift sync pattern
- [x] Ollama serves Qwen 2.5 7B on Mac Mini M4 Pro with acceptable latency
- [x] Wiki content can be injected as RAG context into Ollama system prompt
- [ ] Claude Code Agent Teams mode enables and runs with multiple agents
- [x] Thought logging to `.logs/thoughts/` — instruction baked into all agent definitions, validates with Agent Teams
- [x] Playwright can test Flutter web output (connects and runs; text locators need Flutter semantics mode for full DOM access)
- [x] Flutter web build deploys and is accessible
- [x] Herzog branding renders correctly in Flutter (Oswald + Roboto fonts, color system)
- [ ] TestFlight build submits and installs successfully — **First build has a review delay (up to 24hrs). After that, subsequent builds are available in minutes.**
- [x] AutoResearch pattern validated (eval loop runs 5/5 evals against Qwen with wiki RAG — all passed)

---

## Validate During Hackathon (Needs Rubric / App Context)

These depend on knowing what the app actually does.

- [ ] In-app JSON action dispatch → `go_router` navigation works
- [ ] In-app JSON action dispatch → `TextEditingController` form filling works
- [ ] Flutter `Shortcuts`/`Actions` keyboard shortcuts work on web
- [x] Wiki auto-regeneration works via CLAUDE.md instruction (Claude regenerates before every commit)
- [ ] Wiki output can be bundled as a Flutter asset
- [ ] ADA compliance passes automated audit (e.g., Flutter accessibility checker)
- [ ] Claude browser agent can navigate and validate the Flutter web app

---

## Not Blocking (Documented, Not Actionable This Sprint)

---

## Open Decisions

- [x] **Parent DB:** PostgreSQL via Go API — relational match with Drift/SQLite, GORM ORM for auto-migration. Firebase retained for auth only.
- [x] **Primary build environment:** Claude Code CLI — all development, agent teams, and Alex's own contributions happen here
- [ ] **In-app agent action schema:** Define the JSON structure for navigation + form actions

### Resolved Contingencies
- **Team composition:** Solo (Alex + Claude agents only). No other humans.
- **Agent Teams fallback:** If experimental Agent Teams fails, fallback is Alex working directly with Claude Code in standard mode (no hierarchy, just direct collaboration)
- [x] **7B model selection:** Qwen 2.5 7B — strong coding/reasoning, good fit for in-app assistant with RAG context
- [x] **Playwright role:** Primary QA tool — QA agent writes and runs Playwright tests for every PR. Claude browser agent is secondary (exploratory validation)
- [x] **App Store expedited review:** Not needed — distributing via TestFlight (beta), which skips App Store review entirely. Upload build → share link → judges install immediately
- [x] **AutoResearch integration depth:** Deferred — ship with base Qwen 2.5 7B + system prompt + wiki-as-RAG during hackathon. AutoResearch optimization happens post-build once app is stable and wiki content exists. Use the pipeline as a judge-facing talking point ("continuous model improvement infrastructure")
