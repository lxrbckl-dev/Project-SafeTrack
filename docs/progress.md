# Feature Progress

> Updated before every commit. Tracks what's built vs what's planned.

---

## Done

| Feature | Details |
|---|---|
| Flutter multi-platform scaffold | iOS, Android, Web, macOS, Windows — all build and run |
| go_router navigation | 4 routes configured, works on web with URL handling |
| Drift local database | Notes table with CRUD, works on mobile (SQLite) and web (WASM) |
| Auth system (3-layer) | Email/password login (seeded demo accounts, bcrypt) + Firebase Auth (real SSO) + provider-agnostic Go middleware (Azure AD-ready) |
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
| Agent Teams validation | Complete | 40 feature tasks + 4 bug fixes across 9 phases via multi-agent team |
| Phase 6: Rubric deferred items | Complete | TASK-026 through TASK-032 — all merged |
| Phase 7: Judge differentiators | Complete | TASK-033 through TASK-038 — all merged |
| Phase 8: Domain innovation | Complete | TASK-039 through TASK-041 — all merged |
| Phase 9: Demo polish | Complete | TASK-042 through TASK-043 — all merged |
| Bug sweep | Complete | 6 bugs found, 4 fixed (#88-91), 2 low-severity deferred. Clean re-pass |
| Integration stress test | Complete | 17/17 cross-feature tests passed. Zero bugs |
| Resilience stress test | Complete | 14 tests: 1 High + 3 Medium fixed (#94-97), 3 Low deferred. Clean re-pass |

## Completed — Rubric Features (QA Verified)

| Feature | TASK | QA | Details |
|---|---|---|---|
| Incident reporting UI | TASK-005 | PASSED | Full form with 7 types, GPS auto-fill, photos, draft save, completion %, OSHA decision tree, railroad notification tracking, injured person details |
| Investigation models + API | TASK-006 | PASSED | Go backend: Investigation, FiveWhy, ContributingFactor, WitnessStatement models + 13 REST endpoints |
| Investigation UI | TASK-007 | PASSED | InvestigationListPage (filters, overdue highlighting L1/L2/L3), InvestigationDetailPage (5 tabs), FiveWhyChain (interactive inline editing, keyboard nav, min-3 warning, arrows, Semantics), ContributingFactorsPanel (API-driven types, primary toggle), WitnessStatementCard (inline edit + add), InvestigationReviewPanel (Safety Manager only, required comments), InvestigationFormPage (auto target date by severity) |
| CAPA models + API | TASK-008 | PASSED | Go backend: CAPA model (20+ lifecycle fields), 6 REST endpoints (CRUD + complete + verify), dashboard KPIs, auto due dates by priority (Critical=7d/High=14d/Med=30d/Low=60d), verificationDueDate by priority (Critical=30d/High=60d/Med+Low=90d), 403 self-verify block, nextSteps on ineffective, CloseIncident CAPA gate, incident status transitions, full audit logging |
| CAPA management UI | TASK-009 | PASSED | Flutter UI: CAPADashboardPage (4 KPI cards, filterable table, overdue row highlighting), CAPADetailPage (lifecycle stepper, 4 info sections, CRITICAL Verify button absent from tree for assignee, Complete button for assignee on Open/InProgress, IneffectiveActionDialog with Create New CAPA + Reopen Investigation), CAPAFormPage (type/category/description/assignee/priority/verificationMethod, auto due dates by priority), CAPALifecycleStepper (5-stage), router (/capas /capas/:id /capas/new), InvestigationDetailPage Create CAPA wired for Safety Manager on Approved investigations. ADA Semantics throughout. |
| Safety dashboard | TASK-010 | PASSED | Backend: GET /api/dashboard (TRIR/DART/NearMissRatio YTD, 12-month TRIR trend, incident stacked bar trend, division grouped bar, severity donut, 3 leading indicators, recent 10 incidents, TRIR benchmark from settings). POST/GET /api/hours-worked (Safety Manager/Admin only, audit logged). HoursWorked model in AllModels(). Flutter: SafetyDashboardPage (6 KPI cards with TRIR trend arrow, 4 fl_chart charts, leading indicators with progress bars, clickable recent incidents DataTable), HoursWorkedPage (date pickers + entry form + existing entries list), responsive LayoutBuilder 900px breakpoint, ADA Semantics throughout, Herzog branding. |
| Manual recurrence linking | TASK-011 | PASSED | Backend: IncidentLink model (uniqueIndex pair, 5 similarity types), RegisterIncidentLinkRoutes (POST/GET/DELETE + clusters), canLinkIncidents RBAC (safety_coordinator+), isValidSimilarityType, N+1 fix (batch WHERE id IN ?), union-find cluster algorithm, audit logging on create+delete. Flutter: IncidentLinkRepository (kSimilarityTypes const, createLink/getLinksForIncident/deleteLink/getClusters), Recurrence tab on IncidentDetailPage (link cards, delete confirm dialog, Link Incident gated to coordinator+), IncidentClusterPage at /incidents/clusters (cluster cards with common threads chips). GAP: playwright/incident-links.spec.ts not committed — action item filed in PR comment. |
| Audit log viewer UI | TASK-012 | PASSED | Backend: GetAuditLogs RBAC (admin + safety_manager 200; all others 403 at handler level), action/entity_type/user_id/date_start/date_end filters, per_page cap at 100 (>100 falls back to 50), newest-first ordering. Flutter: AuditLogPage (paginated table >=700px + card layout <700px), AuditLogFilters (entity type dropdown, action dropdown, user ID text field, date range picker, Clear All), AuditLogPagination (prev/next, page indicator, record count, WCAG tooltips), JsonDiffViewer (side-by-side >=700px / stacked <700px, pretty-print with fallback), expandable before/after rows, Semantics on all rows + controls, Herzog branding, keyboard navigable, skip-nav link. Router /audit-log gated to Admin + Safety Manager. Build: clean. dart analyze: no issues. playwright/audit-log.spec.ts: 11 suites / 47 tests. |
| In-app AI agent | TASK-019 | PASSED | Backend: agentSystemPrompt (navigate/fill/navigate_and_fill schema), parseActions() (fenced JSON blocks + string-aware brace scanner BUG FIX), ChatResponse{Response, Actions []}. Flutter: FormFillService ChangeNotifier (setPendingFields/consume/clear, MultiProvider registered), ChatActionDispatcher (permission-gated: /admin+/audit-log→admin/safetyManager, /investigations+/capas→coordinator+), all 3 form pages (incident/investigation/CAPA) reactively addListener(_applyPendingFields) BUG FIX + removeListener+clear in dispose, _ActionButtons for navigate+navigate_and_fill, fill actions auto-dispatched. Graceful degradation. go build clean. dart analyze: no issues. |
| Escalation notifications | TASK-013 | PASSED | Backend: Notification model (EscalationLevel field, AllModels registered), 3 routes (GET /api/notifications user-scoped, PUT /api/notifications/{id}/read ownership-checked, POST /api/notifications/check-escalations Safety Manager/Admin RBAC). Dedup via entity_type+entity_id+type+escalation_level (BUG FIX). CAPA escalations only for Open/In Progress/Verification Pending — Completed excluded (BUG FIX). RBAC 403 for field_reporter/coordinator (BUG FIX). Investigation +3/+7/+14 day thresholds → levels 1/2/3. Railroad BNSF/UP/CSX/NS deadlines checked. Flutter: NotificationService ChangeNotifier (30s polling, setToken lifecycle, optimistic markRead). Bell badge in AppShellPage AppBar (desktop+mobile). NotificationPanel drawer (read/unread styling, entity icons, relative timestamps, tap-to-navigate). go build clean. dart analyze: no issues. playwright/notifications.spec.ts: 13 test cases. |

## Not Started — Rubric Features (SRD-10)

| Feature | Notes |
|---|---|
| ~~CAPA management UI~~ | ~~Flutter UI — CAPA list, detail, form, workflow actions (complete/verify), dashboard KPIs~~ — DONE (TASK-009, QA PASSED) |
| ~~Safety dashboard~~ | ~~TRIR/DART/Near Miss KPIs, trend charts, incidents by division, severity donut, leading indicators, recent incidents table, TRIR benchmark configurable via admin settings~~ — DONE (TASK-010, QA PASSED) |
| ~~Manual recurrence linking~~ | ~~Link incidents by similarity type, cluster view~~ — DONE (TASK-011, QA PASSED) |
| ~~Audit log viewer~~ | ~~UI for browsing immutable audit trail — Admin and Safety Manager access~~ — DONE (TASK-012, QA PASSED) |
| ~~Admin settings page~~ | ~~Configurable factor types, TRIR industry benchmark, system settings~~ — DONE (TASK-003, QA PASSED) |
| ~~Medical data encryption~~ | ~~Application-level encryption for injured person fields in Go backend~~ — DONE (TASK-004, AES-256-GCM) |
| ~~RBAC route protection~~ | ~~7 roles with scoped UI and API permissions per rubric~~ — DONE (TASK-014, QA PASSED) |
| ~~Draft incident visibility~~ | ~~Drafts visible only to reporter~~ — DONE (TASK-014, QA PASSED) |

## Not Started — Supporting Features

| Feature | Notes |
|---|---|
| ~~In-app AI agent (page nav + form filling)~~ | ~~JSON action dispatch to go_router/TextEditingController. Not started.~~ — DONE (TASK-019, QA PASSED) |
| ~~Keyboard shortcuts~~ | ~~Flutter Shortcuts/Actions system. Not started.~~ — DONE (TASK-018 initial, TASK-021 Alt modifier, TASK-022 Alt+K chat) |
| ~~Playwright test suite~~ | ~~QA agent writes tests during hackathon. Infrastructure ready.~~ — DONE (15 spec files, 100+ test cases across all features) |
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
| Claude Desktop / Claude.ai integration | Once MCP server (TASK-048) is live, register SafeTrack as an MCP server in Claude Desktop or Claude.ai projects. Users interact with SafeTrack via natural conversation: "Show me overdue investigations", "Create a near miss at Houston". All role-scoped, audit-logged, zero custom UI needed. |
| Multi-language / i18n (Spanish) | Construction workforce is heavily Spanish-speaking. Flutter has built-in i18n. Translate incident form, key UI labels, and AI assistant responses. |
| Photo annotation | Draw circles/arrows on incident photos to highlight hazards. Practical for safety teams documenting scene evidence. |
| QR code job site check-in | Generate QR codes for job sites, scan to pre-fill incident location. Reduces GPS dependency indoors. |
| Bulk CSV import/export | Import historical incidents from CSV for migration. Export data for external analysis tools. |
