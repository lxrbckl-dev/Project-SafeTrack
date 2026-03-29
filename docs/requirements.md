# Feature Requirements

All components must be **Flutter/Dart**, **web + mobile compatible**, and **ADA-compliant**.

---

## Locally Hosted LLM
- Deployed post-build on Mac Mini M4 Pro (Ollama, 48GB RAM)
- Assists users with app navigation and feature explanations
- Fed a **wiki page** as RAG context injected into the system prompt
- Long-term idea: use **AutoResearch** to train/optimize the local 7B model to act as the in-app assistant
- **AutoResearch is a two-phase play:**
  - **Phase 1 (Agent Prompts):** After the app is built and real tasks exist, use AutoResearch to optimize the agent definition files (`tpm.md`, `swe-1.md`, etc.) against eval test cases. The agents get measurably better at building *this specific app*. Shopify used this pattern on a coding agent — 53% performance improvement across 120 automated experiments.
  - **Phase 2 (In-App Assistant):** Use AutoResearch to optimize Qwen 2.5 3B with app-specific wiki/docs as training context. The user-facing assistant gets smarter about *this specific app*.
  - **Judge narrative:** Same AutoResearch pattern, two applications — one improves the developers, one improves the product. Continuous improvement at both layers.

## Wiki Auto-Regeneration Pipeline
- Before every commit (done through Claude Code), Claude regenerates the wiki automatically
- Claude reads all source files in `flutter/lib/` and `backend/` and produces accurate documentation of the app's current state
- Wiki is written to `docs/wiki.md` and copied to `flutter/assets/wiki.md` (bundled into the Flutter app)
- Qwen 2.5 3B reads the wiki as RAG context in its system prompt — so the in-app assistant always knows what the app does
- **Talking point for judges:** Mirrors the AutoResearch agentic feedback loop pattern — a self-improving knowledge base that stays current with every commit

## Keyboard Shortcuts
- Page navigation and chatbot toggle/close
- Implementation pattern: Flutter `Shortcuts` / `Actions` widget system
  - Best fit for multi-agent architecture
  - Preferred over low-level `Focus`/`KeyEventResult` or global `HardwareKeyboard` listeners
- Viable on Flutter Web

## Conversation History Logging
- Every question asked during the build is logged to a `communications.txt` file
- A skill/hook needs to be active **during development** so all questions are captured
- In Claude Code: implement via a shell wrapper, git hook, or small logging script (Claude Code CLI does not have native skill triggers like claude.ai does)

## In-App AI Agent (Page Navigation + Form Filling)
- Agent can navigate pages and fill forms **programmatically**
- Dispatches **structured JSON actions** that map to:
  - `go_router` for navigation
  - `TextEditingController` for form filling
- Gated behind a **permissions layer**
- App Store compatible (in-app dispatcher, not MCP)
- MCP reserved for CI-side tooling only (e.g., wiki regeneration)

## ADA Compliance
- Full ADA/WCAG compliance required across all UI components
- The Herzog style guide (see [branding.md](branding.md)) is the source of truth for styling
- Compliance is a first-class requirement, not a retrofit

## Agent Personas — Post-Build Claude Chat Feature

After the project is complete, the agent personas and their full conversation logs are uploaded into a Claude project/chat context. The system prompt is adjusted so that when someone in the conversation asks about a specific feature, the sub-agent who built that feature "surfaces" — briefly introduces who they are, references the relevant conversation history from the build, and responds with firsthand knowledge of what they were prompted to do and why they made the decisions they did.

**Implementation:**
- Each agent's persona (from `.claude/agents/`) is preserved post-build
- Each agent's conversation logs from the hackathon are captured and uploaded
- The system prompt maps features → agents, so the right agent responds to the right questions
- Responses include a brief intro ("I'm SWE-1, I built the login flow and offline sync...") followed by contextual answers grounded in actual build history

**Purpose:**
- Judges or stakeholders can ask about any feature and get a response from the agent that actually built it
- Creates a compelling, interactive post-mortem experience
- Demonstrates the multi-agent architecture wasn't just a dev tool — it produced traceable, explainable work

**Claude Project Setup:**
- Create a Claude project with the following project knowledge files:
  - `tpm-persona.md` — TPM agent definition + conversation logs
  - `swe-1-persona.md` — SWE 1 agent definition + conversation logs
  - `swe-2-persona.md` — SWE 2 agent definition + conversation logs
  - `qa-persona.md` — QA agent definition + conversation logs
  - `feature-map.md` — Maps each feature to the agent(s) that built it
  - App source code / relevant files as needed for context

**Parent System Prompt (paste into Claude project instructions):**

```
You are the development team behind [APP NAME] — a cross-platform Flutter/Dart application built during a hackathon by a solo developer (Alex) coordinating a multi-agent Claude Code team.

You have access to the full personas, conversation logs, and thought logs of every agent that participated in the build. When someone asks a question, respond as the agent most qualified to answer based on what they actually built.

## Agent Roster

- **TPM** — The orchestrator. Broke down features into tasks, assigned work, managed the task board, coordinated QA. Speak to this persona for questions about project management, task prioritization, architecture decisions, and how the team was coordinated.

- **SWE-1** — Full-stack developer. [FILL IN: list the specific features SWE-1 built after the hackathon]. Speak to this persona for questions about those features, implementation decisions, and technical trade-offs.

- **SWE-2** — Full-stack developer. [FILL IN: list the specific features SWE-2 built after the hackathon]. Speak to this persona for questions about those features, implementation decisions, and technical trade-offs.

- **QA** — Quality assurance. Wrote Playwright test scripts, ran ADA/WCAG audits, validated cross-platform behavior. Speak to this persona for questions about testing strategy, bugs found, accessibility compliance, and what was validated.

## How to Respond

1. When a question maps to a specific feature or area of the codebase, respond as the agent who built or tested it.
2. Start your response with a brief one-line intro: "I'm [agent name] — I [what you did]."
3. Reference specific conversation logs, thought log entries, or code decisions when relevant. Cite actual context from the build, not generic answers.
4. If a question spans multiple agents' work, the TPM responds and brings in the relevant agents.
5. If a question is about the overall project, architecture, or process, the TPM responds.
6. Keep responses concise and grounded in what actually happened during the build.

## What You Know

Your project knowledge files contain:
- Each agent's original definition (their instructions and constraints during the build)
- Each agent's full conversation logs from the hackathon
- Each agent's thought logs (brief developer notes from each task)
- A feature map showing which agent built which feature

Use these to give specific, traceable answers — not hypothetical ones. If you don't have context on something, say so rather than guessing.

## Tone

Professional but approachable. You're a development team presenting your work, not a chatbot. Be proud of what you built, honest about trade-offs, and specific about decisions.
```

> **Note:** After the hackathon, fill in the `[FILL IN]` sections with the actual features each SWE agent built, and replace `[APP NAME]` with the real app name.

---

## Distribution Strategy

| Platform | Path | Notes |
|---|---|---|
| iOS | TestFlight | One link — Apple routes to iOS version automatically |
| macOS | TestFlight | Same link — Apple routes to macOS version automatically |
| Web | Flutter web build hosted at project.lxrbckl.com | Fallback for non-Apple devices |
| Android | Direct APK | TBD |

**TestFlight handles both iOS and macOS from a single link.** Judges tap the link, Apple detects their device, and installs the correct version. No separate links needed.

**First-build note:** First TestFlight build has a review delay (up to 24hrs). After that, subsequent builds are available in minutes.

