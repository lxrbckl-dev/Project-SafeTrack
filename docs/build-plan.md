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
- Shortcuts: page navigation (Alt+D=Dashboard, Alt+I=Incidents, Alt+V=Investigations, Alt+C=CAPAs), chatbot toggle (Alt+K or /), Escape to close panels

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

## Phase 6: Future Roadmap

> These tasks implement the rubric's "Future Phase (Deferred)" items. All prerequisite data models and infrastructure are already in place from Phases 0-5.

### TASK-023: User Authentication System (Login Page + Seeded Accounts) ✅
> Renumbered from TASK-020 to TASK-023 to match actual implementation (PR #48, Issue #47).
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** All feature tasks merged

**Go:**
- `models/user.go` — `User{ID, Email, PasswordHash, DisplayName, Role, Division, Project, CreatedAt, UpdatedAt}`. Register in `AllModels()`
- `handlers/login.go` — `POST /api/login` accepts `{email, password}`, validates with bcrypt, returns JWT with same claim structure (sub, role, displayName, division, project, exp, iat)
- Add `/api/login` to public routes in `middleware/auth.go`
- Seed 7 test users in `database/seed.go` (all password `demo1234`, bcrypt-hashed):
  - `reporter@safetrack.demo` — Maria Santos, field_reporter
  - `coordinator@safetrack.demo` — James Chen, safety_coordinator
  - `manager@safetrack.demo` — Sarah Williams, safety_manager
  - `pm@safetrack.demo` — Michael Torres, pm, Project Alpha
  - `director@safetrack.demo` — Lisa Anderson, division_manager, Construction
  - `executive@safetrack.demo` — Robert Kim, executive
  - `admin@safetrack.demo` — Alex Thompson, admin
- Update all existing seed data (incidents, investigations, CAPAs, notifications) to reference new user IDs
- Remove `POST /api/dev-login` endpoint

**Flutter:**
- `features/auth/pages/login_page.dart` — email + password fields, show/hide toggle, login button, error snackbar
- Display "Test Accounts" card on login page listing all 7 emails with roles and shared password
- Update `AuthService` — replace `devLogin(role)` with `login(email, password)` calling `POST /api/login`
- Delete `dev_login_page.dart`
- Update `app_router.dart` — point `/login` to new `LoginPage`
- Update README with test credentials

**QA:** All 7 accounts log in successfully. Wrong credentials show error. RBAC works per role. Seed data attributed to correct users. Notifications scoped to logged-in user. Responsive at 375px. ADA compliant.

---

### TASK-026: Offline Incident Reporting
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-023 merged

**Flutter:**
- Wire existing `AppDatabase` (Drift) into `main.dart` MultiProvider
- Register existing `SyncService` as a Provider with `connectivity_plus` listener
- Save incident form data to Drift when offline, auto-sync to Go API when connectivity restored
- Offline indicator banner in app shell (connectivity_plus stream)
- Photo queuing for deferred upload
- Conflict resolution: server wins (last-write-wins)

**QA:** Create incident while offline (disable network). Reconnect — incident syncs to API. Offline banner appears/disappears. Photos upload after reconnect. No data loss.

---

### TASK-027: Fishbone / Ishikawa Diagram
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-007 merged (investigation UI with contributing factors)

**Flutter:**
- `features/investigations/widgets/fishbone_diagram.dart` — interactive fishbone with 6 category spines (People, Equipment, Environmental, Procedural, Management/Organizational, Other)
- Rendered from existing `ContributingFactor` data on investigation detail page
- Pan/zoom via `InteractiveViewer`, ADA compliant (semantic labels per factor)
- New tab on `InvestigationDetailPage`

**QA:** Diagram renders with correct factors on correct spines. Primary factor visually distinguished. Pan/zoom works. Screen reader labels present.

---

### TASK-028: Automated Recurrence Detection
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-011 merged (manual recurrence linking)

**Go:**
- `handlers/recurrence.go` — `POST /api/incidents/{id}/check-recurrence` scans historical incidents across 4 match criteria (same location, same type, same root cause via contributing factors, same equipment)
- Configurable lookback window via admin setting (default 12 months)
- Returns ranked list of potential matches with similarity scores

**Flutter:**
- "Suggested Matches" section on incident detail Recurrence tab
- Safety Coordinator confirms (creates link) or dismisses suggestions
- Dismissed suggestions not shown again

**QA:** New incident triggers suggestions. Correct matches surfaced. Confirm creates link. Dismiss persists. Lookback window configurable.

---

### TASK-029: Advanced Analytics Views
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-010 merged (safety dashboard)

**Go:**
- `GET /api/dashboard/body-map` — injury counts by body part
- `GET /api/dashboard/time-heatmap` — incidents by hour-of-day × day-of-week
- `GET /api/dashboard/division-radar` — multi-metric comparison across divisions

**Flutter:**
- Body part injury heat map (SVG body diagram with color-coded regions)
- Hour × day heatmap grid (fl_chart or custom painter)
- Division comparison radar chart (fl_chart)
- New tabs or sections on `SafetyDashboardPage`

**QA:** All three visualizations render with seed data. Accurate counts. Responsive. ADA compliant.

---

### TASK-030: OSHA 300/300A/301 Log Generation
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-004 merged (incident models with OSHA fields)

**Go:**
- `handlers/osha_logs.go` — `GET /api/osha/300`, `GET /api/osha/300a`, `GET /api/osha/301/{incidentId}`
- Generate formatted logs per OSHA requirements from existing incident + injured person data
- CSV export format. Safety Manager + Admin RBAC

**Flutter:**
- `features/admin/pages/osha_export_page.dart` — year selector, download buttons for 300/300A, per-incident 301
- Route: `/admin/osha-export`

**QA:** Logs generate with correct data. Only Safety Manager + Admin can access. CSV downloads. Covers all OSHA-recordable incidents.

---

### TASK-031: Email/Push Notifications
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-013 merged (in-app notifications), TASK-023 merged (user accounts with emails)

**Go:**
- `services/email.go` — email delivery service (SMTP or SendGrid)
- Extend `POST /api/notifications/check-escalations` to send email for new escalation notifications
- `PUT /api/users/{id}/notification-preferences` — in-app only, email, or both

**Flutter:**
- Notification preferences toggle in user profile or settings
- Email templates for: overdue investigation, overdue CAPA, railroad deadline, review request

**QA:** Escalation triggers email to correct user. Preferences respected. In-app notifications still work. Email contains correct entity links.

---

### TASK-032: Training CAPA Verification
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-008 merged (CAPA models), TASK-023 merged (user accounts)

**Go models:**
- `TrainingRequirement` — ID, CAPAID, CourseName, Description, AssignedToUserID, AssignedByUserID, DueDate, Status (Pending/Completed), CreatedAt, UpdatedAt. Register in `AllModels()`
- `TrainingCompletion` — ID, TrainingRequirementID, CompletedByUserID, CompletionDate, DurationHours, InstructorName, Notes, Evidence, VerifiedByUserID, CreatedAt. Register in `AllModels()`

**Go handlers (`handlers/training.go`):**
- `POST /api/training` — auto-created when a CAPA with category "Training" is created. Links to CAPA via CAPAID. Sets due date from CAPA due date. Audit-log
- `GET /api/training` — list with filters (?status, ?assigned_to, ?capa_id)
- `GET /api/training/{id}` — single requirement with completion record
- `POST /api/training/{id}/complete` — body: {completionDate, durationHours, instructorName, notes, evidence}. Status → Completed. Auto-updates linked CAPA to Completed with training completion as evidence. Audit-log
- RBAC: Safety Coordinator+ can create/view. Supervisors (Safety Coordinator+) log completions for their team

**Flutter:**
- `features/training/pages/training_list_page.dart` — list of pending/completed training requirements with status badges
- `features/training/pages/training_detail_page.dart` — requirement details, completion form (date, hours, instructor, notes), completion record display
- When creating a CAPA with category "Training", auto-navigate to training requirement after save
- On CAPA detail page, show linked training requirement status with link to training detail
- Routes: `/training`, `/training/:id`

**QA:** Creating a Training CAPA auto-creates training requirement. Completing training auto-completes linked CAPA. Completion record shows as CAPA evidence. Training list filters work. Audit logged. ADA compliant.

---

## Phase 7: Judge Differentiators

> These features go beyond the rubric to show production readiness and polish. High visual impact for demo sessions.

### TASK-033: PDF Incident Report Export
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-005 merged (incident UI), TASK-007 merged (investigation UI), TASK-009 merged (CAPA UI)

**Flutter:**
- Add `pdf` and `printing` packages to `pubspec.yaml`
- `features/incidents/services/incident_pdf_service.dart` — generates formatted PDF report containing:
  - Incident summary (type, date, location, severity, description, immediate actions)
  - Photos (embedded in PDF)
  - OSHA determination result and justification
  - Railroad notification status (if applicable)
  - Injured person details (if Safety Coordinator+ — respect RBAC for medical data)
  - Investigation summary: 5-Why chain, contributing factors, witness statements
  - CAPAs: status, assignee, due date, completion notes, verification result
  - Audit trail summary (key status changes with timestamps)
- "Export PDF" button on `IncidentDetailPage` — generates and opens print/save dialog via `printing` package
- Herzog branding in PDF: Oswald headings, gold accent bars, company logo header
- Works on web (download) and mobile (share sheet)

**QA:** PDF generates with all sections populated. Medical data redacted for unauthorized roles. Photos embedded. Branding correct. Works on Chrome web and mobile. Print dialog opens.

---

### TASK-034: Global Search
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-002 merged (app shell)

**Go:**
- `handlers/search.go` — `GET /api/search?q=` searches across incidents (description, location, type), investigations (team members, review comments), and CAPAs (description, category). Returns unified results with entity type, ID, title, snippet, and relevance. RBAC-scoped (user only sees results they have access to). Limit 20 results
- Full-text search via PostgreSQL `ILIKE` or `to_tsvector/to_tsquery` for better performance

**Flutter:**
- Search icon button in AppBar (both desktop and mobile layouts in `app_shell_page.dart`)
- `Alt+S` keyboard shortcut to focus search
- `features/search/pages/search_results_page.dart` — grouped results by entity type (Incidents, Investigations, CAPAs) with clickable rows that navigate to detail pages
- Search input with debounced API calls (300ms)
- Route: `/search?q=`

**QA:** Search returns results across all 3 entity types. RBAC-scoped (Field Reporter doesn't see admin data). Debounce works. Clicking result navigates to correct detail page. Empty state for no results. Alt+S focuses search. Responsive at 375px.

---

### TASK-035: Incident Lifecycle Timeline
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** TASK-005 merged (incident detail), TASK-012 merged (audit log)

**Go:**
- `GET /api/incidents/{id}/timeline` — queries audit log by `entity_type=incident, entity_id={id}` plus related investigations and CAPAs. Returns chronological list of events: `{timestamp, action, userDisplayName, userRole, description, entityType}`. Includes cross-entity events (investigation created, CAPA assigned, CAPA verified)

**Flutter:**
- `features/incidents/widgets/incident_timeline.dart` — vertical timeline widget with:
  - Color-coded dots by action type (green=created, blue=updated, amber=status change, red=escalation)
  - Timestamp, user name, action description
  - Connecting line between events
- New "Timeline" tab on `IncidentDetailPage` (6th tab after Recurrence)
- ADA: semantic labels per event, keyboard navigable

**QA:** Timeline shows all lifecycle events in chronological order. Cross-entity events included (investigation, CAPAs). Color coding correct. Scrollable for long timelines. Screen reader accessible.

---

### TASK-036: Dark Mode
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-002 merged (app shell with theme)

**Flutter:**
- `flutter/lib/app/herzog_theme.dart` — add `herzogDarkTheme()` function:
  - Background: dark navy (#0D1B2A) instead of off-white
  - Surface: dark gray (#1B2838) for cards
  - Text: light gray/white instead of rich black
  - Keep gold accent (#FFD100) and navy action (#1E3A5F) — gold pops on dark backgrounds
  - Status badge colors adjusted for dark contrast (WCAG AA)
  - Charts (fl_chart) colors adjusted for dark backgrounds
- `core/services/theme_service.dart` — `ChangeNotifier` that toggles between light/dark, persists preference to `SharedPreferences`
- Register `ThemeService` in `main.dart` MultiProvider
- `MaterialApp` uses `Consumer<ThemeService>` to switch `theme`/`darkTheme`
- Toggle button in app shell sidebar (bottom, near shortcut hint) — sun/moon icon
- Add `shared_preferences` to `pubspec.yaml` if not already present

**QA:** Toggle switches between light and dark. All pages readable in dark mode. WCAG AA contrast ratios met. Charts visible. Preference persists across sessions. Gold branding still prominent.

---

### TASK-037: Role-Based Landing Pages
- **Difficulty:** Routine
- **Assignee:** SWE-1
- **Dependencies:** TASK-001 merged (auth/roles), TASK-010 merged (dashboard)

**Flutter:**
- Update `app_router.dart` redirect logic: after login, route to role-appropriate landing:
  - **Field Reporter** → `/incidents` (their incidents, with "New Incident" prominent)
  - **Safety Coordinator** → `/dashboard` (full safety dashboard)
  - **Safety Manager** → `/dashboard` with pending review count badge
  - **PM** → `/dashboard` (project-scoped KPIs)
  - **Division Manager** → `/dashboard` (division-scoped KPIs)
  - **Executive** → `/dashboard` (read-only overview)
  - **Admin** → `/dashboard`
- Add "Welcome back, [Name]" header with role badge on landing
- Quick action cards on landing: role-specific shortcuts (e.g., Field Reporter sees "Report New Incident", Safety Manager sees "3 Investigations Pending Review")

**QA:** Each role lands on correct page after login. Welcome message shows correct name and role. Quick action cards are role-appropriate. Navigation still works normally after landing.

---

### TASK-038: Live Activity Feed
- **Difficulty:** Complex
- **Assignee:** SWE-2
- **Dependencies:** TASK-012 merged (audit log), TASK-023 merged (user accounts)

**Go:**
- `handlers/activity.go` — `GET /api/activity?since=` returns recent audit log entries formatted as human-readable feed items: `{id, timestamp, userDisplayName, userRole, message, entityType, entityId, action}`
- Message templates: "Maria Santos reported a Near Miss incident", "Sarah Williams approved Investigation #4", "James Chen completed CAPA #12"
- RBAC-scoped: users only see activity for entities they can access
- Returns last 50 items, or items since a given timestamp

**Flutter:**
- `features/activity/widgets/activity_feed.dart` — scrollable feed with:
  - User avatar/initials circle
  - Formatted message with entity link
  - Relative timestamp ("2 minutes ago", "1 hour ago")
  - Action-type icon (report, approve, complete, etc.)
- Accessible from dashboard page as a collapsible panel or dedicated section
- Auto-refreshes every 30 seconds (same polling pattern as notifications)
- Route: `/activity` (or embedded in dashboard)

**QA:** Feed shows recent actions across the system. Messages are human-readable. Clicking entity link navigates correctly. RBAC-scoped (Field Reporter doesn't see admin actions). Auto-refresh works. Responsive.

---

## Phase 8: Domain Innovation

> Features that show deep understanding of the safety domain and real-world field worker needs.

### TASK-039: Incident Map View
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-004 merged (incident model with Latitude/Longitude fields)

**Flutter:**
- Add `flutter_map` and `latlong2` packages to `pubspec.yaml` (open-source, no API key required)
- `features/incidents/pages/incident_map_page.dart` — full-page map view with:
  - OpenStreetMap tile layer (free, no key)
  - Incident markers color-coded by severity (red=Critical, amber=High, blue=Medium, green=Low)
  - Marker clusters when zoomed out (group nearby incidents)
  - Tap marker → popup card with incident type, date, severity, status, link to detail page
  - Filter controls: by type, severity, status, date range (same filters as incident list)
  - Heat map overlay toggle showing incident density
- Map icon button in incident list page header (toggle between list and map view)
- Route: `/incidents/map`
- Existing `geolocator` package (already installed) for "center on my location" button
- Responsive: full-width map on all screen sizes

**QA:** Map renders with incident markers at correct GPS coordinates. Color coding by severity correct. Tap shows popup with correct data. Filters work. Cluster/uncluster on zoom. Heat map toggle works. "My location" centers map. ADA: markers have semantic labels. Works on Chrome web.

---

### TASK-040: Voice-to-Text Incident Reporting
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-005 merged (incident form)

**Flutter:**
- Add `speech_to_text` package to `pubspec.yaml`
- `shared/widgets/voice_input_button.dart` — microphone icon button that:
  - Starts browser Speech Recognition API via `speech_to_text` package
  - Shows pulsing red indicator while listening
  - Appends recognized text to the associated `TextEditingController`
  - Graceful degradation: if speech not available (unsupported browser), hide the button entirely
- Add voice input button next to these text fields on `IncidentFormPage`:
  - Description textarea
  - Immediate Actions textarea
- Also add to `InvestigationFormPage` and `CAPAFormPage` description fields
- Works on Chrome (Web Speech API), gracefully hidden on unsupported platforms

**QA:** Microphone button appears next to description fields. Tapping starts listening (browser permission prompt). Speaking fills text. Stop listening appends text. Button hidden on unsupported browsers. Pulsing indicator visible during recording. ADA: button has aria label "Start voice input".

---

### TASK-041: Dashboard PDF Summary Report
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-010 merged (dashboard), TASK-033 merged (pdf/printing packages installed)

**Flutter:**
- `features/dashboard/services/dashboard_pdf_service.dart` — generates monthly safety summary PDF:
  - Header: "SafeTrack Monthly Safety Report — [Month Year]", Herzog branding
  - KPI summary: TRIR, DART Rate, Near Miss Ratio, Open Investigations, Open CAPAs
  - TRIR trend vs benchmark (rendered as simple table or sparkline)
  - Incident breakdown by type (table)
  - Incident breakdown by division (table)
  - Severity distribution (table)
  - Leading indicators: Near Miss Rate, CAPA Closure Rate, Investigation Timeliness with target vs actual
  - Open/overdue items requiring attention
  - Footer: generated date, report period, "Generated by SafeTrack"
- "Export Report" button on `SafetyDashboardPage` header
- Month/year picker dialog before generating

**QA:** PDF generates with current dashboard data. All KPI sections populated. Branding correct. Month picker works. Print/save dialog opens. Works on Chrome web.

---

## Phase 9: Demo Polish

> Features that make the first 30 seconds of a judge demo unforgettable.

### TASK-042: Onboarding Tour
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-002 merged (app shell)

**Flutter:**
- Add `tutorial_coach_mark` package to `pubspec.yaml`
- `core/services/onboarding_service.dart` — tracks whether tour has been shown (via `SharedPreferences`)
- Tour triggers on first login (or when `SharedPreferences` has no `onboarding_complete` flag)
- Tour steps (highlighted with coach marks):
  1. Sidebar/nav — "Navigate between Dashboard, Incidents, Investigations, and CAPAs"
  2. New Incident button — "Report an incident from here"
  3. Notification bell — "Escalation alerts appear here"
  4. AI chat (Alt+K) — "Ask the AI assistant questions about SafeTrack"
  5. Keyboard shortcuts — "Press ? to see all keyboard shortcuts"
- "Skip Tour" button always visible
- "Restart Tour" option in settings or sidebar footer
- Adapts to role: Field Reporter tour emphasizes incident creation, Safety Manager tour emphasizes review/approval

**QA:** Tour triggers on first login. All 5 steps highlight correct elements. Skip button works. Tour doesn't trigger on subsequent logins. "Restart Tour" works. Role-appropriate steps shown. ADA: coach marks are keyboard navigable.

---

### TASK-043: Real-Time WebSocket Updates
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-013 merged (notifications), TASK-038 merged (activity feed)

**Go:**
- Add `github.com/gorilla/websocket` to `go.mod`
- `handlers/websocket.go` — `GET /api/ws` upgrades HTTP connection to WebSocket
  - Authenticated: requires valid JWT in query param (`?token=...`)
  - Server broadcasts events when audit log entries are created: `{type: "notification"|"activity", data: {...}}`
  - Hub pattern: central hub manages connected clients, broadcasts to relevant users based on RBAC
  - Graceful fallback: if WebSocket connection fails, Flutter falls back to existing 30s polling

**Flutter:**
- Add `web_socket_channel` package to `pubspec.yaml`
- `core/services/websocket_service.dart` — `ChangeNotifier` that:
  - Connects to `ws://localhost:8000/api/ws?token=...` on login
  - Listens for notification and activity events
  - Updates `NotificationService` unread count in real-time
  - Updates activity feed in real-time (if TASK-038 is built)
  - Auto-reconnect with exponential backoff on disconnect
  - Falls back to polling if WebSocket unavailable
- Register in `main.dart` MultiProvider

**QA:** Create incident as one user → notification bell updates instantly for Safety Manager (no 30s delay). WebSocket reconnects after network drop. Falls back to polling if WebSocket endpoint unavailable. No duplicate notifications. Works on Chrome web.

---

## Phase 10: AI-Powered Navigation

> Enhance the in-app AI assistant to generate clickable pre-filled URLs, making the chat a command center for the app.

### TASK-044: Query Parameter Pre-Fill on Form Pages
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-005, TASK-007, TASK-009 merged (form pages exist)

**Flutter:**
- Update `IncidentFormPage` to read query parameters from `GoRouterState.uri.queryParameters` on init:
  - `type`, `division`, `project`, `location`, `severity`, `description`, `shift`, `weather`
  - Pre-fill corresponding `TextEditingController` values
- Update `InvestigationFormPage` to read: `incidentId` (already exists), `leadInvestigator`
- Update `CAPAFormPage` to read: `investigationId` (already exists), `type`, `category`, `priority`, `description`
- URL example: `/incidents/new?type=Near+Miss&division=Construction&location=Rail+Yard+5`
- Fields pre-filled but editable — user reviews before submitting

**Edge cases to handle:**
- Query param pre-fill MUST NOT run in edit mode — guard against `_isEditMode` to prevent race condition with `_loadExisting()` API fetch
- URL-encoded values: `Rail+Yard+5` and `Rail%20Yard%205` must both decode correctly
- Invalid enum values in query params (e.g., `?type=InvalidType`) — ignore gracefully, don't crash
- Deep-link with params while not logged in: auth redirect must preserve query params so they survive the login → redirect-back flow
- FormFillService conflict: if AI dispatch queues pending fields AND URL has query params, query params take precedence (clear pending fields on param-based init)
- Type coercion: `?severity=High` is invalid (severity uses Fatality/Lost Time/etc, not High/Low) — must validate against actual enum values

**QA:** Navigate to `/incidents/new?type=Injury&division=Construction` → verify Type and Division are pre-filled. Verify all supported params work on each form. Verify URL with no params still works (empty form). Verify pre-filled fields are editable. Verify edit mode (`/incidents/5/edit?type=Injury`) ignores query params and loads from API. Verify invalid enum values are ignored.

---

### TASK-045: AI Chat URL Generation
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-044 merged (pre-fill params work), TASK-017 merged (AI chat exists)

**Go:**
- Update `handlers/chat.go` system prompt to include:
  - Full list of available routes with supported query parameters
  - Instruction: when user describes an action, generate a clickable URL instead of JSON dispatch
  - URL format: `[Action description](/route?param=value&param2=value2)`
  - Example: user says "I need to report a near miss at the Houston rail yard" → AI responds with context + `[Report Near Miss Incident](/incidents/new?type=Near+Miss&location=Houston+Rail+Yard)`
- Keep existing JSON action dispatch as fallback for non-URL actions (navigate-only, no pre-fill needed)
- Update wiki.md RAG context with the URL generation format

**Flutter:**
- Update `ChatWidget` message rendering to detect markdown links `[text](url)` and render as clickable `InkWell` widgets that call `context.go(url)`
- Style clickable links with Herzog gold underline

**Edge cases to handle:**
- Whitelist valid action types in `parseActions()` — unknown types from Qwen must be logged and dropped, not silently swallowed
- Chat UI currently uses `SelectableText` (no markdown) — must add `[text](url)` link detection and render as tappable widgets
- AI must not generate URLs for routes the user's role can't access (e.g., no `/admin` links for Field Reporter)
- Query params with special characters must be URL-encoded in AI output
- Keep JSON action dispatch working alongside URL generation — don't break existing form-fill behavior
- Malformed markdown links from AI (e.g., `[Report][/url]`, `[[double brackets]]`) — render as plain text, don't crash
- Onboarding tour overlay: if tour is active, AI-generated URL clicks may be blocked by coach-mark overlay — test this interaction
- API key material must NEVER appear in error logs, stack traces, or monitoring output

**QA:** Ask AI "I need to report an injury at the downtown office" → verify it generates a clickable URL → click it → verify incident form opens with type=Injury and location pre-filled. Test with various natural language inputs. Verify non-URL responses still render normally. Verify RBAC — AI should not generate URLs for pages the user's role can't access. Verify existing JSON action dispatch still works (backward compat). Test with malformed markdown — verify graceful degradation to plain text.

---

## Phase 11: MCP Agent Integration

> Expose SafeTrack as an MCP server so external AI agents (Claude Desktop, OpenClaw, any MCP client) can authenticate, discover capabilities, and execute role-scoped actions through the existing API.

### TASK-046: Agent API Key System
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-023 merged (user model)

**Go models:**
- `AgentApiKey` — ID, UserID (foreign key to User), KeyHash (bcrypt hash of the API key), KeyPrefix (first 8 chars for display, e.g., `stk_abc1...`), Name (user-given label, e.g., "OpenClaw agent"), IsActive, LastUsedAt, CreatedAt, RevokedAt. Register in `AllModels()`

**Go handlers (`handlers/agent_auth.go`):**
- `POST /api/agent/keys` — Safety Manager or Admin creates an API key for a user. Returns the full key ONCE (never stored in plaintext). Response: `{key: "stk_abc123...", prefix: "stk_abc1", userId: 5, role: "field_reporter"}`
- `GET /api/agent/keys` — list active keys for current user (shows prefix + name + lastUsed, never full key)
- `DELETE /api/agent/keys/{id}` — revoke a key (sets IsActive=false, RevokedAt=now). Audit-logged
- `POST /api/agent/auth` — accepts `{apiKey: "stk_abc123..."}`. Validates against stored hash. Returns JWT with same claims as user login PLUS `is_agent: true` claim. Audit-logged as "agent_login"

**Go middleware update (`middleware/auth.go`):**
- Extract `is_agent` claim from JWT and set on request context
- Add `GetIsAgent(r)` helper to `helpers.go`

**Go audit log update:**
- All audit log entries include `is_agent` flag so actions show "Maria Santos (via agent)" vs "Maria Santos"

**Flutter:**
- `features/admin/pages/api_keys_page.dart` — manage API keys: create (show key once in modal), list active keys, revoke
- Route: `/admin/api-keys` (Admin + Safety Manager only)

**Edge cases to handle:**
- **HIGH: JWT backward compatibility** — existing JWTs from `/api/login` won't have `is_agent` claim. Middleware MUST default missing claim to `false`, not crash. Extract with: `isAgent, _ := claims["is_agent"].(bool)` (nil → false)
- **MEDIUM: Audit log migration** — add `IsAgent bool` field to AuditLog model with `gorm:"default:false"`. GORM auto-migrates. Old records default to false (human). Update `LogAction()` to accept `isAgent` parameter
- `/api/agent/auth` must be a PUBLIC route (no JWT required — agents authenticate with API key to GET a JWT)
- API key generation must use crypto/rand, not math/rand
- Show full key exactly once in the creation response, then never again — UI must warn "copy this now"
- **HIGH: API key brute force** — add rate limiting on `/api/agent/auth` (e.g., 5 failed attempts per minute per IP)
- **HIGH: API key in error logs** — scrub key material from all error messages and log output. Never log the full key
- **MEDIUM: Revoked key window** — revoked API key's JWT remains valid until 24h expiry. Consider adding key ID to JWT claims so middleware can check revocation in real-time, or shorten agent JWT expiry to 1 hour
- **CRITICAL: Use bcrypt for key hashing** — never SHA256 without salt. Verify `bcrypt.CompareHashAndPassword()` is used
- **MEDIUM: WebSocket event loop** — if agent is connected via WebSocket, ensure it doesn't receive events for its own actions (filter by `userId` + `is_agent` on broadcast)

**QA:** Create API key → authenticate with it via curl → verify JWT has is_agent=true. Verify RBAC is identical to user's role. Revoke key → verify auth fails. Verify audit log shows agent attribution. Verify only Admin/Safety Manager can manage keys. Verify old user JWTs (without is_agent) still work with default false. Verify revoked key returns 401 immediately.

---

### TASK-047: Agent Capabilities Endpoint
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-046 merged (agent auth)

**Go handlers (`handlers/agent_capabilities.go`):**
- `GET /api/agent/capabilities` — returns role-scoped list of available actions as JSON:
  ```json
  {
    "role": "field_reporter",
    "capabilities": [
      {
        "action": "create_incident",
        "method": "POST",
        "path": "/api/incidents",
        "description": "Create a new incident report",
        "parameters": { "type": "string enum [Injury, Near Miss, ...]", "location": "string", ... }
      },
      {
        "action": "list_incidents",
        "method": "GET",
        "path": "/api/incidents",
        "description": "List incidents (scoped to reporter's drafts + all non-draft)"
      }
    ]
  }
  ```
- Each role gets a different capabilities set matching existing RBAC rules
- Include parameter schemas for create/update actions
- Safety Manager gets investigation/CAPA management capabilities
- Admin gets settings/API key capabilities
- Field Reporter gets incident creation only

**Edge cases to handle:**
- Capabilities must stay in sync with actual RBAC rules — if a new endpoint is added, capabilities must be updated
- Parameter schemas must match actual API validation (e.g., if API requires `type` as enum, schema must list exact values)
- Capabilities for PM and Division Manager must reflect scoping (PM sees "list incidents (project-scoped)" not just "list incidents")

**QA:** Authenticate as each of 7 roles → call capabilities → verify each role sees only their permitted actions. Verify parameter schemas are accurate. Verify unauthorized actions are not listed. Verify PM/Division Manager capabilities mention scoping.

---

### TASK-048: MCP Server Protocol
- **Difficulty:** Complex
- **Assignee:** SWE-1
- **Dependencies:** TASK-046 merged (agent auth), TASK-047 merged (capabilities)

**Go:**
- `handlers/mcp.go` — MCP protocol handler at `/mcp/`
- Implements MCP server protocol (JSON-RPC 2.0 over HTTP or SSE):
  - `initialize` — returns server info and capabilities
  - `tools/list` — maps capabilities endpoint to MCP tool definitions with JSON schemas
  - `tools/call` — executes a tool by proxying to the corresponding REST endpoint with the agent's JWT
- Tool names derived from capabilities: `create_incident`, `list_incidents`, `get_investigation`, `approve_investigation`, `create_capa`, `verify_capa`, `search`, `get_dashboard`, etc.
- Each tool includes parameter schema so MCP clients auto-generate correct inputs
- Authentication: API key passed as MCP auth header, converted to JWT internally
- RBAC enforced: tools only listed if the agent's role permits them

**Example MCP tool definition:**
```json
{
  "name": "create_incident",
  "description": "Create a new incident report in SafeTrack",
  "inputSchema": {
    "type": "object",
    "properties": {
      "type": {"type": "string", "enum": ["Injury", "Near Miss", "Property Damage", "Environmental", "Vehicle", "Fire", "Utility Strike"]},
      "location": {"type": "string"},
      "division": {"type": "string"},
      "description": {"type": "string"},
      "severity": {"type": "string", "enum": ["Low", "Medium", "High", "Critical"]}
    },
    "required": ["type", "location", "description"]
  }
}
```

**Edge cases to handle:**
- **MEDIUM: Route namespace** — MCP routes at `/mcp/*` need separate auth middleware (`MCPAuth`) that accepts API keys, NOT `FirebaseAuth` which expects JWTs. Register via `handlers.RegisterMCPRoutes(mux, db)` outside the `api` mux
- **MEDIUM: WebSocket event namespacing** — if MCP events piggyback on existing WebSocket hub, namespace types as `mcp.message`, `mcp.result` to avoid collision with `notification` and `activity` types
- **LOW: JSON-RPC library** — MCP uses JSON-RPC 2.0. Pre-select a Go library (e.g., `github.com/sourcegraph/jsonrpc2`) or implement a minimal custom parser. Must handle: method not found, invalid params, internal error
- MCP `tools/call` must validate all input against the schema BEFORE proxying to the REST endpoint — don't pass garbage to the API
- **HIGH: Rate limiting required** — agents can call tools much faster than humans. Implement per-key rate limiting (60 requests/minute). Without this, a single agent can DoS the system
- **MEDIUM: Input sanitization** — MCP tool inputs pass JSON schema validation but may contain XSS/injection payloads. GORM parameterized queries handle SQL injection, but verify no raw SQL in analytics/search handlers
- **MEDIUM: Agent offline** — MCP has no offline mode. If backend is down, agent gets connection refused. Return clear JSON-RPC error, not generic 500

**QA:** Connect a test MCP client → call tools/list → verify tools match role's capabilities. Call create_incident tool → verify incident created in database. Call with wrong role → verify tool not listed. Verify JSON-RPC error handling for invalid tool names and bad parameters. Verify MCP auth rejects user JWTs (must use API key). Verify rate limiting — 61st request in 1 minute returns 429. Test XSS payload in tool input — verify stored safely, rendered safely.

---

### TASK-049: Agent Session Awareness
- **Difficulty:** Routine
- **Assignee:** SWE-2
- **Dependencies:** TASK-046 merged (agent auth with is_agent claim)

**Go:**
- Track active agent sessions: `GET /api/agent/sessions` (Admin only) — shows currently active agent tokens (last API call within 5 minutes), their role, user, and key name
- `GET /api/agent/activity` — scoped version of activity feed filtered to agent-only actions

**Flutter:**
- `features/admin/pages/agent_sessions_page.dart` — live view of active agent sessions with role, user, last action, connected since
- Agent activity indicator in the admin dashboard — "2 agents active" badge
- Route: `/admin/agents`

**Edge cases to handle:**
- Session tracking must handle multiple agents for the same user (e.g., user has 3 API keys, 2 active simultaneously)
- "Last used" timestamp must update on every API call, not just auth — use middleware to update `AgentApiKey.LastUsedAt`
- Session timeout (5 min) is a display heuristic, not a real session — agents don't have persistent connections (except WebSocket)

**Edge cases to handle (additional):**
- **HIGH: Division scoping on agent activity** — agent activity feed must respect division/project scoping. A Safety Coordinator for East Plant should not see agent actions in West Plant
- Agent activity must show rollback/rejection actions, not just creates — if Safety Manager rejects an agent-created investigation, that rejection must appear in agent activity
- Audit log pagination: with agents generating high volumes, ensure audit log viewer handles 10,000+ records without OOM (cursor-based pagination, not offset)

**QA:** Authenticate agent via API key → verify it appears in active sessions. Wait 5+ minutes → verify it drops off. Verify only Admin can see sessions page. Verify agent activity filters correctly. Verify multiple concurrent agents for same user show separately. Verify division-scoped agent activity. Verify rejection/rollback events visible in agent activity.

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
| Total tasks | 44 (40 complete + 8 bug fixes + 6 planned) |
| Trivial | 0 |
| Routine | 18 (001, 002, 003, 011, 013, 015, 016, 017, 018, 024, 030, 035, 036, 040, 042, 044, 047, 049) |
| Complex | 25 (004, 005, 006, 007, 008, 009, 010, 012, 019, 023, 026, 027, 028, 029, 031, 032, 033, 034, 038, 039, 041, 043, 045, 046, 048) |
| Critical | 1 (014) |
| Phases 0-5 (complete) | 19 tasks — all merged and QA verified |
| Post-launch (complete) | TASK-021, 022, 023, 024 — merged |
| Phase 6 (complete) | 7 tasks — TASK-026, 027, 028, 029, 030, 031, 032 |
| Phase 7 (complete) | 6 tasks — TASK-033, 034, 035, 036, 037, 038 |
| Phase 8 (complete) | 3 tasks — TASK-039, 040, 041 |
| Phase 9 (complete) | 2 tasks — TASK-042, 043 |
| Bug fixes (complete) | 8 fixes — issues #88-91, #94-97 |
| Phase 10 (planned) | 2 tasks — TASK-044, 045 |
| Phase 11 (planned) | 4 tasks — TASK-046, 047, 048, 049 |

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
