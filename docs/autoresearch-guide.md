# AutoResearch Guide

> Eval-driven optimization of the SafeTrack AI assistant using wiki-as-RAG.

---

## Results

The eval suite measures how well the AI assistant answers questions about SafeTrack with and without the wiki injected as RAG context.

**Latest run (2026-03-29, Qwen 2.5 3B, Docker CPU):**

| Mode | Score | Avg Response Time |
|---|---|---|
| Baseline (no wiki) | **4/42 (10%)** | 3.9s |
| With Wiki RAG | **37/42 (88%)** | 11.6s |
| **Improvement** | **+79 percentage points** | — |

Category breakdown with wiki RAG:

| Category | Score | Notes |
|---|---|---|
| Routes | 6/6 (100%) | All route questions answered correctly |
| RBAC | 5/5 (100%) | Roles, permissions, access rules |
| Accounts | 3/3 (100%) | Test emails, passwords, role mappings |
| Incidents | 4/4 (100%) | Types, drafts, encryption, railroad |
| Dashboard | 2/2 (100%) | KPIs, chart types |
| OSHA | 2/2 (100%) | Decision tree, log types |
| Tech | 4/4 (100%) | Database, ports, WebSocket, MCP |
| Identity | 2/2 (100%) | App purpose, industry |
| CAPAs | 3/4 (75%) | Lifecycle, verification rules |
| Investigations | 2/3 (67%) | 5-Why, fishbone |
| Accessibility | 2/3 (67%) | Offline, WCAG |
| AI | 1/2 (50%) | Form filling (shortcuts missed) |
| API | 1/2 (50%) | Auth (specific endpoint missed) |

Without the wiki, the model knows almost nothing about SafeTrack — it scores 10%. With the wiki as RAG context, it accurately answers 88% of domain-specific questions. This is the measurable value of the wiki-as-RAG pipeline.

---

## How It Works

1. **Wiki generation:** Before every commit, `docs/wiki.md` is regenerated from the codebase and copied to `flutter/assets/wiki.md`
2. **RAG injection:** The Flutter chat widget loads the wiki from the bundled asset and sends it as the `system` field in chat API requests
3. **System prompt assembly:** The Go backend prepends the agent system prompt (role awareness, action dispatch instructions) and appends the wiki content
4. **Eval scoring:** The eval script sends the same questions with and without the wiki, then checks responses for required keywords

```
User question → Go backend → [system prompt + wiki RAG + user role] → Qwen 2.5 3B → response
                                                                            ↑
                                            wiki auto-regenerated on every commit
```

---

## Running the Eval

```bash
# Full run: baseline (no wiki) + RAG (with wiki) — shows the delta
python3 eval/wiki_eval.py

# RAG only (skip baseline — faster)
python3 eval/wiki_eval.py --rag-only

# Baseline only
python3 eval/wiki_eval.py --baseline-only

# Verbose mode (show model responses)
python3 eval/wiki_eval.py --verbose
```

**Requirements:**
- Ollama running on `localhost:11434` with `qwen2.5:3b` loaded
- `docs/wiki.md` must exist

**Environment variables:**
| Variable | Default | Purpose |
|---|---|---|
| `OLLAMA_URL` | `http://localhost:11434` | Ollama endpoint |
| `EVAL_MODEL` | `qwen2.5:3b` | Model to evaluate |
| `EVAL_WIKI_MAX_CHARS` | `8000` | Max wiki chars sent as context |

**Performance note:** On Docker CPU (no GPU passthrough on macOS), a full 42-case baseline + RAG run takes ~10 minutes with the model warm. First run may be longer due to cold start. For faster iteration, run Ollama natively to get Metal GPU acceleration — eval completes in under a minute:

```bash
# Native Ollama (sub-second inference, full wiki fits)
brew services start ollama
OLLAMA_URL=http://localhost:11434 EVAL_WIKI_MAX_CHARS=0 python3 eval/wiki_eval.py
```

---

## Eval Case Design

The eval suite has 42 cases across 13 categories. Each case has:
- A natural-language question (what a user would actually ask)
- Required keywords that must appear in the response (case-insensitive)
- Keywords support OR alternatives with `|` (e.g., `"TRIR|Total Recordable"`)
- A case passes only if ALL required keywords are present

Categories cover the full application surface: identity, routes, RBAC, test accounts, incident reporting, investigations, CAPAs, dashboard, AI assistant, OSHA compliance, technical architecture, accessibility, and API endpoints.

To add a new eval case, append to the `EVAL_CASES` list in `eval/wiki_eval.py`:
```python
(
    "category",
    "What is the question?",
    ["required_keyword_1", "keyword_2|alternative_2"],
    "Brief description of what this tests",
),
```

---

## The AutoResearch Loop

The eval enables a systematic optimization cycle:

### Phase 1: Optimize Wiki Content (current)

The wiki is the primary lever for improving assistant quality. The loop:

1. **Run eval** → establish current score (88%)
2. **Identify failures** → which categories score lowest?
3. **Improve wiki** → add missing content, restructure for clarity, front-load common questions
4. **Re-run eval** → did the score improve?
5. **Keep or revert** → only commit changes that improve the score
6. **Repeat**

Concrete improvement opportunities from the current run:
- CAPA priority due dates (Critical=7d) are in the wiki but after the 8K truncation — restructure to put key data earlier
- Keyboard shortcuts section could be more prominent
- API endpoint details are deep in the wiki — add a quick-reference section

### Phase 2: Automate (future)

Point an AutoResearch agent at the wiki file and let it iterate overnight:
```
program.md → tells AutoResearch what to optimize (wiki content + structure)
wiki.md → the RAG context (the optimization target)
wiki_eval.py → the scoring function (42 cases, keyword matching)
```

The agent modifies the wiki, runs the eval, keeps improvements, loops. This is the pattern Shopify used to achieve 53% performance improvement across 120 experiments on their agent definitions.

### Phase 3: Optimize Agent Definitions (future)

Same pattern, different target — optimize the Claude Code agent definitions:

**Eval cases:** "Given this task, did the agent produce working code?"
**Target files:** `.claude/agents/swe-1.md`, `.claude/agents/tpm.md`
**Scoring:** Code compiles, tests pass, style guide followed

---

## Files

| File | Purpose |
|---|---|
| `eval/wiki_eval.py` | Eval script — 42 cases, baseline + RAG comparison, category breakdown |
| `docs/wiki.md` | Source wiki — RAG context for the AI assistant |
| `flutter/assets/wiki.md` | Bundled copy loaded by the Flutter app |
| `flutter/lib/features/chat/data/chat_repository.dart` | Loads wiki asset, sends as `system` field |
| `backend/internal/handlers/chat.go` | Appends wiki to Ollama system prompt |
| `.claude/agents/*.md` | Agent definitions (Phase 3 optimization targets) |
