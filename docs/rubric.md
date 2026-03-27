# SRD-10: Incident Investigation & Corrective Action System

> Source: Hackathon rubric received 2026-03-27. This is the spec the agents build against.

---

## Overview

An internal web application for incident reporting, investigation workflows (5-Why analysis, contributing factor classification), CAPA management with effectiveness verification, safety dashboard with TRIR/DART metrics, and manual incident recurrence linking.

---

## In Scope

### Incident Reporting
- Field reporter creates incident report: type (Injury, Near Miss, Property Damage, Environmental, Vehicle, Fire, Utility Strike), date/time, location (GPS auto-fill + manual), division, project/job site, description, immediate actions, severity, potential severity, shift, weather, photos
- Minimal required fields for initial quick report (type, date, location, description); remaining fields completable in stages (save draft)
- Completion percentage indicator on report form
- OSHA recordability determination: guided decision tree per 29 CFR 1904 (was it work-related? did it result in death/days away/restricted duty/transfer/medical treatment beyond first aid/loss of consciousness?); system sets is_osha_recordable and is_dart flags; user can override with required justification (logged)
- Railroad client notification tracking: for incidents on railroad property, track whether client was notified, date, and method; system flags if overdue per railroad-specific rules (BNSF injury ≤2 hrs, UP injury = immediately, CSX injury ≤1 hr, NS injury ≤2 hrs)
- Injured person details: name, job title, division, injury type, body part, side, treatment type, return-to-work status

### Investigation Management
- Safety Manager assigns lead investigator and team; target completion date auto-sets by severity: Fatality = 48 hrs, Lost Time = 5 business days, Medical Treatment = 10 days, First Aid/Near Miss = 14 days
- Overdue investigations flagged; escalation notifications (in-app) at +3, +7, and +14 days overdue
- 5-Why Analysis: investigator builds chain of Why/Answer pairs (minimum 3, no maximum); each level includes question, answer, and supporting evidence; displayed as a vertical visual sequence with connecting arrows
- Contributing Factor Classification: investigator selects factors from configurable FactorType library (People, Equipment, Environmental, Procedural, Management/Organizational categories); one primary factor required; additional contributing factors optional
- Witness statement collection: witness name, title, employer, phone, statement text, collection date and collector
- Investigation review: Safety Manager approves or returns for further investigation with required comments; approved investigation triggers CAPA creation prompt

### CAPA Management
- Create CAPAs from investigation recommendations: type (Corrective / Preventive), category (Training, Procedure Change, Engineering Control, PPE, Equipment Modification, Policy Change, Other), assigned user, due date, priority, verification method
- Priority-based due dates: Critical = 7 days, High = 14 days, Medium = 30 days, Low = 60 days
- Verification due dates: Critical = 30 days post-completion, High = 60 days, Medium/Low = 90 days
- CAPA lifecycle: Open → In Progress → Completed (with notes and evidence) → Verification Pending → Verified Effective / Verified Ineffective
- Verifier must be a different user from the assignee
- Ineffective verification prompts: create new CAPA or reopen investigation
- All CAPAs must be Verified Effective before incident can be Closed
- Overdue CAPAs auto-flagged; in-app escalation notifications
- CAPA dashboard: KPI cards (Open CAPAs, Overdue, Avg Time to Close, Effectiveness Rate); filterable CAPA table

### Manual Recurrence Linking
- Safety Coordinator can manually link two incidents as related with similarity type (Same Location, Same Type, Same Root Cause, Same Equipment, Same Person) and notes
- Linked incidents visible on each incident's Recurrence tab
- Incident cluster view: grouped cards showing linked incidents with common threads surfaced

### Safety Dashboard
- KPI cards: TRIR (with trend arrow), DART Rate, Near Miss Ratio, Open Investigations, Open CAPAs, Lost Work Days YTD
- Incident trend by month: stacked bar by incident type (12-month rolling)
- TRIR trend line with configurable industry benchmark reference line
- Incidents by division: grouped bar chart
- Severity distribution: donut chart
- Leading indicators card: Near Miss Reporting Rate, CAPA Closure Rate, Investigation Timeliness — each with target vs. actual
- Recent incidents table: last 10 with date, type, severity, status, division

### Security & Standards
- Azure AD SSO (demo: dev login with role picker; production: provider-agnostic JWT middleware supports Azure AD as config swap)
- RBAC: 7 roles (see below)
- Injured person medical data restricted to Safety role and above; medical data encrypted at field level
- All incident and investigation actions immutably audit-logged; records retained permanently
- TLS 1.2+; WCAG 2.1 AA; mobile-responsive down to 375px viewport; Herzog UI Brand System throughout

---

## RBAC Roles & Permissions

| Role | Can Do | Cannot Do |
|---|---|---|
| Field Reporter | Create incidents | Manage investigations, CAPAs, or configure system |
| Safety Coordinator | Manage investigations/CAPAs, manually link incidents as related | Approve investigations, configure system |
| Safety Manager | Review/approve investigations, assign investigators, configure system | — (full access to safety functions) |
| PM (Project Manager) | View project-scoped data | Modify incidents, investigations, or CAPAs outside their projects |
| Division Manager | View division-scoped data | Modify incidents, investigations, or CAPAs outside their division |
| Executive | View all data across all divisions | Modify records (view-only) |
| Admin | Configure system (factor types, settings) | — (full system access) |

**Special rules:**
- Injured person medical data: restricted to Safety Coordinator and above
- CAPA verifier must be a different user from the CAPA assignee

---

## Key Formulas

```
TRIR = (Recordable Incidents × 200,000) / Total Hours Worked
DART = (DART Cases × 200,000) / Total Hours Worked
Near Miss Ratio = Near Miss Reports / Recordable Incidents
```

Total hours worked entered manually per reporting period by Safety Manager.

---

## OSHA Decision Tree (condensed)

Work-related? → No = Not Recordable | Yes → Any of: death, days away, restricted/transfer, medical treatment beyond first aid, loss of consciousness, significant diagnosis → Yes = Recordable (+ DART if days away/restricted/transfer) | None = Not Recordable.

First aid treatments (NOT recordable): non-prescription medications, wound cleaning/bandaging, butterfly strips, hot/cold therapy, elastic bandages, eye patches/flushing, tetanus immunization.

---

## Railroad Client Notification Deadlines

| Railroad | Injury | Near Miss | Property Damage |
|---|---|---|---|
| BNSF | 2 hours | 24 hours | 4 hours |
| UP | Immediately | 24 hours | 2 hours |
| CSX | 1 hour | Within shift | 1 hour |
| NS | 2 hours | 24 hours | 2 hours |

---

## Incident Status Flow

```
Reported → Under Investigation → Investigation Complete → CAPA Assigned
→ CAPA In Progress → Closed (all CAPAs verified effective)
Closed → Reopened (if new info or recurrence identified)
```

---

## Implementation Clarifications

Answers from rubric review — these override or refine the spec above.

### Incident Reporting
- **GPS auto-fill**: Developer's call on UX — can auto-request browser location or use a button trigger
- **Photos**: No max count or file size limit specified — developer's call
- **Completion percentage**: Weight all fields equally (not prioritized by required vs optional)
- **Draft visibility**: Draft incident reports visible only to the reporter, not other users
- **Total hours worked**: Literal man-hours (daily/cumulative hours across all units per reporting period). Safety Manager enters the total.

### Investigation Management
- **5-Why visual chain**: Should be interactive (not static with edit buttons) — better for ADA compliance (keyboard-navigable, screen-reader friendly editing in-place)
- **Contributing factor types**: Must be configurable via admin UI (not pre-set/hardcoded)

### CAPA Management
- **Verify button**: Hidden from the assignee entirely (not shown with an error message)

### Safety Dashboard
- **TRIR benchmark line**: Configurable via admin settings page (not a hardcoded default)

### Security
- **Medical data encryption**: Application-level encryption (more secure than database-level alone — encrypts before data reaches the DB)

### Escalation Notifications — PENDING ANSWER
- Banner, toast, or notifications panel? (awaiting response)

### Incident Cluster View — PENDING ANSWER
- Own page or tab within incident detail? (awaiting response)

### Audit Log — PENDING ANSWER
- UI viewer needed or database-level logging sufficient? (awaiting response)

---

## Future Phase (Deferred — NOT in scope for this build)

- Offline incident reporting (we have the infrastructure — potential differentiator)
- Fishbone / Ishikawa diagram visualization (data captured as structured list)
- Automated recurrence detection (manual linking covers this build)
- Advanced analytics views (body part heat map, hour/day heatmap, radar chart)
- OSHA 300/300A/301 log generation (data captured, export deferred)
- Training system CAPA integration
- Email/push notifications (in-app only this build)
