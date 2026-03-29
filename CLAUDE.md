# SafeTrack

Incident Investigation & Corrective Action System (SRD-10). Cross-platform Flutter/Dart app built for a hackathon. Solo developer (Alex) + multi-agent Claude Code team.

## Quick Reference

| Item | Value |
|---|---|
| Frontend | Flutter / Dart (`flutter/`) |
| Backend | Go (`backend/`) |
| Navigation | `go_router` |
| Local DB | Drift (SQLite mobile, WASM web) |
| Remote DB | PostgreSQL (via Go API) |
| Auth | Three-layer: Email/password login (seeded demo accounts, bcrypt) + Firebase Auth (real SSO) + Azure AD-ready (provider-agnostic JWT middleware) |
| Offline detection | `connectivity_plus` |
| Local LLM | Ollama — Qwen 2.5 3B |
| Testing (Primary) | Playwright |
| Testing (Secondary) | Claude Browser Agent |
| Distribution | TestFlight (iOS + macOS, single link), Flutter web (fallback) |
| Styling | Herzog brand system (docs/branding.md) |
| Local dev | `docker-compose.yml` (Go + PostgreSQL + Ollama) |

## Team Structure

```
Alex ← CI/CD, pipelines, TestFlight, GitHub Actions, infrastructure
 └── TPM (sole point of contact for Alex)
       ├── SWE 1 (Full-Stack)
       ├── SWE 2 (Full-Stack)
       └── QA (Playwright + exploratory)
```

Agent definitions: `.claude/agents/`
Thought logs: `.logs/thoughts/`

## Launch Command

When Alex asks to "launch agents", "start the team", or "spin up agents", provide this prompt for pasting into the CLI:

```
Create a team based on our agent definitions in .claude/agents/. The team structure is:

- You are the TPM (read .claude/agents/tpm.md for your instructions)
- Spawn SWE-1 as a full-stack developer (their instructions are in .claude/agents/swe-1.md)
- Spawn SWE-2 as a full-stack developer (their instructions are in .claude/agents/swe-2.md)
- Spawn QA as the testing agent (their instructions are in .claude/agents/qa.md)

Read CLAUDE.md for project rules. Read docs/rubric.md for the full SRD-10 spec (including the Implementation Clarifications section). Read docs/architecture.md and docs/backend-patterns.md for implementation patterns. Each agent logs exchanges to their own file in docs/conversations/.

Read docs/build-plan.md for the complete 19-task execution plan. Create GitHub Issues for the current phase upfront using `gh issue create`. Assign tasks to SWE-1 or SWE-2 per the plan's assignments and difficulty ratings. Begin with Phase 0.
```

## Rules for All Agents

1. **Work in worktrees.** Each agent creates a branch (`swe1/TASK-{NNN}`, `swe2/TASK-{NNN}`, `qa/test-run`) in their own git worktree. SWEs open PRs, the other SWE peer reviews via comment, QA tests the PR branch and comments results. Author merges only after both peer review AND QA pass.
2. **API-first.** Call the Go backend directly for all data operations. Drift is available for local caching but offline-first sync is deferred (rubric Future Phase). Do NOT create Drift tables for feature data.
3. **ADA/WCAG compliant.** Every widget, every page, no exceptions. See `docs/accessibility.md`.
4. **Herzog branding.** Oswald headings, Roboto body, color palette per `docs/branding.md`.
5. **Web + mobile compatible.** No platform-specific forks.
5a. **Use Provider for state management.** Shared state (auth, notifications) should be `ChangeNotifier` classes provided at the app root via `MultiProvider` in `main.dart`. Do not use global variables or singletons.
6. **Brief thought logs.** 2-4 lines per task in `.logs/thoughts/[agent-name].md`. Developer notes, not reports.
7. **Read before you build.** Check other agents' thought logs and changelogs before starting a task.
8. **Don't touch infrastructure.** CI/CD, GitHub Actions, TestFlight, pipelines — Alex owns these.
9. **Only the TPM creates tasks.** TPM creates GitHub Issues. SWEs open PRs. The other SWE peer reviews via PR comment, QA tests and comments results on the PR. Author merges only after both peer review and QA pass.
10. **If blocked, say so.** Tell the TPM what you need. Don't spin.

## Task Management

**GitHub Issues are the sole source of truth for task tracking.**

- TPM creates a GitHub Issue for each task (`gh issue create`)
- Task lifecycle: `open → in_progress → in_review → qa → done` (tracked via issue labels/comments)
- SWEs check their assignments with `gh issue list --assignee @me`

## Agent Worktree Isolation

All agents work in git worktrees to prevent interference:
- SWE-1 worktree: `../highlander-swe1/`
- SWE-2 worktree: `../highlander-swe2/`
- QA worktree: `../highlander-qa/`

Each agent commits to their worktree branch. SWEs open PRs, peer review each other, and merge their own PRs after approval.

QA tests PR branches directly (not main), so SWEs can continue working on new tasks while QA tests. Main stays clean until QA passes and the author merges.

## Data Flow

```
User Action → Go API → PostgreSQL (primary data path)
Auth via Go backend (bcrypt + JWT), Azure AD-ready as config swap
Drift available for local caching (offline-first sync deferred to Future Phase)
```

## In-App Agent Actions

JSON dispatch to `go_router` (navigation) and `TextEditingController` (form filling). No MCP in-app — MCP is CI-side only. App Store compatible.

## Key Files

- `docs/rubric.md` — **THE SPEC.** SRD-10 Incident Investigation & Corrective Action System. All features, RBAC roles, formulas, status flows. Agents build against this.
- `docs/overview.md` — Project overview, tech stack, engineering principles
- `docs/architecture.md` — Data architecture, multi-agent system, task/ticket system, QA strategy
- `docs/requirements.md` — Feature requirements, distribution, judge experience
- `docs/progress.md` — What's built vs what's not (updated before every commit)
- `docs/branding.md` — Full Herzog brand system (typography, colors, components, dark mode)
- `docs/accessibility.md` — ADA/WCAG specs, contrast ratios, focus indicators
- `docs/presentation.md` — Judge-facing narratives and talking points
- `docs/checklist.md` — Validation items, open decisions, resolved contingencies
- `docs/caveats.md` — Gotchas, constraints, raw ideas
- `docs/autoresearch-guide.md` — How to run the AutoResearch optimization loop
- `docs/setup.md` — Development environment setup, tool installation, run commands
- `docs/judge-session-prompt.md` — System prompt for the Claude project at https://claude.ai/project/019cea93-d4b6-75f0-930e-585f4d4357a5 — used for post-build judge Q&A where agents speak to their own work
- `docs/backend-patterns.md` — GORM models, handlers, route registration, encryption, audit logging patterns
- `docs/admin-settings-pattern.md` — How to build configurable admin settings (factor types, TRIR benchmark)
- `.claude/agents/tpm.md` — TPM agent definition
- `.claude/agents/swe-1.md` — SWE Agent 1 definition
- `.claude/agents/swe-2.md` — SWE Agent 2 definition
- `.claude/agents/qa.md` — QA agent definition
- `.logs/thoughts/` — Agent thought logs

## Wiki Generation

**Before every commit**, regenerate `docs/wiki.md` and copy it to `flutter/assets/wiki.md`. When Alex asks you to commit, always regenerate the wiki first, stage it, then commit — so the wiki is always included and up to date.

The wiki is injected into Qwen 2.5 3B's system prompt as RAG context for the in-app assistant. It should be concise, accurate, and cover:
- What the app does
- All pages/routes and their purpose
- How data is stored and synced (Drift → Go API → PostgreSQL)
- Key features and how to use them
- Keyboard shortcuts (if any)

Write it from the perspective of documentation that helps an AI assistant answer user questions about the app. Do NOT hallucinate features that don't exist — only document what's actually in the code.

## Feature Progress Tracking

**Before every commit**, review the code changes and update `docs/progress.md`:
- Check if any features from `docs/requirements.md` have been completed, partially completed, or started
- Mark their status accordingly (Done, In Progress, Not Started)
- Add any new features that were built but weren't originally planned
- Stage `docs/progress.md` with the commit

## Setup Documentation

**Whenever you install a tool, add a dependency, configure a platform, or run any setup command**, update `docs/setup.md` with the instructions so the environment can be reproduced from scratch.

## Conversation Logging

**Before every commit**, append Alex's messages since the last update to `docs/conversations/aarbuckle.md`. Organize entries by time of day under the current date:

```markdown
## YYYY-MM-DD — Morning

### Category Name (e.g., Repo Setup, Bug Fixes, Feature Work)
- Brief note about what was done
- Another note

---

## YYYY-MM-DD — Afternoon

### Category Name
- Brief note

---

## YYYY-MM-DD — Evening

### Category Name
- Brief note
```

Group related work under descriptive sub-headings (e.g., "Backend Infrastructure", "Documentation Cleanup", "Rubric Clarifications"). Keep entries brief — one line per action, not detailed summaries. Append to the existing file, don't overwrite.

## Token Tracking

TPM runs `/cost` after each major delegation and appends results below.

---

### Cost Log

<!-- TPM appends /cost output here -->

#### 2026-03-28 — Full Build Session (Phases 0-7)

**Subagent token usage (estimated from task completion reports):**

| Category | Est. Tokens | Notes |
|---|---|---|
| Phase 0-5 SWE builds | ~2.5M | 19 tasks, mix of Sonnet + Opus |
| Phase 0-5 peer reviews | ~800K | Cross-review every PR |
| Phase 0-5 QA | ~1.2M | Code verification + Playwright specs |
| Post-launch (021-024) | ~400K | Alt shortcuts, login overhaul, Playwright fixes |
| Phase 6 SWE builds (026-032) | ~1.2M | 7 tasks, mostly Opus |
| Phase 6 reviews + QA | ~600K | |
| Phase 7 SWE builds (033-038) | ~1.0M | 6 tasks, mix of Sonnet + Opus |
| Phase 7 reviews + QA | ~500K | |
| Fix cycles (all phases) | ~800K | ~30 blocker fixes across all PRs |
| **Subagent subtotal** | **~9.0M** | |
| TPM orchestration | **~1M+** | Main conversation context |
| **Estimated session total** | **~10M+** | |

**Note:** These are estimates from agent completion metadata. Run `/cost` in the CLI for exact totals with pricing.

**Build output:** 35 tasks, 77 PRs, ~25,000 lines of code added across Go backend + Flutter frontend + Playwright tests.
