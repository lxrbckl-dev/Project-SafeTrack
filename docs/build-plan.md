# Build Plan — SRD-10: Incident Investigation & Corrective Action System

> This is the TPM's execution plan. Tasks are ordered by dependency. Both SWEs work in parallel.

---

## Phase 0: Foundation

### TASK-001: Dev Login + Role Provider
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** None

**Go:**
- Update `middleware/auth.go` to decode JWT claims and set `userRole` + `userID` on request context via `context.WithValue` (see `backend-patterns.md` Auth Context section). Dev mode: decode self-signed HS256 JWT. Prod mode: verify Firebase/Azure AD RS256 JWT. Helper functions `GetUserRole(r)` and `GetUserID(r)` already exist in `middleware/helpers.go`.
- Add `POST /api/dev-login` endpoint — accepts role string, returns mock JWT with role + user ID

**Flutter:**
- `features/auth/pages/dev_login_page.dart` — role picker screen with 7 role cards
- `features/auth/data/auth_service.dart` — `ChangeNotifier` class holding current user ID, role, display name; exposes `isAtLeast(role)` for hierarchical RBAC checks. Provided at app root via `MultiProvider` in `main.dart` (per CLAUDE.md rule 5a).
- `features/auth/data/role.dart` — enum of 7 roles with hierarchy
- Wrap `MyApp` with `MultiProvider` in `main.dart` — `AuthService` as the first provider
- Update `app_router.dart`: add `/login` route, set as initial location, redirect if no role selected

**QA:** Each of the 7 roles selectable, role persists across navigation, returning to login resets role.

---

### TASK-002: App Shell + Navigation Scaffold
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** None (isolated files; merges shared files AFTER TASK-001 merges)

**Flutter:**
- `features/shell/pages/app_shell_page.dart` — scaffold with responsive sidebar (desktop) / bottom nav (mobile <900px)
- Nav items: Dashboard, Incidents, Investigations, CAPAs, Admin (Admin role only), Audit Log (Admin + Safety Manager only)
- Placeholder pages for each destination
- `ShellRoute` wrapping all authenticated routes in `app_router.dart`

**QA:** Navigation works for all 7 roles. Admin/Audit Log hidden for unauthorized roles. Responsive at 375px.

- Clean up: remove or gate the existing `poc/` routes from `app_router.dart` (these are infrastructure test pages, not features)
- Establish shared form patterns in `flutter/lib/shared/widgets/`: common text field wrapper, dropdown wrapper, date picker wrapper, loading button

---

### TASK-003: Admin Settings (Backend + UI)
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** TASK-001 merged

**Go:**
- `models/setting.go` — `Setting{ID, Category, Key, Value, UpdatedAt, UpdatedBy}`. Register in `AllModels()`.
- Seed defaults: `trir_benchmark=3.0`, `factor_types_list=["People","Equipment","Environmental","Procedural","Management/Organizational"]`, `escalation_days=[3,7,14]`
- `handlers/settings.go` — `GET /api/settings`, `GET /api/settings/{key}`, `PUT /api/settings/{key}` (Admin and Safety Manager, audit-logged)

**Flutter:**
- `features/admin/pages/admin_settings_page.dart` — settings page with Factor Types, TRIR Benchmark, Notifications sections
- `features/admin/pages/factor_types_page.dart` — CRUD list for contributing factor types
- Routes: `/admin`, `/admin/factor-types`

**QA:** Only Admin and Safety Manager can access. TRIR benchmark persists after edit. Factor types add/edit/delete works. Changes appear in audit log.

---

## Phase 1: Incident Reporting

### TASK-004: Incident Models + API (Backend)
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-002 merged

**Go models:**
- `Incident` — ID, Type (7 types), Date, Location, Latitude, Longitude, Division, ProjectJobSite, Description, ImmediateActions, Severity, PotentialSeverity, Shift, Weather, Status, ReporterID, IsDraft, CompletionPercent, IsOshaRecordable, IsDart, OshaOverrideJustification, IsRailroadProperty, RailroadClient, RailroadNotified, RailroadNotificationDate, RailroadNotificationMethod, RailroadNotificationOverdue, CreatedAt, UpdatedAt
- `InjuredPerson` — ID, IncidentID (foreign key, one-to-many: one incident can have multiple injured persons), Name, JobTitle, Division, InjuryType (encrypted), BodyPart (encrypted), BodyPartSide, TreatmentType (encrypted), ReturnToWorkStatus (encrypted), CreatedAt, UpdatedAt
- `IncidentPhoto` — ID, IncidentID, FileName, FileData, ContentType, UploadedBy, CreatedAt
- Register all in `AllModels()`

**Go handlers (`handlers/incidents.go`):**
- `POST /api/incidents` — create incident, encrypt medical fields via `crypto.Encrypt()`, calculate completion %, audit-log
- `GET /api/incidents` — list with filters (?status, ?type, ?division, ?reporter_id). Drafts filtered to reporter only. Medical fields redacted unless Safety Coordinator+
- `GET /api/incidents/{id}` — get with InjuredPerson + Photos. Medical decryption gated by role
- `PUT /api/incidents/{id}` — update, recalculate completion %, audit-log
- `POST /api/incidents/{id}/photos` — upload photo
- `POST /api/incidents/{id}/osha-determination` — OSHA decision tree logic per 29 CFR 1904. Sets is_osha_recordable + is_dart flags. Audit-log
- `PUT /api/incidents/{id}/osha-override` — override with required justification. Audit-log with justification in notes
- `POST /api/incidents/{id}/close` — validates all CAPAs verified effective. Updates status to Closed. Audit-log
- `POST /api/incidents/{id}/reopen` — status to Reopened. Audit-log
- Railroad notification overdue checker: time elapsed since incident vs railroad-specific deadlines (BNSF/UP/CSX/NS x Injury/Near Miss/Property Damage)
- Completion % helper: count all fields, count non-empty, return percentage (all weighted equally)
- Incident status flow enforcement: Draft → Reported (on submit) → Under Investigation → Investigation Complete → CAPA Assigned → CAPA In Progress → Closed. Closed → Reopened.

**QA:** CRUD works. Drafts only visible to reporter. Medical fields encrypted in DB, decrypted only for Safety Coordinator+. Completion % accurate. OSHA decision tree follows 29 CFR 1904. Railroad deadline flags correct per table. Status flow enforced.

---

### TASK-005: Incident Reporting UI (Flutter)
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-004 merged, TASK-001 merged, TASK-002 merged

**Flutter pages/widgets:**
- `features/incidents/pages/incident_list_page.dart` — filterable table with status badges, type icons, severity colors. "New Incident" button for Field Reporter+
- `features/incidents/pages/incident_form_page.dart` — multi-section form:
  - Basic Info: type dropdown (7 types), date/time picker, location with GPS auto-fill button (geolocator), division, project/job site
  - Description: description textarea, immediate actions
  - Classification: severity, potential severity, shift, weather
  - Railroad: conditional section (railroad property toggle → client dropdown [BNSF/UP/CSX/NS], notification tracking fields)
  - Injured Person: conditional section (appears for Injury type) — name, job title, division, injury type, body part, side, treatment type, RTW status
  - Photos: multi-image picker
  - Completion % progress bar at top (updates in real-time, all fields weighted equally)
  - Save Draft + Submit buttons
- `features/incidents/pages/incident_detail_page.dart` — read-only view with all fields, photos, status. Medical fields shown only to Safety Coordinator+. Tabs for linked investigations, CAPAs, recurrence (populated by later tasks)
- `features/incidents/pages/osha_determination_page.dart` — guided decision tree wizard. Step-by-step: work-related? → death? → days away? → restricted/transfer? → medical treatment beyond first aid? → loss of consciousness? → significant diagnosis? Shows result + DART flag. Override option with justification textarea
- `widgets/completion_indicator.dart`, `widgets/gps_location_field.dart`, `widgets/railroad_notification_section.dart`
- Routes: `/incidents`, `/incidents/new`, `/incidents/:id`, `/incidents/:id/edit`, `/incidents/:id/osha`

**QA:** Form renders all sections. Completion % updates live. GPS works or degrades gracefully. Draft save works (visible only to reporter). Railroad section conditional. Injured person section conditional on Injury type. OSHA decision tree navigates correctly. Photos attach. Mobile layout at 375px.

---

## Phase 2: Investigation + CAPA

### TASK-006: Investigation Models + API (Backend)
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-004 merged

**Go models:**
- `Investigation` — ID, IncidentID, LeadInvestigatorID, TeamMembers (JSON), TargetCompletionDate, ActualCompletionDate, Status (Assigned/In Progress/Under Review/Approved/Returned), AssignedBy, ReviewedBy, ReviewComments, ReviewDate, IsOverdue, OverdueEscalationLevel, CreatedAt, UpdatedAt
- `FiveWhy` — ID, InvestigationID, Level, Question, Answer, Evidence, SortOrder, CreatedAt, UpdatedAt
- `ContributingFactor` — ID, InvestigationID, FactorType, FactorDescription, IsPrimary, CreatedAt
- `WitnessStatement` — ID, InvestigationID, WitnessName, WitnessTitle, WitnessEmployer, WitnessPhone, StatementText, CollectionDate, CollectorName, CreatedAt, UpdatedAt
- Register all in `AllModels()`

**Go handlers (`handlers/investigations.go`):**
- `POST /api/investigations` — Safety Manager only. Auto-sets target date by severity (Fatality=48hrs, Lost Time=5 biz days, Medical Treatment=10d, First Aid/Near Miss=14d). Updates incident status to Under Investigation. Audit-log
- `GET /api/investigations` — list with filters (?status, ?investigator_id, ?incident_id, ?overdue=true)
- `GET /api/investigations/{id}` — with 5-Whys, factors, witness statements
- `PUT /api/investigations/{id}` — update. Audit-log
- `POST /api/investigations/{id}/five-whys` — add/update 5-Why entry
- `DELETE /api/investigations/{id}/five-whys/{whyId}` — remove (min 3 enforced on submit, not save)
- `POST /api/investigations/{id}/factors` — add contributing factor
- `DELETE /api/investigations/{id}/factors/{factorId}` — remove
- `POST /api/investigations/{id}/witnesses` — add witness statement
- `PUT /api/investigations/{id}/witnesses/{witnessId}` — update
- `POST /api/investigations/{id}/submit-for-review` — validates min 3 five-whys + 1 primary factor. Status → Under Review
- `POST /api/investigations/{id}/review` — Safety Manager approves or returns with required comments. Approve → updates incident to Investigation Complete, triggers CAPA creation prompt. Audit-log

**QA:** Auto-deadline correct per severity. Min 3 five-whys enforced on submit. Primary factor required. Only Safety Manager can create/review. Approve/return updates statuses. Overdue flag logic works. All operations audit-logged. Business day calculation for 'Lost Time = 5 business days' uses weekend-skipping helper (see backend-patterns.md).

---

### TASK-007: Investigation UI (Flutter)
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-006 merged, TASK-005 merged

**Flutter pages/widgets:**
- `features/investigations/pages/investigation_list_page.dart` — filterable table, overdue highlighted
- `features/investigations/pages/investigation_detail_page.dart` — tabs: Overview, 5-Why Analysis, Contributing Factors, Witness Statements, Review
- `features/investigations/pages/investigation_form_page.dart` — assign investigator, set team
- `widgets/five_why_chain.dart` — **interactive** vertical chain with connecting arrows. In-place editing (keyboard-navigable, screen-reader friendly). Add level button at bottom. Min 3 enforced visually
- `widgets/contributing_factors_panel.dart` — select from configurable types (fetched from admin settings API). Mark one as primary
- `widgets/witness_statement_card.dart` — card with inline editing
- `widgets/investigation_review_panel.dart` — Safety Manager sees Approve/Return buttons with required comments field
- Routes: `/investigations`, `/investigations/:id`, `/investigations/new?incidentId=`

**QA:** 5-Why chain is interactive + keyboard-navigable. Factor types from admin settings (not hardcoded). Witness CRUD works. Review panel visible only to Safety Manager. Approve/Return flows work. Overdue visually flagged. Link from incident detail to "Start Investigation" works.

---

### TASK-008: CAPA Models + API (Backend)
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-006 merged

**Go models:**
- `CAPA` — ID, InvestigationID, IncidentID, Type (Corrective/Preventive), Category (Training/Procedure Change/Engineering Control/PPE/Equipment Modification/Policy Change/Other), Description, AssignedToUserID, AssignedByUserID, DueDate, Priority (Critical/High/Medium/Low), VerificationMethod, VerificationDueDate, Status (Open/In Progress/Completed/Verification Pending/Verified Effective/Verified Ineffective), CompletionNotes, CompletionEvidence, CompletionDate, VerifiedByUserID, VerificationDate, VerificationNotes, IsOverdue, OverdueEscalationLevel, CreatedAt, UpdatedAt
- Register in `AllModels()`

**Go handlers (`handlers/capas.go`):**
- `POST /api/capas` — auto-sets due date by priority (Critical=7d, High=14d, Medium=30d, Low=60d). Updates incident status to CAPA Assigned. Audit-log
- `GET /api/capas` — list with filters (?status, ?assigned_to, ?investigation_id, ?incident_id, ?overdue, ?priority)
- `GET /api/capas/{id}` — single CAPA
- `PUT /api/capas/{id}` — update. When CAPA status changes to In Progress, also update parent incident status to CAPA In Progress. Audit-log
- `POST /api/capas/{id}/complete` — body: {notes, evidence}. Status → Completed → Verification Pending. Sets completion date. Auto-calculates verification due date (Critical=30d, High=60d, Medium/Low=90d post-completion). Audit-log
- `POST /api/capas/{id}/verify` — body: {effective: bool, notes}. **Rejects if verifier == assignee (403).** If effective → Verified Effective. If ineffective → Verified Ineffective, prompts create new CAPA or reopen investigation. Audit-log
- `GET /api/capas/dashboard` — KPI aggregates: open count, overdue count, avg time to close, effectiveness rate

**QA:** Priority due dates correct. Verification due dates correct (from completion date). Verifier != assignee enforced (403). Full lifecycle works. Ineffective path prompts. Incident cannot close until all CAPAs verified. Dashboard KPIs correct. All operations audit-logged.

---

### TASK-009: CAPA Management UI (Flutter)
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-008 merged, TASK-007 merged

**Flutter pages/widgets:**
- `features/capas/pages/capa_dashboard_page.dart` — KPI cards: Open CAPAs, Overdue, Avg Time to Close, Effectiveness Rate. Filterable CAPA table below
- `features/capas/pages/capa_detail_page.dart` — lifecycle stepper. Complete button (assignee only). **Verify button HIDDEN from assignee entirely** (not shown with error). Verify visible to other Safety Coordinator+ users
- `features/capas/pages/capa_form_page.dart` — create from investigation. Type, category, description, assigned user, priority, verification method. Due dates auto-filled
- `widgets/capa_lifecycle_stepper.dart` — visual stepper showing lifecycle stages
- `widgets/ineffective_action_dialog.dart` — dialog after ineffective: "Create New CAPA" or "Reopen Investigation"
- Routes: `/capas`, `/capas/:id`, `/capas/new?investigationId=`

**QA:** Verify button completely absent for assignee (not in DOM). Lifecycle stepper correct. KPI cards accurate. Create from investigation works. Complete + verify flows work. Ineffective dialog offers both options. Overdue CAPAs visually distinguished.

---

## Phase 3: Dashboard, Recurrence, Audit, Notifications

### TASK-010: Safety Dashboard (Backend + Flutter)
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-008 merged (needs incidents, investigations, CAPAs for metrics)

**Go models:**
- `HoursWorked` — ID, ReportingPeriodStart, ReportingPeriodEnd, TotalHours, Division, EnteredByUserID, CreatedAt, UpdatedAt
- Register in `AllModels()`

**Go handlers (`handlers/dashboard.go`):**
- `GET /api/dashboard` — returns: TRIR, DART Rate, Near Miss Ratio, TRIR trend (with configurable benchmark from admin settings), Open Investigations, Open CAPAs, Lost Work Days YTD, incident trend by month (stacked by type, 12-month rolling), incidents by division, severity distribution, leading indicators (Near Miss Rate, CAPA Closure Rate, Investigation Timeliness — target vs actual), recent 10 incidents
- `POST /api/hours-worked` — Safety Manager enters total hours per period
- `GET /api/hours-worked` — list entries

**Flutter pages/widgets:**
- `features/dashboard/pages/safety_dashboard_page.dart` — main dashboard
- KPI cards: TRIR (trend arrow), DART Rate, Near Miss Ratio, Open Investigations, Open CAPAs, Lost Work Days YTD
- Charts (fl_chart): incident trend stacked bar, TRIR trend line with configurable benchmark, incidents by division grouped bar, severity donut
- Leading indicators card: target vs actual for 3 metrics
- Recent incidents table: last 10
- `features/dashboard/pages/hours_worked_page.dart` — Safety Manager entry form
- Routes: `/dashboard` (replace placeholder), `/dashboard/hours-worked`

**QA:** TRIR/DART calculations correct with known test data. Benchmark line matches admin setting. Charts render. All KPIs display. Hours worked restricted to Safety Manager. Dashboard accessible to all roles. Responsive at 375px.

---

### TASK-011: Manual Recurrence Linking
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** TASK-005 merged

**Go models:**
- `IncidentLink` — ID, IncidentID1, IncidentID2, SimilarityType (Same Location/Same Type/Same Root Cause/Same Equipment/Same Person), Notes, LinkedByUserID, CreatedAt
- Register in `AllModels()`

**Go handlers (`handlers/incident_links.go`):**
- `POST /api/incident-links` — Safety Coordinator only. Audit-log
- `GET /api/incidents/{id}/links` — linked incidents for a given incident
- `DELETE /api/incident-links/{id}` — Safety Coordinator only. Audit-log
- `GET /api/incident-clusters` — grouped linked incidents with common threads

**Flutter:**
- Recurrence tab on incident detail page — linked incidents with similarity type + notes. "Link Incident" button for Safety Coordinator
- Link incident dialog — search/select incident, pick similarity type
- `features/incidents/pages/incident_cluster_page.dart` — cluster view with grouped cards
- Route: `/incidents/clusters`

**QA:** Only Safety Coordinator can create links. Links visible on both incidents. All 5 similarity types work. Cluster view groups correctly.

---

### TASK-012: Audit Log Viewer UI
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-002 merged (backend partially exists — needs filter additions)

**Go (extend existing handler — `handlers/audit_logs.go` already has `entity_type`, `entity_id`, `user_id` filters + pagination):**
- Add `date_start` and `date_end` query params to `GET /api/audit-logs` for date range filtering
- Add `action` query param for action type filtering (create, update, status_change, approve, reject, assign, verify)
- Add RBAC check at handler level: only Admin and Safety Manager can access (`middleware.GetUserRole(r)` check)

**Flutter:**
- `features/audit_log/pages/audit_log_page.dart` — paginated filterable table. Columns: Timestamp, User, Role, Action, Entity Type, Entity ID, Notes. Expandable rows showing Before/After JSON diffs. Filters: entity type, user, date range, action type
- Route: `/audit-log` (replace placeholder)

**QA:** Only Admin + Safety Manager can access. Pagination works. All filters work (entity type, user, date range, action type). Expandable rows show before/after. Keyboard-navigable. Responsive at 375px.

---

### TASK-013: Escalation Notifications
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** TASK-006 merged, TASK-008 merged

**Go models:**
- `Notification` — ID, UserID, Title, Message, Type (overdue_investigation/overdue_capa/railroad_notification/review_request), EntityType, EntityID, IsRead, CreatedAt
- Register in `AllModels()`

**Go handlers (`handlers/notifications.go`):**
- `GET /api/notifications` — for current user. Filter: ?unread=true
- `PUT /api/notifications/{id}/read` — mark read
- `POST /api/notifications/check-escalations` — checks investigations + CAPAs for overdue at +3/+7/+14 days. Checks railroad notification deadlines. Creates notifications

**Flutter:**
- Notification bell in app shell header with unread count badge
- Notification panel — list with read/unread styling, click navigates to entity

**QA:** Notifications at correct overdue intervals. Railroad deadline notifications correct. Bell shows unread count. Click navigates correctly. Mark-as-read works. Scoped to current user.

---

## Phase 4: Hardening + Polish

### TASK-014: RBAC Route Protection + Scoped Data
- **Difficulty:** Critical
- **Assignee:** SWE-2
- **Dependencies:** All feature tasks (001-013) merged

**Go:**
- Create `middleware/rbac.go` — `RequireRole(handler, roles...)` and `RequireMinRole(handler, role)` middleware
- Audit every endpoint for correct role enforcement
- PM sees only project-scoped data — filter incidents/investigations/CAPAs by matching PM's user ID against `ProjectJobSite` field (pragmatic approach, no separate user-project mapping table needed)
- Division Manager sees only division-scoped data — filter by matching `Division` field
- Draft incidents filtered to reporter only at API level (orthogonal to role — even a Safety Manager cannot see another user's drafts)
- Medical data decryption gated by role in every handler that returns InjuredPerson data

**Flutter:**
- Sweep all pages: buttons/actions hidden (not disabled) for unauthorized roles
- Executive sees all data read-only
- Field Reporter can only create incidents
- CAPA verify button absent for assignee
- Draft incidents invisible to non-reporters

**QA:** Test all 7 roles end-to-end. Verify each role's Can Do / Cannot Do per rubric RBAC table. Medical data redacted for unauthorized roles. Drafts invisible. Verify button absent for assignee.

---

### TASK-015: Seed Data + Demo Script
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** All feature tasks merged

**Go:**
- `database/seed.go` — creates: 3+ users per role (21+), 15-20 incidents spanning all 7 types and statuses, 5-8 investigations with 5-Why chains + factors + witnesses, 10-15 CAPAs across lifecycle, hours worked data for TRIR/DART, incident links for recurrence, admin settings already seeded
- Idempotent (only if DB empty). Triggered by `SEED_DATA=true` env var

**QA:** Seed populates without errors. Dashboard shows meaningful KPIs. All incident types represented. CAPA lifecycle stages visible. TRIR/DART calculations reasonable.

---

### TASK-016: Integration Testing + Polish
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-015 merged

**Scope:**
- End-to-end happy path: create incident → assign investigation → 5-Why → factors → approve → create CAPA → complete → verify effective → close incident
- Reopen flow: close → reopen → new investigation
- Ineffective CAPA flow: verify ineffective → create new CAPA
- All 7 roles tested for correct access
- All charts render with seed data
- Mobile responsive pass at 375px on all pages
- Keyboard navigation pass on all interactive elements
- WCAG 2.1 AA audit (contrast, focus indicators, semantic structure, screen reader labels)
- Incident detail page compound view (all tabs integrated: info, OSHA, investigation, CAPAs, recurrence, audit)

---

## Phase 5: Differentiators (if time permits)

### TASK-017: In-App AI Chat Widget
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** TASK-002 merged (app shell)

**Flutter:**
- Chat widget (floating action button or sidebar panel) that sends user questions to `POST /api/chat`
- Displays Qwen 2.5 7B responses with wiki-as-RAG context
- Toggle open/close

**QA:** Chat opens/closes. Questions get responses. Responses are contextually relevant.

---

### TASK-018: Keyboard Shortcuts
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-002 merged (app shell)

**Flutter:**
- `Shortcuts`/`Actions` widget in app shell
- Shortcuts: page navigation (D=Dashboard, I=Incidents, V=Investigations, C=CAPAs), chatbot toggle (Ctrl+K or /), Escape to close panels

**QA:** All shortcuts work. No conflicts with browser defaults. Visible shortcut hints somewhere in UI.

---

### TASK-019: In-App AI Agent (Page Nav + Form Filling)
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-017 merged, TASK-005/007/009 merged (forms exist)

**Flutter:**
- JSON action dispatch schema: `{action: "navigate", route: "/incidents/new"}` or `{action: "fill", field: "type", value: "Near Miss"}`
- Chat responses can include structured actions that `go_router` and `TextEditingController` execute
- Gated behind permissions layer

**QA:** Navigation actions work. Form filling actions work. Permissions enforced.

---

## Parallelism Map

```
TIME    SWE-1                          SWE-2                          QA           SHARED FILES
────    ─────                          ─────                          ──           ────────────
T0      TASK-001: Dev Login            TASK-002: App Shell            —            SWE-1 owns router
T1      TASK-003: Admin Settings       (rebases after 001)            Tests 001,2  SWE-1 owns main.go/models.go
T2      (waits for 004)               TASK-004: Incident Backend     Tests 003    SWE-2 owns main.go/models.go
T3      TASK-005: Incident UI          TASK-006: Investigation BE     Tests 004    SWE-1→router, SWE-2→main.go
T4      TASK-007: Investigation UI     TASK-008: CAPA Backend         Tests 005,6  SWE-1→router, SWE-2→main.go
T5a     TASK-009: CAPA UI (routes)     TASK-010: Dashboard (backend)  Tests 007,8  SWE-1 merges router FIRST
T5b     (done)                         TASK-010: Dashboard (routes)   —            SWE-2 rebases, adds routes
T6a     TASK-011: Recurrence (all)     TASK-012: Audit Log (backend)  Tests 009,10 SWE-1 merges shared FIRST
T6b     (done)                         TASK-012: Audit Log (routes)   —            SWE-2 rebases, adds routes
T7a     TASK-013: Notifications        (waits for 013 merge)          Tests 011,12 SWE-1 merges shared FIRST
T7b     (done)                         TASK-014: RBAC Hardening       —            SWE-2 audits all endpoints
T8      TASK-015: Seed Data            TASK-016: Integration          Tests 013,14 Minimal conflicts
T9      TASK-017: AI Chat              TASK-018: Keyboard Shortcuts   Tests 015,16 Isolated feature files
T10     TASK-019: AI Agent             (polish)                       Tests 017-19 Isolated feature files
```

**Conflict resolution rule:** At T5, T6, and T7, SWE-1 merges their shared file changes first. SWE-2 rebases onto updated main before touching shared files. This ensures only one SWE modifies `main.go`, `models.go`, or `app_router.dart` at any given time.

## Task Statistics

| Metric | Value |
|---|---|
| Total tasks | 19 |
| Trivial | 0 |
| Routine | 9 (001, 002, 003, 011, 013, 015, 016, 017, 018) |
| Complex | 9 (004, 005, 006, 007, 008, 009, 010, 012, 019) |
| Critical | 1 (014) |
| SWE-1 tasks | 10 (001, 003, 005, 007, 009, 011, 013, 015, 017, 019) |
| SWE-2 tasks | 9 (002, 004, 006, 008, 010, 012, 014, 016, 018) |

## Shared File Coordination

Only one SWE touches these files at a time:
- `backend/cmd/server/main.go` — route registration
- `backend/internal/models/models.go` — model registration
- `flutter/lib/app/app_router.dart` — route registration

The SWE not touching shared files works on isolated feature directories. Before starting a task that touches shared files, rebase onto latest main.

## Widget Placement Strategy

- **App-wide services** (AuthService, NotificationService): `flutter/lib/core/services/`
- **Shared widgets** (used by multiple features): `flutter/lib/shared/widgets/`
- **Feature-specific widgets**: inside the feature directory at `features/X/widgets/`
- **Feature pages**: `features/X/pages/`
- **API repositories**: `features/X/data/`
