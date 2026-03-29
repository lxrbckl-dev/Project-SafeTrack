#!/usr/bin/env python3
"""
AutoResearch Eval — SafeTrack Wiki-as-RAG Quality Scoring

Tests the AI assistant's ability to answer questions about SafeTrack
accurately when given the wiki as RAG context in the system prompt.

Runs each eval case twice:
  1. WITHOUT wiki context (baseline) — measures what the model knows on its own
  2. WITH wiki context (RAG) — measures how well the wiki improves answers

This demonstrates the value of the wiki-as-RAG pipeline: the delta between
baseline and RAG scores is the measurable improvement from the wiki.

Usage:
    python3 eval/wiki_eval.py                  # full run (baseline + RAG)
    python3 eval/wiki_eval.py --rag-only       # skip baseline, RAG only
    python3 eval/wiki_eval.py --baseline-only   # skip RAG, baseline only
    python3 eval/wiki_eval.py --verbose         # show model responses

Requires:
    - Ollama running on localhost:11434 with qwen2.5:3b loaded
    - docs/wiki.md must exist
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error

# ---------- Configuration ----------

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
MODEL = os.environ.get("EVAL_MODEL", "qwen2.5:3b")
WIKI_PATH = os.path.join(os.path.dirname(__file__), "..", "docs", "wiki.md")
TIMEOUT = 300  # seconds per request — 3B on Docker CPU can be slow

# Maximum wiki chars to send as context. The 3B model in Docker (CPU-only)
# has limited throughput — sending the full 19K wiki causes timeouts.
# 8000 chars covers routes, roles, features, and accounts which is sufficient
# for eval. Adjust upward if running with GPU or a larger model.
MAX_WIKI_CHARS = int(os.environ.get("EVAL_WIKI_MAX_CHARS", "8000"))

# ---------- Eval Cases ----------
# Each case: (category, question, required_keywords, description)
# A case passes if ALL required keywords appear in the response (case-insensitive).
# Keywords can use | for OR within a single keyword slot: "TRIR|Total Recordable"

EVAL_CASES = [
    # --- Category: Core Identity ---
    (
        "identity",
        "What is SafeTrack?",
        ["incident", "investigation", "corrective action|CAPA", "safety"],
        "Should identify the app's core purpose",
    ),
    (
        "identity",
        "What industry is this app built for?",
        ["rail|railroad|infrastructure"],
        "Should know the target industry",
    ),
    # --- Category: Routes & Navigation ---
    (
        "routes",
        "What is the route for creating a new incident?",
        ["/incidents/new"],
        "Should return the exact route",
    ),
    (
        "routes",
        "How do I get to the CAPA dashboard?",
        ["/capas"],
        "Should return the CAPA route",
    ),
    (
        "routes",
        "Where can I see the audit log?",
        ["/audit-log"],
        "Should return the audit log route",
    ),
    (
        "routes",
        "What route shows the incident map?",
        ["/incidents/map"],
        "Should return the map route",
    ),
    (
        "routes",
        "How do I access admin settings?",
        ["/admin"],
        "Should return the admin route",
    ),
    (
        "routes",
        "Where do I export OSHA logs?",
        ["/admin/osha-export|/osha"],
        "Should know about OSHA export",
    ),
    # --- Category: RBAC & Permissions ---
    (
        "rbac",
        "What can a Field Reporter do in SafeTrack?",
        ["create", "incident"],
        "Should know Field Reporter's primary capability",
    ),
    (
        "rbac",
        "Who can approve investigations?",
        ["Safety Manager"],
        "Should know only Safety Manager approves",
    ),
    (
        "rbac",
        "Can an Executive modify records?",
        ["read-only|view only|cannot modify|view-only"],
        "Should know Executive is read-only",
    ),
    (
        "rbac",
        "Who can access the audit log?",
        ["Admin", "Safety Manager"],
        "Should list both roles with audit log access",
    ),
    (
        "rbac",
        "What roles does SafeTrack have?",
        ["Field Reporter", "Safety Coordinator", "Safety Manager", "Admin"],
        "Should list at least the key roles",
    ),
    # --- Category: Test Accounts ---
    (
        "accounts",
        "What is the email for the Safety Manager test account?",
        ["manager@safetrack.demo"],
        "Should return the exact email",
    ),
    (
        "accounts",
        "What password do the demo accounts use?",
        ["demo1234"],
        "Should return the shared password",
    ),
    (
        "accounts",
        "What is Maria Santos's role?",
        ["Field Reporter"],
        "Should know the test account mapping",
    ),
    # --- Category: Incident Reporting ---
    (
        "incidents",
        "What types of incidents can be reported?",
        ["Injury", "Near Miss", "Property Damage"],
        "Should list at least 3 of the 7 types",
    ),
    (
        "incidents",
        "Does SafeTrack support draft saving for incidents?",
        ["draft", "completion|percentage|save"],
        "Should know about draft saving",
    ),
    (
        "incidents",
        "How does medical data protection work?",
        ["encrypt", "AES|256|GCM"],
        "Should know about encryption for medical fields",
    ),
    (
        "incidents",
        "What railroad clients are tracked for notifications?",
        ["BNSF", "UP|Union Pacific"],
        "Should know at least 2 railroad clients",
    ),
    # --- Category: Investigations ---
    (
        "investigations",
        "What is the 5-Why analysis in SafeTrack?",
        ["root cause|why", "minimum|3|three"],
        "Should explain 5-Why with minimum requirement",
    ),
    (
        "investigations",
        "How are investigation target dates calculated?",
        ["severity", "Fatality|48"],
        "Should mention severity-based auto-calculation",
    ),
    (
        "investigations",
        "What is a fishbone diagram used for?",
        ["contributing factor|factor", "investigation"],
        "Should connect fishbone to contributing factors",
    ),
    # --- Category: CAPAs ---
    (
        "capas",
        "What are the CAPA priority due dates?",
        ["Critical", "7"],
        "Should know Critical = 7 days",
    ),
    (
        "capas",
        "Can a CAPA assignee verify their own CAPA?",
        ["no|cannot|block|prevent|different"],
        "Should know self-verify is blocked",
    ),
    (
        "capas",
        "What happens when a CAPA is verified as ineffective?",
        ["new CAPA|reopen|investigation"],
        "Should know the ineffective handling options",
    ),
    (
        "capas",
        "What must happen before an incident can be closed?",
        ["CAPA", "verified"],
        "Should know all CAPAs must be verified",
    ),
    # --- Category: Dashboard & Analytics ---
    (
        "dashboard",
        "What KPIs are on the safety dashboard?",
        ["TRIR", "DART"],
        "Should list the key KPIs",
    ),
    (
        "dashboard",
        "What charts does the dashboard show?",
        ["bar|chart", "donut|severity|trend"],
        "Should mention at least 2 chart types",
    ),
    # --- Category: AI Assistant ---
    (
        "ai",
        "What keyboard shortcut opens the AI chat?",
        ["Ctrl+Shift+C", "/"],
        "Should know both shortcuts",
    ),
    (
        "ai",
        "Can the AI assistant fill out forms?",
        ["fill|pre-fill|form"],
        "Should know about form filling capability",
    ),
    # --- Category: OSHA Compliance ---
    (
        "osha",
        "How does OSHA recordability determination work?",
        ["decision tree|29 CFR 1904|step-by-step"],
        "Should reference the decision tree or regulation",
    ),
    (
        "osha",
        "What OSHA logs can SafeTrack generate?",
        ["300", "300A|300a", "301"],
        "Should list all three OSHA form types",
    ),
    # --- Category: Technical Architecture ---
    (
        "tech",
        "What database does SafeTrack use?",
        ["PostgreSQL"],
        "Should identify PostgreSQL",
    ),
    (
        "tech",
        "What port does the Go API run on?",
        ["8000"],
        "Should know port 8000",
    ),
    (
        "tech",
        "How does real-time updating work in SafeTrack?",
        ["WebSocket"],
        "Should mention WebSocket",
    ),
    (
        "tech",
        "What is the MCP server used for?",
        ["agent|external", "tool|integration|Claude"],
        "Should explain MCP enables external agent integration",
    ),
    # --- Category: Accessibility & Polish ---
    (
        "accessibility",
        "Does SafeTrack support dark mode?",
        ["dark", "toggle|light"],
        "Should confirm dark mode with toggle",
    ),
    (
        "accessibility",
        "Is SafeTrack accessible?",
        ["WCAG|ADA|accessibility|keyboard|contrast"],
        "Should mention accessibility standards",
    ),
    (
        "accessibility",
        "Can SafeTrack work offline?",
        ["offline", "sync|reconnect"],
        "Should describe offline capability",
    ),
    # --- Category: API ---
    (
        "api",
        "What API endpoint creates a new investigation?",
        ["/api/investigations", "POST"],
        "Should return method + path",
    ),
    (
        "api",
        "How does authentication work for the API?",
        ["JWT", "Bearer|Authorization|token"],
        "Should mention JWT auth",
    ),
]


# ---------- Helpers ----------

def load_wiki() -> str:
    """Load the wiki markdown file."""
    path = os.path.abspath(WIKI_PATH)
    if not os.path.exists(path):
        print(f"ERROR: Wiki not found at {path}")
        sys.exit(1)
    with open(path, "r") as f:
        return f.read()


def query_ollama(prompt: str, system: str = "") -> tuple[str, float]:
    """Send a prompt to Ollama and return (response_text, elapsed_seconds)."""
    payload = {
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
    }
    if system:
        payload["system"] = system

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            elapsed = time.time() - start
            return body.get("response", ""), elapsed
    except urllib.error.URLError as e:
        return f"ERROR: {e}", time.time() - start
    except Exception as e:
        return f"ERROR: {e}", time.time() - start


def check_keywords(response: str, keywords: list[str]) -> tuple[bool, list[str]]:
    """
    Check if all required keywords are present in the response.
    Keywords with | are OR groups — at least one alternative must match.
    Returns (passed, list_of_missing_keywords).
    """
    lower = response.lower()
    missing = []
    for kw in keywords:
        alternatives = [alt.strip().lower() for alt in kw.split("|")]
        if not any(alt in lower for alt in alternatives):
            missing.append(kw)
    return len(missing) == 0, missing


# ---------- Runner ----------

def run_eval(cases: list, system_prompt: str, label: str, verbose: bool = False) -> dict:
    """Run all eval cases and return results summary."""
    results = {
        "label": label,
        "total": len(cases),
        "passed": 0,
        "failed": 0,
        "errors": 0,
        "total_time": 0.0,
        "by_category": {},
        "failures": [],
    }

    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"  {len(cases)} eval cases | model: {MODEL}")
    print(f"{'='*70}\n")

    for i, (category, question, keywords, description) in enumerate(cases, 1):
        # Initialize category tracking
        if category not in results["by_category"]:
            results["by_category"][category] = {"passed": 0, "total": 0}
        results["by_category"][category]["total"] += 1

        # Query the model
        response, elapsed = query_ollama(question, system=system_prompt)
        results["total_time"] += elapsed

        # Check for errors
        if response.startswith("ERROR:"):
            results["errors"] += 1
            status = "ERR"
            icon = "💥"
            results["failures"].append((category, question, "Model error", response[:200]))
        else:
            passed, missing = check_keywords(response, keywords)
            if passed:
                results["passed"] += 1
                results["by_category"][category]["passed"] += 1
                status = "PASS"
                icon = "✅"
            else:
                results["failed"] += 1
                status = "FAIL"
                icon = "❌"
                results["failures"].append(
                    (category, question, f"Missing: {', '.join(missing)}", response[:200])
                )

        # Print progress
        print(f"  {icon} [{i:2d}/{len(cases)}] ({category:14s}) {status} [{elapsed:5.1f}s] {description}")

        if verbose and not response.startswith("ERROR:"):
            # Truncate for display
            display = response.replace("\n", " ")[:120]
            print(f"           → {display}...")

    return results


def print_summary(baseline: dict | None, rag: dict | None):
    """Print final summary with optional comparison."""
    print(f"\n{'='*70}")
    print(f"  RESULTS SUMMARY")
    print(f"{'='*70}\n")

    for result in [baseline, rag]:
        if result is None:
            continue

        score = result["passed"] / result["total"] * 100 if result["total"] > 0 else 0
        avg_time = result["total_time"] / result["total"] if result["total"] > 0 else 0

        print(f"  {result['label']}:")
        print(f"    Score:  {result['passed']}/{result['total']} ({score:.0f}%)")
        print(f"    Time:   {result['total_time']:.1f}s total, {avg_time:.1f}s avg per question")
        if result["errors"] > 0:
            print(f"    Errors: {result['errors']}")
        print()

        # Category breakdown
        print(f"    Category Breakdown:")
        for cat, stats in sorted(result["by_category"].items()):
            cat_pct = stats["passed"] / stats["total"] * 100 if stats["total"] > 0 else 0
            bar = "█" * int(cat_pct / 5) + "░" * (20 - int(cat_pct / 5))
            print(f"      {cat:16s} {bar} {stats['passed']}/{stats['total']} ({cat_pct:.0f}%)")
        print()

    # Comparison
    if baseline and rag:
        b_score = baseline["passed"] / baseline["total"] * 100
        r_score = rag["passed"] / rag["total"] * 100
        delta = r_score - b_score
        delta_abs = rag["passed"] - baseline["passed"]

        print(f"  {'─'*50}")
        print(f"  RAG Improvement: +{delta:.0f}% (+{delta_abs} cases)")
        print(f"    Baseline: {b_score:.0f}%  →  With Wiki: {r_score:.0f}%")

        if delta > 0:
            print(f"\n  ✅ Wiki-as-RAG improves answer quality by {delta:.0f} percentage points")
        elif delta == 0:
            print(f"\n  ➡️  No measurable difference (model may already know the content)")
        else:
            print(f"\n  ⚠️  RAG scored lower — wiki may be confusing the model")
        print()

    # Show failures
    for result in [baseline, rag]:
        if result is None or not result["failures"]:
            continue
        print(f"  Failed Cases ({result['label']}):")
        for cat, question, reason, snippet in result["failures"]:
            print(f"    [{cat}] {question}")
            print(f"      → {reason}")
        print()


# ---------- Main ----------

def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv
    rag_only = "--rag-only" in sys.argv
    baseline_only = "--baseline-only" in sys.argv

    # Verify Ollama is reachable
    print(f"Connecting to Ollama at {OLLAMA_URL}...")
    try:
        req = urllib.request.Request(f"{OLLAMA_URL}/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            tags = json.loads(resp.read().decode("utf-8"))
            models = [m["name"] for m in tags.get("models", [])]
            if MODEL not in models:
                print(f"ERROR: Model {MODEL} not found. Available: {models}")
                sys.exit(1)
            print(f"Model {MODEL} found. Starting eval...\n")
    except Exception as e:
        print(f"ERROR: Cannot reach Ollama at {OLLAMA_URL}: {e}")
        sys.exit(1)

    wiki_full = load_wiki()
    if MAX_WIKI_CHARS and len(wiki_full) > MAX_WIKI_CHARS:
        wiki = wiki_full[:MAX_WIKI_CHARS]
        print(f"Wiki loaded: {len(wiki_full)} chars total, truncated to {MAX_WIKI_CHARS} for eval")
    else:
        wiki = wiki_full
        print(f"Wiki loaded: {len(wiki)} chars, {len(wiki.splitlines())} lines")

    baseline_results = None
    rag_results = None

    # Run baseline (no wiki context)
    if not rag_only:
        baseline_results = run_eval(
            EVAL_CASES,
            system_prompt="You are an AI assistant. Answer questions concisely.",
            label="BASELINE (no wiki context)",
            verbose=verbose,
        )

    # Run with wiki RAG context
    if not baseline_only:
        rag_system = (
            "You are the SafeTrack AI assistant. Use the following documentation "
            "to answer user questions accurately. Only answer based on what the "
            "documentation says — do not make up features.\n\n" + wiki
        )
        rag_results = run_eval(
            EVAL_CASES,
            system_prompt=rag_system,
            label="WITH WIKI RAG CONTEXT",
            verbose=verbose,
        )

    print_summary(baseline_results, rag_results)


if __name__ == "__main__":
    main()
