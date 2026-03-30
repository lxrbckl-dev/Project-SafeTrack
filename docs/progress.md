# Feature Progress

> Updated 2026-03-27. Tracks what's built vs what's planned. 191 PRs merged to date.

---

## Done — All Phases Complete (0 through 11)

### Phase 0: Foundation

| Feature | Details |
|---|---|
| Flutter multi-platform scaffold | iOS, Android, Web, macOS, Windows — all build and run |
| go_router navigation | Full route tree with auth redirect, role gating, deep linking |
| Drift local database | SQLite on mobile, WASM on web, offline-capable |
| Auth system (3-layer) | Email/password login (seeded demo accounts, bcrypt) + Firebase Auth (real SSO) + provider-agnostic Go middleware (Azure AD-ready) |
| RBAC (7 roles) | Field Reporter, Safety Coordinator, Safety Manager, PM, Division Manager, Executive, Admin |
| Go backend | Go API server with GORM ORM, health/sync/data/chat endpoints, JWT auth middleware |
| PostgreSQL (via GORM) | Auto-migrating ORM — tables defined as Go structs, no SQL migrations needed |
| Sync service | API-first: Flutter → Go API → PostgreSQL. Drift available for local caching |
| connectivity_plus | Real-time online/offline detection |
| Ollama + Qwen 2.5 3B | AI model serving via REST API, warm-up on startup, KEEP_ALIVE=-1 |
| Wiki-as-RAG | Wiki injected into Qwen system prompt for accurate in-app help |
| Wiki auto-generation | Wiki regenerated to reflect current feature state |
| Herzog branding | Full theme system: Oswald headings, Roboto body, gold accents, navy actions, KPI cards, status badges |
| Monorepo structure | flutter/, backend/, deploy/, playwright/, eval/ |
| Docker-compose | Go + PostgreSQL + Ollama — full local dev stack |
| Auto-format hook | `dart format` + `gofmt` run automatically |
| Feature-first architecture | flutter/lib/ restructured: app/, core/, features/, shared/ |
| API config (centralized) | `ApiConfig.baseUrl` and `ApiConfig.ollamaUrl` — single source of truth |

### Phase 1-5: Core Domain (QA Verified)

| Feature | TASK | Details |
|---|---|---|
| Incident reporting UI | TASK-005 | Full form with 7 types, GPS auto-fill, photos, draft save, completion %, OSHA decision tree, railroad tracking, injured person details |
| Investigation models + API | TASK-006 | Investigation, FiveWhy, ContributingFactor, WitnessStatement models + 13 REST endpoints |
| Investigation UI | TASK-007 | List with overdue highlighting, detail with 5 tabs, interactive 5-Why chain, contributing factors panel, witness cards, review panel |
| CAPA models + API | TASK-008 | CAPA model (20+ lifecycle fields), 6 REST endpoints, dashboard KPIs, auto due dates, self-verify block, incident close gate |
| CAPA management UI | TASK-009 | Dashboard (4 KPI cards, filterable table), detail (lifecycle stepper, complete/verify), form (auto due dates by priority) |
| Safety dashboard | TASK-010 | TRIR/DART/NearMiss KPIs, 12-month trend, stacked bar, division bar, severity donut, leading indicators, recent incidents, hours worked entry |
| Manual recurrence linking | TASK-011 | IncidentLink model, POST/GET/DELETE + clusters, union-find cluster algorithm, cluster page |
| Audit log viewer | TASK-012 | Paginated table + card layout, filters (entity/action/user/date), JSON diff viewer, RBAC enforced |
| Escalation notifications | TASK-013 | Notification model, +3/+7/+14 day thresholds, bell badge, notification panel drawer, 30s polling |
| RBAC route protection | TASK-014 | 7 roles with scoped UI and API permissions, draft visibility restricted to reporter |
| Admin settings page | TASK-003 | Configurable factor types, TRIR benchmark, system settings, single Save Changes button |
| Medical data encryption | TASK-004 | AES-256-GCM encryption for injured person fields |
| In-app AI agent | TASK-019 | Agent system prompt, JSON action dispatch (navigate/fill/navigate_and_fill), form pre-fill across all 3 form pages |
| Keyboard shortcuts | TASK-018/021/022 | Ctrl+Shift+H/N/V/A/K/S, `/` chat toggle, `?` overlay, Esc close |
| Email/password login | TASK-023 | Seeded test users, bcrypt, JWT |
| Playwright test suite | TASK-024 | 15 spec files, 100+ test cases across all features |

### Phase 6: Rubric Deferred Items

| Feature | TASK | Details |
|---|---|---|
| Offline incident reporting | TASK-026 | Create incidents without connectivity, auto-sync on reconnect, offline indicator banner |
| Fishbone/Ishikawa diagram | TASK-027 | Visual contributing factor diagram on investigation detail |
| Automated recurrence detection | TASK-028 | Scans new incidents against history across 4 match criteria with similarity scoring |
| Advanced analytics views | TASK-029 | Body part injury map, time heatmap, division radar chart |
| OSHA 300/300A/301 log generation | TASK-030 | CSV export for all three OSHA forms, Safety Manager/Admin only |
| Email/push notifications | TASK-031 | SMTP delivery with user preferences (in-app, email, or both) |
| Training CAPA verification | TASK-032 | Training-category CAPAs auto-create training requirements, completion becomes evidence |

### Phase 7: Judge Differentiators

| Feature | TASK | Details |
|---|---|---|
| PDF incident report export | TASK-033 | Formatted PDF with all details, photos, and audit trail |
| Global search | TASK-034 | Cross-entity search across incidents, investigations, CAPAs with RBAC scoping |
| Incident lifecycle timeline | TASK-035 | Visual chronological timeline from audit log data on incident detail |
| Dark mode | TASK-036 | Light/dark theme toggle, preference persisted, dark navy (#0D1B2A) with gold accents |
| Role-based landing pages | TASK-037 | Field Reporter → /incidents, all others → /dashboard |
| Live activity feed | TASK-038 | System-wide action stream with human-readable messages, WebSocket real-time updates |

### Phase 8: Domain Innovation

| Feature | TASK | Details |
|---|---|---|
| Incident map view | TASK-039 | Geographic view with severity-coded markers, filters, clustering, heat map overlay |
| Voice-to-text incident reporting | TASK-040 | Browser Speech Recognition API for dictating incident descriptions |
| Dashboard PDF summary report | TASK-041 | Generate monthly safety summary PDF for management meetings |

### Phase 9: Demo Polish

| Feature | TASK | Details |
|---|---|---|
| Onboarding tour | TASK-042 | First-time user walkthrough highlighting key features, restartable from sidebar |
| Real-time WebSocket updates | TASK-043 | WebSocket hub for instant notification and activity feed broadcasting |

### Phase 10: AI URL Generation

| Feature | TASK | Details |
|---|---|---|
| Query parameter pre-fill | TASK-044 | Deep links with query params survive auth redirect, all 3 form pages support pre-fill |
| AI chat URL generation | TASK-045 | Clickable markdown URLs in AI responses with gold underline styling, role-aware |

### Phase 11: MCP Agent Integration

| Feature | TASK | Details |
|---|---|---|
| Agent API key system | TASK-046 | Create/list/revoke API keys for external agents, separate from user JWT auth |
| Agent capabilities endpoint | TASK-047 | GET /api/agent/capabilities — manifest of all available tools |
| MCP server protocol | TASK-048 | JSON-RPC MCP endpoint at /mcp/*, API key auth, proxies to REST handlers |
| Agent session awareness | TASK-049 | Active session tracking, agent activity feed, last-used timestamps |

### Bug Fixes & Polish (all resolved)

| Fix | PR/Issue | Details |
|---|---|---|
| Login redirect + investigation RBAC | #93 | Fixed redirect loop, added middleware RBAC for investigations |
| Reopen investigation + CloseIncident validation | #92 | Status transition validation |
| Map incident cap + unsaved changes warning | #98 | Map performance + UX guard |
| JWT 401 handling + upload size limit | #99 | Graceful auth expiry + photo upload limits |
| CAPA avg time to close negative | #169 | Fixed calculation returning negative values |
| KPI cards rendering blank | #161 | Fixed rendering issue with KPI card widgets |
| Filter row buttons/heights/background | #165 | Incident filter row visual consistency |
| Sidebar footer button consolidation | #167 | Unified dark mode + logout buttons |
| Admin settings single save | #163 | Consolidated into single SAVE CHANGES button |
| Double AppBars removed | #171 | Route-based shell titles instead of per-page AppBars |
| AI chat status indicators | #173 | Online/loading/offline status display |
| Seed data expansion | #175 | Demo-ready dataset with realistic variety |
| Investigation inline filters | #185 | Column header filters with Search + Clear buttons |
| AppBar titles match sidebar | #178 | Consistent naming across navigation |
| borderRadius + non-uniform Border fix | #181 | Material widget rendering error |
| Stress test data seeding | #183 | Admin-only endpoint for load testing |
| AI chat timeout handling | #187 | Graceful timeout with retry |
| Seed data visibility | #189 | Draft incidents visible only to correct reporter |
| Dashboard uniform layout | #191 | Consistent spacing and card sizing |
| Seed data ratios | latest | Realistic near miss rate, investigation timeliness, OSHA rates |
| Wiki-as-RAG wired | latest | Flutter loads wiki.md, sends as system context to AI chat |
| Firebase removed | latest | Unused dependency stripped, Azure AD-ready via JWT middleware |
| Login background image | latest | Herzog worker photo with dark overlay, WCAG compliant |
| Help Guide page | latest | /help route renders wiki.md with branded markdown, sidebar button, Ctrl+Shift+G shortcut |
| Division dropdowns | latest | Shared kDivisions constant, dropdowns on incident list/form, injured person, hours worked |
| Searchable investigation form | latest | Autocomplete for Incident ID and Lead Investigator (GET /api/users endpoint) |
| CI/CD pipeline | latest | GitHub Action: Playwright → DockerHub push (lxrbckl/pap-highlander-web + backend) |
| DockerHub deployment | latest | docker-compose.prod.yml — one-command deploy from pre-built images |
| Configurable env vars | latest | SUPPORT_EMAIL, SUPPORT_PHONE, API_BASE_URL, ENCRYPTION_KEY, DB credentials |
| MCP guide + demo key | latest | docs/mcp-guide.md, pre-seeded stk_demo_judge_key_2026 |
| GitHub stats | latest | docs/github-stats.md — 237 commits, 103 issues, 94 PRs |
| Comprehensive dark mode audit | latest | 28+ files fixed across all pages for WCAG contrast |
| Dark mode toggle fix | latest | Theme toggle no longer navigates away from current page |
| Seed data: Herzog locations | latest | 23 actual Herzog operating locations across US + Canada + PR |
| Seed data: randomized times | latest | Weighted hour distribution (70% day, 20% evening, 10% overnight) |
| Incident filter polish | latest | Search + Clear buttons, Division dropdown |
| Refresh + auto-refresh | latest | Refresh button + didChangeDependencies on Investigations, Incidents, CAPAs |
| PDF report icons | latest | SafeTrack icon in incident and dashboard PDF headers |
| Sort header visibility | latest | Active sort arrow gold/navy, hover highlight on investigations table |
| Chart improvements | latest | Incident trend: readable months, axis titles, rich tooltips, tooltip clipping fix |
| 404 page updates | latest | Configurable GIF via dart-define, dashboard redirect button |
| Keyboard shortcut remap | latest | N→I (Incidents), K→C (Chat), G (Help Guide) |
| Navigation transitions | latest | NoTransitionPage on all 22 shell routes — instant page swap |
| Login page links not clickable | #127 | Forgot Password + support contact fixed |
| Forgot Password + support contact | #125 | Added to login page |
| Graceful Ollama offline degradation | #123 | Chat works when Ollama unavailable |
| Flutter debug banner removed | #117 | Clean production appearance |
| Sidebar icon quality | multiple | Pre-rendered 104px @2x icon with FilterQuality.high |
| Onboarding tour highlight fix | #133, #135 | Sidebar highlight targets correct area |
| Ollama cold start fix | — | KEEP_ALIVE=-1, warm-up on startup, 90s chat timeout |
| Persist auth across refresh | #149 | Session survives browser refresh |
| 404 Not Found page | #159 | Custom error page for invalid routes |
| Logout button | #157 | Added to sidebar footer |
| AppBar gold bottom border | #154 | Brand-consistent border |
| KPI cards gold border + responsive layout | #155 | 4-column responsive grid |
| New Incident button moved to AppBar | #146 | Replaced FAB with AppBar action |
| Body part map → horizontal bar chart | #141 | Better readability |
| Time heatmap horizontal layout | #139 | Flipped orientation for clarity |
| Ctrl+Shift shortcuts | #137 | Replaced Alt+key with Ctrl+Shift+key |
| Agent attribution in activity feed | #115 | Agent actions properly attributed |
| Capability enum values | #114 | Fixed enum serialization |
| 31+ edge cases | multiple | Medical data agent access, chat audit logging, photo upload, DB pool, CORS, JSON-RPC, timeouts, notification loops, graceful shutdown, security headers |

### Infrastructure & Process

| Feature | Details |
|---|---|
| Multi-agent development system | 4-agent team (TPM + 2 SWEs + QA) with embedded skills |
| CLAUDE.md orchestration | Central config with rules, key files, automated instructions |
| Agent worktree isolation | All agents work in separate git worktrees, SWEs open PRs, peer review |
| Agent conversation logging | Each agent logs exchanges to docs/conversations/ |
| Playwright setup | Installed, browser downloaded, 15 spec files, 100+ test cases |
| AutoResearch eval suite | 42-case eval: 10% baseline → 88% with wiki RAG (+79 points) |
| Integration stress test | 17/17 cross-feature tests passed, zero bugs |
| Resilience stress test | 14 tests: High/Medium fixed, Low deferred, clean re-pass |
| SafeTrack logo/icon | 2048px icon deployed across all platforms + sidebar |
| Graceful server shutdown | 30-second drain period for in-flight MCP/WebSocket connections |
| Ollama warm-up | Background model preload on server start |

## In Progress

| Feature | Status | What's Left |
|---|---|---|
| TestFlight distribution | Waiting on Apple Developer approval | Upload first build once approved |

## Post-Hackathon

| Feature | Notes |
|---|---|
| AutoResearch Phase 1 | Optimize agent prompts against eval test cases |
| AutoResearch Phase 2 | Optimize Qwen with app-specific training |
| Agent personas post-build | Upload personas + logs to Claude project for interactive Q&A |
| Horizontal scaling (Go backend) | Stateless API design enables multi-container scaling |
| Ollama load balancing | Multiple Ollama instances behind a load balancer or request queuing |
| Claude Desktop / Claude.ai integration | Register SafeTrack as MCP server in Claude Desktop. Users interact via natural conversation |
| Multi-language / i18n (Spanish) | Construction workforce is heavily Spanish-speaking. Flutter has built-in i18n |
| Photo annotation | Draw circles/arrows on incident photos to highlight hazards |
| QR code job site check-in | Generate QR codes for job sites, scan to pre-fill incident location |
| Bulk CSV import/export | Import historical incidents from CSV, export for external analysis |
