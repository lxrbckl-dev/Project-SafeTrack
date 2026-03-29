# Presentation Narrative

---

## Rubric-Aligned Presentation Structure

Structure the presentation to walk judges through each rubric category, demonstrating how we score in every one:

### 1. Functionality & Completeness
- Live demo: incident reporting → investigation (interactive 5-Why) → CAPA lifecycle → safety dashboard with TRIR/DART
- Show 7 RBAC roles via email/password login with seeded test accounts — each sees different UI
- Admin settings: configurable factor types, TRIR benchmark
- Audit log viewer: full traceability of every action
- Application-level medical data encryption
- Cross-platform: same app on iOS, macOS, Android, Web, Windows
- API-first architecture with offline caching infrastructure ready for future phase
- In-app AI assistant powered by Qwen 2.5 3B with auto-generated wiki context

### 2. AI Tool Effectiveness
- **This is our thesis.** Multi-agent development team:
  - 4 agents (TPM + 2 SWEs + QA) with 56 combined embedded skills
  - Difficulty-based model routing (Trivial/Routine → Sonnet, Complex/Critical → Opus)
  - AutoResearch pattern for continuous improvement (agent prompts + Qwen optimization)
  - Wiki-as-RAG: auto-regenerated on every commit, injected into the in-app assistant
- Show the agent conversation logs, thought logs, and task board as evidence of AI-driven development
- Show the skills matrix — agents trained with SOLID principles, Effective Dart/Go, ADA compliance, etc.

### 3. Architecture & Design
- Monorepo: flutter/, backend/, deploy/, playwright/, eval/
- Go backend + PostgreSQL (relational match with Drift/SQLite — no translation layer)
- Two-layer auth: email/password login (seeded demo accounts, bcrypt + JWT) + Azure AD-ready (provider-agnostic Go middleware — swap issuer config, no code changes)
- 7 RBAC roles with role-based UI and route protection
- API-first data flow: Flutter → Go API → PostgreSQL (Drift available for local caching, offline sync deferred)
- Feature-first directory structure
- Docker-compose for local dev, docker-compose.prod.yml for deployment
- Caddy reverse proxy → containerized services

### 4. Code Quality & Craftsmanship
- SOLID principles enforced in every agent's instructions
- Auto-format hooks: `dart format` + `gofmt` run on every file write
- Effective Dart + Effective Go standards
- flutter_lints + go vet for static analysis
- GORM ORM — no raw SQL, type-safe database models
- Centralized API config — no hardcoded URLs

### 5. Testing & Reliability
- Playwright automated testing with dedicated QA agent
- QA runs in isolated git worktree — never interferes with development
- ADA/WCAG compliance validated per feature
- AutoResearch eval loop — 5/5 passing, pattern proven for post-build optimization
- Error handling pattern: API failure → SnackBar + Drift fallback, never crashes

### 6. Documentation & Presentation
- 12+ documentation files covering architecture, requirements, branding, accessibility, setup, progress
- Individual conversation logs per agent — full audit trail of the build process
- Thought logs — developer notes from each agent
- Task board with difficulty ratings and model assignments
- Wiki auto-regenerated before every commit
- Herzog branding system — Oswald headings, Roboto body, gold/navy palette

---

## Key Talking Points

### Why Flutter?
> Google chose Flutter for the **NotebookLM iOS/Android app** because development speed and time-to-market were critical — they shipped a **4.8-star app in 7 months**. The same reasoning applies here: Flutter enables rapid cross-platform delivery from a single codebase, making it the right choice for a hackathon timeline.

### Why the Wiki Pipeline Matters
> The auto-regenerating wiki pipeline mirrors the **AutoResearch agentic feedback loop** pattern — a self-improving knowledge base that stays current with every code change. This connects the project's infrastructure to cutting-edge AI research methodology and demonstrates thoughtful, production-minded architecture.

### The Two-Phase AutoResearch Play
> **Phase 1:** AutoResearch optimizes the agent prompts → better developers building the app.
> **Phase 2:** AutoResearch optimizes Qwen 2.5 3B → better in-app assistant for users.
> Same pattern, two applications, one project.

### Post-Mortem Narrative (Judge-Facing)
After the build, map all agent thought logs and conversation logs into a **unified decision timeline** — a compelling post-mortem showing the multi-agent development process end-to-end. Each agent can resurface in a Claude project and speak to their own work.
