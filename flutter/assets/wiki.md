# SafeTrack — App Wiki

## What SafeTrack Does

SafeTrack is an Incident Investigation & Corrective Action System built for workplace safety management in the rail and infrastructure industry. It covers the full incident lifecycle: field reporting, OSHA recordability determination, root cause investigation (interactive 5-Why analysis with fishbone diagrams), corrective/preventive actions (CAPAs), training verification, and executive safety dashboards with TRIR/DART metrics. Seven role-based access levels control who can see and do what. An AI assistant (Qwen 2.5 3B via Ollama) provides natural-language help, page navigation, and form filling. External agents can integrate via MCP (Model Context Protocol) or REST API with dedicated API keys.

## Pages & Routes

| Route | Page | Purpose |
|---|---|---|
| `/login` | Login | Email/password authentication with forgot password and support contact links |
| `/dashboard` | Safety Dashboard | TRIR, DART, Near Miss KPIs, 12-month trend charts, incidents by division bar chart, severity donut, leading indicators, body part injury map, time heatmap, division radar chart, recent incidents table |
| `/dashboard/hours-worked` | Hours Worked | Enter total hours worked per period for TRIR/DART calculations (Safety Manager/Admin) |
| `/incidents` | Incident List | Filterable, sortable table with status badges, severity colors, and search |
| `/incidents/new` | New Incident | Create incident: 7 types, GPS auto-fill, photo upload, voice-to-text, railroad notification tracking, injured person details, draft saving, completion percentage |
| `/incidents/map` | Incident Map | Geographic view of all incidents with severity-coded markers, filters, clustering, and heat map overlay |
| `/incidents/clusters` | Incident Clusters | Manually linked incident clusters grouped by similarity type (union-find algorithm) |
| `/incidents/:id` | Incident Detail | Tabs: summary, OSHA determination, investigation, CAPAs, recurrence links, lifecycle timeline |
| `/incidents/:id/edit` | Edit Incident | Edit an existing incident report |
| `/incidents/:id/osha` | OSHA Determination | Step-by-step OSHA recordability decision tree per 29 CFR 1904 with override and justification |
| `/investigations` | Investigation List | Filterable list with inline column header filters, overdue highlighting (Level 1/2/3), search and clear buttons |
| `/investigations/new` | New Investigation | Create investigation linked to an incident, assign lead investigator, auto-set target date by severity |
| `/investigations/:id` | Investigation Detail | Tabs: overview, 5-Why root cause analysis (interactive chain), contributing factors (fishbone/Ishikawa diagram), witness statements, review panel |
| `/capas` | CAPA Dashboard | 4 KPI cards (open, overdue, avg close time, effectiveness rate), filterable table with overdue row highlighting |
| `/capas/new` | New CAPA | Create corrective/preventive action with type, category, priority, auto due dates by priority level |
| `/capas/:id` | CAPA Detail | Lifecycle stepper (Open, In Progress, Completed, Verification Pending, Verified), complete/verify actions, ineffective handling with reopen option |
| `/training` | Training List | Pending and completed training requirements linked to Training-category CAPAs |
| `/training/:id` | Training Detail | Completion form: date, hours, instructor, notes. Completion record becomes CAPA evidence |
| `/admin` | Admin Settings | Configure TRIR benchmark, escalation thresholds, system settings (single Save Changes button) |
| `/admin/factor-types` | Factor Types | Add, edit, and delete contributing factor types used in investigations |
| `/admin/osha-export` | OSHA Export | Generate OSHA 300, 300A, and 301 logs as downloadable CSV files |
| `/admin/api-keys` | API Keys | Create, list, and revoke API keys for external agent/MCP integration |
| `/admin/agents` | Agent Sessions | View active agent sessions, agent-specific activity feed, last-used timestamps |
| `/audit-log` | Audit Log | Paginated, filterable audit trail with expandable before/after JSON diffs (Admin/Safety Manager only) |
| `/search` | Global Search | Cross-entity search across incidents, investigations, and CAPAs with debounced results and RBAC scoping |
| `/notification-preferences` | Notification Preferences | Choose notification delivery: in-app only, email, or both |
| `/activity` | Activity Feed | Live system-wide action stream with real-time WebSocket updates and human-readable messages |

## Data Flow

All data flows through the Go REST API to PostgreSQL:

1. **User action** in the Flutter app (create incident, approve investigation, etc.)
2. **REST API call** to the Go backend at `localhost:8000` (JWT authenticated)
3. **Go backend** validates permissions (RBAC), writes to PostgreSQL via GORM ORM, creates an audit log entry
4. **WebSocket broadcast** pushes real-time updates to all connected clients (notifications, activity feed)
5. **Drift (SQLite)** provides offline storage — incidents can be created without connectivity and auto-sync on reconnect

```
Flutter App (port 3000)
    |
    |-- REST API calls (JWT in Authorization header)
    v
Go Backend (port 8000)
    |
    |-- GORM ORM
    |   v
    |   PostgreSQL (port 5432)
    |
    |-- Ollama AI (port 11434, Qwen 2.5 3B)
    |-- WebSocket (real-time push)
    |-- MCP Protocol (/mcp/* endpoints)
```

## Login & Test Accounts

The login page uses email/password authentication. All 7 test accounts share password **demo1234**.

| Email | Display Name | Role |
|---|---|---|
| reporter@safetrack.demo | Maria Santos | Field Reporter |
| coordinator@safetrack.demo | James Chen | Safety Coordinator |
| manager@safetrack.demo | Sarah Williams | Safety Manager |
| pm@safetrack.demo | Michael Torres | Project Manager |
| director@safetrack.demo | Lisa Anderson | Division Manager |
| executive@safetrack.demo | Robert Kim | Executive |
| admin@safetrack.demo | Alex Thompson | Admin |

After login, Field Reporters land on `/incidents` (their primary workflow). All other roles land on `/dashboard`.

First-time users see a guided onboarding tour highlighting key features. The tour can be restarted from the sidebar.

## Roles & Permissions

| Role | Access Level |
|---|---|
| Field Reporter | Create and edit own incidents, view dashboard. Drafts visible only to the reporter |
| Safety Coordinator | All above + manage investigations, CAPAs, training, link incidents for recurrence |
| Safety Manager | All above + approve/reject investigations, assign investigators, access admin settings, audit log, OSHA export |
| PM | View project-scoped incidents and dashboard data |
| Division Manager | View division-scoped data across projects |
| Executive | View all data organization-wide (read-only) |
| Admin | Full access: system settings, audit log, API key management, agent sessions, factor types, OSHA export |

Route protection is enforced at both the Flutter router level (redirect) and the Go API level (middleware RBAC).

## Key Features

### Incident Reporting
- 7 incident types (Injury, Near Miss, Property Damage, Environmental, Vehicle, Utility Strike, Other)
- GPS auto-fill for location
- Photo attachments with upload
- Voice-to-text input via browser Speech Recognition API
- Draft saving with completion percentage indicator
- Railroad notification tracking (BNSF, UP, CSX, NS) with deadline alerts
- Injured person details with medical data encryption (AES-256-GCM)
- Query parameter pre-fill support for AI-generated deep links

### OSHA Compliance
- Step-by-step recordability decision tree per 29 CFR 1904
- DART (Days Away, Restricted, Transferred) flag
- Override with justification for edge cases
- OSHA 300, 300A, and 301 log generation as CSV exports

### Investigations
- Interactive 5-Why root cause analysis with inline editing and keyboard navigation (minimum 3 levels enforced)
- Contributing factors panel with configurable factor types and primary factor designation
- Fishbone/Ishikawa diagram visualization of contributing factors
- Witness statement cards with inline edit and add
- Review panel for Safety Manager approval with required comments
- Auto target date calculation by incident severity
- Overdue highlighting at 3 escalation levels (L1/L2/L3)

### CAPAs (Corrective and Preventive Actions)
- Full lifecycle: Open, In Progress, Completed, Verification Pending, Verified Effective/Ineffective
- Auto due dates by priority: Critical=7d, High=14d, Medium=30d, Low=60d
- Verification due dates by priority: Critical=30d, High=60d, Medium/Low=90d
- Self-verify block (assignee cannot verify their own CAPA)
- Ineffective handling: option to create new CAPA or reopen investigation
- Incident close gate: all CAPAs must be verified before incident can close
- 4 KPI dashboard cards: open count, overdue count, avg close time, effectiveness rate

### Training Verification
- Training-category CAPAs auto-create training requirements
- Completion form: date, hours, instructor, notes
- Completion record automatically becomes CAPA evidence

### Dashboard & Analytics
- TRIR (Total Recordable Incident Rate) and DART KPIs with trend arrows
- Near Miss Ratio with configurable benchmark
- 12-month TRIR trend line chart
- Incident stacked bar chart by month
- Division grouped bar chart
- Severity donut chart
- 3 leading indicator progress bars
- Body part injury horizontal bar chart
- Time heatmap (hour-of-day x day-of-week incident frequency)
- Division radar chart (multi-metric comparison)
- Recent 10 incidents clickable table
- Dashboard PDF summary report generation for management meetings

### Incident Map & Recurrence
- Geographic map view with severity-coded markers and filters
- Heat map overlay for incident density
- Automated recurrence detection: scans new incidents against history across 4 match criteria with similarity scoring
- Manual recurrence linking by similarity type
- Union-find cluster algorithm for grouping related incidents
- Dismiss suggestion to hide false positives

### Notifications & Real-Time
- Escalation notifications at +3/+7/+14 day overdue thresholds
- Bell badge with unread count in AppBar
- Notification panel drawer with read/unread styling, entity icons, relative timestamps, tap-to-navigate
- Email notification delivery via SMTP with user preferences (in-app, email, or both)
- Real-time WebSocket broadcasting for instant updates
- Live activity feed with human-readable action messages

### AI Assistant
- Qwen 2.5 3B language model via Ollama with wiki-as-RAG context injection
- Chat panel toggled via Ctrl+Shift+C or `/` key
- Page navigation commands (AI can direct user to any route)
- Form filling commands (AI can pre-fill incident, investigation, and CAPA forms)
- Clickable markdown URL generation with query parameter pre-fill
- Role-aware: only generates URLs for routes the user can access
- Status indicators: online, loading, offline
- Graceful degradation when Ollama is unavailable

### AI Chat URL Generation
The AI assistant generates clickable markdown URLs to help users navigate with pre-filled data:
- `[Report Near Miss](/incidents/new?type=Near+Miss&location=Houston+Rail+Yard)`
- `[Create Corrective Action](/capas/new?investigationId=5&type=Corrective)`
- `[Search Building A](/search?q=Building+A)`

Supported query parameters by route:
| Route | Parameters |
|---|---|
| `/incidents/new` | type, location, division, project, severity, shift, weather |
| `/investigations/new` | incidentId, leadInvestigator |
| `/capas/new` | investigationId, type, category, priority, description |
| `/search` | q |

### MCP Agent Integration
- Model Context Protocol (MCP) server at `/mcp/*` endpoints
- API key authentication (separate from JWT user auth)
- Agent API key management: create, list, revoke via `/admin/api-keys`
- Agent capabilities endpoint describing all available tools
- Agent session tracking with last-used timestamps and activity feed
- Enables Claude Desktop, Claude.ai, or any MCP-compatible client to interact with SafeTrack

### Accessibility & Polish
- Offline incident creation with auto-sync on reconnect and offline indicator banner
- Dark mode toggle (light/dark themes, preference persisted) in sidebar footer
- Global search across incidents, investigations, and CAPAs with debounced input
- Guided onboarding tour for first-time users (restartable from sidebar)
- Role-based landing pages (Field Reporter to Incidents, all others to Dashboard)
- PDF export of formatted incident reports with details, photos, and audit trail
- Immutable audit log with before/after JSON diffs
- 404 Not Found page for invalid routes
- Responsive layout: sidebar navigation on desktop (>=900px), bottom nav on mobile (<900px)
- Herzog brand system: Oswald headings, Roboto body, gold accents (#FFD100), navy actions (#1E3A5F)
- ADA/WCAG compliance: semantic widgets, contrast ratios, focus indicators, keyboard navigation
- Graceful shutdown with 30-second drain period for in-flight requests

## Keyboard Shortcuts

| Key | Action |
|---|---|
| Ctrl+Shift+H | Go to Dashboard |
| Ctrl+Shift+I | Go to Incidents |
| Ctrl+Shift+V | Go to Investigations |
| Ctrl+Shift+A | Go to CAPAs |
| Ctrl+Shift+C | Toggle AI chat panel |
| Ctrl+Shift+S | Focus global search |
| / | Toggle AI chat (disabled when cursor is in a text field) |
| ? | Show keyboard shortcuts overlay |
| Esc | Close open panels |

## Navigation

- **Desktop (>=900px):** Sidebar navigation with section icons and labels
- **Mobile (<900px):** Bottom navigation bar
- Dark mode toggle in sidebar footer
- Logout button in sidebar footer
- "Restart Tour" option in sidebar
- `go_router` handles all navigation with deep linking and web URL support

## API Endpoints

### Public
| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Health check |
| POST | `/api/login` | Email/password authentication, returns JWT |
| POST | `/api/agent/auth` | Agent API key authentication, returns JWT |
| GET | `/api/ws` | WebSocket connection (auth via query param) |

### Authenticated (JWT required)
| Method | Path | Purpose |
|---|---|---|
| POST | `/api/sync` | Sync local data to server |
| GET | `/api/data` | Fetch all data for current user |
| POST | `/api/chat` | Send message to AI assistant |
| GET | `/api/audit-logs` | Paginated audit log (Admin/Safety Manager) |
| GET | `/api/settings` | List system settings |
| GET | `/api/settings/{key}` | Get single setting |
| PUT | `/api/settings/{key}` | Update setting |
| POST | `/api/incidents` | Create incident |
| GET | `/api/incidents` | List incidents |
| GET | `/api/incidents/{id}` | Get incident detail |
| PUT | `/api/incidents/{id}` | Update incident |
| POST | `/api/incidents/{id}/photos` | Upload photo |
| POST | `/api/incidents/{id}/osha-determination` | Run OSHA decision tree |
| PUT | `/api/incidents/{id}/osha-override` | Override OSHA determination |
| POST | `/api/incidents/{id}/close` | Close incident |
| POST | `/api/incidents/{id}/reopen` | Reopen incident |
| POST | `/api/incidents/{id}/status` | Transition incident status |
| GET | `/api/incidents/{id}/timeline` | Lifecycle timeline |
| POST | `/api/incidents/{id}/check-recurrence` | Automated recurrence scan |
| GET | `/api/incidents/{id}/dismissed-suggestions` | Dismissed recurrence suggestions |
| POST | `/api/incidents/{id}/dismiss-suggestion` | Dismiss a recurrence suggestion |
| GET | `/api/incidents/{id}/links` | Get incident links |
| POST | `/api/incident-links` | Create incident link |
| DELETE | `/api/incident-links/{id}` | Delete incident link |
| GET | `/api/incident-clusters` | Get all clusters |
| POST | `/api/investigations` | Create investigation (Safety Manager/Admin) |
| GET | `/api/investigations` | List investigations |
| GET | `/api/investigations/{id}` | Get investigation detail |
| PUT | `/api/investigations/{id}` | Update investigation |
| POST | `/api/investigations/{id}/five-whys` | Create/update 5-Why entry |
| DELETE | `/api/investigations/{id}/five-whys/{whyId}` | Delete 5-Why entry |
| POST | `/api/investigations/{id}/factors` | Add contributing factor |
| DELETE | `/api/investigations/{id}/factors/{factorId}` | Delete contributing factor |
| POST | `/api/investigations/{id}/witnesses` | Add witness statement |
| PUT | `/api/investigations/{id}/witnesses/{witnessId}` | Update witness statement |
| POST | `/api/investigations/{id}/submit-for-review` | Submit for review |
| POST | `/api/investigations/{id}/review` | Approve/reject review |
| GET | `/api/capas/dashboard` | CAPA dashboard KPIs |
| POST | `/api/capas` | Create CAPA |
| GET | `/api/capas` | List CAPAs |
| GET | `/api/capas/{id}` | Get CAPA detail |
| PUT | `/api/capas/{id}` | Update CAPA |
| POST | `/api/capas/{id}/complete` | Mark CAPA complete |
| POST | `/api/capas/{id}/verify` | Verify CAPA effectiveness |
| GET | `/api/dashboard` | Dashboard KPIs and chart data |
| POST | `/api/hours-worked` | Create hours worked entry |
| GET | `/api/hours-worked` | List hours worked entries |
| GET | `/api/dashboard/body-map` | Body part injury data |
| GET | `/api/dashboard/time-heatmap` | Hour/day incident frequency |
| GET | `/api/dashboard/division-radar` | Division comparison metrics |
| POST | `/api/training` | Create training requirement |
| GET | `/api/training` | List training requirements |
| GET | `/api/training/{id}` | Get training detail |
| POST | `/api/training/{id}/complete` | Complete training |
| GET | `/api/notifications` | List notifications for user |
| PUT | `/api/notifications/{id}/read` | Mark notification read |
| POST | `/api/notifications/check-escalations` | Trigger escalation check |
| GET | `/api/users/me/notification-preferences` | Get notification preferences |
| PUT | `/api/users/{id}/notification-preferences` | Update notification preferences |
| GET | `/api/search` | Global cross-entity search |
| GET | `/api/activity` | Live activity feed |
| GET | `/api/osha/300` | OSHA 300 log CSV |
| GET | `/api/osha/300a` | OSHA 300A summary CSV |
| GET | `/api/osha/301/{incidentId}` | OSHA 301 form CSV |
| POST | `/api/agent/keys` | Create agent API key |
| GET | `/api/agent/keys` | List agent API keys |
| DELETE | `/api/agent/keys/{id}` | Revoke agent API key |
| GET | `/api/agent/capabilities` | Agent capabilities manifest |
| GET | `/api/agent/sessions` | Active agent sessions |
| GET | `/api/agent/activity` | Agent-specific activity feed |

### MCP Protocol (API key auth)
| Method | Path | Purpose |
|---|---|---|
| POST | `/mcp/` | MCP JSON-RPC endpoint for tool calls |

## Styling

The app uses the Herzog brand system with light and dark themes:
- **Headings:** Oswald font, uppercase, letter-spaced
- **Body text:** Roboto font
- **Primary brand color:** Herzog Gold (#FFD100)
- **Action color:** Navy Blue (#1E3A5F)
- **App bar:** Black background with gold text and gold bottom border
- **Status badges:** Color-coded by state (green=complete, amber=in progress, red=overdue)
- **KPI cards:** Gold top border, responsive 4-column grid layout
- **Dark mode:** Dark navy background (#0D1B2A), gold accents pop on dark surfaces
