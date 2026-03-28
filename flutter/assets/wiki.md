# SafeTrack — App Wiki

## What This App Does

SafeTrack is an Incident Investigation & Corrective Action System for workplace safety management. It tracks incidents from initial report through investigation, root cause analysis, corrective actions, and verification — with full RBAC, audit logging, and OSHA compliance.

## Pages & Routes

| Route | Page | Purpose |
|---|---|---|
| `/login` | Dev Login | Pick one of 7 roles to explore the app |
| `/dashboard` | Safety Dashboard | TRIR, DART, Near Miss KPIs, trend charts, leading indicators, recent incidents |
| `/dashboard/hours-worked` | Hours Worked | Enter total hours worked per period (Safety Manager/Admin) |
| `/incidents` | Incident List | Filterable table of all incidents with status badges and severity colors |
| `/incidents/new` | New Incident | Create incident: 7 types, GPS, photos, railroad tracking, injured person details |
| `/incidents/:id` | Incident Detail | View incident with tabs: summary, OSHA, investigation, CAPAs, recurrence |
| `/incidents/:id/edit` | Edit Incident | Edit an existing incident |
| `/incidents/:id/osha` | OSHA Determination | Step-by-step OSHA recordability decision tree (29 CFR 1904) |
| `/incidents/clusters` | Incident Clusters | View manually linked incident clusters grouped by similarity |
| `/investigations` | Investigation List | Filterable list with overdue highlighting (Level 1/2/3) |
| `/investigations/new` | New Investigation | Assign investigator, set team, auto-sets target date by severity |
| `/investigations/:id` | Investigation Detail | 5 tabs: overview, 5-Why analysis, contributing factors, witnesses, review |
| `/capas` | CAPA Dashboard | 4 KPI cards (open, overdue, avg close time, effectiveness), filterable table |
| `/capas/new` | New CAPA | Create corrective/preventive action with auto due dates by priority |
| `/capas/:id` | CAPA Detail | Lifecycle stepper, complete/verify actions, ineffective handling |
| `/admin` | Admin Settings | Configure TRIR benchmark, escalation thresholds |
| `/admin/factor-types` | Factor Types | Add/edit/delete contributing factor types |
| `/audit-log` | Audit Log | Paginated audit trail with filters and expandable JSON diffs |

## Roles & Permissions

| Role | Can Do |
|---|---|
| Field Reporter | Create and edit incidents, view dashboard |
| Safety Coordinator | All above + manage investigations, CAPAs, link incidents |
| Safety Manager | All above + approve investigations, assign investigators, access admin settings and audit log |
| PM | View project-scoped incidents and dashboard |
| Division Manager | View division-scoped data |
| Executive | View all data (read-only) |
| Admin | Full access including system settings and audit log |

## Data Flow

All data flows through the Go API to PostgreSQL:
1. User action in Flutter app
2. REST API call to Go backend (JWT authenticated)
3. Go backend writes to PostgreSQL (with audit logging)
4. Drift (SQLite) available for local caching; full offline sync is a future phase

## Key Features

- **Incident Reporting**: 7 incident types, GPS auto-fill, photo attachments, completion percentage, draft saving
- **OSHA Compliance**: Decision tree per 29 CFR 1904, DART flag, override with justification
- **Railroad Notifications**: BNSF/UP/CSX/NS deadline tracking with overdue alerts
- **Medical Data Encryption**: AES-256-GCM encryption for injured person fields, decrypted only for Safety Coordinator+
- **5-Why Root Cause Analysis**: Interactive chain with inline editing, minimum 3 levels enforced
- **Contributing Factors**: Configurable factor types (managed in admin settings), primary factor designation
- **CAPA Lifecycle**: Open → In Progress → Completed → Verification Pending → Verified Effective/Ineffective. Auto due dates by priority. Verify button hidden from assignee.
- **Safety Dashboard**: TRIR/DART/Near Miss KPIs, 12-month trend charts (fl_chart), incidents by division, severity donut, leading indicators
- **Recurrence Linking**: Manually link incidents by similarity type, union-find cluster view
- **Escalation Notifications**: +3/+7/+14 day overdue thresholds, bell badge with unread count
- **Audit Log**: Immutable trail of all actions with before/after JSON diffs
- **AI Assistant**: Qwen 2.5 7B via Ollama with wiki-as-RAG context, page navigation and form filling via JSON action dispatch

## Keyboard Shortcuts

| Key | Action |
|---|---|
| Alt+D (Option+D on Mac) | Go to Dashboard |
| Alt+I (Option+I on Mac) | Go to Incidents |
| Alt+V (Option+V on Mac) | Go to Investigations |
| Alt+C (Option+C on Mac) | Go to CAPAs |
| Ctrl+K | Toggle AI chat |
| / | Toggle AI chat (disabled in text fields) |
| ? | Show keyboard shortcuts overlay |
| Esc | Close open panels |

## Navigation

- Desktop (≥900px): Sidebar navigation with shortcut hint badges
- Mobile (<900px): Bottom navigation bar
- The app uses `go_router` for all navigation with deep linking and web URL support

## Styling

The app uses the Herzog brand system:
- **Headings**: Oswald font, uppercase, letter-spaced
- **Body text**: Roboto font
- **Primary brand color**: Herzog Gold (#FFD100)
- **Action color**: Navy Blue (#1E3A5F)
- **App bar**: Black background with gold text and gold bottom border
- **Status badges**: Color-coded by state (green=complete, amber=in progress, red=overdue)
