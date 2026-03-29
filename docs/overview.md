# Project Overview

> Flutter/Dart · Cross-Platform · Multi-Agent Claude Code Architecture
> Deadline: Monday Morning Submission

A cross-platform Flutter/Dart application (iOS, Android, Web) built under hackathon conditions. SRD-10: Incident Investigation & Corrective Action System for Herzog. The goal is a polished, judge-ready product with a compelling demo and presentation narrative.

The infrastructure, tooling, agent coordination, branding, and deployment pipelines support rapid feature development. The full spec is in `docs/rubric.md`.

---

## The Rubric Is Everything

The hackathon rubric (`docs/rubric.md`) **dictates priority.** All infrastructure decisions serve the rubric's requirements. See `docs/rubric.md` for the full SRD-10 spec.

---

## Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Frontend | Flutter / Dart | Single codebase for iOS, Android, Web |
| Backend | Go | Thin API layer, single binary, containerized |
| Navigation | `go_router` | Required for in-app agent action dispatching |
| Local DB | Drift (SQLite wrapper) | WebAssembly on web, native SQLite on mobile |
| Remote DB | PostgreSQL (via Go API) | Relational — matches Drift's SQLite schema naturally |
| ORM | GORM | Auto-migrates tables from Go structs on startup |
| Auth | Three-layer | Email/password login (seeded demo accounts, bcrypt) + Firebase Auth (real SSO) + Azure AD-ready (provider-agnostic Go middleware) |
| Connectivity | `connectivity_plus` | Network state detection |
| Local LLM | Ollama | Mac Mini M4 Pro, 48GB RAM |
| LLM Model | Qwen 2.5 3B | Strong coding + reasoning, selected for in-app assistant role |
| CI/CD | GitHub Actions | Wiki regeneration pipeline |
| Agentic Tooling | Claude Code (CLI) | Multi-agent builds; all development happens here |
| Testing (Primary) | Playwright | QA agent writes and runs automated tests for every PR |
| Testing (Secondary) | Claude Browser Agent | Exploratory validation, visual/UX verification |
| Distribution | TestFlight (iOS + macOS, single link) + Web (fallback) | Avoids App Store review; Apple routes to correct platform automatically |
---

## Engineering Principles

- **SOLID principles** enforced across the entire multi-agent architecture
- All components must be **web + mobile compatible** (no platform-specific forks)
- **API-first** data flow with local caching infrastructure (offline sync deferred)
- **ADA/WCAG compliance** required from the start, not retrofitted

---

*See also: [architecture.md](architecture.md) · [requirements.md](requirements.md) · [branding.md](branding.md) · [accessibility.md](accessibility.md) · [presentation.md](presentation.md) · [checklist.md](checklist.md) · [caveats.md](caveats.md)*
