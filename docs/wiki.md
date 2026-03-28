# SafeTrack — App Wiki

## What This App Does

SafeTrack is an Incident Investigation & Corrective Action System for workplace safety management. It tracks incidents from initial report through investigation, root cause analysis, corrective actions, and verification — with full RBAC, audit logging, OSHA compliance, offline support, and real-time updates.

## Pages & Routes

| Route | Page | Purpose |
|---|---|---|
| `/login` | Login | Email/password login with tap-to-autofill test account cards |
| `/dashboard` | Safety Dashboard | TRIR, DART, Near Miss KPIs, trend charts, leading indicators, body map, time heatmap, division radar, recent incidents |
| `/dashboard/hours-worked` | Hours Worked | Enter total hours worked per period (Safety Manager/Admin) |
| `/incidents` | Incident List | Filterable table with status badges, severity colors, map toggle |
| `/incidents/new` | New Incident | Create incident: 7 types, GPS, photos, voice-to-text, railroad tracking, injured person details |
| `/incidents/map` | Incident Map | Geographic view of all incidents with severity-coded markers, filters, heat map overlay |
| `/incidents/:id` | Incident Detail | Tabs: summary, OSHA, investigation, CAPAs, recurrence, timeline |
| `/incidents/:id/edit` | Edit Incident | Edit an existing incident |
| `/incidents/:id/osha` | OSHA Determination | Step-by-step OSHA recordability decision tree (29 CFR 1904) |
| `/incidents/clusters` | Incident Clusters | Manually linked incident clusters grouped by similarity |
| `/investigations` | Investigation List | Filterable list with overdue highlighting (Level 1/2/3) |
| `/investigations/new` | New Investigation | Assign investigator, set team, auto-sets target date by severity |
| `/investigations/:id` | Investigation Detail | Tabs: overview, 5-Why analysis, contributing factors (with fishbone diagram), witnesses, review |
| `/capas` | CAPA Dashboard | 4 KPI cards (open, overdue, avg close time, effectiveness), filterable table |
| `/capas/new` | New CAPA | Create corrective/preventive action with auto due dates by priority |
| `/capas/:id` | CAPA Detail | Lifecycle stepper, complete/verify actions, ineffective handling |
| `/training` | Training List | Pending/completed training requirements linked to CAPAs |
| `/training/:id` | Training Detail | Completion form: date, hours, instructor, notes |
| `/admin` | Admin Settings | Configure TRIR benchmark, escalation thresholds |
| `/admin/factor-types` | Factor Types | Add/edit/delete contributing factor types |
| `/admin/osha-export` | OSHA Export | Generate OSHA 300/300A/301 logs as CSV |
| `/audit-log` | Audit Log | Paginated audit trail with filters and expandable JSON diffs |
| `/search` | Global Search | Search across incidents, investigations, and CAPAs |
| `/activity` | Activity Feed | Live feed of system actions with real-time WebSocket updates |
| `/notification-preferences` | Notification Preferences | Choose in-app only, email, or both |

## Login & Test Accounts

The login page uses email/password authentication. Tapping any test account row auto-fills the credentials. All accounts share password **demo1234**.

| Email | Display Name | Role |
|---|---|---|
| reporter@safetrack.demo | Maria Santos | Field Reporter |
| coordinator@safetrack.demo | James Chen | Safety Coordinator |
| manager@safetrack.demo | Sarah Williams | Safety Manager |
| pm@safetrack.demo | Michael Torres | Project Manager |
| director@safetrack.demo | Lisa Anderson | Division Manager |
| executive@safetrack.demo | Robert Kim | Executive |
| admin@safetrack.demo | Alex Thompson | Admin |

After login, Field Reporters land on Incidents; all other roles land on Dashboard.

First-time users see a guided onboarding tour highlighting key features.

## Roles & Permissions

| Role | Can Do |
|---|---|
| Field Reporter | Create and edit incidents, view dashboard |
| Safety Coordinator | All above + manage investigations, CAPAs, training, link incidents |
| Safety Manager | All above + approve investigations, assign investigators, access admin settings, audit log, OSHA export |
| PM | View project-scoped incidents and dashboard |
| Division Manager | View division-scoped data |
| Executive | View all data (read-only) |
| Admin | Full access including system settings and audit log |

## Data Flow

All data flows through the Go API to PostgreSQL:
1. User action in Flutter app
2. REST API call to Go backend (JWT authenticated)
3. Go backend writes to PostgreSQL (with audit logging)
4. Real-time WebSocket broadcasts update to connected clients
5. Drift (SQLite) stores incidents offline when disconnected, auto-syncs on reconnect

## Key Features

### Core Workflow
- **Incident Reporting**: 7 types, GPS auto-fill, photo attachments, voice-to-text input, completion percentage, draft saving
- **OSHA Compliance**: Decision tree per 29 CFR 1904, DART flag, override with justification, OSHA 300/300A/301 log export
- **Railroad Notifications**: BNSF/UP/CSX/NS deadline tracking with overdue alerts
- **Medical Data Encryption**: AES-256-GCM encryption for injured person fields, decrypted only for Safety Coordinator+
- **5-Why Root Cause Analysis**: Interactive chain with inline editing, minimum 3 levels enforced
- **Contributing Factors**: Configurable factor types, primary factor designation, fishbone/Ishikawa diagram visualization
- **CAPA Lifecycle**: Open → In Progress → Completed → Verification Pending → Verified Effective/Ineffective. Auto due dates by priority. Verify button hidden from assignee
- **Training Verification**: Training CAPAs auto-create training requirements. Completion record becomes CAPA evidence

### Dashboard & Analytics
- **Safety Dashboard**: TRIR/DART/Near Miss KPIs, 12-month trend charts, incidents by division, severity donut, leading indicators
- **Body Part Injury Map**: Heat map showing injury counts by body part
- **Time Heatmap**: Hour-of-day x day-of-week incident frequency grid
- **Division Radar Chart**: Multi-metric comparison across divisions
- **Dashboard PDF Report**: Generate monthly safety summary for management meetings

### Investigation Tools
- **Incident Map View**: Geographic view with severity-coded markers, filters, clustering, heat map overlay
- **Automated Recurrence Detection**: Scans new incidents against historical data across 4 match criteria with similarity scoring
- **Manual Recurrence Linking**: Link incidents by similarity type, union-find cluster view
- **Incident Lifecycle Timeline**: Visual chronological timeline of all status changes from audit log data

### Notifications & Real-Time
- **Escalation Notifications**: +3/+7/+14 day overdue thresholds, bell badge with unread count
- **Email Notifications**: SMTP delivery for escalations with user preferences (in-app, email, or both)
- **Real-Time WebSocket**: Instant notification and activity feed updates without polling delay
- **Live Activity Feed**: System-wide action stream with human-readable messages

### Accessibility & Polish
- **Offline Support**: Create incidents without connectivity, auto-sync on reconnect, offline indicator banner
- **Voice-to-Text**: Dictate incident descriptions via browser Speech Recognition API
- **Dark Mode**: Toggle between light and dark themes, preference persisted
- **Global Search**: Search across incidents, investigations, and CAPAs with debounced results
- **Onboarding Tour**: First-time user walkthrough highlighting key features
- **Role-Based Landing**: Field Reporter lands on Incidents, others on Dashboard
- **PDF Export**: Generate formatted incident reports with all details, photos, and audit trail
- **Audit Log**: Immutable trail of all actions with before/after JSON diffs
- **AI Assistant**: Qwen 2.5 7B via Ollama with wiki-as-RAG context, page navigation and form filling via JSON action dispatch, and clickable URL generation

## AI Chat URL Generation

The AI assistant can generate clickable markdown URLs in its responses to help users navigate the app with pre-filled query parameters.

**Format:** `[Descriptive action text](/route?param=value&param2=value2)`

**Examples:**
- User: "I need to report a near miss at Houston rail yard"
- AI: `[Report Near Miss Incident](/incidents/new?type=Near+Miss&location=Houston+Rail+Yard)`

- User: "Create a corrective action for investigation 5"
- AI: `[Create Corrective Action](/capas/new?investigationId=5&type=Corrective)`

- User: "Search for incidents at Building A"
- AI: `[Search Building A Incidents](/search?q=Building+A)`

**Supported routes with query parameters:**
| Route | Query Parameters |
|---|---|
| `/incidents/new` | type, location, division, project, severity, shift, weather |
| `/investigations/new` | incidentId |
| `/capas/new` | investigationId, type, priority |
| `/search` | q |

The AI is role-aware: it only generates URLs for routes the current user's role can access. For example, a Field Reporter will not receive links to `/admin` or `/investigations`.

Clickable URLs are rendered with a gold underline in the chat panel. Tapping a URL navigates to the route. The existing JSON action dispatch (navigate, fill, navigate_and_fill) continues to work alongside URL generation for backward compatibility.

## Keyboard Shortcuts

| Key | Action |
|---|---|
| Ctrl+Shift+H | Go to Dashboard |
| Ctrl+Shift+N | Go to Incidents |
| Ctrl+Shift+V | Go to Investigations |
| Ctrl+Shift+A | Go to CAPAs |
| Ctrl+Shift+K | Toggle AI chat |
| Ctrl+Shift+S | Focus search |
| / | Toggle AI chat (disabled in text fields) |
| ? | Show keyboard shortcuts overlay |
| Esc | Close open panels |

## Navigation

- Desktop (≥900px): Sidebar navigation with shortcut hint badges
- Mobile (<900px): Bottom navigation bar
- Dark mode toggle in sidebar footer
- "Restart Tour" option in sidebar
- The app uses `go_router` for all navigation with deep linking and web URL support

## Styling

The app uses the Herzog brand system with light and dark themes:
- **Headings**: Oswald font, uppercase, letter-spaced
- **Body text**: Roboto font
- **Primary brand color**: Herzog Gold (#FFD100)
- **Action color**: Navy Blue (#1E3A5F)
- **App bar**: Black background with gold text and gold bottom border
- **Status badges**: Color-coded by state (green=complete, amber=in progress, red=overdue)
- **Dark mode**: Dark navy background (#0D1B2A), gold accents pop on dark surfaces
